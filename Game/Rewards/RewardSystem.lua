-- RewardSystem.lua - Main reward system that manages the pool and selection
local Reward = require("Game.Rewards.Reward")

local RewardSystem = {}
RewardSystem.__index = RewardSystem
local RewardIndex = require("Game.Rewards.RewardIndex")
local Cursor = require("Game.GUI.Cursor")
local TestingIndex = require("Game.Rewards.TestingRewardIndex")
local RewardPool = require("Game.Rewards.RewardPool")
local CardReveal = require("Graphics.Animations.CardReveal")
local CardFactory = require("Game.Cards.CardFactory")
local Neon = require("Game.GUI.Neon")

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
    system.cardHeight = 280
    system.cardSpacing = 24
    system.startX = 100
    system.startY = 220       -- centered nicely for the 720-tall canvas

    system.skipBtnW = 160
    system.skipBtnH = 40
    system.skipBtnX = VIRTUAL_WIDTH / 2 - system.skipBtnW / 2
    system.skipBtnY = 535
    
    -- Initialize the reward pool
    system:initializeRewardPool()
    
    return system
end

function RewardSystem:initializeRewardPool(poolLogicMode, numCards)
    self.mode = poolLogicMode
    self.rewardPool = {} -- Clear previous
    self.revealTimer = 0
    self.nextRevealIndex = 1
    
    local count = numCards or 3
    local isSpecial = false
    local specialInterval = self.game.specialWaveInterval or 5
    if self.game.wave and (self.game.wave % specialInterval == 0) then
        isSpecial = true
    end
    
    local indexToUse = RewardIndex

    
    self.poolLogic = RewardPool:new(indexToUse, self.game)
    -- Rarity scales with the current battle level (the merchant's level only affects his stock)
    local weights = RewardPool.getCardDraftRarityWeights(self:getBattleLevel())
    local choices = self.poolLogic:generateChoicesWithWeights(count, weights)
    
    local totalWidth = (count * self.cardWidth) + ((count - 1) * self.cardSpacing)
    local startX = (VIRTUAL_WIDTH - totalWidth) / 2
    self.startX = startX
    
    for i, rewardData in ipairs(choices) do
        rewardData.game = self.game
        local rewardObj = Reward:new(rewardData)
        if self.mode == "cards" then
            -- Show the exact card the player will receive (correct type art and cost)
            rewardObj.deckCard = CardFactory.fromReward(rewardObj, rewardObj.rawConfig)
            rewardObj.rewardCard = rewardObj.deckCard:getCardDraw()
        end
        local x =self.startX + (i - 1) * (self.cardWidth + self.cardSpacing)
        local y = self.startY
        
        local card = CardReveal:new(rewardObj, x, y, self.cardWidth, self.cardHeight)
        table.insert(self.rewardPool, card)
    end
end

--- Current battle level: the selected battle's level, else battles completed + 1.
function RewardSystem:getBattleLevel()
    local state = _G.PersistentState
    if state and state.selectedBattle and state.selectedBattle.playerLevel then
        return state.selectedBattle.playerLevel
    end
    return ((state and state.battlesCompleted) or 0) + 1
end

function RewardSystem:close()
    self.isActive = false
    self.currentChoices = {}
    self.mode = nil
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
        if self.mode == "cards" then
            local cardObj = reward.deckCard or CardFactory.fromReward(reward, reward.rawConfig or reward)

            if _G.PersistentState and _G.PersistentState.deck and cardObj then
                _G.PersistentState.deck:addCard(cardObj)
            end
        elseif reward.type == "building" then
            self.game:placeBuilding(reward.building, reward)
        elseif reward.type == "main_upgrade" then
            if self.game.base and self.game.base.mainLazer then
                self.game.base.mainLazer:applyUpgrade(reward)
            end
        else
            error("Invalid reward type: " .. reward.type)
        end
    end
    self:close()
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
    if self.mode == "cards" then
        Neon.title("Choose One", 0, 140, VIRTUAL_WIDTH, "center", Neon.hot(Neon.CYAN, 0.35), 2.5)
    else
        love.graphics.printf("Choose Your Reward", 0, 160, VIRTUAL_WIDTH, "center")
    end
    --love.graphics.printf("Use A/D or Arrow Keys to select, Enter/Space to confirm", 0, 80, VIRTUAL_WIDTH, "center")
    
    -- Draw reward cards
    local mx, my = love.mouse.getPosition()
    for i, card in ipairs(self.currentChoices) do
        local cardX = self.startX + (i - 1) * (self.cardWidth + self.cardSpacing)
        local cardY = self.startY
        local isHovered = (mx >= cardX and mx <= cardX + self.cardWidth and my >= cardY and my <= cardY + self.cardHeight)
        card:draw(isHovered) -- only the hovered card is highlighted
    end

    -- Draw skip button (card draft) or reroll button (standard mid-battle upgrade mode)
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
    if self.mode == "cards" then
        love.graphics.printf("Skip", self.skipBtnX, self.skipBtnY + 12, self.skipBtnW, "center")
    else
        if self.game.tokens >= 1 then
            love.graphics.printf("Reroll (-1 Token)", self.skipBtnX, self.skipBtnY + 12, self.skipBtnW, "center")
        else
            love.graphics.setColor(1, 0.4, 0.4, 1)
            love.graphics.printf("Reroll (-1 Token)", self.skipBtnX, self.skipBtnY + 12, self.skipBtnW, "center")
        end
    end

    -- Add-to-deck cursor over "Choose One" cards (select-card for other rewards),
    -- hand over skip / reroll.
    local pickIcon = (self.mode == "cards") and "addCard" or "selectCard"
    for i = 1, #self.currentChoices do
        local cardX = self.startX + (i - 1) * (self.cardWidth + self.cardSpacing)
        Cursor.hover(cardX, self.startY, self.cardWidth, self.cardHeight, pickIcon)
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

    -- Check for skip (card draft) / reroll button
    if x >= self.skipBtnX and x <= self.skipBtnX + self.skipBtnW and
       y >= self.skipBtnY and y <= self.skipBtnY + self.skipBtnH then
        if self.mode == "cards" then
            self:close()
        elseif self.game.tokens >= 1 then
            self.game.tokens = self.game.tokens - 1
            self:activate()
        end
    end
end

return RewardSystem
