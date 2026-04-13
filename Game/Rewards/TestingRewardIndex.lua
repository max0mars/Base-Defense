local RewardIndex = {
    common = {
        {
            id = "lobber",
            name = "Lobber",
            description = "Fires parabolic shots that hit the ground or enemies.",
            building = require("Buildings.Turrets.Lobber"),
            type = "building"
        },
    },
    uncommon = {
        {
            id = "slottedBlocker",
            name = "Slotted Blocker",
            description = "Block Enemies and allow turrets to be placed on it",
            building = require("Buildings.Blockers.SlottedBlocker"),
            type = "building"
        },
    },
    rare = {},
    epic = {},
    legendary = {}
}

return RewardIndex
