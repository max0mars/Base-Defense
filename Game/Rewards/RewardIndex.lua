local RewardIndex = {}
RewardIndex.__index = RewardIndex

RewardIndex.Rewards = {
    basicturret = {
        name = "Basic Turret",
        description = "Pew Pew",
        building = require("Buildings.Turrets.Turret"),
        rarity = "common",
        type = "building"
    },
    ammoCache = {
        name = "Ammo Cache",
        description = "Increase turret damage by 20%",
        rarity = "common",
        type = "building",
        building = require("Buildings.Buffs.Buff")
    },
    poisonTurret = {
        name = "Poison Turret",
        description = "Bullets apply poison effect",
        rarity = "rare",
        type = "building",
        building = require("Buildings.Turrets.PoisonTurret")
    },
    sniper = {
        name = "Sniper Turret",
        description = "High damage, slow fire rate, massive range.",
        rarity = "uncommon",
        type = "building",
        building = require("Buildings.Turrets.Sniper")
    },
    autoCannon = {
        name = "Auto Cannon",
        description = "High fire rate, low damage, shorter range.",
        rarity = "uncommon",
        type = "building",
        building = require("Buildings.Turrets.AutoCannon")
    },
    x = {
        name = "Fence",
        description = "Block Enemies",
        building = require("Buildings.Battlefield.Blocker"),
        rarity = "common",
        type = "uncommon"
    }
}   

return RewardIndex