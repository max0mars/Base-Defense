local RewardPool = require("Game.Rewards.RewardPool")
local SpecialRewardIndex = require("Game.Rewards.SpecialRewardIndex")
local EnemyRewardIndex = require("Game.Rewards.EnemyRewardIndex")
local Reward = require("Game.Rewards.Reward")

local SpecialUpgradeManager = {}
SpecialUpgradeManager.__index = SpecialUpgradeManager

function SpecialUpgradeManager:new(game)
    local mgr = setmetatable({
        game = game,
        isActive = false,
        playerPool = RewardPool:new(SpecialRewardIndex),
        enemyPool = RewardPool:new(EnemyRewardIndex),
        currentPairs = {},
        selectedIndex = 1
    }, self)
    
    -- UI Scaling
    mgr.cardWidth = 240
    mgr.cardHeight = 320
    mgr.cardSpacing = 30
    
    return mgr
end

function SpecialUpgradeManager:generatePairs(count, luckLevel)
    self.currentPairs = {}
    local chosenPlayerIds = {}
    local chosenEnemyIds = {}
    
    for i = 1, count do
        -- 1. Roll for a player reward first to determine the rarity of the pair
        -- We use a modified generateChoices logic to get a specific rarity first
        local luck = math.max(1, math.min(10, luckLevel or 1))
        local weights = self.playerPool.LuckTable[luck]
        local totalWeight = 0
        for _, w in pairs(weights) do totalWeight = totalWeight + w end
        
        local roll = math.random(1, totalWeight)
        local runningWeight = 0
        local targetRarity = "common"
        
        for _, r in ipairs(self.playerPool.RarityOrder) do
            runningWeight = runningWeight + (weights[r] or 0)
            if roll <= runningWeight then
                targetRarity = r
                break
            end
        end
        
        -- 2. Fetch unique player reward of that rarity
        local pReward = self.playerPool:getRandomRewardFromTier(targetRarity, chosenPlayerIds)
        
        -- 3. Fetch unique enemy reward of the SAME rarity
        local eReward = self.enemyPool:getRandomRewardFromTier(targetRarity, chosenEnemyIds)
        
        if pReward and eReward then
            -- Wrap them in Reward objects for UI compatibility
            local pair = {
                player = Reward:new(pReward),
                enemy = Reward:new(eReward),
                rarity = targetRarity
            }
            table.insert(self.currentPairs, pair)
            chosenPlayerIds[pReward.id] = true
            chosenEnemyIds[eReward.id] = true
        end
    end
end

function SpecialUpgradeManager:activate()
    self.isActive = true
    self.selectedIndex = 1
    self:generatePairs(3, self.game.luck or 1)
end

function SpecialUpgradeManager:applyChoice(index)
    local pair = self.currentPairs[index]
    if not pair then error("No pair found at index " .. index) end
    
    -- Apply Player Buff to Player Effect Manager
    if pair.player.type == "effect" then
        self.game.playerEffectManager:applyEffect(pair.player.effect)
    else
        error("Invalid special player reward type: " .. pair.player.type)
    end
    
    -- Apply Enemy Buff to Enemy Effect Manager
    if pair.enemy.type == "effect" then
        self.game.enemyEffectManager:applyEffect(pair.enemy.effect)
    else
        error("Invalid enemy reward type: " .. pair.enemy.type)
    end
    
    self.isActive = false
    self.game.rewardActive = false
end

function SpecialUpgradeManager:draw()
    if not self.isActive then return end
    
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    
    -- Background
    love.graphics.setColor(0.1, 0, 0, 0.85) -- Darker, redder for "Devil's Bargain"
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.printf("THE DEVIL'S BARGAIN", 0, 40, screenW, "center")
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf("Greater power comes with greater risks. Choose wisely.", 0, 75, screenW, "center")
    
    local totalW = (#self.currentPairs * self.cardWidth) + ((#self.currentPairs - 1) * self.cardSpacing)
    local startX = (screenW - totalW) / 2
    local startY = 150
    
    for i, pair in ipairs(self.currentPairs) do
        local x = startX + (i - 1) * (self.cardWidth + self.cardSpacing)
        local y = startY
        local isHovered = (i == self.selectedIndex)
        
        -- Draw Pair Card
        self:drawPairCard(pair, x, y, isHovered)
    end
end

function SpecialUpgradeManager:drawPairCard(pair, x, y, isHovered)
    local w, h = self.cardWidth, self.cardHeight
    
    -- Card Style
    love.graphics.setColor(isHovered and {0.2, 0.1, 0.1, 1} or {0.15, 0.1, 0.1, 1})
    love.graphics.rectangle("fill", x, y, w, h, 10, 10)
    
    -- Border based on rarity
    local color = {0.5, 0.5, 0.5, 1}
    if pair.rarity == "legendary" then color = {1, 0.8, 0, 1}
    elseif pair.rarity == "epic" then color = {0.6, 0.2, 1, 1}
    elseif pair.rarity == "rare" then color = {0, 0.5, 1, 1}
    end
    
    love.graphics.setColor(color)
    love.graphics.setLineWidth(isHovered and 3 or 1)
    love.graphics.rectangle("line", x, y, w, h, 10, 10)
    love.graphics.setLineWidth(1)
    
    -- Player Portion (Green)
    love.graphics.setColor(0.4, 1, 0.4, 1)
    love.graphics.printf(pair.player.name, x, y + 20, w, "center")
    love.graphics.printf(pair.player.description, x + 10, y + 60, w - 20, "center")
    
    -- Separator
    love.graphics.setColor(1, 0, 0, 0.3)
    love.graphics.line(x + 20, y + h/2, x + w - 20, y + h/2)
    
    -- Enemy Portion (Red)
    love.graphics.setColor(1, 0.3, 0.3, 1)
    love.graphics.printf("RISK: " .. pair.enemy.name, x, y + h/2 + 20, w, "center")
    love.graphics.printf(pair.enemy.description, x + 10, y + h/2 + 60, w - 20, "center")
end

function SpecialUpgradeManager:mousepressed(x, y, button)
    if not self.isActive or button ~= 1 then return end
    
    local screenW = love.graphics.getWidth()
    local totalW = (#self.currentPairs * self.cardWidth) + ((#self.currentPairs - 1) * self.cardSpacing)
    local startX = (screenW - totalW) / 2
    local startY = 150
    
    for i = 1, #self.currentPairs do
        local cardX = startX + (i - 1) * (self.cardWidth + self.cardSpacing)
        if x >= cardX and x <= cardX + self.cardWidth and y >= startY and y <= startY + self.cardHeight then
            self:applyChoice(i)
            return true
        end
    end
end

return SpecialUpgradeManager
