local RewardPool = {}
RewardPool.__index = RewardPool

-- Static Luck Table: Luck (1-10) -> {rarity -> weight}
RewardPool.LuckTable = {
    [1]  = { common = 90, uncommon = 10, rare = 0,  epic = 0,  legendary = 0 },
    [2]  = { common = 80, uncommon = 20, rare = 0,  epic = 0,  legendary = 0 },
    [3]  = { common = 70, uncommon = 25, rare = 5,  epic = 0,  legendary = 0 },
    [4]  = { common = 55, uncommon = 30, rare = 13, epic = 2,  legendary = 0 },
    [5]  = { common = 50, uncommon = 30, rare = 15,  epic = 4,  legendary = 1 },
    [6]  = { common = 40, uncommon = 35, rare = 15, epic = 7,  legendary = 3 },
    [7]  = { common = 30, uncommon = 35, rare = 20, epic = 10, legendary = 5 },
    [8]  = { common = 20, uncommon = 35, rare = 25, epic = 15, legendary = 5 },
    [9]  = { common = 10, uncommon = 35, rare = 30, epic = 20, legendary = 5 },
    [10] = { common = 5, uncommon = 30, rare = 35, epic = 20, legendary = 10 }
}

-- Preferred rarity order for fallbacks
RewardPool.RarityOrder = { "legendary", "epic", "rare", "uncommon", "common" }

function RewardPool:new(rewardIndex, game)
    local obj = setmetatable({
        index = rewardIndex,
        game = game
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
                        local eligible = true
                        if item.isEligible then
                            eligible = item.isEligible(self.game)
                        end
                        if eligible then
                            table.insert(available, item)
                        end
                    end
                end
                
                if self.game and self.game.base and self.game.base.mainLazer then
                    local ml = self.game.base.mainLazer
                    if ml.upgradeRewards and ml.upgradeRewards[r] then
                        for _, item in ipairs(ml.upgradeRewards[r]) do
                            if not excludedIds[item.id or item.name] then
                                local eligible = true
                                if item.isEligible then
                                    eligible = item.isEligible(self.game)
                                end
                                if eligible then
                                    table.insert(available, item)
                                end
                            end
                        end
                    end
                end
                
                if #available > 0 then
                    local choice = available[math.random(1, #available)]
                    
                    -- Deep copy to prevent modifying the master index
                    local function deepCopy(obj)
                        if type(obj) ~= 'table' then return obj end
                        local res = {}
                        for k, v in pairs(obj) do res[k] = deepCopy(v) end
                        return res
                    end
                    
                    local reward = {}
                    for k, v in pairs(choice) do
                        if k == "building" or k == "bulletType" or k == "hitEffects" or k == "types" then
                            reward[k] = v
                        else
                            reward[k] = deepCopy(v)
                        end
                    end
                    
                    if reward.onGenerate then
                        reward:onGenerate()
                    end
                    
                    if not reward.rarity then
                        reward.rarity = r
                    end
                    return reward
                end
            end
        end
    end
    
    return nil
end

function RewardPool:getLuckProbabilities(luckLevel)
    luckLevel = math.max(1, math.min(10, math.floor(luckLevel or 1)))
    local weights = self.LuckTable[luckLevel]
    local totalWeight = 0
    for _, w in pairs(weights) do totalWeight = totalWeight + w end
    
    local probs = {}
    local rarityColors = {
        common = {1, 1, 1},
        uncommon = {0.2, 0.8, 0.2},
        rare = {0.2, 0.4, 1},
        epic = {0.7, 0.2, 1},
        legendary = {1, 0.7, 0}
    }
    
    -- Iterate in display order (Reverse probability order usually looks nice)
    for i = #self.RarityOrder, 1, -1 do
        local rarity = self.RarityOrder[i]
        local w = weights[rarity]
        if w > 0 then
            table.insert(probs, {
                rarity = rarity:sub(1,1):upper() .. rarity:sub(2),
                percent = (w / totalWeight) * 100,
                color = rarityColors[rarity]
            })
        end
    end
    return probs
end

return RewardPool
