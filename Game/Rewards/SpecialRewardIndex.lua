local SpecialRewardIndex = {
    common = {
        {   id = "damageBuff",
            name = "Damage Buff",
            description = "Increases all damage by 5%",
            type = "effect",
            targetTags = {}, --optional
            targetTypes = {}, --optional
            effect = {
                name = "Damage Buff",
                statModifiers = {damage = {mult = 0.05}},
                duration = math.huge
            }
        },
        {   id = "fireRateBuff",
            name = "Fire Rate Buff",
            description = "Increases all fire rate by 5%",
            type = "effect",
            targetTags = {}, --optional
            targetTypes = {}, --optional
            effect = {
                name = "Fire Rate Buff",
                statModifiers = {fireRate = {mult = 0.05}},
                duration = math.huge
            }
        },

        {   id = "rangeBuff",
            name = "Range Buff",
            description = "Increases all range by 5%",
            type = "effect",
            targetTags = {}, --optional
            targetTypes = {}, --optional
            effect = {
                name = "Range Buff",
                statModifiers = {range = {mult = 0.05}},
                duration = math.huge
            }
        },
    },
    uncommon = {

    },
    rare = {

    },
    epic = {

    },
    legendary = {

    }
}

return SpecialRewardIndex
