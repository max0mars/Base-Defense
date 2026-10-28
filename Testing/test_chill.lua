package.path = package.path .. ";./?.lua"
-- Mock love2d (every love.* function is a no-op; GameManager pulls in the whole game)
local noop = function() end
_G.love = setmetatable({
    math = setmetatable({ random = math.random }, { __index = function() return noop end }),
    timer = { getTime = function() return 0 end },
}, { __index = function() return setmetatable({}, { __index = function() return noop end }) end })
_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720

local Enemy = require("Enemies.Enemy")
local Tank = require("Enemies.Tank")
local Chill = require("Game.Effects.StatusEffects.Chill")
local EnemyRegistry = require("Game.Spawning.EnemyRegistry")

print("--- Starting Chill / Freeze Tests ---")

local mockGame = { objects = {}, seenEnemies = {}, base = { x = 0, w = 100 } }
function mockGame:addObject(obj) table.insert(self.objects, obj); obj.game = self end
function mockGame:EnemyDied() end
function mockGame:spawnDamageNumber() end
EnemyRegistry:reset(mockGame)

local function near(a, b) return math.abs(a - b) < 1e-6 end
local function tick(enemy, seconds)
    -- Step the effect manager in small frames, like the game loop does.
    local steps = math.floor(seconds / 0.01 + 0.5)
    for _ = 1, steps do enemy.effectManager:update(0.01) end
end
-- A Grunt: a real index entry, so it has a non-zero base speed for the slow checks.
local function newBasic()
    local e = Enemy:new({ game = mockGame, x = 100, y = 100, name = "Grunt" })
    mockGame:addObject(e)
    return e
end

-- 1. Stacks slow multiplicatively, 10% each: 2 stacks = 0.9^2
local e = newBasic()
local baseSpeed = e:getStat("speed")
assert(baseSpeed > 0, "test enemy needs a real base speed")
Chill.apply(e, 2)
assert(near(Chill.getStacks(e), 2), "expected 2 stacks")
assert(near(e:getStat("speed"), baseSpeed * 0.9 ^ 2), "chill slow should compound per stack")
do
    local one = newBasic()
    Chill.apply(one, 1)
    assert(near(one:getStat("speed"), baseSpeed * 0.9), "1 stack slows by 10%")
    local half = newBasic()
    Chill.apply(half, 0.5)
    assert(near(half:getStat("speed"), baseSpeed * 0.9 ^ 0.5), "half a stack slows too (~5%)")
    local quarter = newBasic()
    Chill.apply(quarter, 0.25)
    assert(quarter:getStat("speed") < baseSpeed and quarter:getStat("speed") > half:getStat("speed"),
        "a quarter stack slows, but less than half a stack")
    -- Decay also eases the slow continuously, not one whole stack at a time.
    tick(half, Chill.DECAY_DELAY + 0.3)
    local eased = half:getStat("speed")
    assert(eased > baseSpeed * 0.9 ^ 0.5 and eased < baseSpeed, "slow eases off smoothly as chill decays")
end
print("[PASS] Chill stacks slow multiplicatively")

-- 2. Compounds with other slows
local SlowEffect = require("Game.Effects.StatusEffects.Slow")
e.effectManager:applyEffect(SlowEffect:new({ name = "test_slow", duration = 10, amount = 0.5 }))
assert(near(e:getStat("speed"), baseSpeed * 0.9 ^ 2 * 0.5), "chill should combine with other slows")
print("[PASS] Chill combines with other slows")

-- 3. Decays at 1 stack per 1.5 seconds (after the decay delay) and is removed at 0
assert(near(Chill.DECAY_PER_SECOND, 1 / 1.5), "chill decays one stack every 1.5s")
e = newBasic()
Chill.apply(e, 2)
tick(e, Chill.DECAY_DELAY + 1.5)
assert(math.abs(Chill.getStacks(e) - 1) < 0.02, "expected ~1 stack after 1.5s, got " .. Chill.getStacks(e))
tick(e, 1.6)
assert(Chill.getStacks(e) == 0, "chill should be fully drained")
assert(e.effectManager:getEffect(Chill.CHILL_NAME) == nil, "drained chill state should be removed")
assert(near(e:getStat("speed"), baseSpeed), "speed should be restored after chill drains")
print("[PASS] Chill decays at a fixed rate and clears")

-- 3b. Each application pauses decay for DECAY_DELAY seconds
e = newBasic()
Chill.apply(e, 2)
tick(e, Chill.DECAY_DELAY - 0.05)
assert(near(Chill.getStacks(e), 2), "chill should not decay during the decay delay")
Chill.apply(e, 1) -- re-applying restarts the delay
tick(e, Chill.DECAY_DELAY - 0.05)
assert(near(Chill.getStacks(e), 3), "re-applying chill should restart the decay delay")
tick(e, 0.35)
assert(Chill.getStacks(e) < 3, "chill should decay once the delay runs out")
print("[PASS] Applying chill pauses decay")

