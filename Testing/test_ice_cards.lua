-- Testing/test_ice_cards.lua
-- Ice support cards on a real battle: Permafrost (instant), Cryoelectronics
-- (instant) and Cryo Coolant (artifact).

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
local function near(a, b) return math.abs(a - b) < 1e-6 end

local game = require("Game.Core.GameManager")
local menu = require("Scenes.menu_scene")
local Enemy = require("Enemies.Enemy")
local TurretIndex = require("Buildings.TurretIndex")
local Chill = require("Game.Effects.StatusEffects.Chill")
local InstantCardRegistry = require("Instants.InstantCardRegistry")
local InstantIndex = require("Instants.InstantIndex")
local ArtifactManager = require("Game.Artifacts.ArtifactManager")
local CardFactory = require("Game.Cards.CardFactory")

-- A normal new run, then a battle
menu.scene_manager = { switch = noop }
menu:keypressed("return")
local function loadGame()
    local ps = _G.PersistentState
    ps.selectedMainTurret = "MainLazer"
    ps.discoveredEnemies = { Grunt = true }
    game:load(nil, false)
end
loadGame()

local function findTurret(id)
    for _, rarity in ipairs({ "common", "uncommon", "rare", "epic", "legendary" }) do
        for _, entry in ipairs(TurretIndex[rarity] or {}) do
            if entry.id == id then return entry end
        end
    end
end

local grid = game.base.buildGrid
local function slotAt(x, y)
    if x < 0 or x >= grid.width or y < 0 or y >= grid.height then error("cell off the base grid") end
    return y * grid.width + x + 1
end

--- Places turret `id` on the base grid at cell (x, y).
local function place(id, x, y)
    local entry = findTurret(id)
    local cfg = {}
    for k, v in pairs(entry) do cfg[k] = v end
    cfg.game = game
    local t = entry.building:new(cfg)
    local slot = slotAt(x, y)
    grid.unlocked[slot] = true
    game:newBuilding(t, slot)
    return t
end

local function clearBoard()
    for _, obj in ipairs(game.objects) do
        if obj.isType and obj:isType("turret") and not obj:isType("mainturret") and not obj.destroyed then
            obj:remove()
        end
    end
    game:takeOutTheTrash()
end

-- -----------------------------------------------------------------------------
-- 1. Permafrost: +20% ice damage for the battle, ice turrets only
-- -----------------------------------------------------------------------------
local permafrost = InstantCardRegistry.Permafrost
assert(permafrost.rarity == "Uncommon" and permafrost.cost == 2, "Permafrost is an uncommon 2-cost instant")
local inPool = false
for _, entry in ipairs(InstantIndex.uncommon) do
    if entry.id == permafrost.id then inPool = true end
end
assert(inPool, "Permafrost is in the uncommon reward pool")

local shard = place("iceShard", 0, 0)
local sentry = place("sentry", 2, 0)
local shardDamage, sentryDamage = shard:getStat("damage"), sentry:getStat("damage")
assert(CardFactory.fromReward({ type = "instant", id = permafrost.id }):execute(game), "Permafrost can be played")
assert(near(shard:getStat("damage"), shardDamage * 1.2), "Permafrost: ice turrets deal +20% damage")
assert(near(sentry:getStat("damage"), sentryDamage), "Permafrost: non-ice turrets are unaffected")
local cannon = place("frostCannon", 0, 2)
assert(near(cannon:getStat("damage"), findTurret("frostCannon").damage * 1.2), "Permafrost: ice turrets placed later get it too")
game:clearGlobalBuffs()
clearBoard()

-- -----------------------------------------------------------------------------
-- 2. Cryoelectronics: energy turrets gain chill; faster turrets chill more per
--    second in smaller hits, and no single shot adds more than 2 stacks
-- -----------------------------------------------------------------------------
local cryo = InstantCardRegistry.Cryoelectronics
local blaster = place("blaster", 0, 0)         -- 0.63/s, 1 pellet
local scatter = place("plasmaScattershot", 2, 0) -- 1.6/s, 10 pellets
local flux = place("fluxCannon", 0, 2)         -- 0.33/s, untagged but deals energy damage
local nonEnergy = place("sentry", 2, 2)
assert(cryo:isValidTarget(blaster) and cryo:isValidTarget(scatter) and cryo:isValidTarget(flux),
    "Cryoelectronics targets any turret that deals energy damage")
assert(not cryo:isValidTarget(nonEnergy), "Cryoelectronics can't target a non-energy turret")

local function hitEffectOf(turret)
    local eff = turret.effectManager:getEffect("inst_cryoelectronics_1_eff")
    return eff and eff.grantedHitEffect
