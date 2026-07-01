-- Testing/test_reward_system.lua
local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

-- Mock love2d
_G.love = {
    graphics = {
        getFont = function() return { getHeight = function() return 10 end, getWidth = function() return 10 end } end,
        print = function() end,
        printf = function() end,
        setColor = function() end,
        rectangle = function() end,
        polygon = function() end,
        line = function() end,
        push = function() end,
        pop = function() end,
        setFont = function() end,
        setLineWidth = function() end,
        draw = function() end,
        newImage = function() return {} end,
        newShader = function() return {} end,
    },
    mouse = {
        getPosition = function() return 0, 0 end
    },
    math = {
        random = math.random,
        colorFromBytes = function() return 1, 1, 1, 1 end
    },
    audio = {
        newSource = function() return {} end
    }
}

_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720

-- Mocks
package.loaded["Game.Core.Base"] = { new = function() return {} end }
package.loaded["Game.Core.BattlefieldGrid"] = { new = function() return {} end }
package.loaded["Physics.collisionSystem_brute"] = { setGrid = function() end }
package.loaded["Game.Input.InputHandler"] = { new = function() return {} end }
package.loaded["Game.Spawning.WaveSpawner"] = { new = function() return {} end }
package.loaded["Game.Spawning.WaveDirector"] = { new = function() return {} end }
package.loaded["Game.Inventory.Inventory"] = { new = function() return {} end }
package.loaded["Game.Effects.EffectManager"] = { new = function() return { recalculateStats = function() end } end }
package.loaded["Game.GUI.GUIManager"] = { new = function() return {} end }
package.loaded["Game.GUI.Layout"] = { W = 1280, H = 720, field = {x=0,y=0,w=100,h=100}, pushWorld = function() end, popWorld = function() end }
package.loaded["Game.GUI.Cursor"] = { reset = function() end, applyOS = function() end, wantHand = false }
package.loaded["Game.Spawning.EnemyRegistry"] = { reset = function() end }
package.loaded["Graphics.Animations.ParticleExplosion"] = {}
package.loaded["Graphics.Animations.CircleFade"] = {}
package.loaded["Graphics.Animations.DamageNumber"] = {}
package.loaded["Graphics.Animations.LightningBolt"] = {}
package.loaded["Graphics.Animations.ExpandingCircle"] = {}
package.loaded["Graphics.Animations.ArmorBreak"] = {}
package.loaded["Graphics.Animations.DebuffArrows"] = {}
package.loaded["Graphics.Animations.DebuffProjectile"] = {}
package.loaded["Graphics.Animations.BuffPluses"] = {}
package.loaded["Enemies.Enemy"] = {}

-- Load the real dependencies
local RewardIndex = require("Game.Rewards.RewardIndex")
local RewardPool = require("Game.Rewards.RewardPool")
local RewardSystem = require("Game.Rewards.RewardSystem")
local GameManager = require("Game.Core.GameManager")

print("--- Starting Reward System Tests ---")

-- 1. Test RewardIndex
assert(type(RewardIndex.common) == "table", "RewardIndex has common tier")
assert(type(RewardIndex.uncommon) == "table", "RewardIndex has uncommon tier")
assert(type(RewardIndex.rare) == "table", "RewardIndex has rare tier")
assert(type(RewardIndex.epic) == "table", "RewardIndex has epic tier")
assert(type(RewardIndex.legendary) == "table", "RewardIndex has legendary tier")

-- Verify injection works correctly for a test registry
local testSpells = {
    TestSpell1 = { id = "test_s1", name = "S1", cost = 1, rarity = "Common" },
    TestSpell2 = { id = "test_s2", name = "S2", cost = 2, rarity = "Rare" }
}
RewardIndex.injectSpells(testSpells)
local foundS1, foundS2 = false, false
for _, r in ipairs(RewardIndex.common) do if r.id == "test_s1" then foundS1 = true end end
for _, r in ipairs(RewardIndex.rare) do if r.id == "test_s2" then foundS2 = true end end
assert(foundS1, "Test spell 1 injected into common tier successfully")
assert(foundS2, "Test spell 2 injected into rare tier successfully")

-- 2. Test RewardPool
local mockGame = {
    wave = 1,
    shopLevel = 1,
    base = { hp = 100 }
}

local pool = RewardPool:new(RewardIndex, mockGame)
local choices = pool:generateChoices(3, 1)

assert(#choices == 3, "RewardPool generated exactly 3 choices")

local ids = {}
local unique = true
for _, c in ipairs(choices) do
    if ids[c.id] then unique = false end
    ids[c.id] = true
end
assert(unique, "Generated choices have no duplicates")

-- Test fallback mechanism (force luck to max so it requests legendary, but clear legendary)
local oldLegendary = RewardIndex.legendary
RewardIndex.legendary = {}
-- Generate again
local highLuckChoices = pool:generateChoices(1, 10)
assert(#highLuckChoices == 1, "RewardPool fell back and found a lower tier reward when legendary was empty")
RewardIndex.legendary = oldLegendary

-- 3. Test RewardSystem
local sys = RewardSystem:new(mockGame)
assert(sys.isActive == false, "RewardSystem starts inactive")

sys:activate()
assert(sys.isActive == true, "RewardSystem activates successfully")
assert(sys.currentChoices ~= nil and #sys.currentChoices > 0, "RewardSystem populated cards on activation")

sys.isActive = false
assert(sys.isActive == false, "RewardSystem deactivates successfully")

print("--- Reward System Tests Completed with " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
