local RewardIndex = {
    common = {
        {
            id = "basicturret",
            name = "Basic Turret",
            description = "Pew Pew",
            building = require("Buildings.Turrets.Turret"),
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
        }
    },
    uncommon = {
        {
            id = "heavygun",
            name = "Heavy Gun",
            description = "High damage, slow fire rate",
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
    },
    rare = {
        {
            id = "poisonTurret",
            name = "Poison Turret",
            description = "Bullets apply poison effect",
            type = "building",
            building = require("Buildings.Turrets.PoisonTurret")
        }
    },
    epic = {
        {
            id = "sniper",
            name = "Sniper Turret",
            description = "High damage, slow fire rate, massive range.",
            type = "building",
            building = require("Buildings.Turrets.Sniper")
        }
    },
    legendary = {
        
    }
}

return RewardIndex