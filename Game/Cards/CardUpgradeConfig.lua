local MaterialRegistry = require("Game.Cards.MaterialRegistry")

local CardUpgradeConfig = {}

-- Roman numerals mapping for Tiers 1 through 5
CardUpgradeConfig.TIER_NAMES = { "I", "II", "III", "IV", "V" }
CardUpgradeConfig.MAX_TIER = 5

-- Flat bonus per tier above Tier I, per stat (Tier V = 1 + 4 * bonus)
CardUpgradeConfig.TIER_BONUS = {
    damage = 0.20,
    fireRate = 0.10,
    range = 0.15,
}

--- Stat multiplier for a tier (1.0 at Tier I).
function CardUpgradeConfig.getTierMultiplier(statName, tier)
    local bonus = CardUpgradeConfig.TIER_BONUS[statName] or 0
    return 1.0 + ((tier or 1) - 1) * bonus
end

-- Placeholder key in cost tables for "this card's upgrade material" (see MaterialRegistry)
CardUpgradeConfig.MATERIAL = "material"

-- Default modular upgrade costs per tier transition (target tier as key)
-- Can be overridden per-card or per-item
CardUpgradeConfig.DEFAULT_COSTS = {
    [2] = { gold = 30,  material = 1 },
    [3] = { gold = 75,  material = 1 },
    [4] = { gold = 250, material = 4 },
    [5] = { gold = 600, material = 7 },
}

--- Replaces the `material` placeholder in a cost table with a real material id.
function CardUpgradeConfig.resolveCost(costTable, materialId)
    if not costTable then return nil end
    local resolved = {}
    for resName, amount in pairs(costTable) do
        if resName == CardUpgradeConfig.MATERIAL then
            resName = materialId or MaterialRegistry.resolve(nil)
        end
        resolved[resName] = (resolved[resName] or 0) + amount
    end
    return resolved
end

-- Economy Helper to query and deduct arbitrary modular resources
CardUpgradeConfig.Economy = {
    getResource = function(resName)
        _G.PersistentState = _G.PersistentState or {}
        if resName == "gold" or resName == "cash" then
            return _G.PersistentState.cash or 0
        end
        if resName == "Card Removal" or resName == "cardRemovals" or resName == "trash" or resName == "Trash" then
            if _G.PersistentState.cardRemovals ~= nil then
                return _G.PersistentState.cardRemovals
            end
            _G.PersistentState.materials = _G.PersistentState.materials or {}
            return _G.PersistentState.materials["Card Removal"] or _G.PersistentState.materials["Trash"] or 0
        end
        _G.PersistentState.materials = _G.PersistentState.materials or {}
        return _G.PersistentState.materials[resName] or 0
    end,

    --- Exact resources a cost would spend, or nil if unaffordable. Typed materials are
    -- spent first; Universal Essence covers any shortfall of typed materials.
    planSpend = function(costTable)
        if not costTable then return nil end
        local getResource = CardUpgradeConfig.Economy.getResource
        local plan = {}
        local universalNeeded = 0
        for resName, amount in pairs(costTable) do
            local have = getResource(resName)
            local mat = MaterialRegistry.get(resName)
            if mat and not mat.universal and have < amount then
                if have > 0 then plan[resName] = have end
                universalNeeded = universalNeeded + (amount - have)
            elseif have < amount then
                return nil
            else
                plan[resName] = (plan[resName] or 0) + amount
            end
        end
        if universalNeeded > 0 then
            local universal = MaterialRegistry.UNIVERSAL
            plan[universal] = (plan[universal] or 0) + universalNeeded
            if getResource(universal) < plan[universal] then return nil end
        end
        return plan
    end,

    canAfford = function(costTable)
        return CardUpgradeConfig.Economy.planSpend(costTable) ~= nil
    end,

    deduct = function(costTable)
        local plan = CardUpgradeConfig.Economy.planSpend(costTable)
        if not plan then return false end
        for resName, amount in pairs(plan) do
            if resName == "gold" or resName == "cash" then
                _G.PersistentState.cash = (_G.PersistentState.cash or 0) - amount
            elseif resName == "Card Removal" or resName == "cardRemovals" or resName == "trash" or resName == "Trash" then
                _G.PersistentState.cardRemovals = math.max(0, (_G.PersistentState.cardRemovals or 0) - amount)
                _G.PersistentState.materials = _G.PersistentState.materials or {}
                _G.PersistentState.materials["Card Removal"] = _G.PersistentState.cardRemovals
            else
                _G.PersistentState.materials = _G.PersistentState.materials or {}
                _G.PersistentState.materials[resName] = (_G.PersistentState.materials[resName] or 0) - amount
            end
        end
        return true
    end,

    addResource = function(resName, amount)
        _G.PersistentState = _G.PersistentState or {}
        if resName == "gold" or resName == "cash" then
            _G.PersistentState.cash = (_G.PersistentState.cash or 0) + amount
        elseif resName == "Card Removal" or resName == "cardRemovals" or resName == "trash" or resName == "Trash" then
            _G.PersistentState.cardRemovals = (_G.PersistentState.cardRemovals or 0) + amount
            _G.PersistentState.materials = _G.PersistentState.materials or {}
            _G.PersistentState.materials["Card Removal"] = _G.PersistentState.cardRemovals
        else
            _G.PersistentState.materials = _G.PersistentState.materials or {}
            _G.PersistentState.materials[resName] = (_G.PersistentState.materials[resName] or 0) + amount
        end
    end,

    getCardRemovals = function()
        return CardUpgradeConfig.Economy.getResource("Card Removal")
    end,

    addCardRemovals = function(amount)
        CardUpgradeConfig.Economy.addResource("Card Removal", amount)
    end,

    useCardRemoval = function()
        if CardUpgradeConfig.Economy.getCardRemovals() >= 1 then
            return CardUpgradeConfig.Economy.deduct({ ["Card Removal"] = 1 })
        end
        return false
    end
}

return CardUpgradeConfig
