local EnemyIndex = require("Game.Spawning.EnemyIndex")
local TestingEnemyIndex = require("Game.Spawning.TestingEnemyIndex")
local Duplicator = require("Enemies.Duplicator")

print("--- Starting Slime Verification Tests ---")

local function findSlime(index)
    for _, entry in ipairs(index) do
        if entry.id == "Slime" then
            return entry
        end
    end
    return nil
end

local mainSlime = findSlime(EnemyIndex)
local testingSlime = findSlime(TestingEnemyIndex)

if mainSlime then
    print("[PASS] Slime registered in EnemyIndex.lua")
    print("Slime properties:")
    print("  Tier:", mainSlime.tier)
    print("  HP:", mainSlime.maxHp)
    print("  Class matches Duplicator:", mainSlime.class == Duplicator)
else
    print("[FAIL] Slime not found in EnemyIndex.lua")
end

if testingSlime then
    print("[PASS] Slime registered in TestingEnemyIndex.lua")
else
    print("[FAIL] Slime not found in TestingEnemyIndex.lua")
end

print("--- Slime Verification Tests Completed ---")