-- 4. Partial stacks accumulate and freeze at 5; stacks reset to 0
e = newBasic()
for _ = 1, 24 do Chill.apply(e, 0.2) end
assert(near(Chill.getStacks(e), 4.8), "partial stacks should accumulate")
assert(not Chill.isFrozen(e), "should not freeze below threshold")
local froze = Chill.apply(e, 0.2)
assert(froze and Chill.isFrozen(e), "should freeze at 5 stacks")
assert(Chill.getStacks(e) == 0, "stacks should reset to 0 on freeze")
assert(e:getStat("stunned", 0) > 0, "frozen should act as a stun")
print("[PASS] Partial stacks freeze at threshold and reset")

-- 5. Immune to chill while frozen and thawing; thaw slows by 50% for 1.5s
Chill.apply(e, 3)
assert(Chill.getStacks(e) == 0, "chill should not apply while frozen")
tick(e, 1.9)
assert(Chill.isFrozen(e), "should still be frozen just before 2s")
tick(e, 0.15)
assert(Chill.isThawing(e), "should be thawing after 2s")
assert(e:getStat("stunned", 0) == 0, "thawing enemy should no longer be stunned")
assert(near(e:getStat("speed"), baseSpeed * 0.5), "thawing should slow by 50%")
Chill.apply(e, 3)
assert(Chill.getStacks(e) == 0, "chill should not apply while thawing")
tick(e, 1.35)
assert(Chill.isThawing(e), "thaw should still be running just before 1.5s")
tick(e, 0.15)
assert(not Chill.isThawing(e) and not Chill.isFrozen(e), "thaw should end after 1.5s")
assert(near(e:getStat("speed"), baseSpeed), "speed restored after thaw")
Chill.apply(e, 1)
assert(near(Chill.getStacks(e), 1), "chill applies again after thawing")
print("[PASS] Frozen/thawing immunity and thaw slow")

-- 6. Bosses (tier 5) need 10 stacks and freeze for 0.75s
local tank = Tank:new({ game = mockGame, x = 100, y = 100, name = "Tank" })
mockGame:addObject(tank)
assert(Chill.isBoss(tank), "Tank should count as a boss (tier " .. tostring(tank.tier) .. ")")
Chill.apply(tank, 9.5)
assert(not Chill.isFrozen(tank), "boss should not freeze below 10 stacks")
Chill.apply(tank, 0.5)
assert(Chill.isFrozen(tank), "boss should freeze at 10 stacks")
tick(tank, 0.8)
assert(Chill.isThawing(tank), "boss freeze should last 0.75s")
assert(not Chill.isBoss(newBasic()), "Basic enemy should not be a boss")
print("[PASS] Boss threshold and freeze duration")

-- 7. On-hit effect respects amount and chance
e = newBasic()
local onHit = Chill.onHit({ amount = 0.5 })
onHit:trigger(e, nil)
onHit:trigger(e, nil)
assert(near(Chill.getStacks(e), 1), "on-hit should apply its amount per hit")
local never = Chill.onHit({ amount = 1, chance = 0 })
never:trigger(e, nil)
assert(near(Chill.getStacks(e), 1), "chance 0 should never apply chill")
e.effectManager:applyEffect(Chill.onHit({ amount = 1 }))
assert(near(Chill.getStacks(e), 2), "on-hit via applyEffect should apply chill")
print("[PASS] Chill on-hit effect")

-- 8. Ice turrets are registered with the agreed stats
local TurretIndex = require("Buildings.TurretIndex")
local function find(rarity, id)
    for _, entry in ipairs(TurretIndex[rarity]) do
        if entry.id == id then return entry end
    end
end

local gunner = find("rare", "iceShard")
assert(gunner and gunner.name == "Ice Shard Gunner", "Ice Shard Gunner should be a rare turret")
assert(gunner.cost == 1 and gunner.fireRate == 2.3 and gunner.range == 350, "Gunner: 1 token, 2.3/s, 350 range")
assert(gunner.bulletSpeed * gunner.lifespan >= gunner.range, "Gunner shards must reach max range")
local hit = gunner.hitEffects[1]
assert(hit.amount == 0.5 and hit.hitChance == 1, "Gunner: half a stack on every hit")
assert(near(gunner.firingArc.angle, math.rad(35)), "Gunner: 35 degree arc")
print("[PASS] Ice Shard Gunner registered")

