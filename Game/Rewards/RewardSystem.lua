-- RewardSystem.lua - Main reward system that manages the pool and selection
local Reward = require("Game.Rewards.Reward")
local push = require("Libraries.push")

local RewardSystem = {}
RewardSystem.__index = RewardSystem
local RewardIndex = require("Game.Rewards.NormalRewardIndex")
local TestingIndex = require("Game.Rewards.TestingRewardIndex")
local RewardPool = require("Game.Rewards.RewardPool")
--local Reward = require("Game.Rewards.Reward")

function RewardSystem:new(game)
    local system = setmetatable({
        game = game,
        isActive = false,
        rewardPool = {}, -- current choices being presented
        poolLogic = RewardPool:new(RewardIndex)
    }, self)
    
    system.currentChoices = {}
    system.selectedIndex = 1
    
    -- UI Properties
    system.cardWidth = 200
    system.cardHeight = 180
    system.cardSpacing = 20
    system.startX = 100
    system.startY = 150
    
    -- Initialize the reward pool
    system:initializeRewardPool()
    
    return system
end

function RewardSystem:initializeRewardPool()
    self.rewardPool = {} -- Clear previous
    local luck = self.game.luck or 1
    local choices = self.poolLogic:generateChoices(3, luck)
    
    for _, rewardData in ipairs(choices) do
        table.insert(self.rewardPool, Reward:new(rewardData))
    end
end

function RewardSystem:activate()
    self.isActive = true
    self.selectedIndex = 1
    self:initializeRewardPool()
    self.currentChoices = self.rewardPool
end


function RewardSystem:selectReward(index)
    if not self.isActive then return end
    local reward = self.currentChoices[index]
    if reward then
        --print("Selected reward: " .. reward.name)
        if reward.type == "building" then
            self.game:placeBuilding(reward.building, reward)
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
    love.graphics.rectangle("fill", 0, 0, push:getWidth(), push:getHeight())
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Choose Your Reward", 0, 50, push:getWidth(), "center")
    --love.graphics.printf("Use A/D or Arrow Keys to select, Enter/Space to confirm", 0, 80, push:getWidth(), "center")
    
    -- Draw reward cards
    for i, reward in ipairs(self.currentChoices) do
        local x = self.startX + (i - 1) * (self.cardWidth + self.cardSpacing)
        local y = self.startY
        local isSelected = (i == self.selectedIndex)
        
        reward:draw(x, y, self.cardWidth, self.cardHeight, isSelected)
    end
end

function RewardSystem:mousepressed(x, y, button)
    if not self.isActive or button ~= 1 then return end
    
    -- Check if click is on a reward card
    for i, reward in ipairs(self.currentChoices) do
        local cardX = self.startX + (i - 1) * (self.cardWidth + self.cardSpacing)
        local cardY = self.startY
        
        if x >= cardX and x <= cardX + self.cardWidth and 
           y >= cardY and y <= cardY + self.cardHeight then
            self:selectReward(i)
            break
        end
    end
end

return RewardSystem