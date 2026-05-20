local RewardIndex = {
    common = {
        {
            id = "ammoCache",
            name = "Ammo Cache",
            description = "Increase nearby turret damage by 20%",
            type = "building",
            building = require("Buildings.Buffs.Buff"),
            iconCategory = "buff"
        },
        {
            id = "mortar",
            name = "Mortar",
            description = "KABOOM!",
            type = "building",
            building = require("Buildings.Turrets.Mortar"),
            iconCategory = "turret"
        },
        {
            id = "grenadier",
            name = "Grenadier",
            description = "Lobs grenades that explode after a short delay.",
            type = "building",
            iconCategory = "turret",
            building = require("Buildings.Turrets.Grenadier")
        },
    },
}

return RewardIndex