end
for _, t in ipairs({ blaster, scatter, flux }) do
    local card = CardFactory.fromReward({ type = "instant", id = cryo.id })
    assert(card:execute(t), "Cryoelectronics applies to " .. t.name)
end
assert(not cryo:isValidTarget(blaster), "Cryoelectronics can't be stacked on the same turret")

local function perShot(t) return hitEffectOf(t):getAmount({ source = t }) * (t:getStat("pelletCount") or 1) end
local function perSecond(t) return perShot(t) * t:getStat("fireRate") end
-- 1.2 x sqrt(fire rate) per second
assert(near(perSecond(blaster), 1.2 * math.sqrt(blaster.fireRate)), string.format("Blaster chills %.2f/s", perSecond(blaster)))
-- Pellets count as extra fire rate: 10 pellets = sqrt(10) shots
assert(near(perSecond(scatter), 1.2 * math.sqrt(1.6 * math.sqrt(10))),
    string.format("Plasma Scattershot chills %.2f/s (pellets count toward fire rate)", perSecond(scatter)))
assert(perSecond(scatter) > perSecond(blaster) and perSecond(blaster) > perSecond(flux),
    "faster turrets chill more per second")
assert(perShot(flux) > perShot(blaster), "slower single-shot turrets chill more per shot")
assert(hitEffectOf(scatter):getAmount({ source = scatter }) < perShot(blaster), "each shotgun pellet chills less than a single shot")
-- Flux Cannon would be 1.2 / sqrt(0.33) = 2.09 a shot: capped
assert(near(perShot(flux), 2), "one shot never adds more than 2 stacks")

local target = Enemy:new({ game = game, x = 400, y = 300, size = 20, maxHp = 1000, hp = 1000 })
game:addObject(target)
hitEffectOf(blaster):trigger(target, { source = blaster })
assert(near(Chill.getStacks(target), 1.2 / math.sqrt(blaster.fireRate)), "a hit chills the enemy")

-- Net over time against decay: a lone fast turret builds chill, a lone slow one barely does
local function netAfter(t, seconds)
    local e = Enemy:new({ game = game, x = 400, y = 300, size = 20, maxHp = 1e6, hp = 1e6 })
    game:addObject(e)
    local hit, interval, timer, peak = hitEffectOf(t), 1 / t.fireRate, 0, 0
    local pellets = t.pelletCount or 1
    for _ = 1, math.floor(seconds * 100) do
        if timer <= 0 then
            for _ = 1, pellets do hit:trigger(e, { source = t }) end
            timer = timer + interval
        end
        e.effectManager:update(0.01)
        timer = timer - 0.01
        peak = math.max(peak, Chill.getStacks(e))
        if Chill.isImmune(e) then e:died(); return 5 end
    end
    e:died()
    return peak
end
assert(netAfter(scatter, 6) >= 5, "Plasma Scattershot (every pellet hitting) freezes within 6s")
assert(netAfter(flux, 6) < 2.5, "Flux Cannon alone barely builds chill")

-- Chill per hit uses the base fire rate, so fire-rate buffs add chill per second
local unbuffedHit = hitEffectOf(blaster):getAmount({ source = blaster })
blaster.effectManager:applyEffect({ name = "test_haste", statModifiers = { fireRate = { mult = 1 } } })
assert(near(hitEffectOf(blaster):getAmount({ source = blaster }), unbuffedHit), "a fire-rate buff doesn't shrink each hit")
assert(near(perSecond(blaster), 2 * 1.2 * math.sqrt(blaster.fireRate)), "doubling fire rate doubles chill per second")

