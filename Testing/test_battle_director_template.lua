-- test_battle_director_template.lua
-- Standalone script to test the template selection logic in BattleDirector.

-- Mock global love library for tests
love = {
    math = {
        random = math.random
    }
}

local BattleDirector = require("Game.Spawning.BattleDirector")
local BattleTemplate = require("Game.Spawning.BattleTemplate")

print("--- Starting BattleDirector Template Tests ---")

local bd = BattleDirector:new({})

-- Test 1: Selecting template for battle 1
print("\nTesting Battle 1:")
local t1 = bd:selectTemplate(1)
if t1 and t1.id == "battle_1" then
    print("[PASS] Successfully selected battle_1 for battle number 1")
else
    print("[FAIL] Failed to select battle_1 for battle number 1")
end

-- Test 2: Selecting template for battle 2
print("\nTesting Battle 2:")
local t2 = bd:selectTemplate(2)
if t2 and t2.id == "battle_2" then
    print("[PASS] Successfully selected battle_2 for battle number 2")
else
    print("[FAIL] Failed to select battle_2 for battle number 2")
end

-- Test 3: Selecting template for battle 3
print("\nTesting Battle 3:")
local t3 = bd:selectTemplate(3)
if t3 and t3.id == "battle_3" then
    print("[PASS] Successfully selected battle_3 for battle number 3")
else
    print("[FAIL] Failed to select battle_3 for battle number 3")
end

-- Test 4: Selecting template for battle 5 (range 4-8) - should be valid early game templates
print("\nTesting Battle 5 (weighted random among valid early templates):")
local rolled_templates = {}
for i = 1, 100 do
    local t = bd:selectTemplate(5)
    if t and t.id then
        rolled_templates[t.id] = (rolled_templates[t.id] or 0) + 1
        assert(t:isValidForBattle(5), "Template " .. t.id .. " must be valid for battle 5!")
    end
end

local distinctCount = 0
for id, count in pairs(rolled_templates) do
    distinctCount = distinctCount + 1
    print(string.format("  - %s: %d rolls", id, count))
end

if distinctCount >= 2 then
    print("[PASS] Weighted selection working for battle range 4-8 with multiple distinct templates.")
else
    print("[FAIL] Weighted selection did not roll multiple valid templates")
end

print("\n--- BattleDirector Template Tests Completed ---")
