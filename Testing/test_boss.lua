local BattleDirector = require("Game.Spawning.BattleDirector")
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

print("--- Starting Boss Spawning Tests ---")

-- 1. Setup mock game and objects
local mockGame = {
    objects = {},
    seenEnemies = {},
    testingMode = true,
    base = { x = 0, w = 100 }
}

-- Reset EnemyRegistry
EnemyRegistry:reset(mockGame)

-- Let's make sure there is a tier 5 enemy registered
-- In testingMode, Tank is tier 5 (from our earlier change)
local tankFound = false
for _, e in ipairs(EnemyRegistry.allEnemies) do
    if e.tier == 5 then
        tankFound = true
        print("Found registered tier 5 enemy in allEnemies:", e.id)
    end
end
if not tankFound then
    print("[FAIL] No tier 5 enemy registered in test environment.")
end

-- 2. Mock battlesCompleted = 19 (for Battle 20)
_G.PersistentState = {
    battlesCompleted = 19,
    globalDifficulty = 1,
    activeMutations = {},
    discoveredEnemies = { ["Basic"] = true, ["Tank"] = true }
}
EnemyRegistry:reset(mockGame)

local bd = BattleDirector:new(mockGame)
local upcomingWaves, upcomingSummaries, forecastTotals = bd:generateBattle(1)

-- Check waves count
local numWaves = #upcomingWaves
print("Total waves in Battle 20:", numWaves)

-- Check final wave summary for a tier 5 enemy
local finalWaveSummary = upcomingSummaries[numWaves]
local finalWaveContainsTier5 = false
local tier5Count = 0

for _, s in ipairs(finalWaveSummary) do
    local enemyData = nil
    for _, e in ipairs(EnemyRegistry.allEnemies) do
        if e.type == s.type then
            enemyData = e
            break
        end
    end
    
    if enemyData and enemyData.tier == 5 then
        finalWaveContainsTier5 = true
        tier5Count = s.count
        print(string.format("Final wave contains enemy: %s (Tier: %d) Count: %d", s.type, enemyData.tier, s.count))
    end
end

if finalWaveContainsTier5 and tier5Count == 1 then
    print("[PASS] Battle 20 final wave correctly spawned exactly one tier 5 enemy.")
else
    print("[FAIL] Battle 20 final wave failed to spawn exactly one tier 5 enemy.")
end

print("--- Boss Spawning Tests Completed ---")