local cannon = find("epic", "frostCannon")
assert(cannon, "Frost Cannon should be an epic turret")
assert(cannon.cost == 1 and cannon.pelletCount == 6 and cannon.damage == 12, "Cannon: 1 token, 6 x 12 dmg")
assert(cannon.range == 420 and cannon.fireRate == 0.8, "Cannon: 420 range, 0.8/s")
assert(near(cannon.firingArc.angle, math.rad(45 * 0.75 - 5)), "Cannon: arc 28.75 degrees")
assert(cannon.hitEffects[1].amount == 0.5 and cannon.hitEffects[1].hitChance == 1, "Cannon: half a chill stack per pellet")
-- Slowest pellet (speed x0.9) still reaches max range
assert(cannon.bulletSpeed * 0.9 * cannon.lifespan >= cannon.range, "Cannon pellets must reach max range")
-- Pellets spread uniformly across the cone; expected hits on a 20px enemy at max range
local expectedHits = cannon.pelletCount * (20 / cannon.range) / cannon.spread
assert(expectedHits >= 1 and expectedHits <= 3,
    string.format("Cannon: expected %.2f pellets on target at max range (want 1-3)", expectedHits))
print(string.format("[PASS] Frost Cannon registered (~%.1f pellets hit at max range)", expectedHits))

local slush = find("uncommon", "slushCannon")
assert(slush, "Slush Cannon should be an uncommon turret")
assert(near(slush.damage, 36 * 0.8 * 0.8) and near(slush.fireRate, 0.25 * 1.2 * 1.2 * 1.1),
    "Slush: two rounds of -20% damage / +20% fire rate, then +10% fire rate")
assert(#slush.hitEffects == 1 and slush.hitEffects[1].amount == 2 and slush.hitEffects[1].hitChance == 1,
    "Slush: 2 chill per hit and no separate slow")
print("[PASS] Slush Cannon reworked")

-- 9. Cryo Beam: locks on, 25 DPS, freezes a locked target at ~3s
local beamEntry = find("epic", "cryoBeam")
assert(beamEntry and beamEntry.cost == 1, "Cryo Beam should be an epic costing 1")
assert(beamEntry.range == 380, "Cryo Beam range is 380")
assert(near(beamEntry.damage * beamEntry.fireRate, 25), "Cryo Beam deals 25 DPS")

local beamGame = { objects = {}, seenEnemies = {}, inputMode = "idle", inputHandler = {}, base = { x = 0, w = 100 } }
function beamGame:addObject(obj) table.insert(self.objects, obj); obj.game = self end
function beamGame:EnemyDied() end
function beamGame:spawnDamageNumber() end

local config = {}
for k, v in pairs(beamEntry) do config[k] = v end
config.game = beamGame
local beam = beamEntry.building:new(config)
beam.x, beam.y = 0, 100

local target = Enemy:new({ game = beamGame, x = 200, y = 100, name = "Basic", maxHp = 100000 })
local decoy = Enemy:new({ game = beamGame, x = 150, y = 100, name = "Basic", maxHp = 100000 })
beamGame:addObject(target)
-- Lock on first, then a closer enemy arrives: the beam must stay on its target.
local dt = 1 / 60
beam:update(dt)
assert(beam.target == target, "beam should lock onto the only enemy")
beamGame:addObject(decoy)

local t, frozeAt = 0, nil
local startHp = target.hp
while t < 4 and not frozeAt do
    target.effectManager:update(dt)
    beam:update(dt)
    t = t + dt
    if Chill.isFrozen(target) then frozeAt = t end
end
assert(beam.target == target, "beam should stay locked on its target")
assert(frozeAt and frozeAt > 2.9 and frozeAt < 3.1,
    "locked target should freeze at ~3s, froze at " .. tostring(frozeAt))
local dps = (startHp - target.hp) / frozeAt
assert(dps > 23 and dps < 28, string.format("beam DPS should be ~25, got %.1f", dps))
print(string.format("[PASS] Cryo Beam locks on, ~%.1f DPS, freezes at %.2fs", dps, frozeAt))

-- Once frozen, the beam moves on to the nearest unfrozen enemy.
beam:update(dt)
assert(beam.target == decoy, "beam should switch off a frozen target")
print("[PASS] Cryo Beam switches off a frozen target")

-- It also won't lock onto a thawing enemy while a chillable one is in reach.
local thawing = Enemy:new({ game = beamGame, x = 100, y = 100, name = "Basic", maxHp = 100000 })
beamGame:addObject(thawing)
Chill.apply(thawing, 5)
local thawTime = 0
while not Chill.isThawing(thawing) and thawTime < 3 do thawing.effectManager:update(dt); thawTime = thawTime + dt end
assert(Chill.isThawing(thawing), "setup: enemy should be thawing")
beam.target = nil
beam:update(dt)
assert(beam.target == decoy, "beam should skip a closer thawing enemy")
thawing.x = 1000
print("[PASS] Cryo Beam skips thawing enemies")

