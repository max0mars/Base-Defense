local HandUI = {}
HandUI.__index = HandUI

local ExecutionType = require("Game.Cards.ExecutionType")
local Cursor = require("Game.GUI.Cursor")

function HandUI:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    return obj
end

function HandUI:update(dt)
end

function HandUI:draw()
    if not self.game.hand then return end
    
    local numCards = self.game.hand and #self.game.hand or 0
    
    local cardWidth = 100
    local cardHeight = 140
    
    local inventoryStartX = 320
    local inventoryMaxWidth = 740
    
    local deckX = inventoryStartX
    local deckY = VIRTUAL_HEIGHT - cardHeight - 20
    
    local handStartX = deckX + cardWidth + 20
    local maxHandWidth = inventoryMaxWidth - cardWidth - 20
    
    local spacing = 10
    if numCards > 1 then
        local requiredWidth = numCards * cardWidth + (numCards - 1) * spacing
        if requiredWidth > maxHandWidth then
            spacing = (maxHandWidth - numCards * cardWidth) / (numCards - 1)
        end
    end
    
    local mx, my = love.mouse.getPosition()
    
    -- Draw Deck Card
    local hoverDeck = mx >= deckX and mx <= deckX + cardWidth and my >= deckY and my <= deckY + cardHeight
    if hoverDeck then Cursor.wantHand = true end
    
    love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
    love.graphics.rectangle("fill", deckX, deckY, cardWidth, cardHeight, 5)
    
    love.graphics.setColor(hoverDeck and {0.8, 0.8, 1, 1} or {0.4, 0.4, 0.5, 1})
    love.graphics.setLineWidth(hoverDeck and 2 or 1)
    love.graphics.rectangle("line", deckX, deckY, cardWidth, cardHeight, 5)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("DRAW\nPILE", deckX + 5, deckY + 40, cardWidth - 10, "center")
    
    local drawCost = self.game.drawCost or 1
    local canAffordDraw = (self.game.tokens or 0) >= drawCost
    love.graphics.setColor(canAffordDraw and {0.2, 0.8, 0.2, 1} or {0.8, 0.2, 0.2, 1})
    love.graphics.printf(drawCost .. " Tk", deckX, deckY + cardHeight - 40, cardWidth, "center")
    
    if self.game.drawPile then
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.printf(#self.game.drawPile .. " Left", deckX, deckY + cardHeight - 20, cardWidth, "center")
    end
    
    for i, card in ipairs(self.game.hand) do
        local cx = handStartX + (i - 1) * (cardWidth + spacing)
        local cy = deckY
        local cost = card:getCost()
        
        -- Highlight active card
        if self.game.activeCard == card then
            cy = cy - 20 -- Pop up
        end
        
        local isHovered = mx >= cx and mx <= cx + cardWidth and my >= cy and my <= cy + cardHeight
        if isHovered then Cursor.wantHand = true end
        
        local rcolors = {
            common = {0.5, 0.5, 0.5},
            uncommon = {0.2, 0.8, 0.2},
            rare = {0.2, 0.5, 1.0},
            epic = {0.7, 0.3, 0.9},
            legendary = {1.0, 0.7, 0.1}
        }
        local rarity = card.payload and card.payload.rarity or card.rarity or "common"
        local rCol = rcolors[rarity:lower()] or rcolors.common
        
        -- Draw Card Background
        love.graphics.setColor(rCol[1]*0.2, rCol[2]*0.2, rCol[3]*0.2, 0.95)
        love.graphics.rectangle("fill", cx, cy, cardWidth, cardHeight, 5)
        
        -- Border
        if self.game.activeCard == card then
            love.graphics.setColor(1, 1, 1, 1) -- White for active
            love.graphics.setLineWidth(3)
        elseif isHovered then
            love.graphics.setColor(rCol[1]*1.2, rCol[2]*1.2, rCol[3]*1.2, 1)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(rCol[1]*0.8, rCol[2]*0.8, rCol[3]*0.8, 1)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", cx, cy, cardWidth, cardHeight, 5)
        love.graphics.setLineWidth(1)
        
        -- Text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(card.name, cx + 5, cy + 10, cardWidth - 10, "center")
        
        -- Type
        local typeStr = "Place"
        if card.executionType == ExecutionType.Global or card.executionType == "Global" then typeStr = "Global"
        elseif card.executionType == ExecutionType.Targeted or card.executionType == "Targeted" then typeStr = "Target" end
        
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.printf(typeStr, cx + 5, cy + 40, cardWidth - 10, "center")
        
        -- Cost
        local canAfford = self.game.tokens >= cost
        if canAfford then
            love.graphics.setColor(0.2, 0.8, 0.2, 1)
        else
            love.graphics.setColor(0.8, 0.2, 0.2, 1)
        end
        love.graphics.printf(cost .. " Tk", cx, cy + cardHeight - 20, cardWidth, "center")
    end
end

function HandUI:mousepressed(x, y, button)
    if button ~= 1 then return false end
    if not self.game.hand then return false end
    
    local numCards = self.game.hand and #self.game.hand or 0
    
    local cardWidth = 100
    local cardHeight = 140
    
    local inventoryStartX = 320
    local inventoryMaxWidth = 740
    
    local deckX = inventoryStartX
    local deckY = VIRTUAL_HEIGHT - cardHeight - 20
    
    local handStartX = deckX + cardWidth + 20
    local maxHandWidth = inventoryMaxWidth - cardWidth - 20
    
    local spacing = 10
    if numCards > 1 then
        local requiredWidth = numCards * cardWidth + (numCards - 1) * spacing
        if requiredWidth > maxHandWidth then
            spacing = (maxHandWidth - numCards * cardWidth) / (numCards - 1)
        end
    end
    
    -- Check Draw Deck Card
    if x >= deckX and x <= deckX + cardWidth and y >= deckY and y <= deckY + cardHeight then
        local cost = self.game.drawCost or 1
        if self.game.tokens >= cost then
            local drawn = self.game:drawCard(1)
            if drawn > 0 then
                self.game.tokens = self.game.tokens - cost
                self.game.drawCost = cost + 1
            end
        else
            self.game:spawnFloatingText("Not enough tokens!", x, y, {0.8, 0.2, 0.2, 1})
        end
        return true
    end
    
    for i, card in ipairs(self.game.hand) do
        local cx = handStartX + (i - 1) * (cardWidth + spacing)
        local cy = deckY
        if self.game.activeCard == card then
            cy = cy - 20
        end
        
        if x >= cx and x <= cx + cardWidth and y >= cy and y <= cy + cardHeight then
            -- Clicked a card
            if self.game.activeCard == card then
                -- Clicked the already active card -> cancel it
                self.game:refundCard(card)
                if self.game.blueprint then
                    self.game.blueprint = nil
                end
                return true
            end
            
            -- If we already have a different active card, refund it first
            if self.game.activeCard then
                self.game:refundCard(self.game.activeCard)
                if self.game.blueprint then
                    self.game.blueprint = nil
                end
            end
            
            local cost = card:getCost()
            if self.game.tokens >= cost then
                self.game.tokens = self.game.tokens - cost
                self.game.activeCard = card
                
                if card.executionType == ExecutionType.Global or card.executionType == "Global" then
                    card:execute(self.game)
                    self.game:consumeCard(card)
                elseif card.executionType == ExecutionType.Placement then
                    self.game.inputMode = "placing"
                    local config = {}
                    if card.payload.config then
                        for k, v in pairs(card.payload.config) do
                            config[k] = v
                        end
                    end
                    config.game = self.game
                    self.game.blueprint = card.payload.buildingClass:new(config)
                    self.game.blueprint.showArc = true
                elseif card.executionType == ExecutionType.Targeted or card.executionType == "Targeted" then
                    self.game.inputMode = "targeting_card"
                end
            else
                self.game:spawnFloatingText("Not enough tokens!", x, y, {0.8, 0.2, 0.2, 1})
            end
            
            return true
        end
    end
    
    return false
end

return HandUI
