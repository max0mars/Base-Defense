local Medic = require("Enemies.Medic")
local Enemy = require("Enemies.Enemy")
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

print("--- Starting Medic Tests ---")

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

function mockGame:spawnDamageNumber(amount, x, y, damageType)
    print(string.format("[HEAL EVENT] Spawned damage number of type %s with amount %d at (%d, %d)", damageType, amount, x, y))
end

-- Reset EnemyRegistry
EnemyRegistry:reset(mockGame)

-- 2. Instantiate damaged basic enemy
local targetEnemy = Enemy:new({
    game = mockGame,
    x = 100,
    y = 100,
    name = "Basic",
    maxHp = 100,
    speed = 20,
})
targetEnemy.hp = 50 -- Damaged
mockGame:addObject(targetEnemy)

-- 3. Instantiate Medic enemy
local medicInstance = Medic:new({
    game = mockGame,
    x = 110,
    y = 110,
    name = "Medic",
    range = 150,
    targets = 3,
    regenAmount = 20, -- heals 20 hp per second
})
medicInstance.navigator = nil
mockGame:addObject(medicInstance)

-- Verify initial targets attached
medicInstance:update(0.1)
print("Attached targets count:", #medicInstance.attachedTargets)
if #medicInstance.attachedTargets == 1 then
    print("[PASS] Medic attached to target enemy successfully.")
else
    print("[FAIL] Medic failed to attach to target.")
end

-- Update for 1 second of regeneration
medicInstance:update(1.0)
print(string.format("Target HP after 1.1s healing: %f (expected: 70.0)", targetEnemy.hp))
if targetEnemy.hp > 69.9 and targetEnemy.hp < 70.1 then
    print("[PASS] Medic healed target correctly.")
else
    print("[FAIL] Healing amount is incorrect.")
end

print("--- Medic Tests Completed ---")
