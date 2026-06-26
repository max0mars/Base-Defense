local EnemyIndex = require("Game.Spawning.EnemyIndex")
local TestingEnemyIndex = require("Game.Spawning.TestingEnemyIndex")
local Enemy = require("Enemies.Enemy")

print("--- Starting Sapper Verification Tests ---")

local function findSapper(index)
    for _, entry in ipairs(index) do
        if entry.id == "Sapper" then
            return entry
        end
    end
    return nil
end

local mainSapper = findSapper(EnemyIndex)
local testingSapper = findSapper(TestingEnemyIndex)

if mainSapper then
    print("[PASS] Sapper registered in EnemyIndex.lua")
    print("Sapper properties:")
    print("  Tier:", mainSapper.tier)
    print("  HP:", mainSapper.maxHp)
    print("  Speed:", mainSapper.speed)
    print("  Damage:", mainSapper.damage)
    print("  Size:", mainSapper.size)
else
    print("[FAIL] Sapper not found in EnemyIndex.lua")
end

if testingSapper then
    print("[PASS] Sapper registered in TestingEnemyIndex.lua")
else
    print("[FAIL] Sapper not found in TestingEnemyIndex.lua")
end

print("--- Sapper Verification Tests Completed ---")
