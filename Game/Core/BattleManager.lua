-- =============================================================================
-- BATTLE MANAGER (BattleManager.lua)
-- Manages post-battle reward generation based on difficulty and player level.
-- =============================================================================

local BattleManager = {}
BattleManager.__index = BattleManager

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

-- Value assignments per reward item:
-- 1 piece of Gold = 2
-- 1 Card Draft = 50
-- 1 Upgrade Material = 200
-- 1 Card Removal = 250
-- 1 Relic = 500
BattleManager.REWARD_VALUES = {
    GOLD = 1,
    CARD_DRAW = 50,
    UPGRADE_MATERIAL = 200,
    CARD_REMOVAL = 250,
    RELIC = 500
}

--- Generates rewards based on difficulty multiplier and current player level.
-- Uses a value-budget model:
--   Total Reward Budget = (Base Value(level) * difficultyMultiplier) / 2
-- Non-gold rewards are sampled from the pool based on affordability and level,
-- and the remaining budget is converted into Cash (1:1 value).
-- @param difficultyMultiplier number: Value between 1.0 and 2.0 (higher = tougher battle, more budget)
-- @param playerLevel number: Current battle / sector level (1, 2, 3...)
-- @return table: Array of reward objects
function BattleManager:generateRewards(difficultyMultiplier, playerLevel)
    local mult = difficultyMultiplier or 1.0
    local level = playerLevel or 1

    -- Ensure bounds [1.0, 2.0]
    mult = math.max(1.0, math.min(2.0, mult))

    -- 1. Calculate Total Value Budget for this battle
    -- Formula: ((100 + (level * 25)) * battle difficulty scale) / 2, rounded to the nearest 1
    local baseBudget = (40 + (level * 10))
    local totalBudget = math.floor(baseBudget * mult + 0.5)
    local remainingBudget = totalBudget

    local rewards = {}
    local addedTypes = {}

    -- 2. Determine non-gold reward candidates
    -- Each candidate has a fixed value cost:
    --   Card Removal: 250 (level >= 3, rare)
    --   Upgrade Material: 200 (level >= 2)
    --   Card Draft: 50 (available from level 1+, high frequency)

    -- Candidate: Card Removal (Value 250)
    -- Eligible if level >= 3 and remainingBudget >= 280
    if level >= 3 and remainingBudget >= 280 and not addedTypes[BattleManager.REWARD_TYPES.CARD_REMOVAL] then
        if math.random() < 0.35 then
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

    -- Candidate: Upgrade Material (Value 200 each)
    -- Eligible if level >= 2 and remainingBudget >= 230
    if level >= 2 and remainingBudget >= 230 and not addedTypes[BattleManager.REWARD_TYPES.UPGRADE_MATERIAL] then
        if math.random() < 0.50 then
            local maxAfford = math.floor((remainingBudget - 30) / BattleManager.REWARD_VALUES.UPGRADE_MATERIAL)
            local matAmt = 1
            if maxAfford >= 2 and (mult >= 1.4 or math.random() < 0.3) then
                matAmt = 2
            end
            matAmt = math.min(matAmt, maxAfford)
            
            if matAmt >= 1 then
                local cost = matAmt * BattleManager.REWARD_VALUES.UPGRADE_MATERIAL
                remainingBudget = remainingBudget - cost
                addedTypes[BattleManager.REWARD_TYPES.UPGRADE_MATERIAL] = true
                table.insert(rewards, {
                    type = BattleManager.REWARD_TYPES.UPGRADE_MATERIAL,
                    name = "Upgrade Material",
                    amount = matAmt,
                    value = cost,
                    description = string.format("+%d Upgrade Material", matAmt),
                    icon = "material"
                })
            end
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

    -- 3. Remainder Budget -> Cash (1 Cash = 1 Value Budget)
    -- Cash is 100% guaranteed. Even if other rewards were rolled, remaining budget becomes cash.
    -- Rounded to the nearest 1.
    local cashAmount = math.max(1, math.floor((remainingBudget / BattleManager.REWARD_VALUES.GOLD) + 0.5))

    local isSoloCash = (#rewards == 0)
    local cashDesc = string.format("+$%d Cash", cashAmount)

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
            CardUpgradeConfig.Economy.addResource("Upgrade Material", reward.amount or 1)
        elseif reward.type == BattleManager.REWARD_TYPES.CARD_REMOVAL then
            local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
            CardUpgradeConfig.Economy.addCardRemovals(reward.amount or 1)
        elseif reward.type == BattleManager.REWARD_TYPES.CARD_DRAW then
            -- Card draw is presented as a pick 1 of 3 card reward
            if game and game.rewardSystem then
                game.rewardSystem:activate("cards", 3)
            end
        elseif reward.type == BattleManager.REWARD_TYPES.RELIC then
            -- TODO: Relic system hook placeholder
            print("[BattleManager] Relic awarded (Placeholder): " .. tostring(reward.name))
        end
    end
end

return BattleManager
