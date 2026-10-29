-- Testing/test_cursor_icons.lua
-- The game draws its own cursor in every scene. In battle it tells the player
-- what they're doing: the reload reticle over the battlefield during a wave
-- only, a targeting icon matching the card being played (on a turret, on the
-- main turret, a building to place, or anywhere), aiming a turret, and HUD
-- hovers with their own icons. Between battles: removing, buying, upgrading.

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
assert(pick() == "ui", "between waves the battlefield shows the normal pointer")
game:setState("wave")
assert(pick() == "reticle", "during a wave the battlefield shows the reticle")
assert(game:pickCursor(fx, fy, false, true) == "ui", "not over the base")
assert(game:pickCursor(fx, fy, true, false) == "ui", "an open menu gets the normal pointer")

-- The reticle tracks the main turret's reload
local mt = game.mainLazer
mt.cooldown = 0
assert(mt:getCharge() == 1, "a ready main turret is fully charged")
mt.cooldown = 1 / mt:getStat("fireRate") / 2
assert(math.abs(mt:getCharge() - 0.5) < 1e-9, "halfway through its reload it is half charged")
game:setState("startup")

-- 2. The targeting icon matches the card being played
game.inputMode = "placing"
assert(pick() == "placeBuilding", "a building card shows the place-building icon")
for _, mode in ipairs({ "targeting_spell", "targeting_area", "targeting_global" }) do
    game.inputMode = mode
    assert(pick() == "targetAnywhere", mode .. " cards go anywhere")
end
game.inputMode = "targeting_card"
game.activeCard = { payload = { effect = {} } }
assert(pick() == "targetTurret", "an effect card goes on a turret")
game.activeCard = { requiredType = "turret" }
assert(pick() == "targetTurret", "an instant that needs a turret goes on a turret")
game.activeCard = { payload = { isMainUpgrade = true } }
assert(pick() == "targetMainTurret", "a main-turret upgrade goes on the main turret")
game.activeCard = { requiredType = "mainturret" }
assert(pick() == "targetMainTurret", "an instant that needs the main turret goes on it")
game.activeCard = { payload = { requiredType = "mainturret" } }
assert(pick() == "targetMainTurret", "so does a payload that needs the main turret")
game.activeCard = nil
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
assert(pick() == "ui", "a selected turret that isn't being aimed doesn't")
game.inputHandler.selectedBuilding = mt
game.inputMode = "aiming"
assert(pick() ~= "aimTurret", "the main turret aims itself, so no aiming icon")
game.inputMode = "idle"
game.inputHandler.selectedBuilding = nil

-- 3b. Build Mode shows the hammer (the hand over buttons, the aim arrow while aiming a group)
local ih = game.inputHandler
ih.editMode = true
Cursor.reset()
assert(pick() == "buildMode", "Build Mode shows the hammer")
Cursor.wantHand = true
assert(pick() == "ui", "but a button under the mouse still gets the hand")
Cursor.reset()
ih.editSelection = { turret }
assert(pick() == "aimTurret", "aiming a group in Build Mode shows the aiming icon")
ih.editSelection = {}
ih.editMode = false
assert(pick() == "ui", "out of Build Mode the hammer goes away")

-- 4. HUD hovers flag their own icons, over targeting and aiming
Cursor.reset()
Cursor.setIcon("selectCard")
assert(pick() == "ui" and Cursor.current() == "selectCard", "hovering a hand card shows the card icon")
game.inputMode = "targeting_card"
assert(pick() == "ui" and Cursor.current() == "selectCard", "even while a card is waiting for its target")
game.inputMode = "idle"
Cursor.reset()
Cursor.setIcon("viewPile")
assert(Cursor.current() == "viewPile", "hovering a pile button shows the pile icon")
Cursor.reset()
assert(Cursor.icon == nil and Cursor.current() == "pointer", "icons reset each frame, back to the pointer")

