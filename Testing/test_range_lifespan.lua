-- Testing/test_range_lifespan.lua
-- Bullets must be able to travel the turret's full range, including when range is
-- boosted by cards (instants, passives, tier upgrades). The lifespan boost is hidden.

package.path = package.path .. ";./?.lua"

_G.love = {
    math = { random = math.random },
    timer = { getTime = function() return 0 end }
}
math.atan2 = math.atan2 or math.atan

local EffectManager = require("Game.Effects.EffectManager")

local mockGame = {
    objects = {},
    ground = { x = 0, y = 0, w = 1000, h = 1000 },
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
local Card = require("Game.Cards.Card")
local ExecutionType = require("Game.Cards.ExecutionType")
local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
local InstantCardRegistry = require("Instants.InstantCardRegistry")

local function findTurret(id)
    for _, rarity in ipairs({ "common", "uncommon", "rare", "epic", "legendary" }) do
        for _, entry in ipairs(TurretIndex[rarity] or {}) do
            if entry.id == id then return entry end
        end
    end
end

-- Builds a turret the way playing its card does (tier scaling included)
local function placeTurret(id, tier)
    local entry = findTurret(id)
    local card = Card:new({
        id = entry.id, name = entry.name,
        executionType = ExecutionType.Placement,
        tier = tier or 1,
        payload = { buildingClass = entry.building, config = entry }
    })
    local turret = card:execute(mockGame)
    turret.x, turret.y = 100, 100
    return turret
end

-- Distance the turret's next straight-flying bullet can travel before expiring
local function bulletReach(turret)
    mockGame.objects = {}
    turret:fire()
    local b = mockGame.objects[1]
    return b:getStat("bulletSpeed") * b.lifespan, b
end

local function applyRange(turret, mod)
    turret.effectManager:applyEffect({ name = "test_range", duration = math.huge, statModifiers = { range = mod } })
end

-- Straight-flying turrets whose reach is closest to their range at base stats
-- (Airburst reaches via shrapnel after bursting; see test_airburst.lua)
local ids = { "sentry", "autoCannon", "fluxCannon" }

for _, id in ipairs(ids) do
    -- 1. Base stats: unchanged lifespan
    local t = placeTurret(id)
    local reach, b = bulletReach(t)
    assert(math.abs(b.lifespan - t:getStat("lifespan")) < 1e-9, id .. ": base lifespan is unchanged")
    assert(reach >= t:getStat("range"), string.format("%s: base reach %.0f covers range %.0f", id, reach, t:getStat("range")))

    -- 2. Big multiplicative range buff (stacked Range Buff passives)
    t = placeTurret(id)
    applyRange(t, { mult = 1.0 })
    reach = bulletReach(t)
    assert(reach >= t:getStat("range"), string.format("%s: +100%% range, reach %.0f covers range %.0f", id, reach, t:getStat("range")))

    -- 3. Flat range buff (Binoculars-style +add)
    t = placeTurret(id)
    applyRange(t, { add = 300 })
    reach = bulletReach(t)
    assert(reach >= t:getStat("range"), string.format("%s: +300 flat range, reach %.0f covers range %.0f", id, reach, t:getStat("range")))

    -- 4. Max tier card upgrade
    t = placeTurret(id, CardUpgradeConfig.MAX_TIER)
    reach = bulletReach(t)
    assert(reach >= t:getStat("range"), string.format("%s: tier %d, reach %.0f covers range %.0f", id, CardUpgradeConfig.MAX_TIER, reach, t:getStat("range")))
end

-- 5. The real Binoculars instant extends reach too
local t = placeTurret("sentry", CardUpgradeConfig.MAX_TIER)
local inst = InstantCardRegistry.RangeFinder
for _ = 1, 10 do inst:applyTargetedEffect(t) end
local reach = bulletReach(t)
assert(reach >= t:getStat("range"), string.format("sentry tier V + 10x Binoculars: reach %.0f covers range %.0f", reach, t:getStat("range")))

-- 6. Range debuffs never shrink lifespan below base
t = placeTurret("sentry")
applyRange(t, { mult = -0.5 })
local _, b = bulletReach(t)
assert(math.abs(b.lifespan - t:getStat("lifespan")) < 1e-9, "Range debuff does not shrink bullet lifespan")

-- 7. Hidden: the lifespan boost never shows up as a stat modifier in tooltips
t = placeTurret("sentry")
applyRange(t, { mult = 1.0 })
for _, s in ipairs(t.effectManager:getTooltipStrings()) do
    assert(not s:lower():find("lifespan"), "Tooltip does not mention lifespan: " .. s)
end
assert((t.effectManager.currentModifiers.lifespan == nil), "No lifespan stat modifier is applied to the turret")

if failures > 0 then
    print(failures .. " test(s) failed")
    os.exit(1)
end
print("All range/lifespan tests passed")
