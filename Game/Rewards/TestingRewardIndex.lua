local RewardIndex = {
    common = {
        {
            id = "toxicTotem",
            name = "Toxic Totem",
            description = "Nearby turrets apply Toxic and explode on death.",
            type = "building",
            building = require("Buildings.Buffs.ToxicTotem"),
            iconCategory = "buff"
        }
    },
}

return RewardIndex
