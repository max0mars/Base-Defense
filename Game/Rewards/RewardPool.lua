local RewardPool = {}
RewardPool.__index = RewardPool

-- Preferred rarity order for fallbacks
RewardPool.RarityOrder = { "legendary", "epic", "rare", "uncommon", "common" }

-- Card Draft Rarity Scale: battle level anchors -> {rarity -> weight}.
-- Levels between anchors interpolate linearly; levels past the last anchor use it as-is.
RewardPool.DraftRarityScale = {
    { level = 1,  common = 85, uncommon = 15, rare = 0,  epic = 0,  legendary = 0 },
    { level = 3,  common = 70, uncommon = 25, rare = 5,  epic = 0,  legendary = 0 },
    { level = 6,  common = 50, uncommon = 30, rare = 15, epic = 5,  legendary = 0 },
    { level = 10, common = 35, uncommon = 32, rare = 20, epic = 10, legendary = 3 },
    { level = 15, common = 20, uncommon = 32, rare = 26, epic = 15, legendary = 7 },
    { level = 20, common = 10, uncommon = 30, rare = 30, epic = 20, legendary = 10 }
}

--- Returns card draft rarity weights for the given battle level.
-- @param battleLevel number: Current battle level (1, 2, 3...)
-- @return table: {rarity -> integer weight}
function RewardPool.getCardDraftRarityWeights(battleLevel)
    local scale = RewardPool.DraftRarityScale
    local level = math.max(scale[1].level, battleLevel or 1)

    local lo, hi = scale[#scale], scale[#scale]
    for i = 1, #scale - 1 do
        if level < scale[i + 1].level then
            lo, hi = scale[i], scale[i + 1]
            break
        end
    end

    local t = (hi.level == lo.level) and 0 or (level - lo.level) / (hi.level - lo.level)
    local weights = {}
    for _, rarity in ipairs(RewardPool.RarityOrder) do
        weights[rarity] = math.floor(lo[rarity] + (hi[rarity] - lo[rarity]) * t + 0.5)
    end
    return weights
end

--- Rolls a rarity from a weight table.
-- @param weights table: {rarity -> weight}
-- @return string: Rolled rarity ("common" if all weights are zero)
function RewardPool.rollRarity(weights)
    local totalWeight = 0
    for _, w in pairs(weights) do totalWeight = totalWeight + w end
    if totalWeight <= 0 then return "common" end

    local roll = math.random(1, totalWeight)
    local runningWeight = 0
    for _, rarity in ipairs(RewardPool.RarityOrder) do
        runningWeight = runningWeight + (weights[rarity] or 0)
        if roll <= runningWeight then
            return rarity
        end
    end
    return "common"
end

function RewardPool:new(rewardIndex, game)
    local obj = setmetatable({
        index = rewardIndex,
        game = game
    }, self)
    return obj
end

function RewardPool:generateChoicesWithWeights(count, weights)
    local choices = {}
    local chosenIds = {}

    for i = 1, count do
        -- Step 1: Roll for Tier
        local rolledRarity = RewardPool.rollRarity(weights)

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

return RewardPool
