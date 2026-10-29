-- Testing/test_vault.lua
-- The Vault: an uncommon 2-cost passive that pays $50 when the battle is won.

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
local PassiveIndex = require("Buildings.PassiveIndex")

menu.scene_manager = { switch = noop }
menu:keypressed("return")
_G.PersistentState.selectedMainTurret = "MainLazer"
_G.PersistentState.discoveredEnemies = { Grunt = true }
_G.PersistentState.artifacts = {}
game:load(nil, false)
game:setState("wave")
local ps = _G.PersistentState

-- 1. Registered as an uncommon passive costing 2
local entry
for _, e in ipairs(PassiveIndex.uncommon) do if e.id == "vault" then entry = e end end
assert(entry and entry.cost == 2 and entry.name == "The Vault", "The Vault: uncommon passive, costs 2")
local types = {}
for _, t in ipairs(entry.types) do types[t] = true end
assert(types.passive and types.building and types.economy, "it's a passive economy building")

-- 2. Placed Vaults pay $50 each when the battle is won; a destroyed one pays nothing
local grid = game.base.buildGrid
local function placeVault(slot)
    local cfg = {}
    for k, v in pairs(entry) do cfg[k] = v end
    cfg.game = game
    local v = entry.building:new(cfg)
    grid.unlocked[slot] = true
    game:newBuilding(v, slot)
    return v
end
local v1 = placeVault(1)
local v2 = placeVault(3)
local v3 = placeVault(5)
assert(v1.cashOnBattleWon == 50, "a Vault holds $50")
v3.destroyed = true

local cashBefore = ps.cash or 0
game:payVaults()
assert(ps.cash == cashBefore + 100 and game.vaultIncome == 100, "each standing Vault pays $50 (a destroyed one doesn't)")

-- 3. Winning the battle pays them out
game.vaultIncome = 0
local beforeWin = ps.cash
ps.selectedBattle = { rewards = {} } -- no other battle rewards, to isolate the Vault
game:winBattle()
assert(game.vaultIncome == 100, "winning the battle pays the Vaults")
assert(ps.cash == beforeWin + 100 + (game.battleReward or 0), "and the cash goes into the run")

print("--- Vault Tests Completed with " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
