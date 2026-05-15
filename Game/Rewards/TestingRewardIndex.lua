local RewardIndex = {
    common = {
        {
            id = "poisonCoating",
            name = "Poison Coating",
            description = "Grants nearby towers poison effect.",
            type = "building",
            building = require("Buildings.Buffs.PoisonTotem"),
            iconCategory = "buff"
        },
        {
            id = "shatterRounds",
            name = "Shatter Rounds",
            description = "Gives nearby turrets bullets that shatter on impact.",
            type = "building",
            building = require("Buildings.Buffs.ShardBullets"),
            iconCategory = "buff"
        },
        {
            id = "chainLaser",
            name = "PROJECT CHIMERA",
            description = "No one is safe",
            type = "building",
            building = require("Buildings.Turrets.ChainLaser"),
            iconCategory = "turret"
        }
         
    },
}

return RewardIndex
