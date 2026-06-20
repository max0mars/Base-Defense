local TurretDebuffer = require("Enemies.TurretDebuffer")
local Turret = require("Buildings.Turrets.Turret")
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

print("--- Starting TurretDebuffer Tests ---")

-- 1. Setup mock game and objects
local mockGame = {
    objects = {},
    seenEnemies = {},
    testingMode = true,
    base = { x = 0, w = 100 }
}

function mockGame:addObject(obj)
    table.insert(self.objects, obj)
    obj.game = self
end

function mockGame:EnemyDied(enemy)
    -- mock
end

-- Reset EnemyRegistry with mockGame
EnemyRegistry:reset(mockGame)

-- 2. Instantiate a Turret
local turretConfig = {
    name = "Test Sentry",
    rotation = 0,
    fireRate = 2.0,
    damage = 10,
    bulletSpeed = 300,
    range = 150,
    barrel = 10,
    firingArc = { direction = 0, minRange = 0, angle = 3.14 },
    shapePattern = {{0,0}},
    color = {1, 1, 1, 1},
    types = { building = true, turret = true },
    game = mockGame
}
local turretInstance = Turret:new(turretConfig)
mockGame:addObject(turretInstance)

-- 3. Instantiate the Drone (TurretDebuffer subclass)
local droneConfig = {
    game = mockGame,
    x = 100,
    y = 100,
    name = "Drone",
    numTargets = 1,
    debuffStacks = 5,
    debuffDuration = nil,
    debuffFrequency = 3.0,
    stickyTargets = true,
    debuffStat = "fireRate",
    debuffAmount = -0.01,
}

local droneInstance = TurretDebuffer:new(droneConfig)
droneInstance.navigator = nil
mockGame:addObject(droneInstance)

-- 4. Initial Checks
local baseFireRate = turretInstance:getStat("fireRate")
print(string.format("Initial fire rate: %f (expected: 2.0)", baseFireRate))
if math.abs(baseFireRate - 2.0) < 0.0001 then
    print("[PASS] Initial fire rate is correct.")
else
    print("[FAIL] Initial fire rate is incorrect.")
end

-- 5. Trigger first tick (on spawn, debuffTimer = 0)
droneInstance:update(0.1)
local rateStack1 = turretInstance:getStat("fireRate")
print(string.format("After first tick fire rate: %f (expected: 1.98)", rateStack1))
if math.abs(rateStack1 - 1.98) < 0.0001 then
    print("[PASS] Stack 1 debuff applied correctly.")
else
    print("[FAIL] Stack 1 debuff incorrect.")
end

-- 6. Tick forward by 1.5 seconds (no new debuff)
droneInstance:update(1.5)
local rateNoChange = turretInstance:getStat("fireRate")
if math.abs(rateNoChange - 1.98) < 0.0001 then
    print("[PASS] Delay tick did not apply a second debuff prematurely.")
else
    print("[FAIL] Debuff applied too early.")
end

-- 7. Tick forward by another 1.5 seconds (total 3.0s, triggers second stack)
droneInstance:update(1.5)
local rateStack2 = turretInstance:getStat("fireRate")
local expectedRateStack2 = 2.0 * (1 - 0.02) -- 1.96
print(string.format("After second tick fire rate: %f (expected: %f)", rateStack2, expectedRateStack2))
if math.abs(rateStack2 - expectedRateStack2) < 0.0001 then
    print("[PASS] Stack 2 debuff applied and accumulated correctly.")
else
    print("[FAIL] Stack 2 debuff incorrect.")
end

-- 8. Destroy the drone and check if debuffs are cleared
droneInstance:died()
local rateRestored = turretInstance:getStat("fireRate")
print(string.format("After drone death, fire rate: %f (expected: 2.0)", rateRestored))
if math.abs(rateRestored - 2.0) < 0.0001 then
    print("[PASS] All drone debuffs cleared from turret upon death.")
else
    print("[FAIL] Drone debuffs failed to clear on death.")
end

print("--- TurretDebuffer Tests Completed ---")
