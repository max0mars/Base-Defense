local PassiveIndex = {
    common = {},
    uncommon = {
        {
            id = "unstable_laser",
            name = "Unstable Laser",
            description = "Gives adjacent Energy Turrets' attacks a 25% chance to apply 3 burn.",
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
            id = "outpost",
            name = "Outpost",
            description = "Unlocks all 8 slots around it for free. Turrets around it get +10% range.",
            type = "building",
            types = {"passive", "building", "economy"},
            building = require("Buildings.Passives.Outpost"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {{-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}}
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
        {
            id = "vault",
            name = "The Vault",
            description = "Gain $50 when the battle is won.",
            type = "building",
            types = {"passive", "building", "economy"},
            building = require("Buildings.Passives.Vault"),
            iconCategory = "buff",
            cost = 2,
            affectedSlots = {}
        },
    },
    rare = {
        {
            id = "coldTactics",
            name = "Cold Tactics",
            description = "Nearby turrets deal more damage the closer the enemy hit is to freezing, up to +50%. Frozen enemies take +50%.",
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
            affectedSlots = {{-1,-1},{-1,1},{1,-1},{1,1}}
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

-- Each entry knows its rarity (the tier it's listed under); placed buildings keep it
for rarity, tierList in pairs(PassiveIndex) do
    for _, passiveConfig in ipairs(tierList) do
        passiveConfig.rarity = rarity
    end
end

return PassiveIndex
