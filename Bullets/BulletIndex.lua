local Bullet = require("Bullets.Bullet")
local LobberBullet = require("Bullets.LobberBullet")
local HitscanBullet = require("Bullets.HitscanBullet")
local GrenadeBullet = require("Bullets.GrenadeBullet")
local MissileBullet = require("Bullets.MissileBullet")
local AirburstBullet = require("Bullets.AirburstBullet")

local ToxicEffect = require("Game.Effects.StatusEffects.Toxic")
local SlowEffect = require("Game.Effects.StatusEffects.Slow")

local BulletIndex = {
    standard = {
        class = Bullet,
        name = "Bullet"
    },
    sentryBullet = {
        class = Bullet,
        name = "Sentry Bullet"
    },
    cannonBullet = {
        class = Bullet,
        name = "Cannon Bullet"
    },
    shotgunPellet = {
        class = Bullet,
        name = "Shotgun Pellet",
        w = 3, h = 3
    },
    heavyShell = {
        class = Bullet,
        name = "Heavy Shell",
        w = 6, h = 12
    },
    poisonDart = {
        class = Bullet,
        name = "Poison Dart"
    },
    sequenceRound = {
        class = Bullet,
        name = "Sequence Round"
    },
    heavyHook = {
        class = Bullet,
        name = "Heavy Hook",
        w = 8, h = 8
    },
    sniperShot = {
        class = HitscanBullet,
        name = "Sniper Shot",
        color = {1, 1, 1}
    },
    hitscan = {
        class = HitscanBullet,
        w = 2, h = 2
    },
    energyBolt = {
        class = Bullet,
        name = "Energy Bolt",
        drawStyle = "energy",
        maxTrail = 12,
        w = 12, h = 4,
        color = {0.2, 0.8, 1, 1}
    },
    fluxCharge = {
        class = Bullet,
        name = "Flux Charge",
        drawStyle = "energy",
        maxTrail = 12,
        w = 8, h = 8,
        color = {0.6, 0.2, 1, 1}
    },
    plasmaBolt = {
        class = Bullet,
        name = "Plasma Bolt",
        drawStyle = "energy",
        maxTrail = 12,
        w = 4, h = 4,
        color = {0.2, 0.6, 1, 1}
    },
    slush = {
        class = Bullet,
        drawStyle = "slush",
        w = 16, h = 16,
        color = {0.6, 0.9, 1, 1},
        shape = "rectangle"
    },
    toxicShard = {
        class = Bullet,
        drawStyle = "shard",
        w = 8, h = 3,
        color = {0.7, 0.2, 0.9, 1},
        shape = "rectangle",
        hitEffects = { ToxicEffect:new({recursion = 0}) },
        hitbox = true,
        types = { bullet = true }
    },
    mortarShell = {
        class = LobberBullet,
        name = "Mortar Shell",
        shape = "rectangle", w = 8, h = 8,
        explodeOnGroundOnly = true
    },
    shrapnel = {
        class = Bullet,
        name = "Shrapnel",
        w = 4, h = 6,
        shape = "ray",
        color = {1, 0.8, 0.2, 1}
    },
    grenade = {
        class = GrenadeBullet,
        name = "Grenade",
        shape = "rectangle", w = 6, h = 6
    },
    missile = {
        class = MissileBullet,
        name = "Missile",
        shape = "rectangle"
    },
    airburst = {
        class = AirburstBullet,
        name = "Flak Shell"
    },
    gatorRound = {
        class = Bullet,
        name = "Gator Rounds",
        w = 8, h = 4
    },
    chainLaserBolt = {
        class = Bullet,
        name = "Lazer Bolt",
        w = 6, h = 6,
        color = {0.4, 0.7, 1, 1}
    }
}

return BulletIndex