-- 4b. What gets drawn: the battle's choice wins, menus drop back to the UI cursor
Cursor.reset()
Cursor.wantHand = true
assert(Cursor.current() == "hand", "a clickable shows the hand")
Cursor.use("reticle", 0.5)
assert(Cursor.current() == "reticle" and Cursor.charge == 0.5, "the battle's reticle carries its reload")
Cursor.usePointer()
assert(Cursor.current() == "hand", "a menu over the battle goes back to the hand / pointer")
Cursor.reset()

-- 4b2. "Choose One" card picks show the add-to-deck icon
local rs = game.rewardSystem
rs:activate("cards", 3)
assert(rs.isActive and rs.mode == "cards" and #rs.currentChoices > 0, "a Choose One card pick is open")
local cardMx, cardMy = rs.startX + rs.cardWidth / 2, rs.startY + rs.cardHeight / 2
love.mouse.getPosition = function() return cardMx, cardMy end
Cursor.reset()
assert(pcall(rs.draw, rs), "the Choose One screen draws")
assert(Cursor.current() == "addCard", "hovering one of its cards shows the add-to-deck icon (got " .. Cursor.current() .. ")")
love.mouse.getPosition = function() return 0, 0 end
rs.isActive = false
Cursor.reset()

-- 4c. The starting-hand screen covers the board: nothing behind it reacts
local scene = require("Scenes.game_scene")
game:setState("mulligan")
assert(game.gui:overlayActive(), "the starting-hand screen counts as an overlay")
local grid = game.base.buildGrid
local lockedSlot
for s = 1, grid.width * grid.height do
    if not grid.unlocked[s] and not grid.buildings[s] and game.base:isSlotVisible(s) then lockedSlot = s break end
end
local lx = grid.x + ((lockedSlot - 1) % grid.width + 0.5) * grid.cellSize
local ly = grid.y + (math.floor((lockedSlot - 1) / grid.width) + 0.5) * grid.cellSize
local sx, sy = Layout.worldToScreen(lx, ly)
love.mouse.getPosition = function() return sx, sy end
game.inputHandler:update(0)
assert(game.base.hoveredLockedSlot == nil and game.base.hoverTooltip == nil,
    "hovering a locked base slot behind it shows no unlock prompt")
local tokens, speed = game.tokens, game.time_mul
scene:mousepressed(sx, sy, 1)
assert(game.tokens == tokens and not grid.unlocked[lockedSlot], "clicking it unlocks nothing")
scene:keypressed("e")
scene:keypressed("q")
assert(game.time_mul == speed, "the speed keys don't change the battle behind it")
scene:keypressed("return")
assert(game:isState("startup"), "Enter still starts the battle")
assert(not game.gui:overlayActive(), "and the board is uncovered again")
love.mouse.getPosition = function() return 0, 0 end

-- 5. Every icon draws, along with the pointer and hand
local ok = true
for _, name in ipairs({ "selectCard", "addCard", "viewPile", "placeBuilding", "targetTurret", "targetMainTurret",
                        "targetAnywhere", "aimTurret", "buildMode", "removeCard", "buyCard", "upgradeCard" }) do
    local fine = Cursor.ICONS[name] ~= nil and pcall(Cursor.drawIcon, name, 100, 100)
    if not fine then log("  icon failed: " .. name) end
    ok = ok and fine
end
assert(ok, "every cursor icon exists and draws")
ok = pcall(Cursor.drawArrow, 10, 10) and pcall(Cursor.drawHand, 10, 10)
for _, name in ipairs({ "pointer", "hand", "reticle", "buyCard" }) do
    Cursor.reset(); Cursor.use(name ~= "pointer" and name ~= "hand" and name or nil)
    if name == "hand" then Cursor.wantHand = true end
    ok = ok and pcall(Cursor.draw, 50, 50)
end
assert(ok, "the pointer, hand and Cursor.draw all draw")
for _, c in ipairs({ 0, 0.5, 1 }) do ok = ok and pcall(Cursor.drawAim, 100, 100, c) end
assert(ok, "the reticle draws at any charge")

log("--- Cursor Icon Tests Completed with " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
