local preparation_scene = {}
preparation_scene.__index = preparation_scene
local scene = require("Scenes.scene")
setmetatable(preparation_scene, { __index = scene })

local Cursor = require("Game.GUI.Cursor")
local WaveDirector = require("Game.Spawning.WaveDirector")
local RewardPool = require("Game.Rewards.RewardPool")
local RewardIndex = require("Game.Rewards.NormalRewardIndex")
local Card = require("Game.Cards.Card")
local ExecutionType = require("Game.Cards.ExecutionType")
local PlayerDeck = require("Game.Cards.PlayerDeck")

function preparation_scene:load()
    love.mouse.setVisible(true)
    self.handCursor = love.mouse.getSystemCursor("hand")
    self.arrowCursor = love.mouse.getSystemCursor("arrow")
    
    local cx = (VIRTUAL_WIDTH - 240) / 2
    local cy = VIRTUAL_HEIGHT - 60
    
    self.startButton = {
        x = cx, y = cy, w = 240, h = 45, label = "START NEXT BATTLE",
        color = {0.1, 0.45, 0.25, 1}, hoverColor = {0.18, 0.7, 0.4, 1}, borderColor = {0.3, 0.9, 0.5, 1}
    }
    
    self.deckButton = {
        x = 20, y = VIRTUAL_HEIGHT - 60, w = 150, h = 45, label = "VIEW DECK",
        color = {0.3, 0.3, 0.4, 1}, hoverColor = {0.4, 0.4, 0.5, 1}, borderColor = {0.6, 0.6, 0.8, 1}
    }
    
    self.rerollButton = {
        x = 20, y = 140, w = 160, h = 40, label = "Reroll Shop (-20$)",
        color = {0.4, 0.3, 0.1, 1}, hoverColor = {0.6, 0.45, 0.15, 1}, borderColor = {0.8, 0.6, 0.2, 1}
    }

    self.buyLuckButton = {
        x = 200, y = 140, w = 160, h = 40, label = "Buy Luck (-50$)",
        color = {0.5, 0.1, 0.5, 1}, hoverColor = {0.7, 0.2, 0.7, 1}, borderColor = {0.9, 0.3, 0.9, 1}
    }

    self.viewingDeck = false

    self:precalculateWaves()
    self:rollShop()
end

function preparation_scene:precalculateWaves()
    -- Create dummy game for WaveDirector
    local dummyGame = {}
    local wd = WaveDirector:new(dummyGame)
    
    _G.PersistentState = _G.PersistentState or {}
    _G.PersistentState.upcomingWaves = {}
    _G.PersistentState.upcomingSummaries = {}
    
    self.forecast = {
        low = 0,
        medium = 0,
        high = 0,
        totals = {}
    }
    
    -- Always calculate waves 1 through 5 for the battle
    for i = 1, 5 do
        local list, summary = wd:generateWaveList(i)
        table.insert(_G.PersistentState.upcomingWaves, list)
        table.insert(_G.PersistentState.upcomingSummaries, summary)
        
        for _, s in ipairs(summary) do
            self.forecast.totals[s.type] = (self.forecast.totals[s.type] or 0) + s.count
        end
    end
end

function preparation_scene:rollShop()
    local luck = _G.PersistentState.luck or 1
    
    -- Mock game for eligibility
    local dummyGame = {
        base = {
            mainLazer = { id = "standard_main", upgrades = {} }
        }
    }
    
    local poolLogic = RewardPool:new(RewardIndex, dummyGame)
    local choices = poolLogic:generateChoices(3, luck)
    
    self.shopItems = {}
    
    local startX = (VIRTUAL_WIDTH - (3 * 220)) / 2 + 10
    
    for i, choice in ipairs(choices) do
        local isGlobal = choice.type == "main_upgrade"
        
        local cardPayload = { rarity = choice.rarity or "common" }
        if isGlobal then
            cardPayload.effect = { name = choice.name, isGlobalUpgrade = true } -- placeholder effect
        else
            cardPayload.buildingClass = choice.building
            cardPayload.config = {}
        end
        
        local card = Card:new({
            id = choice.id,
            name = choice.name,
            description = choice.description,
            executionType = isGlobal and ExecutionType.Global or ExecutionType.Placement,
            payload = cardPayload
        })
        
        table.insert(self.shopItems, {
            x = startX + (i-1) * 220,
            y = 220,
            w = 200,
            h = 250,
            card = card,
            cost = 50,
            purchased = false
        })
    end
end

function preparation_scene:update(dt)
end

function preparation_scene:drawButton(btn, mx, my)
    local isHovered = mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h
    if isHovered then Cursor.wantHand = true end
    
    love.graphics.setColor(isHovered and btn.hoverColor or btn.color)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 6, 6)
    
    love.graphics.setColor(btn.borderColor)
    love.graphics.setLineWidth(isHovered and 2 or 1)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 6, 6)
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.printf(btn.label, btn.x + 1, btn.y + btn.h / 2 - 6, btn.w, "center")
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(btn.label, btn.x, btn.y + btn.h / 2 - 7, btn.w, "center")
end

