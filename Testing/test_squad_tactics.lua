-- Testing/test_squad_tactics.lua
-- Squad Tactics: a rare 1-cost instant giving turrets in a 2x2 square +20% damage.

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

local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

local menu = require("Scenes.menu_scene")
local game = require("Game.Core.GameManager")
local Layout = require("Game.GUI.Layout")

menu.scene_manager = { switch = noop }
menu:keypressed("return")
_G.PersistentState.selectedMainTurret = "MainLazer"
_G.PersistentState.discoveredEnemies = { Grunt = true }
_G.PersistentState.artifacts = {}
game:load(nil, false)
game:setState("wave")

local InstantIndex = require("Instants.InstantIndex")
local CardFactory = require("Game.Cards.CardFactory")
local TurretIndex = require("Buildings.TurretIndex")

-- 1. Registered as a rare costing 1
local entry
for _, e in ipairs(InstantIndex.rare) do if e.id == "inst_squad_tactics_1" then entry = e end end
assert(entry and entry.cost == 1, "Squad Tactics: rare instant, costs 1")

-- 2. Place three sentries: two inside the 2x2 square at columns 0-1, rows 3-4, one outside
local grid = game.base.buildGrid
local function place(x, y)
    local cfg
    for _, e in ipairs(TurretIndex.common) do if e.id == "sentry" then cfg = {} for k, v in pairs(e) do cfg[k] = v end end end
    cfg.game = game
    local t = cfg.building:new(cfg)
    local slot = y * grid.width + x + 1
    grid.unlocked[slot] = true
    game:newBuilding(t, slot)
    return t
end
local a, b, outside = place(0, 3), place(1, 4), place(3, 3)
local baseDmg = a:getStat("damage")

local ih = game.inputHandler
local function mouseAtWorld(wx, wy)
    local sx, sy = Layout.worldToScreen(wx, wy)
    love.mouse.getPosition = function() return sx, sy end
    ih:update(0)
    return sx, sy
end

-- The square snaps to the grid corner nearest the mouse
local cs = grid.cellSize
mouseAtWorld(grid.x + 1 * cs + 3, grid.y + 4 * cs - 2)
local area = ih:getAreaTarget(2)
assert(area and area.x == grid.x and area.y == grid.y + 3 * cs and area.w == 2 * cs and area.h == 2 * cs,
    "the 2x2 square is centred on the nearest grid corner")
local inArea = {}
for _, t in ipairs(area.turrets) do inArea[t] = true end
assert(inArea[a] and inArea[b] and not inArea[outside] and #area.turrets == 2, "it holds the turrets inside it only")

-- Near the grid's edge the square stays inside the grid
mouseAtWorld(grid.x + 2, grid.y + 2)
local corner = ih:getAreaTarget(2)
assert(corner.x == grid.x and corner.y == grid.y, "the square is kept inside the grid")

-- 3. Playing it: selecting the card enters area targeting, the click buffs the turrets inside
local card = CardFactory.fromReward({ id = "inst_squad_tactics_1", type = "instant" })
game.hand = { card }
game.tokens = 3
game.inputMode = "idle"
game.gui.hand:selectCard(card, 0, 0)
assert(game.inputMode == "targeting_area" and game.activeCard == card, "selecting the card enters area targeting")

local sx, sy = mouseAtWorld(grid.x + 1 * cs, grid.y + 4 * cs)
ih:mousepressed(sx, sy, 1)
assert(math.abs(a:getStat("damage") - baseDmg * 1.2) < 1e-6 and math.abs(b:getStat("damage") - baseDmg * 1.2) < 1e-6,
    "turrets in the square get +20% damage")
assert(math.abs(outside:getStat("damage") - baseDmg) < 1e-6, "a turret outside the square is unaffected")
assert(game.tokens == 2 and #game.hand == 0 and game.inputMode == "idle", "the card is spent (1 token)")

-- 4. A square with no turrets in it refunds the card
local card2 = CardFactory.fromReward({ id = "inst_squad_tactics_1", type = "instant" })
game.hand = { card2 }
game.gui.hand:selectCard(card2, 0, 0)
sx, sy = mouseAtWorld(grid.x + 3 * cs, grid.y + 10 * cs)
ih.holdFireUntilRelease = false
ih:mousepressed(sx, sy, 1)
assert(#game.hand == 1 and game.tokens == 2 and game.inputMode == "idle", "an empty square refunds the card")

print("--- Squad Tactics Tests Completed with " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
