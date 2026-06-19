-- test_battle_director_discovery.lua
-- Standalone script to test the Discovered Enemies system in BattleDirector.

love = {
    math = {
        random = math.random
    }
}

local BattleDirector = require("Game.Spawning.BattleDirector")
local BattleTemplateDictionary = require("Game.Spawning.BattleTemplateDictionary")

print("--- Starting BattleDirector Discovery Tests ---")

local bd = BattleDirector:new({})

-- Helper to print discovered enemies list
local function printDiscovered()
    print("Discovered Enemies: [" .. table.concat(bd.discoveredEnemies, ", ") .. "]")
end

printDiscovered()

-- Test 1: updateDiscoveryPool for Battle 1 (needs 1x tier0 -> maps to danger level 2? Wait! No, basic is dangerLevel 1. Wait, let's see what is tier0 and tier1 mapping).
-- Let's test battle_early1 (requires tier0min=2, tier1min=1 -> dangerLevel 2 and dangerLevel 3)
local template_early1 = BattleTemplateDictionary.battle_early1
print("\nUpdating Discovery Pool for battle_early1 (requires tier0min=2, tier1min=1):")
bd:updateDiscoveryPool(template_early1)
printDiscovered()

-- Test 2: updateDiscoveryPool again for battle_early1 - shouldn't discover any more because requirements are met
print("\nUpdating Discovery Pool again for battle_early1 (should show nothing newly discovered):")
bd:updateDiscoveryPool(template_early1)
printDiscovered()

-- Test 3: forceDiscoverEnemy
print("\nForcefully discovering 'Flyer':")
bd:forceDiscoverEnemy("Flyer")
printDiscovered()

-- Test 4: forceDiscoverEnemy with already discovered enemy
print("\nForcefully discovering 'Flyer' again (should not duplicate):")
bd:forceDiscoverEnemy("Flyer")
printDiscovered()

print("\n--- BattleDirector Discovery Tests Completed ---")
