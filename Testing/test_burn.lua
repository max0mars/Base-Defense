-- Testing/test_burn.lua
-- Fire synergy on a real battle: burn stages and decay, oil, thermite, fire
-- zones (cinders, Blazing Flames), the fire turrets, instants and artifacts.

package.path = package.path .. ";./?.lua"

-- Mock love2d (every love.* function is a no-op; GameManager pulls in the whole game)
local noop = function() end
local fontStub = { getWidth = function() return 10 end, getHeight = function() return 10 end, getWrap = function() return 10, { "" } end }
_G.love = setmetatable({
    math = setmetatable({ random = math.random, colorFromBytes = function(...) return ... end }, { __index = function() return noop end }),
    timer = { getTime = function() return 0 end },
    mouse = setmetatable({ getPosition = function() return 0, 0 end }, { __index = function() return noop end }),
    keyboard = { isDown = function() return false end },
    graphics = setmetatable({
        getFont = function() return fontStub end,
        newFont = function() return fontStub end,
        newCanvas = function() return {} end,
        getWidth = function() return 1280 end,
        getHeight = function() return 720 end,
    }, { __index = function() return noop end }),
}, { __index = function() return setmetatable({}, { __index = function() return noop end }) end })
_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720
_G.SetGameScissor = noop
_G.paused = 0
math.atan2 = math.atan2 or math.atan

local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end
local function near(a, b, eps) return math.abs(a - b) < (eps or 1e-6) end

local game = require("Game.Core.GameManager")
local menu = require("Scenes.menu_scene")
local Enemy = require("Enemies.Enemy")
local TurretIndex = require("Buildings.TurretIndex")
local Burn = require("Game.Effects.StatusEffects.Burn")
local Oil = require("Game.Effects.StatusEffects.Oil")
local Thermite = require("Game.Effects.StatusEffects.Thermite")
local DamageTypes = require("Classes.DamageTypes")
local DamageStats = require("Game.Core.DamageStats")
local InstantCardRegistry = require("Instants.InstantCardRegistry")
local InstantIndex = require("Instants.InstantIndex")
local SpellCardRegistry = require("Spells.SpellCardRegistry")
local SpellIndex = require("Spells.SpellIndex")
local ArtifactManager = require("Game.Artifacts.ArtifactManager")
local ArtifactIndex = require("Game.Artifacts.ArtifactIndex")
local CardFactory = require("Game.Cards.CardFactory")

print("--- Starting Burn / Fire Synergy Tests ---")

menu.scene_manager = { switch = noop }
menu:keypressed("return")
local ps = _G.PersistentState
ps.selectedMainTurret = "MainLazer"
ps.discoveredEnemies = { Grunt = true }
game:load(nil, false)
game.damageStats = DamageStats.new()

local function findTurret(id)
    for _, rarity in ipairs({ "common", "uncommon", "rare", "epic", "legendary" }) do
        for _, entry in ipairs(TurretIndex[rarity] or {}) do
            if entry.id == id then return entry, rarity end
        end
    end
end

local grid = game.base.buildGrid
local function place(id, x, y)
    local entry = findTurret(id)
    local cfg = {}
    for k, v in pairs(entry) do cfg[k] = v end
    cfg.game = game
    local t = entry.building:new(cfg)
    local slot = y * grid.width + x + 1
    grid.unlocked[slot] = true
    game:newBuilding(t, slot)
    return t
end

local function clearBoard()
    for _, obj in ipairs(game.objects) do
        if obj.isType and not obj.destroyed and (obj:isType("enemy") or (obj:isType("turret") and not obj:isType("mainturret"))) then
            if obj:isType("enemy") then obj:destroy() else obj:remove() end
        end
    end
    game:takeOutTheTrash()
    game.animations = {}
    game.enemyEffectManager.activeEffects = {}
    game.enemyEffectManager.effectCounts = {}
    game.enemyEffectManager:recalculateStats()
end

local function newEnemy(x, y)
    local e = Enemy:new({ game = game, x = x or 600, y = y or 300, size = 20, maxHp = 1e6, hp = 1e6 })
    game:addObject(e)
    return e
end

