-- test_battle_director_roster.lua
-- Standalone script to test roster building in BattleDirector.

love = {
    math = {
        random = math.random
    }
}

local BattleDirector = require("Game.Spawning.BattleDirector")
local BattleTemplate = require("Game.Spawning.BattleTemplate")

print("--- Starting BattleDirector Roster Tests ---")

local bd = BattleDirector:new({})

-- Discover Speeder (tier0), Armored (tier0), Carrier (tier1), Flyer (tier2)
bd:forceDiscoverEnemy("Speeder")
bd:forceDiscoverEnemy("Armored")
bd:forceDiscoverEnemy("Carrier")
bd:forceDiscoverEnemy("Flyer")

-- Let's construct a mock template
local mockTemplate = BattleTemplate:new({
    id = "mock_template",
    validBattleRange = {min = 1, max = 10},
    numWaves = 3,
    lanesPerWave = {1, 2, 2},
    battleDangerTiers = {
        tier0min = 2,
        tier0max = 2,
        tier1min = 1,
        tier1max = 1
    },
    allowedTypes = {},
    specificEnemies = { "BeastMaster" } -- Force bypass selection
})

local roster = bd:buildBattleRoster(mockTemplate)

print("\nResulting Locked Roster:")
local ids = {}
for _, e in ipairs(roster) do
    table.insert(ids, e.id)
end
print("[" .. table.concat(ids, ", ") .. "]")

-- Verification:
-- 2 tier0 enemies should be selected (Basic is not dangerLevel 2, so it should be Speeder and Armored)
-- 1 tier1 enemy should be selected (Carrier)
-- Specific enemy "BeastMaster" should be forcefully added
local hasSpeeder = false
local hasArmored = false
local hasCarrier = false
local hasBeastMaster = false
for _, id in ipairs(ids) do
    if id == "Speeder" then hasSpeeder = true end
    if id == "Armored" then hasArmored = true end
    if id == "Carrier" then hasCarrier = true end
    if id == "BeastMaster" then hasBeastMaster = true end
end

if hasSpeeder and hasArmored and hasCarrier and hasBeastMaster and #ids == 4 then
    print("[PASS] Roster correctly matches all selection requirements and specificEnemies bypass.")
else
    print("[FAIL] Roster failed to match expected selection.")
end

-- Test 2: Roster constraints with allowedTypes
print("\nTesting allowedTypes constraint (allowedTypes = {'armored'}):")
local mockTemplateTypes = BattleTemplate:new({
    id = "mock_template_types",
    validBattleRange = {min = 1, max = 10},
    numWaves = 3,
    lanesPerWave = {1, 2, 2},
    battleDangerTiers = {
        tier0min = 2,
        tier0max = 2
    },
    allowedTypes = { "armored" },
    specificEnemies = {}
})

local roster2 = bd:buildBattleRoster(mockTemplateTypes)
local ids2 = {}
for _, e in ipairs(roster2) do
    table.insert(ids2, e.id)
end
print("Resulting Roster with Type Constraint: [" .. table.concat(ids2, ", ") .. "]")
if #ids2 == 1 and ids2[1] == "Armored" then
    print("[PASS] allowedTypes restriction successfully filtered candidates to 'Armored'")
else
    print("[FAIL] allowedTypes filter failed.")
end

print("\n--- BattleDirector Roster Tests Completed ---")
