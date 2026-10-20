-- test_battle_director_level_progression.lua
-- Tests that battle templates no longer define numWaves or lanesPerWave,
-- and that BattleDirector properly dictates numWaves and lanesPerWave based on player level.

local BattleDirector = require("Game.Spawning.BattleDirector")
local BattleIndex = require("Game.Spawning.BattleIndex")

print("--- Starting BattleDirector Level Progression Tests ---")

local failed = false
local function assert_eq(actual, expected, desc)
    if actual ~= expected then
        print(string.format("[FAIL] %s: expected %s, got %s", desc, tostring(expected), tostring(actual)))
        failed = true
    else
        print(string.format("[PASS] %s", desc))
    end
end

-- 1. Check all templates in BattleIndex
print("\n1. Verifying BattleIndex templates do not have numWaves or lanesPerWave:")
for id, template in pairs(BattleIndex) do
    if type(template) == "table" and template.id then
        assert_eq(template.numWaves, nil, id .. " numWaves is nil")
        assert_eq(template.lanesPerWave, nil, id .. " lanesPerWave is nil")
    end
end

-- 2. Test BattleDirector numWaves and lanes per level bracket
print("\n2. Verifying BattleDirector wave and lane counts across level brackets:")
local bd = BattleDirector:new({})

-- Level 1: 3 waves, lanes {1, 1, 2}
assert_eq(bd:getNumWavesForLevel(1), 3, "Level 1 numWaves")
assert_eq(bd:getLanesForWave(1, 1), 1, "Level 1 wave 1 lanes")
assert_eq(bd:getLanesForWave(1, 2), 1, "Level 1 wave 2 lanes")
assert_eq(bd:getLanesForWave(1, 3), 2, "Level 1 wave 3 lanes")

-- Level 3 (bracket 2-4): 3 waves, lanes {1, 2, 2}
assert_eq(bd:getNumWavesForLevel(3), 3, "Level 3 numWaves")
assert_eq(bd:getLanesForWave(3, 1), 1, "Level 3 wave 1 lanes")
assert_eq(bd:getLanesForWave(3, 2), 2, "Level 3 wave 2 lanes")
assert_eq(bd:getLanesForWave(3, 3), 2, "Level 3 wave 3 lanes")

-- Level 6 (bracket 5-8): 4 waves, lanes {1, 2, 2, 3}
assert_eq(bd:getNumWavesForLevel(6), 4, "Level 6 numWaves")
assert_eq(bd:getLanesForWave(6, 1), 1, "Level 6 wave 1 lanes")
assert_eq(bd:getLanesForWave(6, 2), 2, "Level 6 wave 2 lanes")
assert_eq(bd:getLanesForWave(6, 3), 2, "Level 6 wave 3 lanes")
assert_eq(bd:getLanesForWave(6, 4), 3, "Level 6 wave 4 lanes")

-- Level 10 (bracket 9-13): 5 waves, lanes {2, 2, 3, 3, 4} (clamped to MAX_LANES = 3)
assert_eq(bd:getNumWavesForLevel(10), 5, "Level 10 numWaves")
assert_eq(bd:getLanesForWave(10, 1), 2, "Level 10 wave 1 lanes")
assert_eq(bd:getLanesForWave(10, 2), 2, "Level 10 wave 2 lanes")
assert_eq(bd:getLanesForWave(10, 3), 3, "Level 10 wave 3 lanes")
assert_eq(bd:getLanesForWave(10, 5), 3, "Level 10 wave 5 lanes clamped to 3")
assert_eq(bd:getLanesForWave(10, 5, false), 4, "Level 10 wave 5 lanes unclamped")

-- Level 15 (bracket 14-17): 6 waves, lanes {2, 2, 3, 3, 4, 4}
assert_eq(bd:getNumWavesForLevel(15), 6, "Level 15 numWaves")
assert_eq(bd:getLanesForWave(15, 6), 3, "Level 15 wave 6 lanes clamped to 3")
assert_eq(bd:getLanesForWave(15, 6, false), 4, "Level 15 wave 6 lanes unclamped")

-- Level 18 (bracket 18-19): 7 waves, lanes {2, 3, 3, 4, 4, 5, 5}
assert_eq(bd:getNumWavesForLevel(18), 7, "Level 18 numWaves")
assert_eq(bd:getLanesForWave(18, 7), 3, "Level 18 wave 7 lanes clamped to 3")
assert_eq(bd:getLanesForWave(18, 7, false), 5, "Level 18 wave 7 lanes unclamped")

-- Level 20 (bracket 20+): 8 waves, lanes {3, 3, 4, 4, 5, 5, 5, 6}
assert_eq(bd:getNumWavesForLevel(20), 8, "Level 20 numWaves")
assert_eq(bd:getLanesForWave(20, 1), 3, "Level 20 wave 1 lanes")
assert_eq(bd:getLanesForWave(20, 8), 3, "Level 20 wave 8 lanes clamped to 3")
assert_eq(bd:getLanesForWave(20, 8, false), 6, "Level 20 wave 8 lanes unclamped")

-- 3. Test generateBattle integration with persistent state
print("\n3. Testing generateBattle wave count:")
_G.PersistentState = { battlesCompleted = 0, discoveredEnemies = {} } -- Level 1
local waves1 = bd:generateBattle(1)
assert_eq(#waves1, 3, "generateBattle produces 3 waves for level 1")

_G.PersistentState = { battlesCompleted = 4, discoveredEnemies = {} } -- Level 5
local waves5 = bd:generateBattle(1)
assert_eq(#waves5, 4, "generateBattle produces 4 waves for level 5")

_G.PersistentState = { battlesCompleted = 19, discoveredEnemies = {} } -- Level 20
local waves20 = bd:generateBattle(1)
assert_eq(#waves20, 8, "generateBattle produces 8 waves for level 20")

if failed then
    error("Some tests failed")
else
    print("\nAll level progression tests passed!")
end
