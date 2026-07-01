local PassiveIndex = {
    common = {},
    uncommon = {
        {
            id = "unstable_laser",
            name = "Unstable Laser",
            description = "Increases adjacent Energy Turrets' attacks with a 25% chance to burn enemies.",
            type = "building",
            types = {"passive", "building"},
            building = require("Buildings.Passives.UnstableLaser"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {{-1, 0}, {0, 1}, {0, -1}, {1, 0}}
        },
        {
            id = "ammoCache",
            name = "Ammo Cache",
            description = "Increase nearby turret damage by 30%",
            type = "building",
            types = {"passive", "building"},
            building = require("Buildings.Passives.Buff"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {{1,0},{-1,0},{0,1},{0,-1}}
        },
        {
            id = "shatterRounds",
            name = "Recursive Rounds",
            description = "Bullets will now split on inpact.",
            type = "building",
            types = {"passive", "building"},
            building = require("Buildings.Passives.ShardBullets"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {{-1, 0}, {1, 0}}
        },
        {
            id = "bank",
            name = "Bank",
            description = "Generates 1 Token per wave if adjacent slots are occupied.",
            type = "building",
            types = {"passive", "building"},
            building = require("Buildings.Passives.Bank"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {{1,0},{-1,0},{0,1},{0,-1}}
        },
    },
    rare = {
        {
            id = "toxicTotem",
            name = "Chem Lab",
            description = "Spreads deadly toxins. Highly contagious.",
            type = "building",
            types = {"passive", "building"},
            building = require("Buildings.Passives.ToxicTotem"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {{1,0},{-1,0},{0,1},{0,-1}}
        },
        {
            id = "conduit",
            name = "Conduit",
            description = "Provides 10 Mana each wave.",
            type = "building",
            types = {"passive", "building"},
            building = require("Buildings.Passives.Conduit"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {}
        },
        {
            id = "slowBlocker",
            name = "Frost Trap",
            description = "Slows down nearby enemies.",
            type = "building",
            types = {"passive", "blocker", "building"},
            building = require("Buildings.Blockers.SlowBlocker"),
            iconCategory = "blocker",
            cost = 1,
            affectedSlots = {{0,0}}
        },
    },
    epic = {
        {
            id = "explosiveBullets",
            name = "Explosive Bullets",
            description = "Adds a little extra something to nearby turrets.",
            type = "building",
            types = {"passive", "building"},
            building = require("Buildings.Passives.ExplosiveTotem"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {{1, 0}, {2, 0}}
        },
    },
    legendary = {}
}

return PassiveIndex
