local RewardIndex = {
    common = {
        {
            id = "toxicTotem",
            name = "Toxic Totem",
            description = "Nearby turrets apply Toxic and explode on death.",
            type = "building",
            building = require("Buildings.Buffs.ToxicTotem"),
            iconCategory = "buff"
        },
        {
            id = "bank",
            name = "Bank",
            description = "Generates 3 Tokens every 3 waves.",
            type = "building",
            building = require("Buildings.Buffs.Bank"),
            iconCategory = "buff"
        }
    },
}

return RewardIndex
