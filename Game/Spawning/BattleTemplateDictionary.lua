local BattleTemplate = require("Game.Spawning.BattleTemplate")

local DEFAULT_BUDGETS = {30, 45, 65, 100, 150, 200, 250}

local BattleTemplateDictionary = {
    battle_1 = BattleTemplate:new({
        id = "battle_1",
        validBattleRange = {min = 1, max = 1},
        numWaves = 3,
        lanesPerWave = {1, 1, 2},
        battleDangerTiers = {tier0min = 1, tier0max = 1},
        weight = 10
    }),
    battle_2 = BattleTemplate:new({
        id = "battle_2",
        validBattleRange = {min = 2, max = 2},
        numWaves = 3,
        lanesPerWave = {1, 2, 2},
        battleDangerTiers = {tier0min = 2, tier0max = 2},
        weight = 10
    }),
    battle_3 = BattleTemplate:new({
        id = "battle_3",
        validBattleRange = {min = 3, max = 3},
        numWaves = 3,
        lanesPerWave = {1, 2, 2},
        battleDangerTiers = {tier0min = 2, tier0max = 3},
        weight = 10
    }),
    battle_early1 = BattleTemplate:new({
        id = "battle_early1",
        validBattleRange = {min = 4, max = 8},
        numWaves = 3,
        lanesPerWave = {1, 2, 2},
        battleDangerTiers = {tier0min = 2, tier0max = 2, tier1min = 1, tier1max = 1},
        weight = 50
    }),
    battle_early2 = BattleTemplate:new({
        id = "battle_early2",
        validBattleRange = {min = 4, max = 8},
        numWaves = 3,
        lanesPerWave = {1, 2, 3},
        battleDangerTiers = {tier0min = 4, tier0max = 4},
        weight = 50
    }),
    battle_mid1 = BattleTemplate:new({
        id = "battle_mid1",
        validBattleRange = {min = 6, max = 12},
        numWaves = 5,
        lanesPerWave = {1, 2, 2, 3},
        battleDangerTiers = {tier0min = 1, tier0max = 2},
        weight = 50
    }),
}

for _, template in pairs(BattleTemplateDictionary) do
    template.budgets = template.budgets or DEFAULT_BUDGETS
end

BattleTemplateDictionary.DEFAULT_BUDGETS = DEFAULT_BUDGETS

return BattleTemplateDictionary
