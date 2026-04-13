local RewardIndex = {
    common = {
        {
            id = "lobber",
            name = "Lobber",
            description = "Fires parabolic shots that hit the ground or enemies.",
            building = require("Buildings.Turrets.Lobber"),
            type = "building"
        },
        {
            id = "poisonTotem",
            name = "Poison Totem",
            description = "Coats the turret in front with deadly toxins, adding Poison on-hit.",
            building = require("Buildings.Buffs.PoisonTotem"),
            type = "building"
        },
        {
            id = "shardBullets",
            name = "Shard Bullets",
            description = "Causes the turret in front to fire splintering rounds that burst into shards on impact.",
            building = require("Buildings.Buffs.ShardBullets"),
            type = "building"
        },
    },
}

return RewardIndex
