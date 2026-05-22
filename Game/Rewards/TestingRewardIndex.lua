local RewardIndex = {
    common = {
        {
            id = "slushCannon",
            name = "The Slush Cannon",
            description = "Fires heavy clumps of slush that slow enemies on impact.",
            type = "building",
            building = require("Buildings.Turrets.SlushCannon"),
            iconCategory = "turret"
        },
        {
            id = "explosiveBullets",
            name = "Explosive Bullets",
            description = "Adds a little extra something to nearby turrets.",
            type = "building",
            building = require("Buildings.Buffs.ExplosiveTotem"),
            iconCategory = "buff"
        },
        {
            id = "hookTurret",
            name = "The Hook",
            description = "Fires a heavy shot that stuns enemies in their tracks.",
            type = "building",
            building = require("Buildings.Turrets.HookTurret"),
            iconCategory = "turret"
        },
    },
    uncommon = {},
    rare = {},
    epic = {},
    legendary = {}
}

return RewardIndex
