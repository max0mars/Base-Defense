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

-- The first grant comes soon after spawning (0.1s has already passed above)
guardianInstance:update(guardianInstance.firstShieldDelay - 0.3)
if allyEnemy.shield == 0 then
    print("[PASS] Shield not granted before the first delay ends.")
else
    print("[FAIL] Shield granted before the first delay ends.")
end
guardianInstance:update(0.3)
print("Ally shield after the first delay:", allyEnemy.shield)
if allyEnemy.shield == 50 then
    print("[PASS] First shield granted soon after spawning.")
else
    print("[FAIL] First shield was not granted.")
end

-- After that, one grant per full cooldown
allyEnemy.shield = 0
guardianInstance:update(guardianInstance.shieldCooldown - 0.2)
if allyEnemy.shield == 0 then
    print("[PASS] Shield not granted again before the cooldown ends.")
else
    print("[FAIL] Shield granted again before the cooldown ends.")
end
guardianInstance:update(0.2)
if allyEnemy.shield == 50 then
    print("[PASS] Shield granted again after the cooldown.")
else
    print("[FAIL] Shield was not granted again after the cooldown.")
end

-- Defaults and the target cap: only the 5 closest allies in range get shields
local failures = 0
local function check(cond, msg)
    print((cond and "[PASS] " or "[FAIL] ") .. msg)
    if not cond then failures = failures + 1 end
end

local defaults = Guardian:new({ game = mockGame, x = 300, y = 300, name = "Guardian" })
check(defaults.shieldCooldown == 12, "Shield cooldown is 12s")
check(defaults.firstShieldDelay == 1.5 and math.abs(defaults.shieldTimer - 10.5) < 1e-9,
    "First shield comes 1.5s after spawning")
check(defaults.shieldAmount == 100, "Shield amount is 100 (50 + 50)")
check(defaults.shieldRadius == 90, "Shield range is 90 (75 + 20%)")
check(defaults.maxShieldTargets == 5, "Shields at most 5 allies")

mockGame.objects = {}
local guardian = Guardian:new({ game = mockGame, x = 300, y = 300, name = "Guardian" })
guardian.navigator = nil
mockGame:addObject(guardian)
local allies = {}
for i = 1, 7 do
    local ally = Enemy:new({ game = mockGame, x = 300 + i * 10, y = 300, name = "Basic", maxHp = 100 })
    mockGame:addObject(ally)
    allies[i] = ally
end
local far = Enemy:new({ game = mockGame, x = 300, y = 300 + guardian.shieldRadius + 5, name = "Basic", maxHp = 100 })
mockGame:addObject(far)
local shielded = guardian:grantShieldsToNearby()
check(#shielded == 5, "One grant shields exactly 5 allies")
for i = 1, 7 do
    check((allies[i].shield > 0) == (i <= 5), "Ally " .. i .. (i <= 5 and " (among the 5 closest) is shielded" or " (farther) is not"))
end
check(far.shield == 0, "An ally outside the shield range is not shielded")
check(allies[1].shield == 100 and allies[1].maxShield == 100, "Shielded allies get 100 shield")

-- Already-shielded allies don't use up the cap: the next grant reaches the rest
shielded = guardian:grantShieldsToNearby()
check(#shielded == 2 and allies[6].shield == 100 and allies[7].shield == 100,
    "A second grant tops up the 2 allies left over")

-- Allies without a shield come first, even when a partly shielded one is closer
mockGame.objects = {}
guardian = Guardian:new({ game = mockGame, x = 300, y = 300, name = "Guardian" })
guardian.navigator = nil
mockGame:addObject(guardian)
local near, bare = {}, {}
for i = 1, 5 do
    near[i] = Enemy:new({ game = mockGame, x = 300 + i * 5, y = 300, name = "Basic", maxHp = 100 })
    near[i].shield = 40
    mockGame:addObject(near[i])
end
for i = 1, 3 do
    bare[i] = Enemy:new({ game = mockGame, x = 300 + 60 + i * 5, y = 300, name = "Basic", maxHp = 100 })
    mockGame:addObject(bare[i])
end
shielded = guardian:grantShieldsToNearby()
local bareFirst = #shielded == 5 and bare[1].shield == 100 and bare[2].shield == 100 and bare[3].shield == 100
check(bareFirst, "The 3 unshielded allies are shielded before closer, partly shielded ones")
check(near[1].shield == 100 and near[2].shield == 100 and near[3].shield == 40,
    "The remaining 2 slots go to the closest partly shielded allies")
check(guardian.shield == 0, "The Guardian doesn't shield itself while allies are in range")

-- No allies in range: it shields itself
mockGame.objects = {}
guardian = Guardian:new({ game = mockGame, x = 300, y = 300, name = "Guardian" })
guardian.navigator = nil
mockGame:addObject(guardian)
local distant = Enemy:new({ game = mockGame, x = 300 + guardian.shieldRadius + 20, y = 300, name = "Basic", maxHp = 100 })
mockGame:addObject(distant)
shielded = guardian:grantShieldsToNearby()
check(#shielded == 1 and shielded[1] == guardian and guardian.shield == 100,
    "With no allies in range, the Guardian shields itself")
check(distant.shield == 0, "Allies out of range still get nothing")

print("--- Guardian Tests Completed ---")
if failures > 0 then os.exit(1) end
