-- Testing/test_shooting.lua
-- Standalone test script to verify turret aiming, shooting, bullet movement, collision detection, and damage impact.

package.path = package.path .. ";./?.lua"

-- 1. Mock love library
_G.love = {
    math = {
        random = math.random
    },
    timer = {
        getTime = function() return 0 end
    }
}
math.atan2 = math.atan2 or math.atan

local EffectManager = require("Game.Effects.EffectManager")
local CollisionSystem = require("Physics.collisionSystem_brute")

-- 2. Mock Game State
local mockGame = {
    objects = {},
    ground = { x = 0, y = 0, w = 1000, h = 1000 },
    base = {
        x = 0,
        y = 100,
        w = 32,
        takeDamage = function() end,
        buildGrid = {
            x = 0,
            y = 0,
            width = 10,
            height = 10,
            cellSize = 32,
            buildings = {}
        }
    },
    addObject = function(self, obj)
        table.insert(self.objects, obj)
    end,
    EnemyDied = function(self, enemy)
        enemy.destroyed = true
    end,
    spawnParticleExplosion = function() end,
    spawnDamageNumber = function() end
}

mockGame.playerEffectManager = EffectManager:new(nil, mockGame)
mockGame.enemyEffectManager = EffectManager:new(nil, mockGame)

-- Initialize Collision System
CollisionSystem:setGrid(1000, 1000, 32)

local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

print("--- Starting Turret Aiming, Shooting, and Bullet Impact Tests ---")

-- 3. Load Classes
local Turret = require("Buildings.Turrets.Turret")
local TurretIndex = require("Buildings.TurretIndex")
local Enemy = require("Enemies.Enemy")

-- 4. Instantiate Turret and Enemy
local sentryConfig = {}
for k, v in pairs(TurretIndex.common[1]) do
    sentryConfig[k] = v
end
sentryConfig.game = mockGame
sentryConfig.x = 100
sentryConfig.y = 100
sentryConfig.rotation = 0

local turret = Turret:new(sentryConfig)
mockGame.objects[1] = turret

local enemy = Enemy:new({
    game = mockGame,
    x = 200,
    y = 100, -- Placed directly to the right of the turret
    size = 20,
    maxHp = 100,
    hp = 100
})
table.insert(mockGame.objects, enemy)

-- 5. Test Aiming & Target Acquisition
local target = turret:getTargetArc()
assert(target == enemy, "Turret acquires the enemy as a target")

-- Face away initially to test rotation
turret.rotation = math.pi
turret:lookAt(enemy.x, enemy.y, 0.1)
assert(math.abs(turret.rotation - 0) < 0.001, "Turret rotation successfully updates to aim at target (angle 0)")

-- 6. Test Firing
local initialObjectCount = #mockGame.objects
turret:fire()
local postFireObjectCount = #mockGame.objects
assert(postFireObjectCount == initialObjectCount + 1, "Firing adds a bullet object to the game objects list")

local bullet = mockGame.objects[postFireObjectCount]
assert(bullet ~= nil, "Bullet is instantiated successfully")
assert(bullet.source == turret, "Bullet lists the firing turret as its source")
assert(bullet:isType("bullet"), "Instantiated object has type 'bullet'")

-- 7. Run Game Loop Ticks to Simulate Bullet Movement and Impact
local bulletHitTarget = false
local ticks = 0
local dt = 0.01

while not bullet.destroyed and ticks < 100 do
    ticks = ticks + 1
    
    -- Update bullet
    bullet:update(dt)
    
    -- Rebuild collision grid
    CollisionSystem:resetGrid()
    for _, obj in ipairs(mockGame.objects) do
        if not obj.destroyed then
            CollisionSystem:addToGrid(obj)
        end
    end
    
    -- Check collisions between bullets and enemies
    CollisionSystem:checkCollisionsByType("bullet", "enemy")
end

assert(bullet.destroyed == true, "Bullet is destroyed after collision/lifespan expiration")
assert(enemy.hp < 100, "Enemy took damage from the bullet impact (HP: " .. enemy.hp .. "/100)")
assert(ticks < 100, "Bullet impacted the enemy within simulated timeframe (took " .. ticks .. " ticks)")

print("--- Aiming, Shooting, and Impact Tests Completed with " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
