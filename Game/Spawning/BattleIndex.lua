local BattleTemplate = require("Game.Spawning.BattleTemplate")

local function calculateSigmoidBudget(wave)
    local min_val = 25
    local max_val = 300
    local k = 0.8
    local x0 = 5.2
    local val = min_val + (max_val - min_val) / (1 + math.exp(-k * (wave - x0)))
    return math.floor(val + 0.5)
end

local DEFAULT_BUDGETS = {}
for i = 1, 100 do
    DEFAULT_BUDGETS[i] = calculateSigmoidBudget(i)
end

setmetatable(DEFAULT_BUDGETS, {
    __index = function(t, wave)
        if type(wave) == "number" and wave > 0 then
            return calculateSigmoidBudget(wave)
        end
        return nil
    end
})

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
    battle_early3 = BattleTemplate:new({
        id = "battle_early3",
        validBattleRange = {min = 5, max = 9},
        numWaves = 4,
        lanesPerWave = {1, 2, 2, 3},
        battleDangerTiers = {tier0min = 3, tier1min = 1},
        weight = 50
    }),
    battle_early4 = BattleTemplate:new({
        id = "battle_early4",
        validBattleRange = {min = 6, max = 9},
        numWaves = 4,
        lanesPerWave = {1, 2, 3, 3},
        battleDangerTiers = {tier0min = 2, tier1min = 2},
        weight = 50
    }),
    battle_mid1 = BattleTemplate:new({
        id = "battle_mid1",
        validBattleRange = {min = 6, max = 10},
        numWaves = 5,
        lanesPerWave = {1, 2, 2, 3, 3},
        battleDangerTiers = {tier0min = 2, tier1min = 2, tier2min = 1},
        weight = 50
    }),
    battle_mid2 = BattleTemplate:new({
        id = "battle_mid2",
        validBattleRange = {min = 9, max = 13},
        numWaves = 5,
        lanesPerWave = {2, 2, 3, 3, 4},
        battleDangerTiers = {tier0min = 2, tier1min = 3, tier2min = 1},
        weight = 50
    }),
    battle_mid3 = BattleTemplate:new({
        id = "battle_mid3",
        validBattleRange = {min = 11, max = 15},
        numWaves = 6,
        lanesPerWave = {2, 2, 3, 3, 4, 4},
        battleDangerTiers = {tier1min = 3, tier2min = 2, tier3min = 1},
        weight = 50
    }),
    battle_mid4 = BattleTemplate:new({
        id = "battle_mid4",
        validBattleRange = {min = 11, max = 15},
        numWaves = 6,
        lanesPerWave = {2, 3, 3, 4, 4, 5},
        battleDangerTiers = {tier1min = 2, tier2min = 3, tier3min = 1},
        weight = 50
    }),
    battle_late1 = BattleTemplate:new({
        id = "battle_late1",
        validBattleRange = {min = 14, max = 18},
        numWaves = 7,
        lanesPerWave = {2, 3, 3, 4, 4, 5, 5},
        battleDangerTiers = {tier2min = 3, tier3min = 2, tier4min = 1},
        weight = 50
    }),
    battle_late2 = BattleTemplate:new({
        id = "battle_late2",
        validBattleRange = {min = 15, max = 19},
        numWaves = 7,
        lanesPerWave = {3, 3, 4, 4, 5, 5, 5},
        battleDangerTiers = {tier2min = 2, tier3min = 3, tier4min = 2},
        weight = 50
    }),
    battle_boss = BattleTemplate:new({
        id = "battle_boss",
        validBattleRange = {min = 20, max = 20},
        numWaves = 8,
        lanesPerWave = {3, 3, 4, 4, 5, 5, 5, 6},
        battleDangerTiers = {tier2min = 3, tier3min = 3, tier4min = 3},
        weight = 100
    }),
}

for _, template in pairs(BattleTemplateDictionary) do
    template.budgets = template.budgets or DEFAULT_BUDGETS
end

BattleTemplateDictionary.DEFAULT_BUDGETS = DEFAULT_BUDGETS

return BattleTemplateDictionary
