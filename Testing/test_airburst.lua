-- Testing/test_airburst.lua
-- Airburst: a slow shell bursts at 60% of the turret's base range (before it can
-- expire) into faster shrapnel that deals damage and still reaches the full range.

package.path = package.path .. ";./?.lua"

_G.love = {
    math = { random = math.random },
    timer = { getTime = function() return 0 end }
}
math.atan2 = math.atan2 or math.atan

local EffectManager = require("Game.Effects.EffectManager")

local mockGame = {
    objects = {},
    ground = { x = 0, y = 0, w = 5000, h = 5000 },
    base = {
        x = 0, y = 100, w = 32,
        takeDamage = function() end,
        buildGrid = { x = 0, y = 0, width = 10, height = 10, cellSize = 32, buildings = {} }
    },
    addObject = function(self, obj) table.insert(self.objects, obj) end,
    spawnParticleExplosion = function() end,
    spawnDamageNumber = function() end
}
mockGame.playerEffectManager = EffectManager:new(nil, mockGame)
mockGame.enemyEffectManager = EffectManager:new(nil, mockGame)

local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

local TurretIndex = require("Buildings.TurretIndex")
local AirburstBullet = require("Bullets.AirburstBullet")
local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
local Card = require("Game.Cards.Card")
local ExecutionType = require("Game.Cards.ExecutionType")

local entry
for _, rarity in ipairs({ "common", "uncommon", "rare", "epic", "legendary" }) do
    for _, e in ipairs(TurretIndex[rarity] or {}) do
        if e.id == "airburst" then entry = e end
    end
end

local function placeAirburst(tier)
    local card = Card:new({
        id = entry.id, name = entry.name,
        executionType = ExecutionType.Placement,
        tier = tier or 1,
        payload = { buildingClass = entry.building, config = entry }
    })
    local turret = card:execute(mockGame)
    turret.x, turret.y = 2500, 2500
    turret.rotation = 0
    return turret
end

-- Fires one shell and steps it until it is gone. Returns the shell, how far it
-- flew, how long it lived, and the shrapnel it left behind.
local function fireAndFly(turret)
    mockGame.objects = {}
    turret:fire()
    local shell = mockGame.objects[1]
    local sx, sy = shell.x, shell.y
    local t, dt = 0, 1 / 60
    while not shell.destroyed and t < 10 do
        shell:update(dt)
        t = t + dt
    end
    local shrapnel = {}
    for i = 2, #mockGame.objects do table.insert(shrapnel, mockGame.objects[i]) end
    local dist = math.sqrt((shell.x - sx) ^ 2 + (shell.y - sy) ^ 2)
    return shell, dist, t, shrapnel
end

-- 1. Base turret: bursts at 60% of base range, before expiring
local turret = placeAirburst()
local shell, dist, life, shrapnel = fireAndFly(turret)
local expected = turret.range * AirburstBullet.BURST_RANGE_FRACTION
assert(getmetatable(shell) and shell.airburst, "Airburst turret fires an Airburst shell")
assert(#shrapnel == 5, "Shell bursts into 5 shrapnel (got " .. #shrapnel .. ")")
assert(math.abs(dist - expected) <= shell:getStat("bulletSpeed") / 60 + 1,
    string.format("Shell bursts at 60%% of base range (%.0f px, expected %.0f)", dist, expected))
assert(life < turret:getStat("lifespan"), "Shell bursts before its lifespan runs out")

-- 2. Shrapnel is much faster, smaller, and deals damage
local s = shrapnel[1]
assert(s:getStat("bulletSpeed") >= shell:getStat("bulletSpeed") * 3,
    string.format("Shrapnel is much faster than the shell (%d vs %d)", s:getStat("bulletSpeed"), shell:getStat("bulletSpeed")))
assert(s.w <= (shell.w or math.huge) and s.h <= (shell.h or math.huge), "Shrapnel is no bigger than the shell")
assert(s:getStat("damage") > 0, "Shrapnel deals damage (got " .. s:getStat("damage") .. ")")
assert(math.abs(s:getStat("damage") - shell:getStat("damage")) < 1e-9, "Shrapnel damage follows the shell's damage")

-- 3. Shrapnel reaches the turret's full range
local reach = dist + s:getStat("bulletSpeed") * s.lifespan
assert(reach >= turret:getStat("range"), string.format("Burst + shrapnel reach %.0f covers range %.0f", reach, turret:getStat("range")))

-- 4. Range buffs: burst point stays at 60% of base range, shrapnel still reaches boosted range
turret = placeAirburst()
turret.effectManager:applyEffect({ name = "test_range", duration = math.huge, statModifiers = { range = { mult = 1.0 } } })
shell, dist, life, shrapnel = fireAndFly(turret)
assert(math.abs(dist - expected) <= shell:getStat("bulletSpeed") / 60 + 1, "Range buff does not move the burst point")
reach = dist + shrapnel[1]:getStat("bulletSpeed") * shrapnel[1].lifespan
assert(reach >= turret:getStat("range"), string.format("+100%% range: burst + shrapnel reach %.0f covers range %.0f", reach, turret:getStat("range")))

-- 5. Tier upgrade: base range grows, so the burst point moves out with it
turret = placeAirburst(CardUpgradeConfig.MAX_TIER)
shell, dist, life, shrapnel = fireAndFly(turret)
local tierExpected = turret.range * AirburstBullet.BURST_RANGE_FRACTION
assert(#shrapnel == 5, "Max tier shell still bursts")
assert(math.abs(dist - tierExpected) <= shell:getStat("bulletSpeed") / 60 + 1,
    string.format("Max tier bursts at 60%% of its base range (%.0f px, expected %.0f)", dist, tierExpected))

-- 6. If lifespan would run out before the burst distance, it bursts instead of vanishing
turret = placeAirburst()
mockGame.objects = {}
turret:fire()
shell = mockGame.objects[1]
shell.lifespan = 0.1
for _ = 1, 30 do if not shell.destroyed then shell:update(1 / 60) end end
assert(#mockGame.objects == 6, "Shell that runs out of lifespan bursts instead of vanishing")

-- 7. The shrapnel count comes from splitamount, spread evenly over the 60 degree cone
turret = placeAirburst()
shell, dist, life, shrapnel = fireAndFly(turret)
local first, last = shrapnel[1].angle - shell.angle, shrapnel[#shrapnel].angle - shell.angle
assert(math.abs(first + math.rad(30)) < 1e-6 and math.abs(last - math.rad(30)) < 1e-6,
    "Shrapnel fans from -30 to +30 degrees")
turret.effectManager:applyEffect({ name = "test_split", duration = math.huge, statModifiers = { splitamount = { add = 2 } } })
shell, dist, life, shrapnel = fireAndFly(turret)
assert(#shrapnel == 7, "+2 splitamount bursts into 7 shrapnel (got " .. #shrapnel .. ")")

if failures > 0 then
    print(failures .. " test(s) failed")
    os.exit(1)
end
print("All airburst tests passed")
