local Guardian = require("Enemies.Guardian")
local Enemy = require("Enemies.Enemy")
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

print("--- Starting Guardian Tests ---")

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

function mockGame:spawnExpandingCircle(...)
    -- mock
end

-- Reset EnemyRegistry
EnemyRegistry:reset(mockGame)

-- 2. Instantiate target basic enemy
local allyEnemy = Enemy:new({
    game = mockGame,
    x = 100,
    y = 100,
    name = "Basic",
    maxHp = 100,
    speed = 20,
})
mockGame:addObject(allyEnemy)

-- 3. Instantiate Guardian enemy close to the ally
local guardianInstance = Guardian:new({
    game = mockGame,
    x = 120,
    y = 100,
    name = "Guardian",
    auraRadius = 100,
    grantsShield = true,
    hasAura = true,
    shieldAmount = 50,
    auraMult = -0.25,
})
guardianInstance.navigator = nil
mockGame:addObject(guardianInstance)

-- Verify aura is applied
guardianInstance:update(0.1)
local auraApplied = allyEnemy.effectManager:getEffect("GuardianAura")
print("Aura applied on ally:", auraApplied ~= nil)
if auraApplied then
    print("[PASS] Guardian Aura applied successfully.")
else
    print("[FAIL] Guardian Aura was not applied.")
end

-- Verify damage reduction is applied through the aura
local red = allyEnemy:getStat("damageReductionMultiplier", 1)
print("Ally damage reduction multiplier:", red)
if math.abs(red - 0.75) < 0.0001 then
    print("[PASS] Ally inherited correct damage reduction.")
else
    print("[FAIL] Damage reduction calculation is incorrect.")
end

-- Verify shield is not yet granted
print("Ally shield initially:", allyEnemy.shield)
if allyEnemy.shield == 0 then
    print("[PASS] Shield not granted prematurely.")
else
    print("[FAIL] Shield granted prematurely.")
end

-- Tick forward by 5 seconds to trigger shield grant
guardianInstance:update(5.0)
print("Ally shield after 5s:", allyEnemy.shield)
if allyEnemy.shield == 50 then
    print("[PASS] Shield granted correctly after cooldown.")
else
    print("[FAIL] Shield was not granted.")
end

print("--- Guardian Tests Completed ---")
