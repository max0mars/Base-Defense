-- Regression: getAvailableEnemies crashed with "attempt to call method 'isType'"
-- once a mutation was active, because index entries are plain tables, not instances.

_G.love = {
    graphics = {
        getFont = function() return { getHeight = function() return 10 end, getWidth = function() return 10 end } end,
        print = function() end,
        printf = function() end,
        rectangle = function() end,
        setColor = function() end
    },
    math = { random = math.random }
}
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

print("--- STARTING ENEMY MUTATION VERIFICATION ---")

local shieldMutation = {
    id = "blueguardian_shield",
    name = "Shield Granter",
    modifiers = { grantsShield = { set = true } },
    target = "Guardian"
}

_G.PersistentState = {
    battlesCompleted = 0,
    discoveredEnemies = { ["Grunt"] = true, ["Guardian"] = true },
    activeMutations = { shieldMutation }
}
EnemyRegistry:reset({ testingMode = false })

-- 1. Available pool with an active mutation must not crash
local ok, available = pcall(EnemyRegistry.getAvailableEnemies, EnemyRegistry)
assert(ok, "getAvailableEnemies crashed with an active mutation: " .. tostring(available))
print("[PASS] getAvailableEnemies works with an active mutation.")

-- 2. Mutation applies to its target entry only
local guardian, grunt
for _, e in ipairs(available) do
    if e.id == "Guardian" then guardian = e end
    if e.id == "Grunt" then grunt = e end
end
assert(guardian and guardian.grantsShield == true, "Guardian pool entry should have grantsShield mutated to true")
assert(grunt and grunt.grantsShield == nil, "Grunt pool entry should be untouched")
print("[PASS] Mutation applies to the targeted pool entry only.")

-- 3. Mutation applies to a spawned instance of the target
local guardianClass
for _, e in ipairs(EnemyRegistry.allEnemies) do
    if e.id == "Guardian" then guardianClass = e.class end
end
local instance = guardianClass:new({ game = { objects = {}, base = { x = 0, w = 100 } } })
EnemyRegistry:applyActiveMutations(instance)
assert(instance.grantsShield == true, "Spawned Guardian instance should have grantsShield mutated to true")
print("[PASS] Mutation applies to a spawned instance of the target.")

-- 4. Triggering a mutation (the preparation scene path) must not crash
assert(pcall(EnemyRegistry.triggerRandomMutation, EnemyRegistry), "triggerRandomMutation crashed")
print("[PASS] triggerRandomMutation works with an active mutation.")

print("--- ALL ENEMY MUTATION TESTS PASSED ---")
