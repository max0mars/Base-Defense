local EnemyRewardIndex = {
    common = {
        {   id = "hpBuff",
            name = "HP Buff",
            description = "Increases all enemy HP by 20%",
            type = "effect",
            targetTags = {}, --optional
            targetTypes = {}, --optional
            effect = {
                name = "HP Buff",
                statModifiers = {hp = {mult = 0.2}},
                description = "Increases all enemy HP by 20%",
                duration = math.huge
            }
        },
        {   id = "speedBuff",
            name = "Speed Buff",
            description = "Increases all enemy speed by 20%",
            type = "effect",
            targetTags = {}, --optional
            targetTypes = {}, --optional
            effect = {
                name = "Speed Buff",
                statModifiers = {speed = {mult = 0.2}},
                description = "Increases all enemy speed by 20%",
                duration = math.huge
            }
        },
        {   id = "armourBuff",
            name = "Armour Buff",
            description = "Increases all enemy armour by 5",
            type = "effect",
            targetTags = {}, --optional
            targetTypes = {}, --optional
            effect = {
                name = "Armour Buff",
                statModifiers = {armour = {add = 5}},
                description = "Increases all enemy armour by 5",
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

return EnemyRewardIndex