function preparation_scene:drawShop(mx, my)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("SHOP", 0, 100, VIRTUAL_WIDTH, "center")
    
    for _, item in ipairs(self.shopItems) do
        if not item.purchased then
            local isHovered = mx >= item.x and mx <= item.x + item.w and my >= item.y and my <= item.y + item.h
            if isHovered then Cursor.wantHand = true end
            
            love.graphics.setColor(0.15, 0.15, 0.2, 1)
            love.graphics.rectangle("fill", item.x, item.y, item.w, item.h, 10)
            
            love.graphics.setColor(isHovered and {0.8, 0.8, 1, 1} or {0.5, 0.5, 0.6, 1})
            love.graphics.rectangle("line", item.x, item.y, item.w, item.h, 10)
            
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(item.card.name, item.x, item.y + 20, item.w, "center")
            
            love.graphics.setColor(0.7, 0.7, 0.7, 1)
            love.graphics.printf(item.card.description, item.x + 10, item.y + 60, item.w - 20, "left")
            
            local afford = (_G.PersistentState.cash or 0) >= item.cost
            love.graphics.setColor(afford and {0.2, 0.8, 0.2, 1} or {0.8, 0.2, 0.2, 1})
            love.graphics.printf("$" .. item.cost, item.x, item.y + item.h - 30, item.w, "center")
        end
    end
end

function preparation_scene:drawForecast()
    local fw = 200
    local fh = 200
    local fx = VIRTUAL_WIDTH - fw - 20
    local fy = 20
    
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", fx, fy, fw, fh, 5)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.rectangle("line", fx, fy, fw, fh, 5)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("FORECAST", fx, fy + 10, fw, "center")
    
    local yOff = 40
    for typeName, count in pairs(self.forecast.totals) do
        local tier = "Low"
        if count >= 15 then tier = "High"
        elseif count >= 5 then tier = "Medium" end
        
        love.graphics.printf(typeName .. ": " .. tier, fx + 10, fy + yOff, fw - 20, "left")
        yOff = yOff + 20
    end
end

function preparation_scene:drawDeck()
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 100, 50, VIRTUAL_WIDTH - 200, VIRTUAL_HEIGHT - 100, 10)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", 100, 50, VIRTUAL_WIDTH - 200, VIRTUAL_HEIGHT - 100, 10)
    
    love.graphics.printf("YOUR DECK", 100, 70, VIRTUAL_WIDTH - 200, "center")
    
    if _G.PersistentState.deck then
        local cards = _G.PersistentState.deck:getCards()
        local yOff = 120
        for i, card in ipairs(cards) do
            love.graphics.printf(card.quantity .. "x " .. card.name .. " (" .. (card.executionType == ExecutionType.Global and "Global" or "Placement") .. ")", 120, yOff, VIRTUAL_WIDTH - 240, "left")
            yOff = yOff + 25
        end
    end
    
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.printf("Click anywhere to close", 100, VIRTUAL_HEIGHT - 80, VIRTUAL_WIDTH - 200, "center")
end

function preparation_scene:draw()
    Cursor.reset()
    local mx, my = love.mouse.getPosition()
    
    love.graphics.setColor(0.1, 0.1, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("PREPARATION PHASE", 0, 20, VIRTUAL_WIDTH, "center")
    
    local hp = _G.PersistentState and _G.PersistentState.baseHP or 100
    local cash = _G.PersistentState and _G.PersistentState.cash or 0
    local luck = _G.PersistentState and _G.PersistentState.luck or 1
    
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.printf("Base HP: " .. hp .. " / 100", 20, 20, 200, "left")
    
    love.graphics.setColor(0.2, 0.8, 0.2, 1)
    love.graphics.printf("Cash: $" .. cash, 20, 45, 200, "left")
    
    love.graphics.setColor(0.8, 0.2, 0.8, 1)
    love.graphics.printf("Luck: " .. luck, 20, 70, 200, "left")
    
    self:drawForecast()
    self:drawShop(mx, my)
    
    self:drawButton(self.rerollButton, mx, my)
    self:drawButton(self.buyLuckButton, mx, my)
    self:drawButton(self.startButton, mx, my)
    self:drawButton(self.deckButton, mx, my)
    
    if self.viewingDeck then
        self:drawDeck()
        Cursor.wantHand = true
    end

    love.mouse.setCursor(Cursor.wantHand and self.handCursor or self.arrowCursor)
end

function preparation_scene:mousepressed(x, y, button)
    if button ~= 1 then return end
    
    if self.viewingDeck then
        self.viewingDeck = false
        return
    end
    
    local btn = self.startButton
    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        self.scene_manager.switch("game")
        return
    end
    
    btn = self.deckButton
    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        self.viewingDeck = true
        return
    end
    
    btn = self.rerollButton
    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        if (_G.PersistentState.cash or 0) >= 20 then
            _G.PersistentState.cash = _G.PersistentState.cash - 20
            self:rollShop()
        end
        return
    end
    
    btn = self.buyLuckButton
    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        if (_G.PersistentState.cash or 0) >= 50 then
            _G.PersistentState.cash = _G.PersistentState.cash - 50
            _G.PersistentState.luck = (_G.PersistentState.luck or 1) + 1
        end
        return
    end
    
    for _, item in ipairs(self.shopItems) do
        if not item.purchased and x >= item.x and x <= item.x + item.w and y >= item.y and y <= item.y + item.h then
            if (_G.PersistentState.cash or 0) >= item.cost then
                _G.PersistentState.cash = _G.PersistentState.cash - item.cost
                item.purchased = true
                
                local qty = math.random(1, 3)
                item.card.quantity = qty
                _G.PersistentState.deck:addCard(item.card)
            end
        end
    end
end

function preparation_scene:keypressed(key)
    if key == "return" and not self.viewingDeck then
        self.scene_manager.switch("game")
    end
end

return preparation_scene