-- Steps an enemy's effects (and optionally the global enemy effects) in small frames
local function tick(enemies, seconds, withGlobal)
    if enemies.effectManager then enemies = { enemies } end
    for _ = 1, math.floor(seconds / 0.01 + 0.5) do
        for _, e in ipairs(enemies) do
            if not e.destroyed then e.effectManager:update(0.01) end
        end
        if withGlobal then game.enemyEffectManager:update(0.01) end
    end
end

local function withArtifact(id, fn)
    ArtifactManager.grant(id)
    game.artifacts:addInstance(id)
    game.artifacts:refresh()
    fn()
    ArtifactManager.remove(id)
    game.artifacts.artifacts = {}
    game.artifacts:refresh()
end

-- With no decay, stacks only ever go up: makes application counts exact
local function withoutDecay(fn)
    local base, scale = Burn.DECAY_BASE, Burn.DECAY_SCALE
    Burn.DECAY_BASE, Burn.DECAY_SCALE = 0, 0
    fn()
    Burn.DECAY_BASE, Burn.DECAY_SCALE = base, scale
end

local fireAff = DamageTypes.affinityMultiplier(newEnemy().affinities, "fire", { "dot" })

-- -----------------------------------------------------------------------------
-- 1. Stages and the decay function
-- -----------------------------------------------------------------------------
assert(Burn.getStage(0) == 0 and Burn.getStage(0.3) == 1 and Burn.getStage(9.9) == 1, "1-9 stacks is stage 1")
assert(Burn.getStage(10) == 2 and Burn.getStage(19.9) == 2, "10-19 stacks is stage 2")
assert(Burn.getStage(20) == 3 and Burn.getStage(50) == 3, "20+ stacks is stage 3")
assert(Burn.getStageDps(5) == 10 and Burn.getStageDps(15) == 20 and Burn.getStageDps(25) == 30, "stages deal 10 / 20 / 30 dps")
assert(near(Burn.getDecayRate(10), 0.5 + 0.04 * 100), "decay = BASE + SCALE * stacks ^ POWER")
assert(Burn.getDecayRate(20) > Burn.getDecayRate(10) * 3, "decay speeds up sharply with more stacks")
assert(near(Burn.getStageProgress(15), 0.5) and near(Burn.getStageProgress(25), 0.5), "progress bar fills through each stage")

-- -----------------------------------------------------------------------------
-- 2. Damage over time and burning out
-- -----------------------------------------------------------------------------
local e = newEnemy()
Burn.apply(e, 5)
assert(near(Burn.getStacks(e), 5), "applying burn adds stacks")
local hp = e.hp
tick(e, 1.0)
assert(near(hp - e.hp, 10 * fireAff, 1e-3), string.format("stage 1 deals 10 damage per second (%.2f)", hp - e.hp))
assert(Burn.getStacks(e) < 5, "stacks decay over time")

local s2, s3 = newEnemy(), newEnemy()
Burn.apply(s2, 15); Burn.apply(s3, 28)
local hp2, hp3 = s2.hp, s3.hp
tick({ s2, s3 }, 0.2)
assert(near(hp2 - s2.hp, 20 * 0.2 * fireAff, 1e-3), "stage 2 deals 20 damage per second")
assert(near(hp3 - s3.hp, 30 * 0.2 * fireAff, 1e-3), "stage 3 deals 30 damage per second")

local out = newEnemy()
Burn.apply(out, 3)
tick(out, 4.5)
assert(Burn.isBurning(out), "3 stacks still burn after 4.5s")
tick(out, 1.0)
assert(not Burn.isBurning(out) and Burn.getState(out) == nil, "3 stacks burn out after ~5s and the state is removed")

-- Steady state against decay, hit by a turret at a fixed rate
local function steadyStacks(stacksPerHit, hitsPerSecond, seconds)
    local target = newEnemy()
    local interval, timer, total, n = 1 / hitsPerSecond, 0, 0, 0
    for i = 1, math.floor(seconds * 100) do
        if timer <= 0 then Burn.apply(target, stacksPerHit); timer = timer + interval end
        target.effectManager:update(0.01)
        timer = timer - 0.01
        if i > 300 then total = total + Burn.getStacks(target); n = n + 1 end
    end
    target:destroy()
    return total / n
