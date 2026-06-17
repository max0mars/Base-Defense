-- Testing/test_damage_levels.lua
-- Standalone test suite verifying level-based persistent damage tracking

package.path = package.path .. ";./?.lua"

-- Mock love library
_G.love = {
    math = {
        colorFromBytes = function() return 1, 1, 1, 1 end,
        random = math.random
    }
}

local Base = require("Game.Core.Base")

print("--- Starting Level-Based Damage History Tests ---")

local failures = 0

local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

-- 1. Setup mock environment
_G.PersistentState = {
    battlesCompleted = 0,
    damageTracker = {}
}

local mockGame = {
    wave = 1,
    damageTakenThisBattle = 0,
    spawnDamageNumber = function() end
}

local mockBaseConfig = {
    game = mockGame,
    buildGrid = {
        x = 0, y = 0, cellSize = 25, width = 4, height = 16
    }
}

local baseInst = Base:new(mockBaseConfig)

-- 2. Mock source entity
local mockEnemy = {
    name = "FastEnemy",
    color = {1, 0, 0, 1},
    w = 20,
    h = 20,
    shape = "rectangle"
}

-- Apply damage in Level 1 (battlesCompleted = 0)
baseInst:takeDamage(10, "normal", 0, 0, mockEnemy, nil)
baseInst:takeDamage(15, "normal", 0, 0, mockEnemy, nil)

assert(_G.PersistentState.damageTracker[1] ~= nil, "Damage tracker recorded entries for Level 1")
assert(_G.PersistentState.damageTracker[1]["FastEnemy"].damage == 25, "Level 1 FastEnemy damage accumulated correctly (25)")

-- Simulate transition to Level 2 (battlesCompleted = 1)
_G.PersistentState.battlesCompleted = 1
mockGame.wave = 3 -- Wave inside Level 2 doesn't affect the level key

baseInst:takeDamage(50, "normal", 0, 0, mockEnemy, nil)

assert(_G.PersistentState.damageTracker[2] ~= nil, "Damage tracker recorded entries for Level 2")
assert(_G.PersistentState.damageTracker[2]["FastEnemy"].damage == 50, "Level 2 FastEnemy damage recorded correctly (50)")

-- 3. Verify processed history
local history = baseInst:getProcessedDamageHistory()
assert(#history == 2, "History contains two entries")
assert(history[1].level == 1 and history[1].damage == 25, "First historical entry matches Level 1")
assert(history[2].level == 2 and history[2].damage == 50, "Second historical entry matches Level 2")

print("--- Level-Based Damage History Tests Completed with " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
