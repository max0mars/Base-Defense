local Tank = require("Enemies.Tank")
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

print("--- Starting Tank Healing Multiplier Tests ---")

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

function mockGame:spawnDamageNumber(...)
    -- mock
end

-- Reset EnemyRegistry
EnemyRegistry:reset(mockGame)

-- 2. Instantiate Tank enemy
local tankInstance = Tank:new({
    game = mockGame,
    x = 100,
    y = 100,
    name = "Tank",
    maxHp = 1000,
    hp = 500, -- damaged
})
mockGame:addObject(tankInstance)

-- Verify healingMultiplier is correct in affinities
print("heal affinity:", tankInstance.affinities and tankInstance.affinities.heal)
if tankInstance.affinities and tankInstance.affinities.heal == 1.5 then
    print("[PASS] heal affinity is set correctly.")
else
    print("[FAIL] heal affinity is incorrect.")
end

-- Try healing
local healReceived = tankInstance:heal(100)
print("Healing received (base 100):", healReceived)
if healReceived == 150 then
    print("[PASS] Tank received 150 healing (1.5x multiplier).")
else
    print("[FAIL] Tank healing calculation failed.")
end

print("--- Tank Healing Multiplier Tests Completed ---")
