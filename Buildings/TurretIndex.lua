local BounceEffect = require("Game.Effects.IndependantEffects.bounce")
local ExplosionEffect = require("Game.Effects.IndependantEffects.explosion")
local PoisonEffect = require("Game.Effects.StatusEffects.Poison")
local SlowEffect = require("Game.Effects.StatusEffects.Slow")
local StunEffect = require("Game.Effects.StatusEffects.Stun")
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
            rotation = 0, fireRate = 0.7, range = 380,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/6},
            bulletSpeed = 400, damageType = "physical", damage = 11,
            pierce = 1, lifespan = 1.25, bulletId = "sentryBullet"
        },
        {
            id = "blaster",
            name = "Blaster",
            description = "Fires energy bolts, effective against armor.",
            type = "building",
            types = {"turret", "building"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.7, range = 300,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/8},
            bulletSpeed = 450, damageType = "energy", damage = 6,
            pierce = 1, lifespan = 1.5, bulletId = "energyBolt",
            burstCount = 2, burstDelay = 0.1, spread = math.rad(2)
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
            bulletSpeed = 480, damageType = "physical", damage = 4,
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
            id = "poisonTurret",
            name = "Poison Turret",
            description = "Fires toxic darts that damage over time.",
            type = "building",
            types = {"turret", "building", "poison"},
            iconCategory = "turret",
            cost = 2,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.4, range = 300,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/4},
            bulletSpeed = 500, damageType = "poison", damage = 9,
            pierce = 1, lifespan = 2, dps_poison = 4, duration_poison = 4, maxStacks = 4, bulletId = "poisonDart",
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
            types = {"turret", "building", "energy"},
            iconCategory = "turret",
            cost = 2,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.3, range = 340,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/6},
            bulletSpeed = 350, damageType = "energy", damage = 54,
            pierce = 1, lifespan = 1.5, bulletId = "fluxCharge"
        },
        {
            id = "grenadier",
            name = "Grenadier",
            description = "Lobs grenades that explode after a short delay.",
            type = "building",
            types = {"turret", "building", "explosive", "lobber"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.3, range = 380, firingArc = {direction = 0, minRange = 200, angle = math.pi/6},
            fuseTime = 0.7, bulletSpeed = 250, damageType = "physical", damage = 7,
            burstCount = 3, burstDelay = 0.2, spread = math.rad(5),
            pierce = 1, lifespan = 1.5, explosionDamage = 35, explosion_from_damage = 1.0, radius = 60, bulletId = "grenade",
            hitEffects = { ExplosionEffect:new({ name = "Grenade Explosion" }) }
        },
        {
            id = "slushCannon",
            name = "Slush Cannon",
            description = "Fires heavy clumps of slush that slow enemies on impact.",
            type = "building",
            types = {"turret", "building", "slow"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.25, range = 340,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/6},
            bulletSpeed = 350, damageType = "water", damage = 36,
            pierce = 1, lifespan = 2, bulletId = "slush",
            hitEffects = { SlowEffect:new({name = "Slush Slow", duration = 2.0, amount = 0.4}) }
        },
    },
    rare = {
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
            types = {"turret", "building", "explosive"},
            iconCategory = "turret",
            cost = 2,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.4, range = 340, firingArc = {direction = 0, minRange = 0, angle = math.pi/6},
            bulletSpeed = 200, damageType = "physical", damage = 81,
            pierce = 1, lifespan = 3, explosionDamage = 81, explosion_from_damage = 1.0, radius = 100, bulletId = "missile",
            hitEffects = { ExplosionEffect:new({ name = "Missile Explosion" }) }
        },
        {
            id = "plasmaScattershot",
            name = "Plasma Scattershot",
            description = "Fires plamsa rounds at high speed but has limited ammo. Reloads slowly.",
            type = "building",
            types = {"turret", "building", "energy", "shotgun"},
            iconCategory = "turret",
            cost = 2,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 1.6, range = 150, firingArc = {direction = 0, minRange = 0, angle = math.rad(80)},
            spread = math.rad(15), pelletCount = 10,
            ammoMax = 15, reloadTime = 4,
            bulletSpeed = 600, damageType = "energy", damage = 11,
            pierce = 2, lifespan = 0.5, bulletId = "plasmaBolt"
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
            types = {"turret", "building", "stun"},
            iconCategory = "turret",
            cost = 1,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.25, range = 230,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/4},
            bulletSpeed = 250, damageType = "physical", damage = 72,
            pierce = 1, lifespan = 2, bulletId = "heavyHook",
            hitEffects = { StunEffect:new({name = "Hook Stun", duration = 1.0}) }
        },
    },
    epic = {
        {
            id = "sniper",
            name = "Sniper Turret",
            description = "High damage, long range.",
            type = "building",
            types = {"turret", "building", "hitscan"},
            iconCategory = "turret",
            cost = 2,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.15, range = 750, firingArc = {direction = 0, minRange = 0, angle = math.pi/2},
            bulletSpeed = 0, damageType = "physical", damage = 225,
            pierce = 1, lifespan = 0.3, maxLifespan = 0.3, bulletId = "sniperShot"
        },
        {
            id = "mortar",
            name = "Mortar",
            description = "KABOOM!",
            type = "building",
            types = {"turret", "building", "lobber", "explosive"},
            iconCategory = "turret",
            cost = 2,
            building = require("Buildings.Turrets.Turret"),
            rotation = 0, fireRate = 0.1, range = 380, firingArc = {direction = 0, minRange = 300, angle = math.pi/4},
            bulletSpeed = 200, damageType = "physical", damage = 90,
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
            types = {"turret", "building", "legendary", "energy"},
            iconCategory = "turret",
            cost = 3,
            building = require("Buildings.Turrets.ChainLaser"),
            rotation = 0, fireRate = 0.5, range = 380, barrel = 12,
            firingArc = {direction = 0, minRange = 0, angle = math.pi/6},
            color = {0.4, 0.7, 1, 1},
            bulletSpeed = 600, damageType = "energy", damage = 27,
            pierce = 1, lifespan = 5, bouncesLeft = 10, bulletId = "chainLaserBolt",
            hitEffects = { BounceEffect:new({ name = "Chain Bounce" }) }
        }
    }
}

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
