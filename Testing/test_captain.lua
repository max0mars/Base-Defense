local Captain = require("Enemies.Captain")
local Enemy = require("Enemies.Enemy")
local Poison = require("Game.Effects.StatusEffects.Poison")
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

print("--- Starting Captain Debuff Clear Tests ---")

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

-- 2. Instantiate basic enemy
local targetEnemy = Enemy:new({
    game = mockGame,
    x = 100,
    y = 100,
    name = "Basic",
    maxHp = 100,
    speed = 20,
})
mockGame:addObject(targetEnemy)

-- 3. Instantiate Captain enemy
local captainInstance = Captain:new({
    game = mockGame,
    x = 110,
    y = 110,
    name = "Captain",
    range = 100,
    targets = 1,
    clearCooldown = 3.0,
})
captainInstance.navigator = nil
mockGame:addObject(captainInstance)

-- Verify initial state
print("Target has debuffs:", targetEnemy.effectManager:hasDebuff())
if not targetEnemy.effectManager:hasDebuff() then
    print("[PASS] Target initially has no debuffs.")
else
    print("[FAIL] Target has debuffs initially.")
end

-- Apply Poison debuff to target
local poisonEffect = Poison:new({
    name = "poison",
    duration_poison = 5.0,
    dps_poison = 10,
    maxStacks = 3,
})
targetEnemy.effectManager:applyEffect(poisonEffect)

print("Target has debuffs after application:", targetEnemy.effectManager:hasDebuff())
if targetEnemy.effectManager:hasDebuff() then
    print("[PASS] Poison debuff applied successfully.")
else
    print("[FAIL] Poison debuff failed to apply.")
end

-- Update Captain by 1.5 seconds (should not clear yet)
captainInstance:update(1.5)
print("After 1.5s - Target has debuffs:", targetEnemy.effectManager:hasDebuff())
if targetEnemy.effectManager:hasDebuff() then
    print("[PASS] Debuff was not cleared prematurely.")
else
    print("[FAIL] Debuff was cleared prematurely.")
end

-- Update Captain by another 1.5 seconds (reaches 3.0s, should clear debuff)
captainInstance:update(1.5)
print("After 3.0s - Target has debuffs:", targetEnemy.effectManager:hasDebuff())
if not targetEnemy.effectManager:hasDebuff() then
    print("[PASS] Debuff was cleared successfully by Captain.")
else
    print("[FAIL] Debuff was not cleared by Captain.")
end

print("--- Captain Debuff Clear Tests Completed ---")
