local RewardPool = {}
RewardPool.__index = RewardPool

-- Static Luck Table: Luck (1-10) -> {rarity -> weight}
RewardPool.LuckTable = {
    [1]  = { common = 80, uncommon = 15, rare = 5,  epic = 0,  legendary = 0 },
    [2]  = { common = 70, uncommon = 20, rare = 8,  epic = 2,  legendary = 0 },
    [3]  = { common = 60, uncommon = 25, rare = 10, epic = 4,  legendary = 1 },
    [4]  = { common = 50, uncommon = 30, rare = 12, epic = 6,  legendary = 2 },
    [5]  = { common = 40, uncommon = 30, rare = 15, epic = 10, legendary = 5 },
    [6]  = { common = 30, uncommon = 30, rare = 20, epic = 15, legendary = 5 },
    [7]  = { common = 25, uncommon = 25, rare = 25, epic = 15, legendary = 10 },
    [8]  = { common = 20, uncommon = 25, rare = 25, epic = 20, legendary = 10 },
    [9]  = { common = 15, uncommon = 20, rare = 25, epic = 25, legendary = 15 },
    [10] = { common = 10, uncommon = 20, rare = 30, epic = 25, legendary = 15 }
}

-- Preferred rarity order for fallbacks
RewardPool.RarityOrder = { "legendary", "epic", "rare", "uncommon", "common" }

function RewardPool:new(rewardIndex)
    local obj = setmetatable({
        index = rewardIndex
    }, self)
    return obj
end

function RewardPool:generateChoices(count, luckLevel)
    luckLevel = math.max(1, math.min(10, luckLevel or 1))
    local weights = self.LuckTable[luckLevel]
    local choices = {}
    local chosenIds = {}

    local totalWeight = 0
    for _, w in pairs(weights) do totalWeight = totalWeight + w end

    for i = 1, count do
        -- Step 1: Roll for Tier
        local roll = math.random(1, totalWeight)
        local runningWeight = 0
        local rolledRarity = "common"
        
        for _, r in ipairs(self.RarityOrder) do
            local rarity = r
            local w = weights[rarity]
            runningWeight = runningWeight + w
            if roll <= runningWeight then
                rolledRarity = rarity
                break
            end
        end
        
        -- Step 2 & 3: Roll for Reward (with internal same-tier unique check and fallback)
        local reward = self:getRandomRewardFromTier(rolledRarity, chosenIds)
        
        if reward then
            table.insert(choices, reward)
            chosenIds[reward.id] = true
        end
    end

    return choices
end

function RewardPool:getRandomRewardFromTier(rarity, excludedIds)
    -- Fallback loop: start from the requested rarity and iterate downwards through RarityOrder
    local foundStart = false
    for _, r in ipairs(self.RarityOrder) do
        if r == rarity then foundStart = true end
        
        if foundStart then
            local tier = self.index[r]
            if tier and #tier > 0 then
                -- Step 2 & 3: Find internal unique reward in this tier
                local available = {}
                for _, item in ipairs(tier) do
                    if not excludedIds[item.id or item.name] then
                        table.insert(available, item)
                    end
                end
                
                if #available > 0 then
                    local choice = available[math.random(1, #available)]
                    
                    -- Step 3: Deep copy to prevent modifying the master index
                    -- (Fixes the issue where stamping rarity leaked into other hands)
                    local reward = {}
                    for k, v in pairs(choice) do
                        if type(v) == "table" and k ~= "building" then
                            reward[k] = {}
                            for subK, subV in pairs(v) do reward[k][subK] = subV end
                        else
                            reward[k] = v
                        end
                    end
                    
                    reward.rarity = r
                    return reward
                end
            end
        end
    end
    
    return nil
end

return RewardPool