end
local flare = steadyStacks(1, 0.7, 15)
assert(flare > 1 and flare < 3.5, string.format("one Flare Gun holds a target in stage 1 (~%.1f stacks)", flare))
local thrower = steadyStacks(1, 3.5, 15)
assert(thrower > 6 and thrower < 10, string.format("one Flamethrower holds a target just under stage 2 (~%.1f stacks)", thrower))
clearBoard()

-- -----------------------------------------------------------------------------
-- 3. Oil
-- -----------------------------------------------------------------------------
local oiled = newEnemy()
local speed = oiled:getStat("speed")
Oil.apply(oiled)
assert(Oil.isOiled(oiled), "oil sticks to an enemy that isn't burning")
assert(near(oiled:getStat("speed"), speed * (1 - Oil.SLOW)), "oil slows")
Burn.apply(oiled, 3)
assert(near(Burn.getStacks(oiled), 3 + Oil.BONUS_STACKS), "burn ignites the oil for 5 extra stacks")
assert(not Oil.isOiled(oiled) and near(oiled:getStat("speed"), speed), "ignited oil is used up (and its slow ends)")

local burning = newEnemy()
Burn.apply(burning, 2)
Oil.apply(burning)
assert(near(Burn.getStacks(burning), 2 + Oil.BONUS_STACKS) and not Oil.isOiled(burning),
    "oiling a burning enemy adds 5 stacks at once")

local lapsed = newEnemy()
Oil.apply(lapsed)
tick(lapsed, Oil.DURATION + 0.1)
assert(not Oil.isOiled(lapsed), "unlit oil wears off")
clearBoard()

-- -----------------------------------------------------------------------------
-- 4. Thermite: 3 burn a second for 5 seconds per charge, and charges stack
-- -----------------------------------------------------------------------------
withoutDecay(function()
    game.damageStats = DamageStats.new()
    local launcher = place("thermiteLauncher", 0, 0)
    local t = newEnemy()
    Thermite.attach(t, { source = launcher })
    tick(t, 2.5)
    Thermite.attach(t, { source = launcher })
    assert(Thermite.count(t) == 2, "thermite charges stack")
    tick(t, 10)
    assert(near(Burn.getStacks(t), 30), string.format("two charges apply 15 burn each (%.1f)", Burn.getStacks(t)))
    assert(Thermite.count(t) == 0, "spent charges fall off")
    assert(game.damageStats:get(launcher).damage > 0, "thermite burn is credited to the launcher")
end)
clearBoard()

-- -----------------------------------------------------------------------------
-- 5. Fire turrets
-- -----------------------------------------------------------------------------
local expected = {
    flareGun = "common", oilGun = "uncommon", flamethrower = "rare", cinderMortar = "rare",
    thermiteLauncher = "rare", infernoTower = "epic", meteor = "legendary",
}
for id, rarity in pairs(expected) do
    local entry, got = findTurret(id)
    assert(entry and got == rarity and entry.damageType == "fire", id .. " is a " .. rarity .. " fire turret")
end

