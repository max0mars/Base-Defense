-- test_phase5.lua
-- Standalone script to verify Phase 5: Dual-Difficulty, Enemy Unlocking, and Mutations.

local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
local WaveDirector = require("Game.Spawning.WaveDirector")
local SpeederGroup = require("Enemies.SpeederGroup")

print("--- Starting Phase 5 Tests ---")

-- Mock PersistentState
_G.PersistentState = {
    battlesCompleted = 0,
    globalDifficulty = 1,
    activeMutations = {},
    discoveredEnemies = { ["Basic"] = true }
}

-- 1. Test updatePools with globalDifficulty = 1
local mockGame = { testingMode = true }
EnemyRegistry:reset(mockGame)
EnemyRegistry:updatePools(_G.PersistentState.globalDifficulty)
local available = EnemyRegistry:getAvailableEnemies()
if #available == 1 and available[1].id == "Basic" then
    print("[PASS] Global Difficulty 1 correctly restricts to Basic enemy.")
else
    print("[FAIL] Global Difficulty 1 failed to restrict enemies. Count: " .. #available)
end

-- 2. Test updatePools with globalDifficulty = 3
_G.PersistentState.globalDifficulty = 3
EnemyRegistry:updatePools(_G.PersistentState.globalDifficulty)
available = EnemyRegistry:getAvailableEnemies()
if #available > 1 then
    print("[PASS] Global Difficulty 3 successfully unlocked a new enemy.")
else
    print("[FAIL] Global Difficulty 3 failed to unlock new enemies.")
end

-- 3. Test Mutation trigger and persistence
local initialMutationCount = #_G.PersistentState.activeMutations
EnemyRegistry:triggerRandomMutation()
if #_G.PersistentState.activeMutations > initialMutationCount then
    print("[PASS] triggerRandomMutation successfully added a mutation to PersistentState.")
else
    print("[FAIL] triggerRandomMutation failed.")
end

-- 4. Test Dual-Scaling formula
local BattleDirector = require("Game.Spawning.BattleDirector")
local bd = BattleDirector:new({})
local budget1 = bd:getBudgetForWave(nil, 1, 1)
local budget5 = bd:getBudgetForWave(nil, 5, 1)

local budget1_hard = bd:getBudgetForWave(nil, 1, 4)
local budget5_hard = bd:getBudgetForWave(nil, 5, 4)

if budget5 > budget1 and budget5_hard > budget1_hard and budget5_hard > budget5 then
    print(string.format("[PASS] Dual-scaling works. W1D1: %d, W5D1: %d | W1D4: %d, W5D4: %d", budget1, budget5, budget1_hard, budget5_hard))
else
    print("[FAIL] Dual-scaling failed to scale properly.")
end

print("--- Phase 5 Tests Completed ---")
