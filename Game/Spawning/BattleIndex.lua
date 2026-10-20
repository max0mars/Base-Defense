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
    -- -------------------------------------------------------------------------
    -- INTRODUCTORY BATTLES (Levels 1 - 3, Fixed Sequence, Low Variety)
    -- -------------------------------------------------------------------------
    battle_1 = BattleTemplate:new({
        id = "battle_1",
        minimumLevel = 1,
        maximumLevel = 1,
        battleDangerTiers = {tier0min = 1, tier0max = 1}, -- Exactly 1 enemy type (Grunt)
        weight = 10
    }),
    battle_2 = BattleTemplate:new({
        id = "battle_2",
        minimumLevel = 2,
        maximumLevel = 2,
        battleDangerTiers = {tier0min = 2, tier0max = 2}, -- 2 Tier-0 types
        weight = 10
    }),
    battle_3 = BattleTemplate:new({
        id = "battle_3",
        minimumLevel = 3,
        maximumLevel = 3,
        battleDangerTiers = {tier0min = 2, tier0max = 2, tier1min = 1, tier1max = 1}, -- First Tier 1 intro
        weight = 10
    }),

    -- -------------------------------------------------------------------------
    -- EARLY GAME (Levels 4 - 8, Strict Max Level 8-9 so they don't appear late game)
    -- Controlled enemy diversity: 1 to 2 enemy types max!
    -- -------------------------------------------------------------------------
    battle_early_patrol = BattleTemplate:new({
        id = "battle_early_patrol",
        minimumLevel = 4,
        maximumLevel = 7,
        battleDangerTiers = {tier0min = 2, tier0max = 2}, -- Just 2 Tier-0 types
        weight = 40
    }),
    battle_early_critter_swarm = BattleTemplate:new({
        id = "battle_early_critter_swarm",
        minimumLevel = 4,
        maximumLevel = 8,
        battleDangerTiers = {tier0min = 1, tier0max = 1}, -- Focused swarm: single type
        allowedTypes = {"Critter"},
        weight = 35
    }),
    battle_early_scout_raid = BattleTemplate:new({
        id = "battle_early_scout_raid",
        minimumLevel = 4,
        maximumLevel = 8,
        battleDangerTiers = {tier0min = 2, tier0max = 2},
        allowedTypes = {"Scout", "Grunt"},
        weight = 40
    }),
    battle_early_soldier_assault = BattleTemplate:new({
        id = "battle_early_soldier_assault",
        minimumLevel = 4,
        maximumLevel = 8,
        battleDangerTiers = {tier0min = 1, tier0max = 1, tier1min = 1, tier1max = 1}, -- 2 enemy types total
        weight = 45
    }),
    battle_early_drone_recon = BattleTemplate:new({
        id = "battle_early_drone_recon",
        minimumLevel = 5,
        maximumLevel = 8,
        battleDangerTiers = {tier0min = 2, tier0max = 2},
        allowedTypes = {"Drone", "Grunt"},
        weight = 35
    }),
    battle_early_breach = BattleTemplate:new({
        id = "battle_early_breach",
        minimumLevel = 6,
        maximumLevel = 9,
        battleDangerTiers = {tier0min = 1, tier0max = 1, tier1min = 1, tier1max = 1},
        weight = 40
    }),

    -- -------------------------------------------------------------------------
    -- MID GAME (Levels 7 - 14, Does not appear late game, Max Level 13-14)
    -- Controlled enemy diversity: 2 to 3 enemy types max
    -- Tier 1 and introductory Tier 2 only (No tier 3+ or high tier tanks)
    -- -------------------------------------------------------------------------
    battle_mid_infantry = BattleTemplate:new({
        id = "battle_mid_infantry",
        minimumLevel = 7,
        maximumLevel = 11,
        battleDangerTiers = {tier0min = 1, tier0max = 1, tier1min = 1, tier1max = 2}, -- 2 to 3 types
        weight = 50
    }),
    battle_mid_sapper_charge = BattleTemplate:new({
        id = "battle_mid_sapper_charge",
        minimumLevel = 7,
        maximumLevel = 12,
        battleDangerTiers = {tier0min = 1, tier0max = 1, tier1min = 1, tier1max = 1},
        allowedTypes = {"Sapper", "Scout"},
        weight = 40
    }),
    battle_mid_nest = BattleTemplate:new({
        id = "battle_mid_nest",
        minimumLevel = 8,
        maximumLevel = 13,
        battleDangerTiers = {tier0min = 1, tier0max = 1, tier1min = 1, tier1max = 1},
        allowedTypes = {"Broodmother", "Critter"},
        weight = 40
    }),
    battle_mid_support_line = BattleTemplate:new({
        id = "battle_mid_support_line",
        minimumLevel = 9,
        maximumLevel = 13,
        battleDangerTiers = {tier1min = 1, tier1max = 2, tier2min = 1, tier2max = 1}, -- 2 to 3 types
        weight = 45
    }),
    battle_mid_slime_infestation = BattleTemplate:new({
        id = "battle_mid_slime_infestation",
        minimumLevel = 9,
        maximumLevel = 14,
        battleDangerTiers = {tier0min = 1, tier0max = 1, tier2min = 1, tier2max = 1},
        allowedTypes = {"Slime", "Grunt"},
        weight = 40
    }),
    battle_mid_vanguard = BattleTemplate:new({
        id = "battle_mid_vanguard",
        minimumLevel = 10,
        maximumLevel = 14,
        battleDangerTiers = {tier1min = 2, tier1max = 2, tier2min = 1, tier2max = 1}, -- 3 types
        weight = 50
    }),
    battle_mid_portal_strike = BattleTemplate:new({
        id = "battle_mid_portal_strike",
        minimumLevel = 11,
        maximumLevel = 14,
        battleDangerTiers = {tier1min = 1, tier1max = 1, tier2min = 1, tier2max = 2}, -- 2 to 3 types
        weight = 40
    }),

    -- -------------------------------------------------------------------------
    -- LATE GAME (Levels 14+, Massive Battles with diverse enemy types)
    -- High enemy diversity: 4 to 6+ distinct enemy types across multiple danger tiers
    -- -------------------------------------------------------------------------
    battle_late_grand_siege = BattleTemplate:new({
        id = "battle_late_grand_siege",
        minimumLevel = 14,
        maximumLevel = 19,
        battleDangerTiers = {tier1min = 2, tier1max = 2, tier2min = 2, tier2max = 3}, -- 4 to 5 distinct types
        weight = 50
    }),
    battle_late_heavy_offensive = BattleTemplate:new({
        id = "battle_late_heavy_offensive",
        minimumLevel = 15,
        maximumLevel = 20,
        battleDangerTiers = {tier1min = 2, tier1max = 2, tier2min = 2, tier2max = 2, tier3min = 1, tier3max = 1}, -- 5 distinct types
        weight = 50
    }),
    battle_late_combined_arms = BattleTemplate:new({
        id = "battle_late_combined_arms",
        minimumLevel = 16,
        maximumLevel = 20,
        battleDangerTiers = {tier0min = 1, tier0max = 1, tier1min = 2, tier1max = 2, tier2min = 2, tier2max = 2, tier3min = 1, tier3max = 1}, -- 6 distinct types
        weight = 55
    }),
    battle_late_swarm_apocalypse = BattleTemplate:new({
        id = "battle_late_swarm_apocalypse",
        minimumLevel = 16,
        maximumLevel = 20,
        battleDangerTiers = {tier0min = 2, tier0max = 2, tier1min = 2, tier1max = 2, tier2min = 1, tier2max = 2}, -- 5 to 6 distinct types
        weight = 45
    }),
    battle_late_elite_vanguard = BattleTemplate:new({
        id = "battle_late_elite_vanguard",
        minimumLevel = 17,
        maximumLevel = 20,
        battleDangerTiers = {tier2min = 3, tier2max = 3, tier3min = 2, tier3max = 2}, -- 5 distinct elite types
        weight = 50
    }),

    -- -------------------------------------------------------------------------
    -- CLIMAX / FINAL BOSS (Level 20)
    -- Massive battle incorporating all elite hostiles
    -- -------------------------------------------------------------------------
    battle_boss = BattleTemplate:new({
        id = "battle_boss",
        minimumLevel = 20,
        maximumLevel = 20,
        battleDangerTiers = {tier1min = 2, tier1max = 2, tier2min = 3, tier2max = 3, tier3min = 2, tier3max = 2},
        weight = 100
    }),
}

for _, template in pairs(BattleTemplateDictionary) do
    template.budgets = template.budgets or DEFAULT_BUDGETS
end

BattleTemplateDictionary.DEFAULT_BUDGETS = DEFAULT_BUDGETS

return BattleTemplateDictionary
