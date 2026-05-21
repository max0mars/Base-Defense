local RewardIndex = {
    common = {
        {
            id = "sniper",
            name = "Sniper Turret",
            description = "High damage, long range.",
            type = "building",
            building = require("Buildings.Turrets.Sniper"),
            iconCategory = "turret"
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
            id = "missileLauncher",
            name = "Missile Launcher",
            description = "Wouldn't want to get in the way of one of these.",
            type = "building",
            building = require("Buildings.Turrets.MissileLauncher"),
            iconCategory = "turret"
        },
    }
}

return RewardIndex
