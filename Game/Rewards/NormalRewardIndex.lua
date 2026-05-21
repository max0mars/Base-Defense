local RewardIndex = {
    common = {
        {
            id = "sentry",
            name = "Sentry",
            description = "Balanced range and damage.",
            building = require("Buildings.Turrets.Sentry"),
            type = "building",
            iconCategory = "turret"
        },
        {
            id = "blaster",
            name = "Blaster",
            description = "Fires energy bolts, effective against armor.",
            building = require("Buildings.Turrets.Blaster"),
            type = "building",
            iconCategory = "turret"
        },
        {
            id = "autoCannon",
            name = "Auto Cannon",
            description = "High fire rate, low damage, short range.",
            type = "building",
            building = require("Buildings.Turrets.AutoCannon"),
            iconCategory = "turret"
        },
        {
            id = "smallbox",
            name = "Small Box",
            description = "Gets in the enemy's way.",
            building = require("Buildings.Blockers.SmallBox"),
            type = "building",
            iconCategory = "blocker"
        },
        {
            id = "rangeBuff",
            name = "Radar Tower",
            description = "Increases range of adjacent turrets by 25%.",
            type = "building",
            building = require("Buildings.Buffs.RangeBuff"),
            iconCategory = "buff"
        },
        {
            id = "shotgunTurret",
            name = "Shotgun Turret",
            description = "Shreds close-range targets.",
            type = "building",
            building = require("Buildings.Turrets.ShotgunTurret"),
            iconCategory = "turret"
        },
        {
            id = "heavygun",
            name = "Heavy Gun",
            description = "Long range, high damage.",
            type = "building",
            building = require("Buildings.Turrets.HeavyGun"),
            iconCategory = "turret"
        },
    },
    uncommon = {
        {
            id = "poisonTurret",
            name = "Poison Turret",
            description = "Fires toxic darts that damage over time.",
            type = "building",
            building = require("Buildings.Turrets.PoisonTurret"),
            iconCategory = "turret"
        },
        {
            id = "airburst",
            name = "Airburst Turret",
            description = "Fires shells that explode mid-air into shrapnel.",
            type = "building",
            building = require("Buildings.Turrets.AirburstTurret"),
            iconCategory = "turret"
        },
        {
            id = "smallfence",
            name = "Small Fence",
            description = "Redirect Enemy movement.",
            building = require("Buildings.Blockers.SmallFence"),
            type = "building",
            iconCategory = "blocker"
        },
        {
            id = "ammoCache",
            name = "Ammo Cache",
            description = "Increase nearby turret damage by 20%",
            type = "building",
            building = require("Buildings.Buffs.Buff"),
            iconCategory = "buff"
        },
        {
            id = "shatterRounds",
            name = "Recursive Rounds",
            description = "Bullets will now split on inpact.",
            type = "building",
            building = require("Buildings.Buffs.ShardBullets"),
            iconCategory = "buff"
        },
        {
            id = "energyBlaster",
            name = "Energy Blaster",
            description = "Energy damage that ignores heavy armor.",
            type = "building",
            building = require("Buildings.Turrets.EnergyBlaster"),
            iconCategory = "turret"
        },
        {
            id = "bank",
            name = "Bank",
            description = "Generates 1 Token per wave if adjacent slots are occupied.",
            type = "building",
            building = require("Buildings.Buffs.Bank"),
            iconCategory = "buff"
        },
        {
            id = "grenadier",
            name = "Grenadier",
            description = "Lobs grenades that explode after a short delay.",
            type = "building",
            iconCategory = "turret",
            building = require("Buildings.Turrets.Grenadier")
        },
    },
    rare = {
        {
            id = "toxicTotem",
            name = "Chem Lab",
            description = "Spreads deadly toxins. Highly contagious.",
            type = "building",
            building = require("Buildings.Buffs.ToxicTotem"),
            iconCategory = "buff"
        },
        {
            id = "gator",
            name = "GTR-55 Gator",
            description = "Hard hitting rounds go right through enemies.",
            type = "building",
            building = require("Buildings.Turrets.Gator"),
            iconCategory = "turret"
        },

        {
            id = "unstable_laser",
            name = "Unstable Laser",
            description = "Gives your big lazer a 20% chance to burn enemies.",
            type = "main_upgrade",
            iconCategory = "upgrade",
            isEligible = function(game)
                local mt = game.base and game.base.mainLazer
                return mt and mt.id == "standard_main" and not mt.upgrades["unstable_laser"]
            end
        },
        {
            id = "missileLauncher",
            name = "Missile Launcher",
            description = "Wouldn't want to get in the way of one of these.",
            type = "building",
            building = require("Buildings.Turrets.MissileLauncher"),
            iconCategory = "turret"
        },
        {
            id = "plasmaScattershot",
            name = "Plasma Scattershot",
            description = "Fires plamsa rounds at high speed but has limited ammo. Reloads slowly.",
            type = "building",
            building = require("Buildings.Turrets.PlasmaScattershot"),
            iconCategory = "turret"
        },
        {
            id = "sequenceTurret",
            name = "CSR-8 Sequence",
            description = "Shoots faster the longer it stays locked onto a target.",
            type = "building",
            building = require("Buildings.Turrets.SequenceTurret"),
            iconCategory = "turret"
        },
        {
            id = "slottedBlocker",
            name = "Slotted Blocker",
            description = "It's a fence with a free turret slot!",
            building = require("Buildings.Blockers.SlottedBlocker"),
            type = "building",
            iconCategory = "blocker"
        },
        {
            id = "slowBlocker",
            name = "Frost Trap",
            description = "Slows down nearby enemies.",
            type = "building",
            building = require("Buildings.Blockers.SlowBlocker"),
            iconCategory = "blocker"
        },
    },
    epic = {
        {
            id = "sniper",
            name = "Sniper Turret",
            description = "High damage, long range.",
            type = "building",
            building = require("Buildings.Turrets.Sniper"),
            iconCategory = "turret"
        },
        {
            id = "mortar",
            name = "Mortar",
            description = "KABOOM!",
            type = "building",
            building = require("Buildings.Turrets.Mortar"),
            iconCategory = "turret"
        },
        {
            id = "explosiveBullets",
            name = "Explosive Bullets",
            description = "Adds a little extra something to nearby turrets.",
            type = "building",
            building = require("Buildings.Buffs.ExplosiveTotem"),
            iconCategory = "buff"
        },
        {
            id = "low_power_operating",
            name = "Low Power Ops",
            description = "Your big lazer shoots much faster but does a little less damage.",
            type = "main_upgrade",
            iconCategory = "upgrade",
            isEligible = function(game)
                local mt = game.base and game.base.mainLazer
                return mt and mt.id == "standard_main" and not mt.upgrades["low_power_operating"]
            end
        },
    },
    legendary = {
        {
            id = "electric_field",
            name = "PROJECT STORMBREAKER",
            description = "zzzZap!",
            type = "main_upgrade",
            iconCategory = "upgrade",
            isEligible = function(game)
                local mt = game.base and game.base.mainLazer
                return mt and not mt.upgrades["electric_field"]
            end
        },
        {
            id = "chainLaser",
            name = "PROJECT CHIMERA",
            description = "No one is safe",
            type = "building",
            building = require("Buildings.Turrets.ChainLaser"),
            iconCategory = "turret"
        }
    }
}

return RewardIndex