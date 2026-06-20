local SpawningUtils = require("Game.Spawning.SpawningUtils")
local WaveDirector = require("Game.Spawning.WaveDirector")
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

print("--- Starting Lane Spawning and Delay Scaling Tests ---")

-- 1. Test getScaledDelay formula
-- Subtraction: 5% per difficulty level above 1. Maximum reduction: 60%. Floor: 0.05 seconds.
local testCases = {
    -- baseDelay, difficulty, expected
    { 2.5, 1, 2.5 },   -- 0% reduction
    { 2.5, 2, 2.375 }, -- 5% reduction (2.5 * 0.95 = 2.375)
    { 2.5, 5, 2.0 },   -- 20% reduction (2.5 * 0.80 = 2.0)
    { 2.5, 13, 1.0 },  -- 60% reduction (2.5 * 0.40 = 1.0)
    { 2.5, 20, 1.0 },  -- capped at 60% reduction
    { 0.1, 13, 0.05 }, -- 60% reduction of 0.1 is 0.04 -> floor is 0.05
}

for i, tc in ipairs(testCases) do
    local got = SpawningUtils.getScaledDelay(tc[1], tc[2])
    if math.abs(got - tc[3]) < 0.0001 then
        print(string.format("[PASS] Test %d: getScaledDelay(%f, %d) = %f", i, tc[1], tc[2], got))
    else
        print(string.format("[FAIL] Test %d: getScaledDelay(%f, %d) expected %f, got %f", i, tc[1], tc[2], tc[3], got))
    end
end

-- 2. Test generateWaveList distribution into lanes
local mockGame = { testingMode = true }
EnemyRegistry:reset(mockGame)

-- Let's construct a mock BattleRoster
local roster = {}
for _, enemy in ipairs(EnemyRegistry.allEnemies) do
    if enemy.id == "Basic" or enemy.id == "Speeder" then
        table.insert(roster, enemy)
    end
end

local wd = WaveDirector:new(mockGame)
local laneQueues, summary, laneCount = wd:generateWaveList(1, roster, nil, 60)

print(string.format("Generated lane count: %d", laneCount))
print("Queues content:")
local totalEnemies = 0
for laneIndex, queue in ipairs(laneQueues) do
    print(string.format("  Lane %d queue size: %d", laneIndex, #queue))
    totalEnemies = totalEnemies + #queue
end

if #laneQueues == laneCount then
    print("[PASS] generateWaveList successfully returned correct number of lane queues.")
else
    print("[FAIL] generateWaveList lane queue count mismatch.")
end

-- 3. Test BattleLoop boilerplate execution
print("Testing BattleLoop runtime execution logic...")
local mockEnemy1 = { id = "Basic", baseSpawnDelay = 1.0 }
local mockEnemy2 = { id = "Speeder", baseSpawnDelay = 0.4 }

local testLaneQueues = {
    { mockEnemy1, mockEnemy2 },
    { mockEnemy2 }
}

local battleLoop = SpawningUtils.BattleLoop:new(testLaneQueues, 3) -- globalDifficulty = 3 (10% reduction)

-- Lane 1: Golem-like wait first: Golem is mockEnemy1 (1.0 * 0.9 = 0.9s delay).
-- Lane 2: Speeder is mockEnemy2 (0.4 * 0.9 = 0.36s delay).
print("Initial update step (dt = 0.1):")
battleLoop:updateSpawns(0.1) -- Lane 1 timer goes from 0.9 to 0.8. Lane 2 timer goes from 0.36 to 0.26. No spawns yet.

print("Updating timer by 0.3 (dt = 0.3):")
battleLoop:updateSpawns(0.3) -- Lane 2 timer hits zero. Lane 2 spawns mockEnemy2.

print("Updating timer by 0.51 (dt = 0.51):")
battleLoop:updateSpawns(0.51) -- Lane 1 timer hits zero. Lane 1 spawns mockEnemy1. Sets new delay for next enemy in Lane 1 (mockEnemy2: 0.36s).

print("Updating timer by 0.37 (dt = 0.37):")
battleLoop:updateSpawns(0.37) -- Lane 1 timer hits zero again. Lane 1 spawns mockEnemy2.

print("--- Lane Spawning and Delay Scaling Tests Completed ---")