-- Flare Gun bullets apply 1 burn
local flareGun = place("flareGun", 0, 0)
local fe = newEnemy()
flareGun.target = fe
flareGun:fire({ targetX = fe.x, targetY = fe.y })
game.objects[#game.objects]:onHit(fe)
assert(near(Burn.getStacks(fe), 1), "a flare applies 1 burn")

-- Cinder Mortar: cinders burn the first enemy to step on them, once
local mortar = place("cinderMortar", 2, 0)
mortar:fire({ targetX = 600, targetY = 300 })
local cinders = {}
for _, obj in ipairs(game.objects) do
    if obj.bulletDef == nil and obj.onGroundImpact and obj.source == mortar then table.insert(cinders, obj) end
end
assert(#cinders == findTurret("cinderMortar").pelletCount, "the mortar lobs one cinder per pellet")
for _, c in ipairs(cinders) do c:onGroundImpact() end
local zones = 0
for _, eff in ipairs(game.enemyEffectManager.activeEffects) do if eff.name == "cinder" then zones = zones + 1 end end
assert(zones == #cinders, "every cinder lands as a burning cinder")
local cz = game.enemyEffectManager.activeEffects[#game.enemyEffectManager.activeEffects]
local walker = newEnemy(cz.x, cz.y)
local walkerHp = walker.hp
game.enemyEffectManager:update(0.01)
assert(Burn.getStacks(walker) >= 3 and walker.hp < walkerHp, "stepping on a cinder deals fire damage and applies burn")
assert(cz.spent, "a cinder goes out after burning one enemy")
clearBoard()

-- Inferno Tower ramps to 5x on one target
local inferno = place("infernoTower", 0, 0)
local ie = newEnemy()
inferno.target, inferno.lockTime = ie, 0
local ihp = ie.hp
inferno:tick(ie)
local first = ihp - ie.hp
inferno.lockTime = 10
ihp = ie.hp
inferno:tick(ie)
assert(near((ihp - ie.hp) / first, 5, 1e-6), "Inferno Tower deals 5x damage once fully ramped")
assert(not Burn.isBurning(ie), "Inferno Tower doesn't apply burn")
clearBoard()

-- Meteor: impact damage (no burn), then a crater that burns
local meteor = place("meteor", 0, 0)
local me = newEnemy(600, 300)
local mhp = me.hp
meteor:fire({ targetX = 600, targetY = 300 })
local strike = game.animations[#game.animations]
assert(meteor.transmitTime == 0, "calling a meteor starts the dish's transmit waves")
assert(pcall(meteor.draw, meteor), "the transmit waves draw")
local T = meteor.TRANSMIT
for _ = 1, math.ceil(((T.WAVES - 1) * T.WAVE_GAP + T.WAVE_LIFE) / 0.05) + 1 do
    meteor:update(0.05)
    if meteor.transmitTime == nil then break end
end
assert(meteor.transmitTime == nil, "the transmit waves finish")
strike:update(0.5)
assert(me.hp == mhp, "the meteor hasn't landed yet")
strike:update(0.4)
assert(me.hp < mhp, "the meteor hits enemies in its radius")
assert(not Burn.isBurning(me), "the impact itself applies no burn")
game.enemyEffectManager:update(0.01)
assert(Burn.isBurning(me), "the crater applies burn to enemies inside")
clearBoard()

-- -----------------------------------------------------------------------------
-- 6. Instants
-- -----------------------------------------------------------------------------
local function inPool(index, rarity, id)
    for _, entry in ipairs(index[rarity]) do if entry.id == id then return true end end
    return false
end

local incendiary = InstantCardRegistry.IncendiaryRounds
assert(incendiary.rarity == "Uncommon" and incendiary.cost == 1 and inPool(InstantIndex, "uncommon", incendiary.id),
    "Incendiary Rounds is an uncommon 1-cost instant in the pool")
local sentry = place("sentry", 0, 0)
local flareT = place("flareGun", 2, 0)
assert(incendiary:isValidTarget(sentry) and not incendiary:isValidTarget(flareT), "Incendiary Rounds targets physical turrets only")
assert(CardFactory.fromReward({ type = "instant", id = incendiary.id }):execute(sentry), "Incendiary Rounds can be played")
assert(not incendiary:isValidTarget(sentry), "Incendiary Rounds can't stack on one turret")
local ie2 = newEnemy()
sentry:fire({ targetX = ie2.x, targetY = ie2.y })
game.objects[#game.objects]:onHit(ie2)
assert(near(Burn.getStacks(ie2), 2), "Incendiary Rounds: each hit applies a flat 2 burn")
assert(sentry.damageType == "physical", "the turret keeps its damage type")

local fan = InstantCardRegistry.FanTheFlames
local flareRate, sentryRate = flareT:getStat("fireRate"), sentry:getStat("fireRate")
assert(CardFactory.fromReward({ type = "instant", id = fan.id }):execute(game), "Fan the Flames can be played")
assert(near(flareT:getStat("fireRate"), flareRate * 1.1), "Fan the Flames: fire turrets fire 10% faster")
assert(near(sentry:getStat("fireRate"), sentryRate), "Fan the Flames: a turret with Incendiary Rounds isn't a fire turret")
game:clearGlobalBuffs()

local accel = InstantCardRegistry.CheapAccelerants
assert(accel.rarity == "Rare" and accel.cost == 1, "Cheap Accelerants is a rare 1-cost instant")
local ce = newEnemy()
local flareDamage = flareT:getStat("damage")
assert(CardFactory.fromReward({ type = "instant", id = accel.id }):execute(game), "Cheap Accelerants can be played")
assert(near(flareT:getStat("damage"), flareDamage * 2), "Cheap Accelerants: fire turrets deal double damage")
assert(near(Burn.getDamageMultiplier(ce), 2), "Cheap Accelerants: burn deals double damage")
game.playerEffectManager:clearWaveEffects()
game.playerEffectManager:recalculateStats()
game.playerEffectManager:propagateRecalculation()
assert(near(Burn.getDamageMultiplier(ce), 1) and near(flareT:getStat("damage"), flareDamage), "Cheap Accelerants ends with the wave")
clearBoard()

-- -----------------------------------------------------------------------------
-- 7. Spells
-- -----------------------------------------------------------------------------
assert(inPool(SpellIndex, "uncommon", "spell_embers") and inPool(SpellIndex, "rare", "spell_blazingflames"),
    "Embers and Blazing Flames are in the spell pool")

local ember = newEnemy(600, 300)
SpellCardRegistry.Embers:execute(600, 300, game)
tick(ember, 1.0, true)
assert(Burn.getStacks(ember) > 3, "Embers keeps applying burn to enemies inside")
clearBoard()

local inside, outside = newEnemy(600, 300), newEnemy(900, 300)
SpellCardRegistry.BlazingFlames:execute(600, 300, game)
assert(near(Burn.getStacks(inside), 10) and not Burn.isBurning(outside), "Blazing Flames applies 10 burn in its radius")
tick({ inside }, 0.05, true)
assert(near(Burn.getDamageMultiplier(inside), 2) and near(Burn.getDecayMultiplier(inside), 2),
    "Blazing Flames doubles burn damage and decay inside")
assert(near(Burn.getDamageMultiplier(outside), 1), "Blazing Flames doesn't affect enemies outside")
inside.x = 900
tick({ inside }, 0.3, true)
assert(near(Burn.getDecayMultiplier(inside), 1), "leaving the zone ends its multipliers")
clearBoard()

-- -----------------------------------------------------------------------------
-- 8. Artifacts
-- -----------------------------------------------------------------------------
withArtifact("fuel_tank", function()
    local f = newEnemy()
    Burn.apply(f, 1)
    Burn.apply(f, 3)
    assert(near(Burn.getStacks(f), 6), "Fuel Tank: each application adds 1 extra stack")
end)

withArtifact("persistent_flames", function()
    local p = newEnemy()
    assert(near(Burn.getDecayMultiplier(p), 0.7), "Persistent Flames: burn decays 30% slower")
end)

clearBoard()
withArtifact("combustion", function()
    local dying, near1, far = newEnemy(600, 300), newEnemy(650, 300), newEnemy(1000, 300)
    Burn.apply(dying, 12)
    dying:takeDamage(dying.hp + 1, "physical")
    for _ = 1, 100 do
        for i = #game.animations, 1, -1 do
            local anim = game.animations[i]
            anim:update(0.01)
            if anim.destroyed then table.remove(game.animations, i) end
        end
    end
    assert(near(Burn.getStacks(near1), 12, 1e-6), "Combustion: a burning enemy's stacks spread to the nearest enemy")
    assert(not Burn.isBurning(far), "Combustion: only the nearest enemy catches")
end)
clearBoard()

for _, id in ipairs({ "fuel_tank", "persistent_flames", "combustion" }) do
    assert(ArtifactIndex.get(id) ~= nil, id .. " artifact exists")
end

-- -----------------------------------------------------------------------------
-- 9. Visuals draw without errors
-- -----------------------------------------------------------------------------
local v = newEnemy()
Burn.apply(v, 25)
Oil.apply(newEnemy())
Thermite.attach(v)
tick(v, 0.3)
assert(#Burn.getState(v).particles > 0, "burning enemies emit flame particles")
local ok, err = pcall(function()
    for _, obj in ipairs(game.objects) do
        if obj.drawStatusEffects and not obj.destroyed then obj:drawStatusEffects() end
    end
end)
assert(ok, "burn, oil and thermite visuals draw (" .. tostring(err) .. ")")
local lo, hi = newEnemy(), newEnemy()
Burn.apply(lo, 2); Burn.apply(hi, 28)
tick({ lo, hi }, 0.5)
assert(#Burn.getState(hi).particles > #Burn.getState(lo).particles, "more stacks, more particles")

if failures > 0 then
    print(failures .. " test(s) failed")
    os.exit(1)
end
print("--- All Burn Tests Passed ---")
