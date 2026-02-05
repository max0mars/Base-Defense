-- RewardSystem.lua - Main reward system that manages the pool and selection
local Reward = require("Game.Reward")

local RewardSystem = {}
local Turret = require("Buildings.Turrets.Turret")
local Buff = require("Buildings.Buffs.Buff")
RewardSystem.__index = RewardSystem

function RewardSystem:new(game)
    local system = setmetatable({}, self)
    
    system.game = game
    system.rewardPool = {}
    system.currentChoices = {}
    system.isActive = false
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
    local basicturret = {
        name = "Basic Turret",
        description = "Pew Pew",
        building = Turret:new({game = self.game}),
        rarity = "common",
        type = "building"
    }
    local ammoCache = Reward:new{
        name = "Ammo Cache",
        description = "Increase turret damage by 20%",
        rarity = "common",
        type = "building",
        building = Buff:new({game = self.game})
    }
    table.insert(self.rewardPool, Reward:new(basicturret))
    table.insert(self.rewardPool, ammoCache)
end

function RewardSystem:activate()
    self.isActive = true
    self.selectedIndex = 1
    self:generateChoices()
end

function RewardSystem:generateChoices()
    self.currentChoices = {}
    local poolSize = #self.rewardPool
    
    -- Randomly select 3 unique rewards from the pool
    local selectedIndices = {}
    while #self.currentChoices < 3 do
        local index = love.math.random(1, poolSize)
        selectedIndices[index] = true
        local reward = self.rewardPool[index]
        table.insert(self.currentChoices, reward)
        print("Added reward to choices: " .. reward.name)
    end
end

function RewardSystem:selectReward(index)
    if not self.isActive then return end
    local reward = self.currentChoices[index]
    if reward then
        print("Selected reward: " .. reward.name)
        if reward.type == "building" then
            self.game:placeBuilding(reward.building)
        elseif reward.type == "upgrade" then
            reward:execute(self.game)
            self.game:setState("preparing")
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
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Choose Your Reward", 0, 50, love.graphics.getWidth(), "center")
    --love.graphics.printf("Use A/D or Arrow Keys to select, Enter/Space to confirm", 0, 80, love.graphics.getWidth(), "center")
    
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