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
            description = "Piercing bullets, slow fire rate",
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
            description = "High damage, long range.",
            type = "building",
            building = require("Buildings.Turrets.Sniper")
        }
    },
    legendary = {
        
    }
}

return RewardIndex