-- Bullets fired by the turret carry the effect
blaster.target = target
local before = #game.objects
blaster:fire()
local bullet = game.objects[#game.objects]
local carried = false
for _, e in ipairs(#game.objects > before and bullet.hitEffects or {}) do
    if e.name == "cryoelectronics_chill" then carried = true end
end
assert(carried, "the turret's bullets carry the chill effect")
target:died()
clearBoard()

-- -----------------------------------------------------------------------------
-- 3. Cryo Coolant: non-ice turrets +10% fire rate per orthogonally adjacent ice turret
-- -----------------------------------------------------------------------------
ArtifactManager.grant("cryo_coolant")
game.artifacts:addInstance("cryo_coolant")
game.artifacts:refresh()

local gun = place("sentry", 1, 5)
local baseRate = gun:getStat("fireRate")
assert(near(baseRate, findTurret("sentry").fireRate), "no bonus without ice neighbours")
local right = place("iceShard", 2, 5)
assert(near(gun:getStat("fireRate"), baseRate * 1.1), "one adjacent ice turret: +10% fire rate")
local below = place("icicleBallista", 1, 6)
assert(near(gun:getStat("fireRate"), baseRate * 1.2), "two adjacent ice turrets: +20% (stacks)")
place("iceShard", 0, 4) -- diagonal
assert(near(gun:getStat("fireRate"), baseRate * 1.2), "diagonal ice turrets don't count")
place("sentry", 0, 5)    -- non-ice neighbour
assert(near(gun:getStat("fireRate"), baseRate * 1.2), "non-ice neighbours don't count")
assert(near(right:getStat("fireRate"), findTurret("iceShard").fireRate), "ice turrets themselves get no bonus")

below:remove()
game:takeOutTheTrash()
assert(near(gun:getStat("fireRate"), baseRate * 1.1), "removing an ice neighbour drops the bonus")

-- The main turret counts too
local main = game.mainLazer
local mainRate = main:getStat("fireRate")
local freeX, freeY
for _, slot in ipairs(main:getSlotsFromPattern(main.slot)) do
    local x, y = (slot - 1) % grid.width, math.floor((slot - 1) / grid.width)
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local nx, ny = x + d[1], y + d[2]
        if not freeX and nx >= 0 and nx < grid.width and ny >= 0 and ny < grid.height
           and not grid.buildings[slotAt(nx, ny)] then
            freeX, freeY = nx, ny
        end
    end
end
local mainNeighbour = place("iceShard", freeX, freeY)
assert(near(main:getStat("fireRate"), mainRate * 1.1), "the main turret gets +10% next to an ice turret")
mainNeighbour:remove()
game:takeOutTheTrash()
ArtifactManager.remove("cryo_coolant")
game.artifacts.artifacts = {}
game.artifacts:refresh()
assert(near(gun:getStat("fireRate"), baseRate), "refreshing without the artifact clears its per-turret bonus")

-- -----------------------------------------------------------------------------
-- 4. Magazine turrets top up a partly used magazine when nothing is in range
-- -----------------------------------------------------------------------------
local mag = place("plasmaScattershot", 3, 10)
mag.ammoCount = 3
for _ = 1, math.floor(Turret.IDLE_RELOAD_DELAY * 60) - 5 do mag:update(1 / 60) end
assert(not mag.isReloading, "a brief gap without a target doesn't trigger a reload")
for _ = 1, 10 do mag:update(1 / 60) end
assert(mag.isReloading, "a partly used magazine reloads after a while with no target")
for _ = 1, math.ceil(mag.reloadTime * 60) + 1 do mag:update(1 / 60) end
assert(not mag.isReloading and mag.ammoCount == mag.ammoMax, "...and comes back full")
mag:update(1 / 60)
assert(not mag.isReloading, "a full magazine doesn't reload")

-- A target arriving mid top-up cancels the reload and the turret fires
local mx, my = mag:getCenterPosition()
local function enemyInFront()
    local e = Enemy:new({ game = game, x = mx + 80, y = my, name = "Grunt", maxHp = 1e6 })
    game:addObject(e)
    return e
end
mag.ammoCount = 5
mag.isReloading, mag.reloadTimer = true, mag.reloadTime
local intruder = enemyInFront()
mag.rotation = 0
for _ = 1, 30 do mag:update(1 / 60) end
assert(not mag.isReloading and mag.ammoCount < 5, "a target cancels a top-up reload and the turret fires")
-- An empty magazine still finishes reloading first
mag.ammoCount = 0
mag.isReloading, mag.reloadTimer = true, mag.reloadTime
for _ = 1, 30 do mag:update(1 / 60) end
assert(mag.isReloading and mag.ammoCount == 0, "an empty magazine can't be interrupted")
intruder:died()
clearBoard()

-- -----------------------------------------------------------------------------
-- 5. Energy damage and the "energy" tag are the same thing
-- -----------------------------------------------------------------------------
-- Tag-based effects (Unstable Laser, Industrial Battery) and damage-type checks
-- (Cryoelectronics) must agree on which turrets count as energy
for _, rarity in ipairs({ "common", "uncommon", "rare", "epic", "legendary" }) do
    for _, entry in ipairs(TurretIndex[rarity] or {}) do
        local t = place(entry.id, 0, 0)
        assert((t.damageType == "energy") == t:isType("energy"),
            entry.id .. ": energy tag matches energy damage")
        clearBoard()
    end
end
for _, obj in ipairs(game.objects) do
    if obj.isType and obj:isType("mainturret") then
        assert((obj.damageType == "energy") == obj:isType("energy"), "main turret: energy tag matches energy damage")
    end
end

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
