-- Testing/test_damage_stats.lua
-- Per-turret damage tracking: effective damage (no overkill), kills, credit through
-- bullets / DoTs / explosions, ranking and MVP.

package.path = package.path .. ";./?.lua"

_G.love = {
    math = { random = math.random },
    timer = { getTime = function() return 0 end }
}
math.atan2 = math.atan2 or math.atan

local EffectManager = require("Game.Effects.EffectManager")
local DamageStats = require("Game.Core.DamageStats")

local mockGame = {
    objects = {},
    animations = {},
    ground = { x = 0, y = 0, w = 1000, h = 1000 },
    base = {
        x = 0, y = 100, w = 32,
        takeDamage = function() end,
        buildGrid = { x = 0, y = 0, width = 10, height = 10, cellSize = 32, buildings = {} }
    },
    addObject = function(self, obj) table.insert(self.objects, obj) end,
    EnemyDied = function(self, enemy) enemy.destroyed = true end,
    spawnParticleExplosion = function() end,
    spawnDamageNumber = function() end,
    spawnArmorBreak = function() end,
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
local function near(a, b) return math.abs(a - b) < 1e-6 end

local Turret = require("Buildings.Turrets.Turret")
local TurretIndex = require("Buildings.TurretIndex")
local Enemy = require("Enemies.Enemy")

local function makeTurret(id)
    for _, rarity in ipairs({ "common", "uncommon", "rare", "epic", "legendary" }) do
        for _, e in ipairs(TurretIndex[rarity] or {}) do
            if e.id == id then
                local c = {}
                for k, v in pairs(e) do c[k] = v end
                c.game, c.x, c.y, c.rotation = mockGame, 100, 100, 0
                return e.building:new(c)
            end
        end
    end
end

local function makeEnemy(hp, shield)
    local e = Enemy:new({ game = mockGame, x = 200, y = 100, size = 20, maxHp = hp, hp = hp })
    e.shield = shield or 0
    return e
end

-- 1. Unit: credit resolution and bookkeeping
mockGame.damageStats = DamageStats.new()
local stats = mockGame.damageStats
local sentry = makeTurret("sentry")
local gator = makeTurret("gator")
local bullet = { source = sentry }
local shard = { source = bullet.source } -- split shards point at the turret too

assert(DamageStats.resolveTurret(sentry) == sentry, "A turret credits itself")
assert(DamageStats.resolveTurret(bullet) == sentry, "A bullet credits its turret")
assert(DamageStats.resolveTurret({ source = bullet }) == sentry, "Bullet-from-bullet credits the original turret")
assert(DamageStats.resolveTurret(shard) == sentry, "Split shard credits the turret")
assert(DamageStats.resolveTurret(nil) == nil, "No source: no credit (e.g. spells)")
assert(DamageStats.resolveTurret({}) == nil, "Source with no turret behind it: no credit")

-- 2. Enemy:takeDamage records effective damage only
local e1 = makeEnemy(100)
e1:takeDamage(40, "ballistic", nil, nil, nil, bullet)
assert(near(stats:get(sentry).damage, 40), "Partial hit credits its full amount (40)")
e1:takeDamage(225, "ballistic", nil, nil, nil, bullet)
assert(near(stats:get(sentry).damage, 100), "Overkill is not counted: only the remaining 60 HP is credited")
assert(stats:get(sentry).kills == 1, "Killing blow counts as a kill")
e1:takeDamage(50, "ballistic", nil, nil, nil, bullet)
assert(near(stats:get(sentry).damage, 100) and stats:get(sentry).kills == 1, "Hitting a dead enemy credits nothing")

local e2 = makeEnemy(100, 30)
e2:takeDamage(80, "ballistic", nil, nil, nil, gator)
assert(near(stats:get(gator).damage, 30), "Shield hit credits only the shield actually removed (30)")
assert(stats:get(gator).kills == 0, "Breaking a shield is not a kill")

local e3 = makeEnemy(100)
e3:takeDamage(50, "ballistic")
assert(near(stats.total, 130), "Damage with no source (spells) is not credited to any turret")

-- 3. Real bullet fired by a turret
mockGame.damageStats = DamageStats.new()
stats = mockGame.damageStats
mockGame.objects = {}
local t = makeTurret("sentry")
local target = makeEnemy(100)
t:fire()
local b = mockGame.objects[#mockGame.objects]
b:onHit(target)
assert(stats:get(t).damage > 0, string.format("Fired bullet's hit is credited to its turret (%.1f)", stats:get(t).damage))

-- 4. Damage-over-time ticks credit the turret that applied them
local Burn = require("Game.Effects.StatusEffects.Burn")
local burnTarget = makeEnemy(1000)
local dot = makeTurret("blaster")
local dotBullet = { source = dot, getStat = function() return 0 end }
burnTarget.effectManager:applyEffect(Burn:new({ dps_burn = 10, duration_burn = 3, maxStacks = 1 }), dotBullet)
for _ = 1, 120 do burnTarget.effectManager:update(1 / 60) end
assert(stats:get(dot).damage > 0, string.format("Burn ticks are credited to the turret behind the bullet (%.1f)", stats:get(dot).damage))

-- 5. Explosions credit the turret behind the bullet
local Explosion = require("Game.Effects.IndependantEffects.explosion")
local boom = makeTurret("mortar")
local blastTarget = makeEnemy(500)
mockGame.objects = { blastTarget }
local event = Explosion:new({ game = mockGame, x = 200, y = 100, radius = 50, explosionDamage = 40, maxLifetime = 0.4 })
event:applyDamage({ source = boom, game = mockGame }, blastTarget)
assert(stats:get(boom).damage > 0, string.format("Explosion damage is credited to the turret (%.1f)", stats:get(boom).damage))

-- 6. Ranking, shares and MVP
mockGame.damageStats = DamageStats.new()
stats = mockGame.damageStats
local a, bT, c, d = makeTurret("sentry"), makeTurret("gator"), makeTurret("blaster"), makeTurret("sniper")
stats:record(a, 300); stats:record(bT, 500); stats:record(c, 200); stats:record(d, 500)
local ranking = stats:getRanking()
assert(ranking[1].turret == bT, "Highest damage ranks first (tie broken by who dealt damage first)")
assert(ranking[2].turret == d and ranking[3].turret == a and ranking[4].turret == c, "Ranking is sorted by damage")
assert(stats:getMVP().turret == bT, "MVP is the top-damage turret")
assert(near(stats:get(bT).share, 500 / 1500), "Share is damage / total turret damage")
assert(near(stats:get(makeTurret("sentry")).damage, 0), "Turret that hasn't hit anything shows 0 damage")
assert(DamageStats.new():getMVP() == nil, "No MVP when no turret dealt damage")

-- Main turrets are turrets too, so they can be MVP
local MainLazer = require("Buildings.MainTurrets.MainLazer")
local FastMainTurret = require("Buildings.MainTurrets.FastMainTurret")
for _, cls in ipairs({ MainLazer, FastMainTurret }) do
    local mainProxy = setmetatable({ name = cls.template.name, types = cls.template.types }, { __index = cls })
    assert(DamageStats.resolveTurret(mainProxy) == mainProxy, cls.template.name .. " (main turret) is credited and MVP-eligible")
end

-- 7. Number formatting
assert(DamageStats.formatNumber(0) == "0", "formatNumber(0)")
assert(DamageStats.formatNumber(999.6) == "1,000", "formatNumber rounds (999.6 -> 1,000)")
assert(DamageStats.formatNumber(1234567) == "1,234,567", "formatNumber adds thousands separators")

if failures > 0 then
    print(failures .. " test(s) failed")
    os.exit(1)
end
print("All damage stats tests passed")
