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
            id = "ammoCache",
            name = "Ammo Cache",
            description = "Increase turret damage by 20%",
            type = "building",
            building = require("Buildings.Buffs.Buff")
        },
    },
    uncommon = {
        {
            id = "autoCannon",
            name = "Auto Cannon",
            description = "High fire rate, low damage, shorter range.",
            type = "building",
            building = require("Buildings.Turrets.AutoCannon")
        }
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
        {
            id = "fence",
            name = "Fence",
            description = "Block Enemies",
            building = require("Buildings.Battlefield.Blocker"),
            type = "building"
        }
    }
}

return RewardIndex