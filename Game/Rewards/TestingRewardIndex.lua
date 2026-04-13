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
            id = "ExplosiveTotem",
            name = "Explosive Rounds",
            description = "Causes the turret in front to fire explosive rounds.",
            building = require("Buildings.Buffs.ExplosiveTotem"),
            type = "building"
        },
    },
}

return RewardIndex
