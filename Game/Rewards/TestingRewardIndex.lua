local RewardIndex = {
    common = {
        {
            id = "poisonTurret",
            name = "Poison Turret",
            description = "Bullets apply poison effect",
            type = "building",
            building = require("Buildings.Turrets.PoisonTurret"),
            iconCategory = "turret"
        }
    },
}

return RewardIndex
