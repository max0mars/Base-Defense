local PortalMaster = require("Enemies.PortalMaster")
local Enemy = require("Enemies.Enemy")
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

print("--- Starting Portal Master Teleport Tests ---")

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

function mockGame:spawnExpandingCircle(x, y, startRadius, endRadius, color, duration)
    -- mock
end

-- Reset EnemyRegistry
EnemyRegistry:reset(mockGame)

-- 2. Instantiate basic enemy (moving left towards x=0)
local targetEnemy = Enemy:new({
    game = mockGame,
    x = 200,
    y = 100,
    name = "Basic",
    maxHp = 100,
    speed = 20,
})
mockGame:addObject(targetEnemy)

-- 3. Instantiate Portal Master enemy
local portalMasterInstance = PortalMaster:new({
    game = mockGame,
    x = 210,
    y = 110,
    name = "PortalMaster",
    range = 120,
    targets = 1,
    teleportDistance = 80,
    teleportCooldown = 3.0,
})
portalMasterInstance.navigator = nil
mockGame:addObject(portalMasterInstance)

-- Verify initial positions
print("Initial target X:", targetEnemy.x)
if targetEnemy.x == 200 then
    print("[PASS] Target is at correct initial position.")
else
    print("[FAIL] Target position is incorrect.")
end

-- Update Portal Master by 1.5 seconds (should not teleport yet)
portalMasterInstance:update(1.5)
print("After 1.5s - target X:", targetEnemy.x)
if targetEnemy.x == 200 then
    print("[PASS] Target was not teleported prematurely.")
else
    print("[FAIL] Target was teleported prematurely.")
end

-- Update Portal Master by another 1.5 seconds (reaches 3.0s, should teleport target forward)
-- Note: default movement direction for enemies is left towards target (0), so it should move to x = 200 - 80 = 120
portalMasterInstance:update(1.5)
print("After 3.0s - target X:", targetEnemy.x)
if targetEnemy.x == 120 then
    print("[PASS] Target was teleported forward correctly.")
else
    print("[FAIL] Target teleport position is incorrect.")
end

print("--- Portal Master Teleport Tests Completed ---")
