-- RewardSystem.lua - Main reward system that manages the pool and selection
local Reward = require("Game.Rewards.Reward")

local RewardSystem = {}
RewardSystem.__index = RewardSystem
local RewardIndex = require("Game.Rewards.NormalRewardIndex")
local Cursor = require("Game.GUI.Cursor")
local TestingIndex = require("Game.Rewards.TestingRewardIndex")
local RewardPool = require("Game.Rewards.RewardPool")
local CardReveal = require("Graphics.Animations.CardReveal")

function RewardSystem:new(game)
    -- Always use the real reward pool (testing mode included) so "Buy Upgrade"
    -- offers the full set rather than a small preset list.
    local indexToUse = RewardIndex
    local system = setmetatable({
        game = game,
        isActive = false,
        rewardPool = {}, -- current choices being presented
        poolLogic = RewardPool:new(indexToUse, game)
    }, self)
    
    system.currentChoices = {}
    system.selectedIndex = 1
    
    -- UI Properties
    system.cardWidth = 200
    system.cardHeight = 230
    system.cardSpacing = 20
    system.startX = 100
    system.startY = 245       -- centered for the 720-tall canvas

    system.skipBtnW = 160
    system.skipBtnH = 40
    system.skipBtnX = VIRTUAL_WIDTH / 2 - system.skipBtnW / 2
    system.skipBtnY = 515
    
    -- Initialize the reward pool
    system:initializeRewardPool()
    
    return system
end

function RewardSystem:initializeRewardPool(poolLogicMode, numCards)
    self.rewardPool = {} -- Clear previous
    self.revealTimer = 0
    self.nextRevealIndex = 1
    
    local count = numCards or 3
    local shopLevel = self.game.shopLevel or 1
    
    local isSpecial = false
    local specialInterval = self.game.specialWaveInterval or 5
    if self.game.wave and (self.game.wave % specialInterval == 0) then
        isSpecial = true
    end
    
    local indexToUse = RewardIndex
    if poolLogicMode == "blocker" then
        indexToUse = require("Game.Rewards.BlockerRewardIndex")
    end
    
    self.poolLogic = RewardPool:new(indexToUse, self.game)
    local choices = self.poolLogic:generateChoices(count, shopLevel)
    
    local totalWidth = (count * self.cardWidth) + ((count - 1) * self.cardSpacing)
    local startX = (VIRTUAL_WIDTH - totalWidth) / 2
    self.startX = startX
    
    for i, rewardData in ipairs(choices) do
        rewardData.game = self.game
        local rewardObj = Reward:new(rewardData)
        local x = self.startX + (i - 1) * (self.cardWidth + self.cardSpacing)
        local y = self.startY
        
        local card = CardReveal:new(rewardObj, x, y, self.cardWidth, self.cardHeight)
        table.insert(self.rewardPool, card)
    end
end

function RewardSystem:activate(poolLogicMode, numCards)
    self.isActive = true
    self.selectedIndex = 1
    self:initializeRewardPool(poolLogicMode, numCards)
    self.currentChoices = self.rewardPool
end

function RewardSystem:update(dt)
    if not self.isActive then return end
    
    -- Sequence card flips
    if self.nextRevealIndex <= #self.currentChoices then
        self.revealTimer = self.revealTimer + dt
        if self.revealTimer >= 0.5 then
            self.revealTimer = 0
            self.currentChoices[self.nextRevealIndex]:startFlip()
            self.nextRevealIndex = self.nextRevealIndex + 1
        end
    end
    
    -- Update all card animations
    for _, card in ipairs(self.currentChoices) do
        card:update(dt)
    end
end

function RewardSystem:selectReward(index)
    if not self.isActive then return end
    local card = self.currentChoices[index]
    if card and card.state == "revealed" then
        local reward = card.reward
        --print("Selected reward: " .. reward.name)
        if reward.type == "building" then
            self.game:placeBuilding(reward.building, reward)
        elseif reward.type == "main_upgrade" then
            if self.game.base and self.game.base.mainLazer then
                self.game.base.mainLazer:applyUpgrade(reward)
            end
        else
            error("Invalid reward type: " .. reward.type)
        end
    end    
    self.isActive = false
    self.currentChoices = {}
end

-- function RewardSystem:keypressed(key)
--     if not self.isActive then return end
    
--     if key == "left" or key == "a" then
--         self.selectedIndex = math.max(1, self.selectedIndex - 1)
--     elseif key == "right" or key == "d" then
--         self.selectedIndex = math.min(#self.currentChoices, self.selectedIndex + 1)
--     elseif key == "return" or key == "space" then
--         self:selectReward(self.selectedIndex)
--     end
-- end

function RewardSystem:draw()
    if not self.isActive then return end
    
    -- Draw background overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Choose Your Reward", 0, 165, VIRTUAL_WIDTH, "center")
    --love.graphics.printf("Use A/D or Arrow Keys to select, Enter/Space to confirm", 0, 80, VIRTUAL_WIDTH, "center")
    
    -- Draw reward cards
    for i, card in ipairs(self.currentChoices) do
        local isSelected = (i == self.selectedIndex)
        card:draw(isSelected)
    end

    -- Draw skip button
    local mx, my = love.mouse.getPosition()
    local isSkipHovered = mx >= self.skipBtnX and mx <= self.skipBtnX + self.skipBtnW and
                         my >= self.skipBtnY and my <= self.skipBtnY + self.skipBtnH
    
    if isSkipHovered then
        love.graphics.setColor(0.4, 0.4, 0.4, 1)
    else
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
    end
    love.graphics.rectangle("fill", self.skipBtnX, self.skipBtnY, self.skipBtnW, self.skipBtnH, 10)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", self.skipBtnX, self.skipBtnY, self.skipBtnW, self.skipBtnH, 10)
    if self.game.tokens >= 1 then
        love.graphics.printf("Reroll (-1 Token)", self.skipBtnX, self.skipBtnY + 12, self.skipBtnW, "center")
    else
        love.graphics.setColor(1, 0.4, 0.4, 1)
        love.graphics.printf("Reroll (-1 Token)", self.skipBtnX, self.skipBtnY + 12, self.skipBtnW, "center")
    end

    -- Hand cursor over reward cards / reroll.
    for i = 1, #self.currentChoices do
        local cardX = self.startX + (i - 1) * (self.cardWidth + self.cardSpacing)
        Cursor.hover(cardX, self.startY, self.cardWidth, self.cardHeight)
    end
    Cursor.hover(self.skipBtnX, self.skipBtnY, self.skipBtnW, self.skipBtnH)
end

function RewardSystem:mousepressed(x, y, button)
    if not self.isActive or button ~= 1 then return end
    
    -- Check if click is on a reward card
    for i, card in ipairs(self.currentChoices) do
        local cardX = self.startX + (i - 1) * (self.cardWidth + self.cardSpacing)
        local cardY = self.startY
        
        if x >= cardX and x <= cardX + self.cardWidth and 
           y >= cardY and y <= cardY + self.cardHeight then
            if card.state == "revealed" then
                self:selectReward(i)
            end
            return
        end
    end

    -- Check for skip button
    if x >= self.skipBtnX and x <= self.skipBtnX + self.skipBtnW and
       y >= self.skipBtnY and y <= self.skipBtnY + self.skipBtnH then
        if self.game.tokens >= 1 then
            self.game.tokens = self.game.tokens - 1
            self:activate()
        end
    end
end

return RewardSystem