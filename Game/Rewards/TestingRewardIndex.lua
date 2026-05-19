local RewardIndex = {
    common = {
        {
            id = "sequenceTurret",
            name = "CSR-8 Sequence",
            description = "Shoots faster the longer it stays locked onto a target.",
            type = "building",
            building = require("Buildings.Turrets.SequenceTurret"),
            iconCategory = "turret"
        },
    },
}

return RewardIndex
