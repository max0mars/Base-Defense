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

-- Test 4: Selecting template for battle 5 (range 4-8) - should be battle_early1 or battle_early2
print("\nTesting Battle 5 (weighted random between battle_early1 and battle_early2):")
local early1_count = 0
local early2_count = 0
for i = 1, 100 do
    local t = bd:selectTemplate(5)
    if t.id == "battle_early1" then
        early1_count = early1_count + 1
    elseif t.id == "battle_early2" then
        early2_count = early2_count + 1
    end
end
print(string.format("Out of 100 rolls: battle_early1 = %d, battle_early2 = %d", early1_count, early2_count))
if early1_count > 0 and early2_count > 0 then
    print("[PASS] Weighted selection working for battle range 4-8")
else
    print("[FAIL] Weighted selection did not roll both valid templates")
end

print("\n--- BattleDirector Template Tests Completed ---")
