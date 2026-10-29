-- =============================================================================
-- BATTLE MANAGER (BattleManager.lua)
-- Manages post-battle reward generation based on difficulty and player level.
-- =============================================================================

local MaterialRegistry = require("Game.Cards.MaterialRegistry")

local BattleManager = {}
BattleManager.__index = BattleManager

-- Chance a material reward is Universal Essence instead of a typed material
BattleManager.UNIVERSAL_MATERIAL_CHANCE = 0.10
-- Chance a battle (level 2+) offers an upgrade material: about 1.2 of the 3 choices
BattleManager.MATERIAL_CHANCE = 0.4
-- Harder battles sometimes give a pair
BattleManager.MATERIAL_PAIR_MIN_DIFFICULTY = 1.6
BattleManager.MATERIAL_PAIR_CHANCE = 0.35
-- Highest difficulty a reward budget scales with (elite battles)
BattleManager.MAX_REWARD_DIFFICULTY = 2.5
-- Chance an eligible battle (level 3+, budget 280+) offers a card removal
BattleManager.CARD_REMOVAL_CHANCE = 0.25
-- Cash given instead of an artifact reward once every artifact is owned
BattleManager.ARTIFACT_FALLBACK_CASH = 500

--- Picks the material for a material reward: rarely Universal, otherwise a
-- uniformly random typed material from the registry.
function BattleManager.rollMaterial()
    if math.random() < BattleManager.UNIVERSAL_MATERIAL_CHANCE then
        return MaterialRegistry.UNIVERSAL
    end
    local typed = MaterialRegistry.getTyped()
    return typed[math.random(1, #typed)].id
end

-- Reward Types supported by the system
BattleManager.REWARD_TYPES = {
    GOLD = "gold",
    UPGRADE_MATERIAL = "upgrade_material",
    CARD_REMOVAL = "card_removal",
    CARD_DRAW = "card_draw",
    RELIC = "relic"
}

function BattleManager:new(config)
    local obj = setmetatable({}, self)
    obj.config = config or {}
    return obj
end

-- Value assignments per reward item. Every non-gold reward is paid for out of
-- the battle's budget, and whatever is left becomes cash (never below 0).
-- 1 Cash = 1
-- 1 Card Draft = 50
-- 1 typed Upgrade Material = 50, 1 Universal Essence = 100
-- 1 Card Removal = 100
-- 1 Relic = 500 (the elite artifact is given on top of the budget)
BattleManager.REWARD_VALUES = {
    GOLD = 1,
    CARD_DRAW = 50,
    UPGRADE_MATERIAL = 50,
    UNIVERSAL_MATERIAL = 100,
    CARD_REMOVAL = 100,
    RELIC = 500
}

--- Generates rewards based on difficulty multiplier and current player level.
-- Uses a value-budget model:
--   Total Reward Budget = (Base Value(level) * difficultyMultiplier) / 2
-- Non-gold rewards are sampled from the pool based on affordability and level,
-- and the remaining budget is converted into Cash (1:1 value).
-- @param difficultyMultiplier number: Value between 1.0 and 2.5 (higher = tougher battle, more budget; 2.5 is elite)
-- @param playerLevel number: Current battle / sector level (1, 2, 3...)
-- @return table: Array of reward objects
function BattleManager:generateRewards(difficultyMultiplier, playerLevel)
    local mult = difficultyMultiplier or 1.0
    local level = playerLevel or 1

    -- Ensure bounds [1.0, 2.5] (2.5 is an elite battle)
    mult = math.max(1.0, math.min(BattleManager.MAX_REWARD_DIFFICULTY, mult))

    -- 1. Calculate Total Value Budget for this battle
    -- Formula: ((100 + (level * 25)) * battle difficulty scale) / 2, rounded to the nearest 1
    local baseBudget = (40 + (level * 10))
    local totalBudget = math.floor(baseBudget * mult + 0.5)
    local remainingBudget = totalBudget

    local rewards = {}
    local addedTypes = {}

    -- 2. Determine non-gold reward candidates (each one's value comes out of the
    -- budget; see REWARD_VALUES):
    --   Card Removal (level >= 3, rare), Card Draft (high frequency),
    --   Upgrade Material (level >= 2; may take the cash down to 0)

    -- Candidate: Card Removal
    -- Eligible if level >= 3 and the budget covers it with 30 to spare
    if level >= 3 and remainingBudget >= BattleManager.REWARD_VALUES.CARD_REMOVAL + 30 and not addedTypes[BattleManager.REWARD_TYPES.CARD_REMOVAL] then
        if math.random() < BattleManager.CARD_REMOVAL_CHANCE then
            addedTypes[BattleManager.REWARD_TYPES.CARD_REMOVAL] = true
            remainingBudget = remainingBudget - BattleManager.REWARD_VALUES.CARD_REMOVAL
            table.insert(rewards, {
                type = BattleManager.REWARD_TYPES.CARD_REMOVAL,
                name = "Card Removal",
                amount = 1,
                value = BattleManager.REWARD_VALUES.CARD_REMOVAL,
                description = "+1 Card Removal Token",
                icon = "trash"
            })
        end
    end

    -- Candidate: Card Draft (Value 50)
    -- Core roguelike progression reward (75% base chance if affordable with >= 20 gold left)
    if remainingBudget >= 70 and not addedTypes[BattleManager.REWARD_TYPES.CARD_DRAW] then
        if math.random() < 0.75 then
            addedTypes[BattleManager.REWARD_TYPES.CARD_DRAW] = true
            remainingBudget = remainingBudget - BattleManager.REWARD_VALUES.CARD_DRAW
            table.insert(rewards, {
                type = BattleManager.REWARD_TYPES.CARD_DRAW,
                name = "Card Draft",
                amount = 1,
                value = BattleManager.REWARD_VALUES.CARD_DRAW,
                description = "Card Draft",
                icon = "card"
            })
        end
    end

    -- Candidate: Upgrade Material
    -- Rolled last and not limited by the budget, so materials turn up from level 2
    -- on; on small budgets they can take the cash all the way to 0
    if level >= 2 and math.random() < BattleManager.MATERIAL_CHANCE then
        -- Roll which material this battle offers (shown on the battle preview)
        local materialId = BattleManager.rollMaterial()
        local matAmt = 1
        -- Universal Essence is rare: never awarded in pairs
        if materialId ~= MaterialRegistry.UNIVERSAL and mult >= BattleManager.MATERIAL_PAIR_MIN_DIFFICULTY
            and math.random() < BattleManager.MATERIAL_PAIR_CHANCE then
            matAmt = 2
        end
        local materialName = MaterialRegistry.getName(materialId)
        local unitValue = (materialId == MaterialRegistry.UNIVERSAL) and BattleManager.REWARD_VALUES.UNIVERSAL_MATERIAL
            or BattleManager.REWARD_VALUES.UPGRADE_MATERIAL
        remainingBudget = remainingBudget - matAmt * unitValue
        addedTypes[BattleManager.REWARD_TYPES.UPGRADE_MATERIAL] = true
        table.insert(rewards, {
            type = BattleManager.REWARD_TYPES.UPGRADE_MATERIAL,
            name = materialName,
            materialId = materialId,
            amount = matAmt,
            value = matAmt * unitValue,
            description = string.format("+%d %s", matAmt, materialName),
            icon = "material"
        })
    end

    -- 3. Remainder Budget -> Cash (1 Cash = 1 Value Budget)
    -- Left out when the other rewards used up the budget ($0 isn't a reward).
    -- Rounded to the nearest 1.
    local cashAmount = math.max(0, math.floor((remainingBudget / BattleManager.REWARD_VALUES.GOLD) + 0.5))

    local isSoloCash = (#rewards == 0)
    local cashDesc = string.format("+$%d Cash", cashAmount)

    if cashAmount <= 0 then return rewards end

    -- Insert Cash as the first reward
    table.insert(rewards, 1, {
        type = BattleManager.REWARD_TYPES.GOLD,
        name = "Cash",
        amount = cashAmount,
        value = cashAmount * BattleManager.REWARD_VALUES.GOLD,
        description = cashDesc,
        isJackpot = isSoloCash,
        icon = "gold"
    })

    return rewards
end

--- A random artifact (elite battles). Which one is only decided when it's
--- claimed, so the battle preview can't show it. If every artifact is already
--- owned by then, it pays ARTIFACT_FALLBACK_CASH instead.
function BattleManager.artifactReward()
    return {
        type = BattleManager.REWARD_TYPES.RELIC,
        name = "Artifact",
        amount = 1,
        value = BattleManager.REWARD_VALUES.RELIC,
        description = "Random Artifact",
        icon = "artifact"
    }
end

--- Applies the resolved rewards to persistent game state and systems.
-- @param rewards table: Array of rewards generated by generateRewards
-- @param game table: Current game instance (optional)
function BattleManager:applyRewards(rewards, game)
    if not rewards then return end
    _G.PersistentState = _G.PersistentState or {}

    for _, reward in ipairs(rewards) do
        if reward.type == BattleManager.REWARD_TYPES.GOLD then
            _G.PersistentState.cash = (_G.PersistentState.cash or 0) + (reward.amount or 0)
        elseif reward.type == BattleManager.REWARD_TYPES.UPGRADE_MATERIAL then
            local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
            local materialId = reward.materialId or MaterialRegistry.resolve(nil)
            CardUpgradeConfig.Economy.addResource(materialId, reward.amount or 1)
        elseif reward.type == BattleManager.REWARD_TYPES.CARD_REMOVAL then
            local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
            CardUpgradeConfig.Economy.addCardRemovals(reward.amount or 1)
        elseif reward.type == BattleManager.REWARD_TYPES.CARD_DRAW then
            -- Card draw is a pick 1 of 3 card reward, offered after the battle summary
            if game then
                game.pendingCardDraws = (game.pendingCardDraws or 0) + 1
            end
        elseif reward.type == BattleManager.REWARD_TYPES.RELIC then
            -- Relics are artifacts: a specific one if the reward names it, else a random unowned one
            local ArtifactManager = require("Game.Artifacts.ArtifactManager")
            local ArtifactIndex = require("Game.Artifacts.ArtifactIndex")
            local def
            if reward.artifactId then
                ArtifactManager.grant(reward.artifactId)
                def = ArtifactIndex.get(reward.artifactId)
            else
                def = ArtifactManager.grantRandom()
                if not def then
                    _G.PersistentState.cash = (_G.PersistentState.cash or 0) + BattleManager.ARTIFACT_FALLBACK_CASH
                    if game then game.artifactFallbackCash = (game.artifactFallbackCash or 0) + BattleManager.ARTIFACT_FALLBACK_CASH end
                end
            end
            -- The battle shows each new artifact with a reveal after the summary
            if def and game then
                game.newArtifacts = game.newArtifacts or {}
                table.insert(game.newArtifacts, def)
            end
        end
    end
end

return BattleManager
