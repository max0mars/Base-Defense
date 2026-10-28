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

-- (Scouting reports no longer use discovery: see test_prep_loop.lua)

print("ALL ENEMY DISCOVERY VERIFICATION CHECKS PASSED!")