-- With only the frozen enemy in reach, it keeps beaming it for damage.
decoy.x = 1000
beam:update(dt)
assert(beam.target == target, "beam should fall back to a frozen enemy when nothing else is in range")
-- Leaving range releases the lock entirely.
target.x = 1000
beam:update(dt)
assert(beam.target == nil, "beam should release a target that leaves range")
print("[PASS] Cryo Beam falls back to frozen targets and releases out-of-range ones")

-- 10. Icicle Ballista: uncommon, between Sentry and Heavy Gun, scales with chill
local ballista = find("uncommon", "icicleBallista")
local sentry, heavy = find("common", "sentry"), find("common", "heavygun")
assert(ballista and ballista.cost == 1 and ballista.pierce == 1, "Ballista: uncommon, 1 token, no pierce")
local function between(v, a, b) return v >= math.min(a, b) and v <= math.max(a, b) end
for _, stat in ipairs({ "fireRate", "damage", "range" }) do
    assert(between(ballista[stat], sentry[stat], heavy[stat]), "Ballista " .. stat .. " should sit between Sentry and Heavy Gun")
end
local function dpsOf(e) return e.damage * e.fireRate end
assert(dpsOf(ballista) > math.max(dpsOf(sentry), dpsOf(heavy)), "Ballista should out-DPS both commons")
assert(ballista.bulletSpeed * ballista.lifespan >= ballista.range, "Ballista icicles must reach max range")

local bonus = { ballista.damageVsChill }
e = newBasic()
assert(near(Chill.getDamageMultiplier(e, bonus), 1), "no bonus without chill")
Chill.apply(e, 2)
local m2 = Chill.getDamageMultiplier(e, bonus)
Chill.apply(e, 2)
local m4 = Chill.getDamageMultiplier(e, bonus)
assert(m2 > 1 and m4 > m2, "bonus should grow with stacks")
Chill.apply(e, 1)
local mFrozen = Chill.getDamageMultiplier(e, bonus)
assert(Chill.isFrozen(e) and mFrozen > m4 and near(mFrozen, 2), "frozen should take the biggest bonus (x2)")
-- A boss at 9 of 10 stacks still gets less than frozen.
local boss = Tank:new({ game = mockGame, x = 100, y = 100, name = "Tank" })
Chill.apply(boss, 9)
assert(Chill.getDamageMultiplier(boss, bonus) < mFrozen, "a heavily chilled boss still takes less than a frozen enemy")
print(string.format("[PASS] Icicle Ballista (%.1f DPS; x%.2f at 2 stacks, x%.2f at 4, x%.2f frozen)", dpsOf(ballista), m2, m4, mFrozen))

-- 11. Glacial Monolith: rare, cost 2, 380 range, 28 deg arc with 18 deg rings, 2 chill per wave
local mono = find("rare", "glacialMonolith")
assert(mono and mono.cost == 2 and mono.range == 380, "Monolith: rare, cost 2, 380 range")
assert(near(mono.firingArc.angle, math.rad(28)) and mono.damage == 0, "Monolith: 28 degree arc, no damage")
assert(near(mono.ringAngle, math.rad(18)), "Monolith: rings stay 18 degrees wide")
assert(mono.chillPerWave == 2, "Monolith: 2 chill per wave")
assert(near(mono.chillPerWave * mono.fireRate, Chill.DECAY_PER_SECOND), "Monolith: chill applied per second equals decay")

local monoGame = { objects = {}, seenEnemies = {}, inputMode = "idle", inputHandler = {}, base = { x = 0, w = 100 } }
function monoGame:addObject(obj) table.insert(self.objects, obj); obj.game = self end
function monoGame:EnemyDied() end
function monoGame:spawnDamageNumber() end
local mcfg = {}
for k, v in pairs(mono) do mcfg[k] = v end
mcfg.game = monoGame
local monolith = mono.building:new(mcfg)
monolith.x, monolith.y = 0, 100

local inArc = Enemy:new({ game = monoGame, x = 240, y = 100, name = "Basic", maxHp = 100000 })
local outOfArc = Enemy:new({ game = monoGame, x = 0, y = 340, name = "Basic", maxHp = 100000 }) -- 90 deg off-axis
monoGame:addObject(inArc); monoGame:addObject(outOfArc)
local mt = 0
local function stepMono(seconds)
    local stop = mt + seconds
    while mt < stop do
        inArc.effectManager:update(dt); outOfArc.effectManager:update(dt)
        monolith:update(dt)
        mt = mt + dt
    end
