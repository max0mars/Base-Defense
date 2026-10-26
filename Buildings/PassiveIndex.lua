local PassiveIndex = {
    common = {},
    uncommon = {
        {
            id = "unstable_laser",
            name = "Unstable Laser",
            description = "Gives adjacent Energy Turrets' attacks with a 25% chance to burn enemies.",
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
            description = "+1 Token per wave when the slots above, below and right are filled. +2 if they are all turrets.",
            type = "building",
            types = {"passive", "building", "economy"},
            building = require("Buildings.Passives.Bank"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {{1,0},{0,1},{0,-1}}
        },
        {
            id = "iceMarket",
            name = "Ice Market",
            description = "Gain $5 every time a frozen enemy dies.",
            type = "building",
            types = {"passive", "building", "economy"},
            building = require("Buildings.Passives.IceMarket"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {}
        },
    },
    rare = {
        {
            id = "coldTactics",
            name = "Cold Tactics",
            description = "Nearby turrets deal +10% damage per stack of chill on the enemy hit. Frozen enemies count as max stacks.",
            type = "building",
            types = {"passive", "building"},
            building = require("Buildings.Passives.ColdTactics"),
            iconCategory = "buff",
            cost = 1,
            affectedSlots = {{0, -1}, {1, -1}, {1, 0}, {1, 1}, {0, 1}}
        },
        {
            id = "toxicTotem",
            name = "Chem Lab",
            description = "Spreads deadly toxins. Highly contagious.",
            type = "building",
            types = {"passive", "building", "toxic"},
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
            types = {"passive", "building", "economy"},
            building = require("Buildings.Passives.Conduit"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {}
        },
        {
            id = "frostTrap",
            name = "Frost Trap",
            description = "Pulses while enemies are nearby, applying a stack of chill every 1.2 seconds.",
            type = "building",
            types = {"passive", "building", "slow", "control"},
            building = require("Buildings.Passives.FrostTrap"),
            iconCategory = "buff",
            cost = 1,
            affectedSlots = {}
        },
    },
    epic = {
        {
            id = "explosiveBullets",
            name = "Explosive Bullets",
            description = "Adds a little extra something to nearby turrets.",
            type = "building",
            types = {"passive", "building", "explosive"},
            building = require("Buildings.Passives.ExplosiveTotem"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {{1, 0}, {2, 0}}
        },
    },
    legendary = {}
}

return PassiveIndex
