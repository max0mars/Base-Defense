local BattleTemplate = require("Game.Spawning.BattleTemplate")
local BattleDirector = require("Game.Spawning.BattleDirector")

print("--- Starting BattleTemplate Limit Tests ---")

-- 1. Create a template with a limit of 2
local testTemplate = BattleTemplate:new({
    id = "TestLimitTemplate",
    validBattleRange = {min = 1, max = 5},
    numWaves = 3,
    lanesPerWave = {1, 1, 1},
    battleDangerTiers = { tier0min = 1 },
    limit = 2
})

-- Verify initial properties
print("Initial template count:", testTemplate.count)
if testTemplate.count == 0 then
    print("[PASS] Initial count is 0.")
else
    print("[FAIL] Initial count is incorrect.")
end

print("Template limit:", testTemplate.limit)
if testTemplate.limit == 2 then
    print("[PASS] Limit property is set correctly.")
else
    print("[FAIL] Limit property is incorrect.")
end

-- Verify validity
print("Is valid initially (battle 1):", testTemplate:isValidForBattle(1))
if testTemplate:isValidForBattle(1) == true then
    print("[PASS] Template is initially valid.")
else
    print("[FAIL] Template should be valid.")
end

-- Simulate picking
-- We can mock selectTemplate's dictionary reference or just manually invoke selectTemplate
-- Let's mock a simple BattleIndex
package.loaded["Game.Spawning.BattleIndex"] = {
    test = testTemplate
}

local bd = BattleDirector:new({ testingMode = true })

-- First pick
local picked1 = bd:selectTemplate(1)
print("First picked ID:", picked1 and picked1.id)
print("Template count after 1 pick:", testTemplate.count)
if testTemplate.count == 1 then
    print("[PASS] Count incremented to 1.")
else
    print("[FAIL] Count failed to increment.")
end

-- Second pick
local picked2 = bd:selectTemplate(1)
print("Second picked ID:", picked2 and picked2.id)
print("Template count after 2 picks:", testTemplate.count)
if testTemplate.count == 2 then
    print("[PASS] Count incremented to 2.")
else
    print("[FAIL] Count failed to increment.")
end

-- Verify invalid now
print("Is valid after reaching limit:", testTemplate:isValidForBattle(1))
if testTemplate:isValidForBattle(1) == false then
    print("[PASS] Template is correctly invalid after reaching limit.")
else
    print("[FAIL] Template should be invalid.")
end

-- Try third pick (should be nil since template is invalid now)
local picked3 = bd:selectTemplate(1)
print("Third picked ID (expected nil):", picked3)
if picked3 == nil then
    print("[PASS] Template was excluded from selection after reaching limit.")
else
    print("[FAIL] Template was selected past its limit.")
end

-- Clean up package.loaded
package.loaded["Game.Spawning.BattleIndex"] = nil

print("--- BattleTemplate Limit Tests Completed ---")