end
-- Ring reaches 240px after 2s at 120px/s (minus the enemy's half-size).
stepMono(1.5)
assert(Chill.getStacks(inArc) == 0, "ring should not have reached the enemy yet")
stepMono(0.5)
assert(Chill.getStacks(inArc) > 1.5, "ring should chill the enemy when it arrives")
assert(Chill.getStacks(outOfArc) == 0, "enemies outside the arc are never chilled")
-- The decay delay leaves +0.2 chill per wave on a stationary enemy, so it builds
-- up slowly rather than freezing quickly.
local peak = 0
for _ = 1, 10 do
    stepMono(1)
    peak = math.max(peak, Chill.getStacks(inArc))
    assert(not Chill.isImmune(inArc), "a lone monolith should not freeze a stationary enemy within 12s")
end
assert(peak > 2 and peak < 3, string.format("chill should build up slowly past one wave (peak %.2f)", peak))
assert(inArc.hp == inArc.maxHp, "monolith deals no damage")
print(string.format("[PASS] Glacial Monolith (peak chill %.2f, builds up slowly)", peak))

-- Rings aim at the enemy but stay fully inside the arc.
do
    local g = { objects = {}, seenEnemies = {}, inputMode = "idle", inputHandler = {}, base = { x = 0, w = 100 } }
    function g:addObject(obj) table.insert(self.objects, obj); obj.game = self end
    function g:EnemyDied() end
    function g:spawnDamageNumber() end
    local cfg = {}
    for k, v in pairs(mono) do cfg[k] = v end
    cfg.game = g
    local m = mono.building:new(cfg)
    m.x, m.y = 0, 100
    local function at(deg, dist)
        local en = Enemy:new({ game = g, x = math.cos(math.rad(deg)) * dist, y = 100 + math.sin(math.rad(deg)) * dist,
            name = "Basic", maxHp = 100000, size = 4 })
        return en
    end
    -- Target near the arc's edge (+12 of +-14 degrees): the ring centre is clamped to +5,
    -- so the ring spans -4..+14 degrees.
    local edge = at(12, 120)
    g:addObject(edge)
    m:update(dt)
    local center = m.waves[1].center
    assert(near(math.deg(center), 5), "ring centre is clamped so the 18 degree ring stays inside the 28 degree arc")
    local opposite = at(-10, 200) -- inside the arc, but outside this ring
    g:addObject(opposite)
    for _ = 1, math.floor(2 / dt) do
        for _, o in ipairs(g.objects) do o.effectManager:update(dt) end
        m:updateWaves(dt)
    end
    assert(Chill.getStacks(edge) > 0, "the ring chills the enemy it was aimed at")
    assert(Chill.getStacks(opposite) == 0, "the 18 degree ring misses enemies on the other side of the arc")
    -- A target straight ahead gets a ring centred on it.
    local m2 = mono.building:new(cfg)
    m2.x, m2.y = 0, 100
    g.objects = {}
    g:addObject(at(2, 150))
    m2:update(dt)
    assert(near(math.deg(m2.waves[1].center), 2), "an unclamped ring centres on its target")
end
print("[PASS] Glacial Monolith rings aim within the arc")

local PassiveIndex = require("Buildings.PassiveIndex")

-- 13. Cold Tactics: rare, cost 1, 5 slots (not the left column), +10%/stack, frozen = max
local ctEntry
for _, entry in ipairs(PassiveIndex.rare) do
    if entry.id == "coldTactics" then ctEntry = entry end
end
assert(ctEntry and ctEntry.cost == 1, "Cold Tactics: rare, cost 1")
assert(#ctEntry.affectedSlots == 5, "Cold Tactics affects 5 slots")
for _, s in ipairs(ctEntry.affectedSlots) do
    assert(s[1] >= 0 and not (s[1] == 0 and s[2] == 0), "Cold Tactics never affects its left side or itself")
end

local ColdTactics = require("Buildings.Passives.ColdTactics")
local ct = ColdTactics:new({ game = mockGame })
local ctBonus = { ct.effect.damageVsChill }
e = newBasic()
Chill.apply(e, 3)
assert(near(Chill.getDamageMultiplier(e, ctBonus), 1.3), "normal enemy: +10% per stack (3 stacks -> x1.3)")
Chill.apply(e, 2)
assert(Chill.isFrozen(e) and near(Chill.getDamageMultiplier(e, ctBonus), 1.5), "frozen: +50%")
-- Bosses scale with progress toward their 10-stack freeze, up to the same +50%.
local chilledBoss = Tank:new({ game = mockGame, x = 100, y = 100, name = "Tank" })
Chill.apply(chilledBoss, 5)
assert(near(Chill.getDamageMultiplier(chilledBoss, ctBonus), 1.25), "boss halfway to freezing: +25%")
local frozenBoss = Tank:new({ game = mockGame, x = 100, y = 100, name = "Tank" })
Chill.apply(frozenBoss, 10)
assert(near(Chill.getDamageMultiplier(frozenBoss, ctBonus), 1.5), "frozen boss: +50%")
-- Bonuses from several sources add together (Ballista + Cold Tactics).
local both = { ballista.damageVsChill, ct.effect.damageVsChill }
assert(near(Chill.getDamageMultiplier(e, both), 1 + 1.0 + 0.5), "Ballista and Cold Tactics bonuses add")

-- A turret carrying the Cold Tactics effect passes the bonus to its bullets.
local sentryCfg = {}
for k, v in pairs(sentry) do sentryCfg[k] = v end
sentryCfg.game = mockGame
local buffed = sentry.building:new(sentryCfg)
assert(buffed:getDamageVsChill() == nil, "no chill bonus without Cold Tactics")
local granted = {}
for k, v in pairs(ct.effect) do granted[k] = v end
buffed.effectManager:applyEffect(granted)
local list = buffed:getDamageVsChill()
assert(list and #list == 1 and list[1].chilledMax == 0.5 and list[1].frozen == 0.5,
    "Cold Tactics grants its bonus to the turret")

-- Two Cold Tactics around the same turret stack (+20% per chill stack).
local ctGrid = { width = 4, height = 4, cellSize = 32, x = 0, y = 0, buildings = {}, unlocked = {} }
local ctGame = { objects = {}, base = { buildGrid = ctGrid } }
local function slotAt(x, y) return y * ctGrid.width + x + 1 end
local stacked = sentry.building:new(sentryCfg)
ctGrid.buildings[slotAt(1, 1)] = stacked
for _, pos in ipairs({ { 0, 1 }, { 0, 2 } }) do -- one left of the turret, one lower-left
    local tactic = ColdTactics:new({ game = ctGame })
    tactic.buildGrid = ctGrid
    tactic.slot = slotAt(pos[1], pos[2])
    tactic:applyBuffs()
end
local stackedList = stacked:getDamageVsChill()
assert(stackedList and #stackedList == 2, "two Cold Tactics should both grant their bonus")
e = newBasic()
Chill.apply(e, 3)
assert(near(Chill.getDamageMultiplier(e, stackedList), 1.6), "two Cold Tactics stack: 3 stacks -> x1.6")
print("[PASS] Cold Tactics (stacks)")

-- 14. Ice Market: uncommon, cost 2, each placed market pays $5 per frozen death
local imEntry
for _, entry in ipairs(PassiveIndex.uncommon) do
    if entry.id == "iceMarket" then imEntry = entry end
end
assert(imEntry and imEntry.cost == 2, "Ice Market: uncommon, cost 2")

local GameManager = require("Game.Core.GameManager")
local marketGame = { objects = {}, seenEnemies = {}, base = { x = 0, w = 100 }, iceMarketIncome = 0, texts = {} }
function marketGame:addObject(obj) table.insert(self.objects, obj); obj.game = self end
function marketGame:EnemyDied() end
function marketGame:spawnDamageNumber() end
function marketGame:spawnFloatingText(text) table.insert(self.texts, text) end
marketGame.onFrozenEnemyDied = GameManager.onFrozenEnemyDied

local savedState = _G.PersistentState
_G.PersistentState = { cash = 100 }
local function placeMarket()
    local m = imEntry.building:new({ game = marketGame })
    m.slot = 1
    marketGame:addObject(m)
    return m
end
local function killEnemy(freeze)
    local victim = Enemy:new({ game = marketGame, x = 100, y = 100, name = "Basic", maxHp = 10 })
    marketGame:addObject(victim)
    if freeze then Chill.apply(victim, 5) end
    victim:takeDamage(1000, "ice")
end

killEnemy(true)
assert(_G.PersistentState.cash == 100, "no payout without an Ice Market")
placeMarket()
killEnemy(false)
assert(_G.PersistentState.cash == 100, "unfrozen deaths don't pay")
killEnemy(true)
assert(_G.PersistentState.cash == 105 and marketGame.iceMarketIncome == 5, "frozen death pays $5")
assert(marketGame.texts[#marketGame.texts] == "+$5", "shows a floating +$5")
placeMarket()
killEnemy(true)
assert(_G.PersistentState.cash == 115 and marketGame.iceMarketIncome == 15, "each Ice Market pays separately")
_G.PersistentState = savedState
print("[PASS] Ice Market")

-- 15. Artifacts: Brittle Ice (+30% vs frozen) and Heart of the Tundra (15% max HP on thaw)
local ArtifactManager = require("Game.Artifacts.ArtifactManager")
local function artifactGame(ids)
    local g = { objects = {}, seenEnemies = {}, base = { x = 0, w = 100 } }
    function g:addObject(obj) table.insert(self.objects, obj); obj.game = self end
    function g:EnemyDied() end
    function g:spawnDamageNumber() end
    g.artifacts = ArtifactManager:new(g, ids)
    return g
end

local brittleGame = artifactGame({ "brittle_ice" })
local victim = Enemy:new({ game = brittleGame, x = 100, y = 100, name = "Basic", maxHp = 1000 })
brittleGame:addObject(victim)
victim:takeDamage(100, "ballistic")
assert(near(victim.hp, 900), "Brittle Ice: no bonus against unfrozen enemies")
Chill.apply(victim, 5)
victim:takeDamage(100, "ballistic")
assert(near(victim.hp, 770), "Brittle Ice: frozen enemies take 30% more")
local brittleBoss = Tank:new({ game = brittleGame, x = 100, y = 100, name = "Tank" })
brittleGame:addObject(brittleBoss)
Chill.apply(brittleBoss, 10)
local bossHp = brittleBoss.hp
brittleBoss:takeDamage(100, "ballistic")
assert(near(bossHp - brittleBoss.hp, 130), "Brittle Ice: bosses get the same +30%")
print("[PASS] Brittle Ice")

local function thawTest(maker, freezeAt, maxHp)
    local g = artifactGame({ "heart_of_the_tundra" })
    local en = maker(g)
    g:addObject(en)
    local hp0 = en.hp
    Chill.apply(en, freezeAt)
    local t = 0
    while not Chill.isThawing(en) and t < 3 do en.effectManager:update(dt); t = t + dt end
    assert(Chill.isThawing(en), "setup: enemy should thaw")
    return hp0 - en.hp, en:getStat("maxHp")
end
local lost, maxHp = thawTest(function(g)
    return Enemy:new({ game = g, x = 100, y = 100, name = "Basic", maxHp = 1000 })
end, 5)
assert(near(lost, maxHp * 0.15), string.format("Heart of the Tundra: thaw deals 15%% max HP (lost %.1f)", lost))
lost, maxHp = thawTest(function(g)
    return Tank:new({ game = g, x = 100, y = 100, name = "Tank" })
end, 10)
assert(near(lost, maxHp * 0.15), "Heart of the Tundra: bosses take the same 15%")
-- No artifact, no thaw damage.
local plainEnemy = newBasic()
local plainHp = plainEnemy.hp
Chill.apply(plainEnemy, 5)
tick(plainEnemy, Chill.FREEZE_DURATION + 0.1)
assert(plainEnemy.hp == plainHp, "thawing without the artifact deals no damage")
print("[PASS] Heart of the Tundra")

-- 16. A thaw-damage kill counts as a frozen kill for Ice Market
do
    local g = artifactGame({ "heart_of_the_tundra" })
    g.iceMarketIncome = 0
    g.onFrozenEnemyDied = GameManager.onFrozenEnemyDied
    function g:spawnFloatingText() end
    _G.PersistentState = { cash = 0 }
    local market = imEntry.building:new({ game = g })
    market.slot = 1
    g:addObject(market)
    local fragile = Enemy:new({ game = g, x = 100, y = 100, name = "Basic", maxHp = 100 })
    g:addObject(fragile)
    Chill.apply(fragile, 5)
    fragile.hp = 10 -- below 15% of max HP: the thaw damage kills it
    local t = 0
    while not fragile.isDead and t < 3 do fragile.effectManager:update(dt); t = t + dt end
    assert(fragile.isDead, "thaw damage should kill the weakened enemy")
    assert(_G.PersistentState.cash == 5, "a thaw-damage kill pays out as a frozen kill")
    _G.PersistentState = savedState
end
print("[PASS] Thaw kills count as frozen kills")

-- 17. Ice spells
local SpellCardRegistry = require("Spells.SpellCardRegistry")
local EffectManager = require("Game.Effects.EffectManager")
local function spellGame()
    local g = { objects = {}, seenEnemies = {}, base = { x = 0, w = 100 }, animations = {} }
    function g:addObject(obj) table.insert(self.objects, obj); obj.game = self end
    function g:EnemyDied() end
    function g:spawnDamageNumber() end
    function g:spawnFloatingText() end
    function g:spawnExpandingCircle() end
    g.enemyEffectManager = EffectManager:new(nil, g)
    return g
end
local function enemyAt(g, x, y)
    local en = Enemy:new({ game = g, x = x, y = y, name = "Basic", maxHp = 100000 })
    g:addObject(en)
    return en
end
local function runFor(g, seconds)
    local steps = math.floor(seconds / dt + 0.5)
    for _ = 1, steps do
        g.enemyEffectManager:update(dt)
        for _, o in ipairs(g.objects) do o.effectManager:update(dt) end
    end
end

-- Blizzard: 0.5 chill/s with no cap, a 20% slow on top, 5 ice DPS
do
    local g = spellGame()
    local inside, outside = enemyAt(g, 0, 100), enemyAt(g, 300, 100)
    local walker = Enemy:new({ game = g, x = 10, y = 100, name = "Grunt" }) -- real base speed
    g:addObject(walker)
    local walkerSpeed = walker:getStat("speed")
    SpellCardRegistry.Blizzard:execute(0, 100, g)
    runFor(g, 0.5)
    -- Two 0.2s ticks so far: 0.2 chill applied (ticks outpace the decay delay, so no decay)
    assert(Chill.getStacks(inside) > 0.15 and Chill.getStacks(inside) <= 0.26, "Blizzard chills at ~0.5/s")
    local stacks = Chill.getStacks(walker)
    assert(near(walker:getStat("speed"), walkerSpeed * 0.9 ^ stacks * 0.8),
        "Blizzard slows by 20% on top of its chill")
    assert(Chill.getStacks(outside) == 0 and outside.effectManager:getEffect("blizzard_slow") == nil,
        "Blizzard only affects enemies inside")
    runFor(g, 4.5)
    -- ~2.5 stacks over the full 5s: not enough to freeze on its own
    assert(Chill.getStacks(inside) > 2.3 and not Chill.isImmune(inside), "Blizzard alone doesn't freeze in one cast")
    local lost = inside.maxHp - inside.hp
    assert(lost > 23 and lost < 27, string.format("Blizzard deals ~5 DPS (lost %.1f over 5s)", lost))
    runFor(g, 0.5)
    assert(walker.effectManager:getEffect("blizzard_slow") == nil, "the slow wears off once the blizzard ends")
end
-- No cap: Blizzard tops a heavily chilled enemy up to a freeze
do
    local g = spellGame()
    local en = enemyAt(g, 0, 100)
    Chill.apply(en, 4.85)
    SpellCardRegistry.Blizzard:execute(0, 100, g)
    runFor(g, 0.7)
    assert(Chill.isFrozen(en), "Blizzard's chill has no cap")
end
assert(SpellCardRegistry.Blizzard.rarity == "Uncommon", "Blizzard is uncommon")
print("[PASS] Blizzard")

-- Flash Freeze: freezes any chilled enemy in the area; thawing enemies stay immune
do
    local g = spellGame()
    local lightly, unchilled, thawingE, far = enemyAt(g, 0, 100), enemyAt(g, 10, 100), enemyAt(g, 20, 100), enemyAt(g, 300, 100)
    Chill.apply(lightly, 0.1)
    Chill.apply(far, 3)
    Chill.apply(thawingE, 5)
    runFor(g, Chill.FREEZE_DURATION + 0.1)
    assert(Chill.isThawing(thawingE), "setup: enemy should be thawing")
    Chill.apply(lightly, 0.1)
    SpellCardRegistry.FlashFreeze:execute(0, 100, g)
    assert(Chill.isFrozen(lightly), "any amount of chill is enough for Flash Freeze")
    assert(not Chill.isImmune(unchilled), "unchilled enemies are not frozen")
    assert(Chill.isThawing(thawingE), "thawing enemies stay immune")
    assert(not Chill.isFrozen(far), "enemies outside the area are not frozen")
end
print("[PASS] Flash Freeze")

-- Overchill: all chill applied is doubled for 5 seconds; recasting refreshes, not stacks
do
    local g = spellGame()
    local en = enemyAt(g, 0, 100)
    SpellCardRegistry.Overchill:execute(0, 100, g)
    Chill.apply(en, 1)
    assert(near(Chill.getStacks(en), 2), "Overchill doubles chill applied")
    SpellCardRegistry.Overchill:execute(0, 100, g)
    local count = 0
    for _, eff in ipairs(g.enemyEffectManager.activeEffects) do
        if eff.chillMultiplier then count = count + 1 end
    end
    assert(count == 1, "recasting refreshes Overchill instead of stacking it")
    runFor(g, 5.1)
    local before = Chill.getStacks(en)
    Chill.apply(en, 1)
    assert(near(Chill.getStacks(en) - before, 1), "chill returns to normal after 5 seconds")
end
print("[PASS] Overchill")

print("--- Chill / Freeze Tests Completed ---")
