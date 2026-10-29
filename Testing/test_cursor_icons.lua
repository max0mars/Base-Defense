-- Testing/test_cursor_icons.lua
-- The battle cursor tells the player what they're doing: the reload reticle over
-- the battlefield during a wave only, and icons for selecting a card, targeting
-- a card, aiming a turret and checking a pile.

package.path = package.path .. ";./?.lua"

-- Mock love2d (every love.* function is a no-op; GameManager pulls in the whole game)
local noop = function() end
local fontStub = { getWidth = function() return 10 end, getHeight = function() return 10 end, getWrap = function() return 10, { "" } end }
_G.love = setmetatable({
    math = setmetatable({ random = math.random, colorFromBytes = function(...) return ... end }, { __index = function() return noop end }),
    timer = { getTime = function() return 0 end },
    mouse = setmetatable({ getPosition = function() return 0, 0 end }, { __index = function() return noop end }),
    keyboard = { isDown = function() return false end },
    graphics = setmetatable({
        getFont = function() return fontStub end,
        newFont = function() return fontStub end,
        newCanvas = function() return {} end,
        getWidth = function() return 1280 end,
        getHeight = function() return 720 end,
    }, { __index = function() return noop end }),
}, { __index = function() return setmetatable({}, { __index = function() return noop end }) end })
_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720
_G.SetGameScissor = noop
_G.paused = 0
math.atan2 = math.atan2 or math.atan

local log = print
print = noop -- silence game logging

local failures = 0
local function assert(condition, message)
    if not condition then
        log("[FAIL] " .. message)
        failures = failures + 1
    else
        log("[PASS] " .. message)
    end
end

local menu = require("Scenes.menu_scene")
local game = require("Game.Core.GameManager")
local Layout = require("Game.GUI.Layout")
local Cursor = require("Game.GUI.Cursor")
local TurretIndex = require("Buildings.TurretIndex")

menu.scene_manager = { switch = noop }
menu:keypressed("return")
_G.PersistentState.selectedMainTurret = "MainLazer"
_G.PersistentState.discoveredEnemies = { Grunt = true }
_G.PersistentState.artifacts = {}
game:load(nil, false)
game:setState("startup")

-- A point over the open battlefield (right of the base)
local fx, fy = Layout.worldToScreen(500, 300)
local function pick() return game:pickCursor(fx, fy, false, false) end

-- 1. Reticle only during a wave
game.inputMode = "idle"
Cursor.reset()
assert(pick() == "os", "between waves the battlefield shows the normal pointer")
game:setState("wave")
assert(pick() == "reticle", "during a wave the battlefield shows the reticle")
assert(game:pickCursor(fx, fy, false, true) == "os", "not over the base")
assert(game:pickCursor(fx, fy, true, false) == "os", "an open menu gets the normal pointer")

-- The reticle tracks the main turret's reload
local mt = game.mainLazer
mt.cooldown = 0
assert(mt:getCharge() == 1, "a ready main turret is fully charged")
mt.cooldown = 1 / mt:getStat("fireRate") / 2
assert(math.abs(mt:getCharge() - 0.5) < 1e-9, "halfway through its reload it is half charged")
game:setState("startup")

-- 2. Targeting a card (placing a building, or picking an instant/spell/area target)
for _, mode in ipairs({ "placing", "targeting_card", "targeting_spell", "targeting_area", "targeting_global" }) do
    game.inputMode = mode
    assert(pick() == "targetCard", mode .. " shows the targeting icon")
end
game.inputMode = "idle"

-- 3. Aiming a turret: just placed, or re-aimed between waves
local cfg = {}
for k, v in pairs(TurretIndex.common[1]) do cfg[k] = v end
cfg.game = game
local turret = require("Buildings.Turrets.Turret"):new(cfg)
game.inputHandler.selectedBuilding = turret
game.inputMode = "aiming"
assert(pick() == "aimTurret", "a just-placed turret shows the aiming icon")
game.inputMode = "idle"
game.inputHandler.reAimSelected = true
assert(pick() == "aimTurret", "re-aiming a turret between waves shows the aiming icon")
game.inputHandler.reAimSelected = false
assert(pick() == "os", "a selected turret that isn't being aimed doesn't")
game.inputHandler.selectedBuilding = mt
game.inputMode = "aiming"
assert(pick() ~= "aimTurret", "the main turret aims itself, so no aiming icon")
game.inputMode = "idle"
game.inputHandler.selectedBuilding = nil

-- 4. HUD hovers flag their own icons, over targeting and aiming
Cursor.reset()
Cursor.setIcon("selectCard")
assert(pick() == "selectCard", "hovering a hand card shows the card icon")
game.inputMode = "targeting_card"
assert(pick() == "selectCard", "even while a card is waiting for its target")
game.inputMode = "idle"
Cursor.reset()
Cursor.setIcon("viewPile")
assert(pick() == "viewPile", "hovering a pile button shows the pile icon")
Cursor.reset()
assert(Cursor.icon == nil, "icons reset each frame")

-- 5. Every icon draws
local ok = true
for name in pairs(Cursor.ICONS) do
    ok = ok and pcall(Cursor.drawIcon, name, 100, 100)
end
assert(ok, "every cursor icon draws")
for _, c in ipairs({ 0, 0.5, 1 }) do ok = ok and pcall(Cursor.drawAim, 100, 100, c) end
assert(ok, "the reticle draws at any charge")

log("--- Cursor Icon Tests Completed with " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
