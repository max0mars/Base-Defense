-- Setup mock LÖVE environment
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
local WaveSpawner = require("Game.Spawning.WaveSpawner")
local LevelManager = require("Game.Core.LevelManager")
local BattleManager = require("Game.Core.BattleManager")

print("--- STARTING ENEMY DISCOVERY VERIFICATION ---")

-- Reset persistent state
_G.PersistentState = {
    battlesCompleted = 0,
    discoveredEnemies = { ["Grunt"] = true }
}
EnemyRegistry:reset({ testingMode = false })

assert(_G.PersistentState.discoveredEnemies["Grunt"] == true, "Grunt should be discovered initially")
assert(_G.PersistentState.discoveredEnemies["Drone"] == nil, "Drone should NOT be discovered yet")
assert(_G.PersistentState.discoveredEnemies["Slime"] == nil, "Slime should NOT be discovered yet")
assert(_G.PersistentState.discoveredEnemies["Scout"] == nil, "Scout should NOT be discovered yet")

-- Create mock game and WaveSpawner
local mockGame = {
    objects = {},
    seenEnemies = {},
    testingMode = false,
    base = { x = 100, y = 200, w = 40, h = 40 },
    battlefieldGrid = { y = 0, cellSize = 40, height = 10 },
    addObject = function(self, obj)
        table.insert(self.objects, obj)
    end
}

local spawner = WaveSpawner:new({ game = mockGame })
spawner.waveInitialized = true

-- Find classes from EnemyRegistry.allEnemies
local droneEntry, slimeEntry, scoutEntry
for _, e in ipairs(EnemyRegistry.allEnemies) do
    if e.id == "Drone" then droneEntry = e end
    if e.id == "Slime" then slimeEntry = e end
    if e.id == "Scout" then scoutEntry = e end
end

assert(droneEntry and droneEntry.class, "Drone class found in EnemyRegistry")
assert(slimeEntry and slimeEntry.class, "Slime class found in EnemyRegistry")
assert(scoutEntry and scoutEntry.class, "Scout class found in EnemyRegistry")

-- Simulate spawning a Drone
spawner.waveState = "active"
spawner.waveList = { { droneEntry.class } }
spawner.laneTimers = { 0 }
spawner:update(1.0)

assert(_G.PersistentState.discoveredEnemies["Drone"] == true, "Drone must now be discovered in _G.PersistentState")
assert(EnemyRegistry.discoveredEnemiesMap["Drone"] == true, "Drone must be in EnemyRegistry.discoveredEnemiesMap")

-- Simulate spawning a Slime
spawner.waveState = "active"
spawner.waveList = { { slimeEntry.class } }
spawner.laneTimers = { 0 }
spawner:update(1.0)

assert(_G.PersistentState.discoveredEnemies["Slime"] == true, "Slime must now be discovered in _G.PersistentState")
assert(EnemyRegistry.discoveredEnemiesMap["Slime"] == true, "Slime must be in EnemyRegistry.discoveredEnemiesMap")

-- Simulate spawning a Scout
spawner.waveState = "active"
spawner.waveList = { { scoutEntry.class } }
spawner.laneTimers = { 0 }
spawner:update(1.0)

assert(_G.PersistentState.discoveredEnemies["Scout"] == true, "Scout must now be discovered in _G.PersistentState")
assert(EnemyRegistry.discoveredEnemiesMap["Scout"] == true, "Scout must be in EnemyRegistry.discoveredEnemiesMap")

-- Verify preparation scene choice formatting logic for cached major battle and level choice
local bm = BattleManager:new()
local lm = LevelManager:new(bm)

-- Generate major battle choices for level 5
local majorChoices = lm:generateChoices(5)
assert(#majorChoices == 1, "Milestone choice count is 1")
local majorChoice = majorChoices[1]

-- Check that any discovered enemy in the major choice enemies list correctly resolves
for _, enemy in ipairs(majorChoice.enemies or {}) do
    local rawId = enemy.id or (enemy.displayName ~= "???" and enemy.displayName)
    local canonicalId = EnemyRegistry:canonicalEnemyId(rawId) or rawId
    local isDiscovered = _G.PersistentState.discoveredEnemies[canonicalId] or EnemyRegistry.discoveredEnemiesMap[canonicalId]
    if canonicalId == "Grunt" or canonicalId == "Drone" or canonicalId == "Slime" or canonicalId == "Scout" then
        assert(isDiscovered == true, "Enemy " .. canonicalId .. " must be detected as discovered")
    end
end

-- If a major choice was generated BEFORE discovery:
local undiscoveredChoice = {
    enemies = {
        { id = "Drone", displayName = "???", isDiscovered = false },
        { id = "Tank", displayName = "???", isDiscovered = false }
    }
}

-- Check UI dynamic resolution (same logic as preparation_scene.lua):
for _, enemy in ipairs(undiscoveredChoice.enemies) do
    local rawId = enemy.id or (enemy.displayName ~= "???" and enemy.displayName)
    local canonicalId = EnemyRegistry:canonicalEnemyId(rawId) or rawId
    local isDiscovered = false
    if canonicalId then
        isDiscovered = _G.PersistentState.discoveredEnemies[canonicalId] or EnemyRegistry.discoveredEnemiesMap[canonicalId]
    end
    if enemy.id == "Drone" then
        assert(isDiscovered == true, "Pre-cached Drone with displayName='???' must dynamically resolve to discovered!")
    elseif enemy.id == "Tank" then
        assert(not isDiscovered, "Tank is not yet encountered, so must remain undiscovered")
    end
end

print("ALL ENEMY DISCOVERY VERIFICATION CHECKS PASSED!")
