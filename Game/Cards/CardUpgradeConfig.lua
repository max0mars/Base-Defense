local CardUpgradeConfig = {}

-- Roman numerals mapping for Tiers 1 through 5
CardUpgradeConfig.TIER_NAMES = { "I", "II", "III", "IV", "V" }
CardUpgradeConfig.MAX_TIER = 5
CardUpgradeConfig.BONUS_PER_TIER = 0.20 -- Flat 20% per tier above Tier I

-- Default modular upgrade costs per tier transition (target tier as key)
-- Can be overridden per-card or per-item
CardUpgradeConfig.DEFAULT_COSTS = {
    [2] = { gold = 50,  ["Upgrade Material"] = 1 },
    [3] = { gold = 100, ["Upgrade Material"] = 2 },
    [4] = { gold = 200, ["Upgrade Material"] = 3 },
    [5] = { gold = 400, ["Upgrade Material"] = 5 },
}

-- Economy Helper to query and deduct arbitrary modular resources
CardUpgradeConfig.Economy = {
    getResource = function(resName)
        _G.PersistentState = _G.PersistentState or {}
        if resName == "gold" or resName == "cash" then
            return _G.PersistentState.cash or 0
        end
        _G.PersistentState.materials = _G.PersistentState.materials or {}
        return _G.PersistentState.materials[resName] or 0
    end,

    canAfford = function(costTable)
        if not costTable then return false end
        for resName, amount in pairs(costTable) do
            if CardUpgradeConfig.Economy.getResource(resName) < amount then
                return false
            end
        end
        return true
    end,

    deduct = function(costTable)
        if not CardUpgradeConfig.Economy.canAfford(costTable) then return false end
        for resName, amount in pairs(costTable) do
            if resName == "gold" or resName == "cash" then
                _G.PersistentState.cash = (_G.PersistentState.cash or 0) - amount
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
        else
            _G.PersistentState.materials = _G.PersistentState.materials or {}
            _G.PersistentState.materials[resName] = (_G.PersistentState.materials[resName] or 0) + amount
        end
    end
}

return CardUpgradeConfig
