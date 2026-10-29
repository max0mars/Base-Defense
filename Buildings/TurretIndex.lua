local BounceEffect = require("Game.Effects.IndependantEffects.bounce")
local ExplosionEffect = require("Game.Effects.IndependantEffects.explosion")
local PoisonEffect = require("Game.Effects.StatusEffects.Poison")
local StunEffect = require("Game.Effects.StatusEffects.Stun")
local Chill = require("Game.Effects.StatusEffects.Chill")
local RewardIndex = {
    common = {
        {
            id = "sentry",
            name = "Sentry",
            description = "Balanced range and damage.",
            type = "building",
            types = {"turret", "building"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.7, range = 420,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/6},
            bulletSpeed = 400, damageType = "physical", damage = 11,
            pierce = 1, lifespan = 1.25, bulletId = "sentryBullet"
        },
        {
            id = "blaster",
            name = "Blaster",
            description = "Fires energy bolts, effective against armor.",
            type = "building",
            types = {"turret", "building", "energy"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.63, range = 340,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/8},
            bulletSpeed = 450, damageType = "energy", damage = 6,
            pierce = 1, lifespan = 1.5, bulletId = "energyBolt",
            burstCount = 3, burstDelay = 0.1, spread = math.rad(2)
        },
        {
            id = "autoCannon",
            name = "Auto Cannon",
            description = "High fire rate, low damage, short range.",
            type = "building",
            types = {"turret", "building"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 3.2, range = 190,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/4},
            bulletSpeed = 350, damageType = "physical", damage = 5,
            pierce = 1, lifespan = 0.8, bulletId = "cannonBullet"
        },
        {
            id = "shotgunTurret",
            name = "Shotgun Turret",
            description = "Shreds close-range targets.",
            type = "building",
            types = {"turret", "building", "shotgun"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.55, range = 150,
            firingArc = {direction = 0, minRange = 0, angle = math.rad(100)},
            spread = math.rad(15), pelletCount = 8,
            bulletSpeed = 480, damageType = "physical", damage = 6,
            pierce = 1, lifespan = 0.8, bulletId = "shotgunPellet"
        },
        {
            id = "heavygun",
            name = "Heavy Gun",
            description = "Long range, high damage.",
            type = "building",
            types = {"turret", "building"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.15, range = 450,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/14},
            bulletSpeed = 500, damageType = "physical", damage = 54,
            pierce = 1, lifespan = 1.5, bulletId = "heavyShell"
        },
    },
    uncommon = {
        {
            id = "icicleBallista",
            name = "Icicle Ballista",
            description = "Fires heavy icicles that deal more damage the more chilled the target is, and the most to frozen enemies.",
            type = "building",
            types = {"turret", "building"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            -- Between Sentry (0.7/s x 11, 420) and Heavy Gun (0.15/s x 54, 450),
            -- with ~15% more base DPS (9.1) as an uncommon.
            rotation = 0, fireRate = 0.35, range = 420,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/9},
            bulletSpeed = 450, damageType = "ice", damage = 26,
            pierce = 1, lifespan = 1.2, bulletId = "icicle",
            -- Up to +60% as chill nears freezing, +100% against frozen enemies.
            damageVsChill = { chilledMax = 0.6, frozen = 1.0 }
        },
        {
            id = "poisonTurret",
            name = "Poison Turret",
            description = "Fires toxic darts that damage over time.",
            type = "building",
            types = {"turret", "building"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.4, range = 300,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/4},
            bulletSpeed = 500, damageType = "poison", damage = 9,
            pierce = 1, lifespan = 2, dps_poison = 8, duration_poison = 4, maxStacks = 4, bulletId = "poisonDart",
            hitEffects = { PoisonEffect:new({name = "Poison"}) }
        },
        {
            id = "airburst",
            name = "Airburst Turret",
            description = "Fires shells that explode mid-air into shrapnel.",
            type = "building",
            types = {"turret", "building"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.4, range = 300,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/4},
            -- Slow shell that bursts at 60% of range into fast shrapnel (see AirburstBullet)
            bulletSpeed = 180, damageType = "physical", damage = 23,
            -- No `spread`: Turret:fire uses it as aim jitter (±spread), so math.pi here made
            -- shells fly in random directions. The burst cone lives in AirburstBullet:airburst().
            pierce = 1, lifespan = 1.5, splitamount = 6, splitDamage = 23, splitDamage_from_damage = 1.0,
            bulletId = "airburst"
        },
        {
            id = "fluxCannon",
            name = "Flux Cannon",
            description = "Energy damage that ignores heavy armor.",
            type = "building",
            types = {"turret", "building"},
            iconCategory = "turret",
            cost = 2,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.33, range = 340,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/6},
            bulletSpeed = 350, damageType = "energy", damage = 54,
            pierce = 1, lifespan = 1.5, bulletId = "fluxCharge"
        },
        {
            id = "grenadier",
            name = "Grenadier",
            description = "Lobs grenades that explode after a short delay.",
            type = "building",
            types = {"turret", "building", "lobber"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.3, range = 380, firingArc = {direction = 0, minRange = 200, angle = math.pi/6},
            fuseTime = 0.7, bulletSpeed = 250, damageType = "explosive", damage = 7,
            burstCount = 3, burstDelay = 0.2, spread = math.rad(5),
            -- Grenades never hit directly: each explodes for damage x explosion_from_damage = 7.
            pierce = 1, lifespan = 1.5, explosionDamage = 7, explosion_from_damage = 1.0, radius = 60, bulletId = "grenade",
            hitEffects = { ExplosionEffect:new({ name = "Grenade Explosion" }) }
        },
        {
            id = "slushCannon",
            name = "Slush Cannon",
            description = "Fires heavy clumps of slush that chill enemies.",
            type = "building",
            types = {"turret", "building", "slow", "control"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.396, range = 340,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/6},
            bulletSpeed = 350, damageType = "ice", damage = 23.04,
            pierce = 1, lifespan = 2, bulletId = "slush",
            hitEffects = { Chill.onHit({ amount = 2 }) }
        },
        {
            id = "heavyShotgun",
            name = "Heavy Shotgun",
            description = "Long range, tight spread shotgun. Its heavy pellets pierce an extra enemy.",
            type = "building",
            types = {"turret", "building", "shotgun"},
            iconCategory = "turret",
            cost = 2,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.5, range = 340,
            firingArc = {direction = 0, minRange = 0, angle = math.rad(40)},
            -- 7 degree cone: ~3.4 of 7 pellets land on a 20px enemy at max range.
            spread = math.rad(7), pelletCount = 7,
            -- Pellet speed varies +-10%, so 650 x 0.6s still reaches 340 at the slowest.
            bulletSpeed = 650, damageType = "physical", damage = 16,
            pierce = 2, lifespan = 0.6, bulletId = "heavyPellet"
        },
    },
    rare = {
        {
            id = "glacialMonolith",
            name = "Glacial Monolith",
            description = "Deals no damage. Sends slow freezing waves through its arc that chill enemies.",
            type = "building",
            types = {"turret", "building"},
            iconCategory = "turret",
            cost = 2,
            building = require("Buildings.Turrets.GlacialMonolith"),
            -- One wave every 3s: 2 chill per wave, but decay only runs for the 2.7s
            -- after chill's decay delay (1.8 stacks), so a stationary enemy slowly
            -- builds up +0.2 per wave.
            rotation = 0, fireRate = 1 / 3, range = 380,
            -- Detects in a 28 degree arc; each ring is 18 degrees wide, aimed at the
            -- target but kept fully inside the arc.
            firingArc = {direction = 0, minRange = 0, angle = math.rad(28)},
            ringAngle = math.rad(18), waveSpeed = 120, chillPerWave = 2,
            bulletSpeed = 0, damageType = "ice", damage = 0,
            pierce = 1, lifespan = 0
        },
        {
            id = "iceShard",
            name = "Ice Shard Gunner",
            description = "Rapidly fires ice shards that chill enemies.",
            type = "building",
            types = {"turret", "building"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 2.3, range = 350,
            firingArc = {direction = 0, minRange = 0, angle = math.rad(35)},
            bulletSpeed = 450, damageType = "ice", damage = 5,
            pierce = 1, lifespan = 0.8, bulletId = "iceShard",
            hitEffects = { Chill.onHit({ amount = 0.5 }) }
        },
        {
            id = "gator",
            name = "GTR-55 Gator",
            description = "Hard hitting rounds go right through enemies.",
            type = "building",
            types = {"turret", "building"},
            iconCategory = "turret",
            cost = 2,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.55, range = 380,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/6},
            bulletSpeed = 500, damageType = "physical", damage = 54,
            pierce = 3, lifespan = 1.5, bulletId = "gatorRound"
        },
        {
            id = "missileLauncher",
            name = "Missile Launcher",
            description = "Wouldn't want to get in the way of one of these.",
            type = "building",
            types = {"turret", "building"},
            iconCategory = "turret",
            cost = 2,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.4, range = 340, firingArc = {direction = 0, minRange = 0, angle = math.pi/6},
            bulletSpeed = 200, damageType = "explosive", damage = 50,
            pierce = 1, lifespan = 3, explosionDamage = 50, explosion_from_damage = 1.0, radius = 40, bulletId = "missile",
            hitEffects = { ExplosionEffect:new({ name = "Missile Explosion" }) }
        },
        {
            id = "plasmaScattershot",
            name = "Plasma Scattershot",
            description = "Fires plasma rounds at high speed from a 6-round magazine. Loads one round every 2 seconds.",
            type = "building",
            types = {"turret", "building", "shotgun"},
            iconCategory = "turret",
            cost = 2,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 1.6, range = 150, firingArc = {direction = 0, minRange = 0, angle = math.rad(80)},
            spread = math.rad(16.5), pelletCount = 8,
            ammoMax = 6, reloadTime = 2, -- one round every 2s
            bulletSpeed = 600, damageType = "energy", damage = 10,
            pierce = 1, lifespan = 0.5, bulletId = "plasmaBolt"
        },
        {
            id = "sequenceTurret",
            name = "CSR-8 Sequence",
            description = "Shoots faster the longer it stays locked onto a target.",
            type = "building",
            types = {"turret", "building"},
            iconCategory = "turret",
            cost = 2,
            building = require("Buildings.Turrets.SequenceTurret"),
            rotation = 0, fireRate = 0.4, range = 340, firingArc = {direction = 0, minRange = 0, angle = math.pi/5},
            coolDownRate = 0.5, fireRateMultiplier = 12,
            bulletSpeed = 500, damageType = "physical", damage = 18,
            pierce = 1, lifespan = 1.5, bulletId = "sequenceRound"
        },
        {
            id = "hookTurret",
            name = "The Hook",
            description = "Fires a heavy shot that stuns enemies in their tracks.",
            type = "building",
            types = {"turret", "building", "stun", "control"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.25, range = 270,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/4},
            bulletSpeed = 250, damageType = "physical", damage = 72,
            pierce = 1, lifespan = 2, bulletId = "heavyHook",
            hitEffects = { StunEffect:new({name = "Hook Stun", duration = 1.0}) }
        },
    },
    epic = {
        {
            id = "frostCannon",
            name = "Frost Cannon",
            description = "Long range, tight spread shotgun. Its pellets chill enemies.",
            type = "building",
            types = {"turret", "building", "shotgun"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.8, range = 420,
            firingArc = {direction = 0, minRange = 0, angle = math.rad(45 * 0.75 - 5)},
            -- 9.2 degree cone: ~1.8 of 6 pellets land on a 20px enemy at max range.
            spread = math.rad(9.2), pelletCount = 6,
            -- Pellet speed varies +-10%, so 600 x 0.8s still reaches 420 at the slowest.
            bulletSpeed = 600, damageType = "ice", damage = 12,
            pierce = 1, lifespan = 0.8, bulletId = "frostPellet",
            hitEffects = { Chill.onHit({ amount = 0.5 }) }
        },
        {
            id = "cryoBeam",
            name = "Cryo Beam",
            description = "Locks a freezing beam onto one enemy until it freezes, then moves to the next target.",
            type = "building",
            types = {"turret", "building"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.CryoBeam"),
            -- Beam ticks: 4 per second x 6.25 damage = 25 DPS.
            rotation = 0, fireRate = 4, range = 380,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/6},
            bulletSpeed = 0, damageType = "ice", damage = 6.25,
            pierce = 1, lifespan = 0,
            -- The first tick lands on lock, then every 0.25s. Ticks come faster
            -- than chill's decay delay, so nothing drains: 13a = 5, so the 13th
            -- tick (t = 3.0s) reaches 5 stacks.
            hitEffects = { Chill.onHit({ amount = 5 / 13 }) }
        },
        {
            id = "sniper",
            name = "Sniper Turret",
            description = "High damage, long range.",
            type = "building",
            types = {"turret", "building"},
            iconCategory = "turret",
            cost = 2,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.10, range = 550, firingArc = {direction = 0, minRange = 225, angle = math.pi/2},
            bulletSpeed = 0, damageType = "physical", damage = 225,
            pierce = 1, lifespan = 0.3, maxLifespan = 0.3, bulletId = "sniperShot"
        },
        {
            id = "mortar",
            name = "Mortar",
            description = "KABOOM!",
            type = "building",
            types = {"turret", "building", "lobber"},
            iconCategory = "turret",
            cost = 2,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.115, range = 380, firingArc = {direction = 0, minRange = 255, angle = math.pi/4},
            bulletSpeed = 200, damageType = "explosive", damage = 90,
            pierce = 1, lifespan = 2, explosionDamage = 90, explosion_from_damage = 1.0, radius = 80, bulletId = "mortarShell",
            hitEffects = { ExplosionEffect:new({ name = "Mortar Explosion" }) }
        },
    },
    legendary = {
        {
            id = "chainLaser",
            name = "PROJECT CHIMERA",
            description = "No one is safe",
            type = "building",
            types = {"turret", "building"},
            iconCategory = "turret",
            cost = 3,
            building = require("Buildings.Turrets.ChainLaser"),
            rotation = 0, fireRate = 0.5, range = 380, barrel = 12,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/6},
            color = {0.4, 0.7, 1, 1},
            bulletSpeed = 600, damageType = "energy", damage = 27,
            pierce = 1, lifespan = 5, bouncesLeft = 5, bulletId = "chainLaserBolt",
            hitEffects = { BounceEffect:new({ name = "Chain Bounce" }) }
        }
    }
}

-- Each entry knows its rarity (the tier it's listed under); placed buildings keep it
for rarity, tierList in pairs(RewardIndex) do
    for _, turretConfig in ipairs(tierList) do
        turretConfig.rarity = rarity
    end
end

-- Deep Merge Visuals
local success, Visuals = pcall(require, "Buildings.TurretVisualIndex")
if success and type(Visuals) == "table" then
    for _, tierList in pairs(RewardIndex) do
        for _, turretConfig in ipairs(tierList) do
            local vis = Visuals[turretConfig.id]
            if vis then
                for k, v in pairs(vis) do
                    turretConfig[k] = v
                end
            end
        end
    end
end

return RewardIndex
