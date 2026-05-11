local RewardIndex = {
    common = {
        {
            id = "sentry",
            name = "Sentry",
            description = "Basic defensive turret. Balanced speed and damage.",
            building = require("Buildings.Turrets.Sentry"),
            type = "building"
        },
        {
            id = "autoCannon",
            name = "Auto Cannon",
            description = "High fire rate, low damage, shorter range.",
            type = "building",
            building = require("Buildings.Turrets.AutoCannon")
        },
        {
            id = "smallbox",
            name = "Small Box",
            description = "Block Enemies",
            building = require("Buildings.Blockers.SmallBox"),
            type = "building"
        },
        {
            id = "rangeBuff",
            name = "Radar Tower",
            description = "Increases range of adjacent turrets by 25%.",
            type = "building",
            building = require("Buildings.Buffs.RangeBuff")
        },
    },
    uncommon = {
        {
            id = "slottedBlocker",
            name = "Slotted Blocker",
            description = "Block Enemies and allow turrets to be placed on it",
            building = require("Buildings.Blockers.SlottedBlocker"),
            type = "building"
        },
        {
            id = "heavygun",
            name = "Heavy Gun",
            description = "High damage, slow fire rate.",
            type = "building",
            building = require("Buildings.Turrets.HeavyGun")
        },
        {
            id = "splitter",
            name = "Splitter",
            description = "Bullets split into multiple smaller projectiles upon hitting an enemy.",
            type = "building",
            building = require("Buildings.Turrets.Splitter")
        },
        {
            id = "smallfence",
            name = "Small Fence",
            description = "Block Enemies",
            building = require("Buildings.Blockers.SmallFence"),
            type = "building"
        },
        {
            id = "ammoCache",
            name = "Ammo Cache",
            description = "Increase turret damage by 20%",
            type = "building",
            building = require("Buildings.Buffs.Buff")
        },
        {
            id = "shatterRounds",
            name = "Shatter Rounds",
            description = "Bullets shatter into multiple smaller projectiles upon hitting an enemy.",
            type = "building",
            building = require("Buildings.Buffs.ShardBullets")
        },
        {
            id = "energyBlaster",
            name = "Energy Blaster",
            description = "High-tech weapon dealing energy damage with trailing projectiles.",
            type = "building",
            building = require("Buildings.Turrets.EnergyBlaster")
        },
        {
            id = "bank",
            name = "Bank",
            description = "Generates 1 Token every 3 waves.",
            type = "building",
            building = require("Buildings.Turrets.Bank")
        },
    },
    rare = {
        {
            id = "poisonTurret",
            name = "Poison Turret",
            description = "Bullets apply poison effect",
            type = "building",
            building = require("Buildings.Turrets.PoisonTurret")
        },
        {
            id = "poisonCoating",
            name = "Poison Coating",
            description = "Bullets apply poison effect.",
            type = "building",
            building = require("Buildings.Buffs.PoisonTotem")
        },
        {
            id = "unstable_laser",
            name = "Unstable Laser",
            description = "Main Turret: 20% chance to burn enemies for 3s.",
            type = "main_upgrade",
            isEligible = function(game)
                local mt = game.base and game.base.mainTurret
                return mt and mt.id == "standard_main" and not mt.upgrades["unstable_laser"]
            end
        },
        
    },
    epic = {
        {
            id = "sniper",
            name = "Sniper Turret",
            description = "High damage, long range.",
            type = "building",
            building = require("Buildings.Turrets.Sniper")
        },
        {
            id = "mortar",
            name = "Mortar",
            description = "Shoots explosive projectiles in an arc.",
            type = "building",
            building = require("Buildings.Turrets.Mortar")
        },
        {
            id = "explosiveBullets",
            name = "Explosive Bullets",
            description = "Bullets explode on impact.",
            type = "building",
            building = require("Buildings.Buffs.ExplosiveTotem")
        },
        {
            id = "low_power_operating",
            name = "Low Power Ops",
            description = "Main Turret: +50% Fire Rate, -20% Damage.",
            type = "main_upgrade",
            isEligible = function(game)
                local mt = game.base and game.base.mainTurret
                return mt and mt.id == "standard_main" and not mt.upgrades["low_power_operating"]
            end
        },
    },
    legendary = {
        {
            id = "electric_field",
            name = "Electric Field",
            description = "Main Turret: Auto-zaps up to 3 nearby enemies for 1.5x damage.",
            type = "main_upgrade",
            isEligible = function(game)
                local mt = game.base and game.base.mainTurret
                return mt and not mt.upgrades["electric_field"]
            end
        },
        {
            id = "chainLaser",
            name = "Chain Laser",
            description = "High-tech turret that fires bouncing energy bolts. Hits up to 10 targets.",
            type = "building",
            building = require("Buildings.Turrets.ChainLaser")
        }
    }
}

return RewardIndex