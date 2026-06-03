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
local SettingsPanel = require("Game.GUI.SettingsPanel")
local CardDraw = require("Game.Cards.CardDraw")

function preparation_scene:load(isPostBattle)
    love.mouse.setVisible(true)
    self.handCursor = love.mouse.getSystemCursor("hand")
    self.arrowCursor = love.mouse.getSystemCursor("arrow")
    
    _G.PersistentState = _G.PersistentState or {}
    
    if isPostBattle then
        _G.PersistentState.battlesCompleted = (_G.PersistentState.battlesCompleted or 0) + 1
        _G.PersistentState.globalDifficulty = (_G.PersistentState.globalDifficulty or 1) + 1
        
        -- Give 1 XP after each battle, except the first one (where it starts at level 1 with 0 XP)
        if _G.PersistentState.battlesCompleted > 1 then
            self:addShopXP(1)
        end
        
        if _G.PersistentState.battlesCompleted % 3 == 0 then
            local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
            EnemyRegistry:triggerRandomMutation()
        end
    end
    
    local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
    EnemyRegistry:updatePools(_G.PersistentState.globalDifficulty or 1)

    local cx = (VIRTUAL_WIDTH - 240) / 2
    local cy = VIRTUAL_HEIGHT - 60
    
    self.settings = SettingsPanel:new({
        title = "PAUSED",
        bottomButtons = {
            { label = "RESUME", action = "resume",
              color = {0.1, 0.45, 0.25, 1}, hoverColor = {0.18, 0.7, 0.4, 1}, borderColor = {0.3, 0.9, 0.5, 1} },
            { label = "EXIT", action = "exit",
              color = {0.4, 0.18, 0.2, 1}, hoverColor = {0.6, 0.28, 0.3, 1}, borderColor = {0.95, 0.45, 0.45, 1} },
        },
    })
    
    self.startButton = {
        x = cx, y = cy, w = 240, h = 45, label = "START NEXT BATTLE",
        color = {0.1, 0.45, 0.25, 1}, hoverColor = {0.18, 0.7, 0.4, 1}, borderColor = {0.3, 0.9, 0.5, 1}
    }
    
    self.deckButton = {
        x = 20, y = VIRTUAL_HEIGHT - 60, w = 150, h = 45, label = "VIEW DECK",
        color = {0.3, 0.3, 0.4, 1}, hoverColor = {0.4, 0.4, 0.5, 1}, borderColor = {0.6, 0.6, 0.8, 1}
    }
    
    self.rerollButton = {
        x = 20, y = 140, w = 160, h = 40, label = "Reroll Shop (20$)",
        color = {0.4, 0.3, 0.1, 1}, hoverColor = {0.6, 0.45, 0.15, 1}, borderColor = {0.8, 0.6, 0.2, 1}
    }

    self.buyXPButton = {
        x = 200, y = 140, w = 160, h = 40, label = "Buy XP (30$)",
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
        local list, summary = wd:generateWaveList(i, _G.PersistentState.globalDifficulty or 1)
        table.insert(_G.PersistentState.upcomingWaves, list)
        table.insert(_G.PersistentState.upcomingSummaries, summary)
        
        for _, s in ipairs(summary) do
            self.forecast.totals[s.type] = (self.forecast.totals[s.type] or 0) + s.count
        end
    end
end

function preparation_scene:getRequiredXP(level)
    if level < 4 then return 1 end
    if level < 6 then return 2 end
    return 3
end

function preparation_scene:addShopXP(amount)
    if not _G.PersistentState.shopLevel then _G.PersistentState.shopLevel = 1 end
    if not _G.PersistentState.shopXP then _G.PersistentState.shopXP = 0 end
    
    if _G.PersistentState.shopLevel >= 10 then return end
    
    _G.PersistentState.shopXP = _G.PersistentState.shopXP + amount
    local req = self:getRequiredXP(_G.PersistentState.shopLevel)
    
    while _G.PersistentState.shopXP >= req do
        _G.PersistentState.shopXP = _G.PersistentState.shopXP - req
        _G.PersistentState.shopLevel = math.min(10, _G.PersistentState.shopLevel + 1)
        
        if _G.PersistentState.shopLevel >= 10 then
            _G.PersistentState.shopXP = 0
            break
        end
        req = self:getRequiredXP(_G.PersistentState.shopLevel)
    end
end

function preparation_scene:rollShop()
    local shopLevel = _G.PersistentState.shopLevel or 1
    
    -- Mock game for eligibility
    local dummyGame = {
        base = {
            mainLazer = { id = "standard_main", upgrades = {} }
        }
    }
    
    local poolLogic = RewardPool:new(RewardIndex, dummyGame)
    local choices = poolLogic:generateChoices(3, shopLevel)
    
    self.shopItems = {}
    
    local prices = { common = 20, uncommon = 30, rare = 40, epic = 50, legendary = 75 }
    local startX = (VIRTUAL_WIDTH - (3 * 220)) / 2 + 10
    
    for i, choice in ipairs(choices) do
        local isGlobal = choice.type == "main_upgrade"
        local rarity = choice.rarity or "common"
        local itemCost = prices[rarity] or 50
        
        local cardPayload = { rarity = rarity }
        if isGlobal then
            cardPayload.isMainUpgrade = true
        else
            cardPayload.buildingClass = choice.building
            cardPayload.config = {}
        end
        
        cardPayload.rewardCard = CardDraw.new(0, 0, choice)
        
        local card = Card:new({
            id = choice.id,
            name = choice.name,
            description = choice.description,
            executionType = isGlobal and ExecutionType.Targeted or ExecutionType.Placement,
            payload = cardPayload
        })
        
        table.insert(self.shopItems, {
            x = startX + (i-1) * 220,
            y = 220,
            w = 200,
            h = 280,
            card = card,
            cost = itemCost,
            purchased = false
        })
    end
end

function preparation_scene:update(dt)
    if paused == 1 and self.settings then
        self.settings:update(dt)
        return
    end
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
            
            if item.card.payload and item.card.payload.rewardCard then
                item.card.payload.rewardCard:draw(item.x, item.y, item.w, item.h, isHovered)
            end
            
            local afford = (_G.PersistentState.cash or 0) >= item.cost
            love.graphics.setColor(afford and {0.2, 0.8, 0.2, 1} or {0.8, 0.2, 0.2, 1})
            love.graphics.printf("$" .. item.cost, item.x, item.y + item.h + 10, item.w, "center")
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
    
    -- Title removed per request
    

    if _G.PersistentState.deck then
        local cards = _G.PersistentState.deck:getCards()
        
        local cols = 4
        local cardW = 200
        local cardH = 280
        local spacingX = 40
        local spacingY = 20
        local startX = (VIRTUAL_WIDTH - (cols * cardW + (cols - 1) * spacingX)) / 2
        local startY = 65
        
        local mx, my = love.mouse.getPosition()
        
        local maxPerPage = 8
        local totalPages = math.max(1, math.ceil(#cards / maxPerPage))
        self.deckPage = self.deckPage or 1
        if self.deckPage > totalPages then self.deckPage = totalPages end
        if self.deckPage < 1 then self.deckPage = 1 end
        
        local startIndex = (self.deckPage - 1) * maxPerPage + 1
        local endIndex = math.min(self.deckPage * maxPerPage, #cards)
        
        for i = startIndex, endIndex do
            local displayIndex = i - startIndex
            local card = cards[i]
            local col = (displayIndex % cols)
            local row = math.floor(displayIndex / cols)
            
            local cx = startX + col * (cardW + spacingX)
            local cy = startY + row * (cardH + spacingY)
            
            if card.getCardDraw and card:getCardDraw() then
                local isHovered = mx >= cx and mx <= cx + cardW and my >= cy and my <= cy + cardH
                card:getCardDraw():draw(cx, cy, cardW, cardH, isHovered)
                
                -- Draw quantity badge
                if card.quantity and card.quantity > 1 then
                    love.graphics.setColor(0.9, 0.2, 0.2, 1)
                    love.graphics.circle("fill", cx + cardW, cy, 12)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.printf(tostring(card.quantity), cx + cardW - 12, cy - 7, 24, "center")
                end
            else
                -- Fallback if no visual card
                love.graphics.setColor(0.3, 0.3, 0.3, 1)
                love.graphics.rectangle("fill", cx, cy, cardW, cardH, 5)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.printf(card.name, cx, cy + 50, cardW, "center")
            end
        end
        
        self.prevPageBtn = { x = 120, y = VIRTUAL_HEIGHT - 90, w = 120, h = 40, label = "Prev Page" }
        self.nextPageBtn = { x = VIRTUAL_WIDTH - 240, y = VIRTUAL_HEIGHT - 90, w = 120, h = 40, label = "Next Page" }
        
        if self.deckPage > 1 then
            local isHovered = mx >= self.prevPageBtn.x and mx <= self.prevPageBtn.x + self.prevPageBtn.w and my >= self.prevPageBtn.y and my <= self.prevPageBtn.y + self.prevPageBtn.h
            if isHovered then Cursor.wantHand = true end
            love.graphics.setColor(isHovered and {0.4, 0.6, 0.9, 1} or {0.3, 0.5, 0.8, 1})
            love.graphics.rectangle("fill", self.prevPageBtn.x, self.prevPageBtn.y, self.prevPageBtn.w, self.prevPageBtn.h, 5)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(self.prevPageBtn.label, self.prevPageBtn.x, self.prevPageBtn.y + 12, self.prevPageBtn.w, "center")
        end
        
        if self.deckPage < totalPages then
            local isHovered = mx >= self.nextPageBtn.x and mx <= self.nextPageBtn.x + self.nextPageBtn.w and my >= self.nextPageBtn.y and my <= self.nextPageBtn.y + self.nextPageBtn.h
            if isHovered then Cursor.wantHand = true end
            love.graphics.setColor(isHovered and {0.4, 0.6, 0.9, 1} or {0.3, 0.5, 0.8, 1})
            love.graphics.rectangle("fill", self.nextPageBtn.x, self.nextPageBtn.y, self.nextPageBtn.w, self.nextPageBtn.h, 5)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(self.nextPageBtn.label, self.nextPageBtn.x, self.nextPageBtn.y + 12, self.nextPageBtn.w, "center")
        end
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Page " .. self.deckPage .. " / " .. totalPages, 0, VIRTUAL_HEIGHT - 75, VIRTUAL_WIDTH, "center")
    end
    
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.printf("Click anywhere else to close", 100, VIRTUAL_HEIGHT - 45, VIRTUAL_WIDTH - 200, "center")
end

function preparation_scene:draw()
    if paused == 1 and self.settings then
        self.settings:draw()
        return
    end
    
    Cursor.reset()
    local mx, my = love.mouse.getPosition()
    
    love.graphics.setColor(0.1, 0.1, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("PREPARATION PHASE", 0, 20, VIRTUAL_WIDTH, "center")
    
    local hp = _G.PersistentState and _G.PersistentState.baseHP or 200
    local cash = _G.PersistentState and _G.PersistentState.cash or 0
    local shopLevel = _G.PersistentState and _G.PersistentState.shopLevel or 1
    local shopXP = _G.PersistentState and _G.PersistentState.shopXP or 0
    
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.printf("Base HP: " .. hp .. " / 200", 20, 20, 200, "left")
    
    love.graphics.setColor(0.2, 0.8, 0.2, 1)
    love.graphics.printf("Cash: $" .. cash, 20, 45, 200, "left")
    
    love.graphics.setColor(0.8, 0.2, 0.8, 1)
    love.graphics.printf("Shop Level: " .. shopLevel, 20, 70, 200, "left")
    
    -- Draw XP circles
    if shopLevel < 10 then
        local reqXP = self:getRequiredXP(shopLevel)
        local startX = 20
        local cy = 95
        local radius = 6
        local spacing = 18
        
        for i = 1, reqXP do
            local drawX = startX + (i - 1) * spacing
            if i <= shopXP then
                love.graphics.setColor(0.8, 0.2, 0.8, 1)
                love.graphics.circle("fill", drawX, cy, radius)
            else
                love.graphics.setColor(0.8, 0.2, 0.8, 1)
                love.graphics.circle("line", drawX, cy, radius)
                love.graphics.setColor(0.2, 0.05, 0.2, 1)
                love.graphics.circle("fill", drawX, cy, radius - 1)
            end
        end
    else
        love.graphics.setColor(0.8, 0.2, 0.8, 1)
        love.graphics.printf("MAX LEVEL", 20, 90, 200, "left")
    end
    
    self:drawForecast()
    self:drawShop(mx, my)
    
    self:drawButton(self.rerollButton, mx, my)
    self:drawButton(self.buyXPButton, mx, my)
    
    self:drawButton(self.startButton, mx, my)
    self:drawButton(self.deckButton, mx, my)
    
    if self.viewingDeck then
        self:drawDeck()
        Cursor.wantHand = true
    end

    love.mouse.setCursor(Cursor.wantHand and self.handCursor or self.arrowCursor)
end

function preparation_scene:mousepressed(x, y, button)
    if paused == 1 and self.settings then
        local action = self.settings:mousepressed(x, y, button)
        if action == "resume" then
            paused = 0
        elseif action == "exit" then
            paused = 0
            self.scene_manager.switch("menu")
        end
        return
    end
    
    if button ~= 1 then return end
    
    if self.viewingDeck then
        if self.deckPage and self.deckPage > 1 and self.prevPageBtn then
            local btn = self.prevPageBtn
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                self.deckPage = self.deckPage - 1
                return
            end
        end
        
        if self.deckPage and self.nextPageBtn then
            local cards = _G.PersistentState.deck and _G.PersistentState.deck:getCards() or {}
            local totalPages = math.max(1, math.ceil(#cards / 8))
            if self.deckPage < totalPages then
                local btn = self.nextPageBtn
                if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                    self.deckPage = self.deckPage + 1
                    return
                end
            end
        end
        
        self.viewingDeck = false
        self.deckPage = 1
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
    

    btn = self.buyXPButton
    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        if (_G.PersistentState.cash or 0) >= 30 and (_G.PersistentState.shopLevel or 1) < 10 then
            _G.PersistentState.cash = _G.PersistentState.cash - 30
            self:addShopXP(1)
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

function preparation_scene:mousereleased(x, y, button)
    if paused == 1 and self.settings then
        self.settings:mousereleased(x, y, button)
    end
end

function preparation_scene:keypressed(key)
    if key == "escape" or key == "p" then
        paused = paused == 1 and 0 or 1
        return
    end

    if key == "return" and not self.viewingDeck then
        self.scene_manager.switch("game")
    end
end

return preparation_scene
