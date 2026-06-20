-- test_wave_director.lua
-- Standalone test script for the updated WaveDirector:generateWaveList implementation.

love = {
    math = {
        random = math.random
    }
}

local WaveDirector = require("Game.Spawning.WaveDirector")
local BattleDirector = require("Game.Spawning.BattleDirector")
local BattleTemplate = require("Game.Spawning.BattleTemplate")

print("--- Starting WaveDirector Tests ---")

local mockGame = { testingMode = true }
local wd = WaveDirector:new(mockGame)
local bd = BattleDirector:new(mockGame)

-- Discover Speeder, Armored, Carrier, Flyer
bd:forceDiscoverEnemy("Speeder")
bd:forceDiscoverEnemy("Armored")
bd:forceDiscoverEnemy("Carrier")
bd:forceDiscoverEnemy("Flyer")

local battleRoster = bd:buildBattleRoster({
    battleDangerTiers = { tier0min = 2, tier0max = 2, tier1min = 1, tier1max = 1 },
    specificEnemies = {}
})

-- Build a mock template with the new parameters
local template = BattleTemplate:new({
    id = "wave_test_template",
    validBattleRange = {min = 1, max = 5},
    numWaves = 3,
    lanesPerWave = {1, 2, 3},
    battleDangerTiers = {},
    relativeDifficulty = { 1.0, 1.5, 2.0 },
    waveDangerTiers = {
        [2] = { tier0min = 1 } -- only spawn tier0 (danger level 2) on wave 2
    },
    specificWaveEnemies = {
        [3] = { Speeder = 0.50 } -- 50% budget on Speeder in wave 3
    }
})



-- Test 2: lanesPerWave & relativeDifficulty
print("\nTest 2: lanesPerWave and relativeDifficulty:")
local spawns2, summary2, lanes2 = wd:generateWaveList(2, battleRoster, template, 67)
print("Budget scale (relativeDifficulty index 2 is 1.5) -> lanes = " .. tostring(lanes2))
if lanes2 == 2 then
    print("[PASS] Successfully fetched lane count of 2 for wave 2.")
else
    print("[FAIL] Failed to fetch lane count.")
end

-- Test 3: waveDangerTiers (restricts allowed pool)
print("\nTest 3: waveDangerTiers (wave 2 only tier0 - Speeder/Armored):")
local onlyTier0 = true
for _, s in ipairs(summary2) do
    if s.id == "Carrier" or s.id == "Flyer" then
        onlyTier0 = false
    end
end
if onlyTier0 then
    print("[PASS] waveDangerTiers successfully filtered out Carrier and Flyer.")
else
    print("[FAIL] waveDangerTiers failed to restrict pool.")
end

-- Test 4: specificWaveEnemies (pre-composed count)
print("\nTest 4: specificWaveEnemies (wave 3 composition contains Speeder):")
local spawns3, summary3, lanes3 = wd:generateWaveList(3, battleRoster, template, 130)
local hasSpeeder = false
for _, s in ipairs(summary3) do
    if s.id == "Speeder" then
        print(string.format("Wave 3 has %d Speeders spawned.", s.count))
        hasSpeeder = true
    end
end
if hasSpeeder then
    print("[PASS] specificWaveEnemies correctly pre-composed Speeders.")
else
    print("[FAIL] specificWaveEnemies failed to pre-compose.")
end

print("\n--- WaveDirector Tests Completed ---")
