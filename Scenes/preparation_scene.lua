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

function preparation_scene:load(isPostBattle)
    love.mouse.setVisible(true)
    self.handCursor = love.mouse.getSystemCursor("hand")
    self.arrowCursor = love.mouse.getSystemCursor("arrow")
    
    _G.PersistentState = _G.PersistentState or {}
    
    if isPostBattle then
        _G.PersistentState.battlesCompleted = (_G.PersistentState.battlesCompleted or 0) + 1
        _G.PersistentState.globalDifficulty = (_G.PersistentState.globalDifficulty or 1) + 1
        
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
        x = 20, y = 140, w = 160, h = 40, label = "Reroll Shop (-20$)",
        color = {0.4, 0.3, 0.1, 1}, hoverColor = {0.6, 0.45, 0.15, 1}, borderColor = {0.8, 0.6, 0.2, 1}
    }

    self.buyLuckButton = {
        x = 200, y = 140, w = 160, h = 40, label = "Buy Luck (-50$)",
        color = {0.5, 0.1, 0.5, 1}, hoverColor = {0.7, 0.2, 0.7, 1}, borderColor = {0.9, 0.3, 0.9, 1}
    }

    self.upgradeTokensButton = {
        x = 20, y = 185, w = 210, h = 30, label = "",
        color = {0.2, 0.4, 0.6, 1}, hoverColor = {0.3, 0.5, 0.7, 1}, borderColor = {0.4, 0.6, 0.8, 1}
    }
    
    self.upgradeHandButton = {
        x = 240, y = 185, w = 210, h = 30, label = "",
        color = {0.2, 0.4, 0.6, 1}, hoverColor = {0.3, 0.5, 0.7, 1}, borderColor = {0.4, 0.6, 0.8, 1}
    }
    
    self.upgradeIncomeButton = {
        x = 460, y = 185, w = 210, h = 30, label = "",
        color = {0.2, 0.4, 0.6, 1}, hoverColor = {0.3, 0.5, 0.7, 1}, borderColor = {0.4, 0.6, 0.8, 1}
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
            h = 250,
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

function preparation_scene:drawUpgrades(mx, my)
    local state = _G.PersistentState
    
    self.upgradeTokensButton.label = string.format("Tokens: %d (+1: $%d)", state.startingTokens or 3, state.upgradeCostTokens or 20)
    
    local hSize = state.startingHandSize or 3
    if hSize >= 8 then
        self.upgradeHandButton.label = string.format("Hand: %d (MAX)", hSize)
    else
        self.upgradeHandButton.label = string.format("Hand: %d (+1: $%d)", hSize, state.upgradeCostHand or 20)
    end
    
    self.upgradeIncomeButton.label = string.format("Income: %d (+1: $%d)", state.incomeTokens or 3, state.upgradeCostIncome or 20)
    
    self:drawButton(self.upgradeTokensButton, mx, my)
    self:drawButton(self.upgradeHandButton, mx, my)
    self:drawButton(self.upgradeIncomeButton, mx, my)
end

function preparation_scene:drawShop(mx, my)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("SHOP", 0, 100, VIRTUAL_WIDTH, "center")
    
    for _, item in ipairs(self.shopItems) do
        if not item.purchased then
            local isHovered = mx >= item.x and mx <= item.x + item.w and my >= item.y and my <= item.y + item.h
            if isHovered then Cursor.wantHand = true end
            
            local rcolors = {
                common = {0.5, 0.5, 0.5},
                uncommon = {0.2, 0.8, 0.2},
                rare = {0.2, 0.5, 1.0},
                epic = {0.7, 0.3, 0.9},
                legendary = {1.0, 0.7, 0.1}
            }
            local rarity = item.card.payload and item.card.payload.rarity or "common"
            local rCol = rcolors[rarity] or rcolors.common
            
            love.graphics.setColor(rCol[1]*0.15, rCol[2]*0.15, rCol[3]*0.15, 1)
            love.graphics.rectangle("fill", item.x, item.y, item.w, item.h, 10)
            
            if isHovered then
                love.graphics.setColor(math.min(1, rCol[1]*1.2), math.min(1, rCol[2]*1.2), math.min(1, rCol[3]*1.2), 1)
            else
                love.graphics.setColor(rCol[1]*0.8, rCol[2]*0.8, rCol[3]*0.8, 1)
            end
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
            local rcolors = {
                common = {0.7, 0.7, 0.7},
                uncommon = {0.3, 0.9, 0.3},
                rare = {0.3, 0.6, 1.0},
                epic = {0.8, 0.4, 1.0},
                legendary = {1.0, 0.8, 0.2}
            }
            local rarity = card.payload and card.payload.rarity or "common"
            local rCol = rcolors[rarity] or rcolors.common
            love.graphics.setColor(rCol[1], rCol[2], rCol[3], 1)
            local typeLabel = (card.executionType == ExecutionType.Placement) and "Building" or "Instant"
            love.graphics.printf(card.quantity .. "x " .. card.name .. " (" .. typeLabel .. ")", 120, yOff, VIRTUAL_WIDTH - 240, "left")
            yOff = yOff + 25
        end
    end
    
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.printf("Click anywhere to close", 100, VIRTUAL_HEIGHT - 80, VIRTUAL_WIDTH - 200, "center")
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
    local luck = _G.PersistentState and _G.PersistentState.luck or 1
    
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.printf("Base HP: " .. hp .. " / 200", 20, 20, 200, "left")
    
    love.graphics.setColor(0.2, 0.8, 0.2, 1)
    love.graphics.printf("Cash: $" .. cash, 20, 45, 200, "left")
    
    love.graphics.setColor(0.8, 0.2, 0.8, 1)
    love.graphics.printf("Luck: " .. luck, 20, 70, 200, "left")
    
    self:drawForecast()
    self:drawShop(mx, my)
    
    self:drawButton(self.rerollButton, mx, my)
    self:drawButton(self.buyLuckButton, mx, my)
    self:drawUpgrades(mx, my)
    
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
    
    local state = _G.PersistentState
    
    btn = self.upgradeTokensButton
    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        if (state.cash or 0) >= (state.upgradeCostTokens or 20) then
            state.cash = state.cash - (state.upgradeCostTokens or 20)
            state.startingTokens = (state.startingTokens or 3) + 1
            state.upgradeCostTokens = (state.upgradeCostTokens or 20) + 20
        end
        return
    end

    btn = self.upgradeHandButton
    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        if (state.startingHandSize or 3) < 8 and (state.cash or 0) >= (state.upgradeCostHand or 20) then
            state.cash = state.cash - (state.upgradeCostHand or 20)
            state.startingHandSize = (state.startingHandSize or 3) + 1
            state.upgradeCostHand = (state.upgradeCostHand or 20) + 20
        end
        return
    end

    btn = self.upgradeIncomeButton
    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        if (state.cash or 0) >= (state.upgradeCostIncome or 20) then
            state.cash = state.cash - (state.upgradeCostIncome or 20)
            state.incomeTokens = (state.incomeTokens or 3) + 1
            state.upgradeCostIncome = (state.upgradeCostIncome or 20) + 20
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
