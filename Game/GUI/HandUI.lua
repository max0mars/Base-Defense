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
    
    local numCards = #self.game.hand
    if numCards == 0 then return end
    
    local cardWidth = 100
    local cardHeight = 140
    local spacing = 10
    local totalWidth = (numCards * cardWidth) + ((numCards - 1) * spacing)
    local startX = (VIRTUAL_WIDTH - totalWidth) / 2
    local startY = VIRTUAL_HEIGHT - cardHeight - 20
    
    local mx, my = love.mouse.getPosition()
    
    for i, card in ipairs(self.game.hand) do
        local cx = startX + (i - 1) * (cardWidth + spacing)
        local cy = startY
        local cost = card:getCost()
        
        -- Highlight active card
        if self.game.activeCard == card then
            cy = cy - 20 -- Pop up
        end
        
        local isHovered = mx >= cx and mx <= cx + cardWidth and my >= cy and my <= cy + cardHeight
        if isHovered then Cursor.wantHand = true end
        
        -- Draw Card Background
        love.graphics.setColor(0.15, 0.15, 0.2, 0.9)
        love.graphics.rectangle("fill", cx, cy, cardWidth, cardHeight, 5)
        
        -- Border
        if self.game.activeCard == card then
            love.graphics.setColor(1, 0.8, 0.2, 1) -- Gold for active
            love.graphics.setLineWidth(3)
        elseif isHovered then
            love.graphics.setColor(0.8, 0.8, 1, 1)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(0.5, 0.5, 0.6, 1)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", cx, cy, cardWidth, cardHeight, 5)
        love.graphics.setLineWidth(1)
        
        -- Text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(card.name, cx + 5, cy + 10, cardWidth - 10, "center")
        
        -- Type
        local typeStr = "Place"
        if card.executionType == ExecutionType.Global then typeStr = "Global"
        elseif card.executionType == ExecutionType.Targeted then typeStr = "Target" end
        
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
    
    local numCards = #self.game.hand
    if numCards == 0 then return false end
    
    local cardWidth = 100
    local cardHeight = 140
    local spacing = 10
    local totalWidth = (numCards * cardWidth) + ((numCards - 1) * spacing)
    local startX = (VIRTUAL_WIDTH - totalWidth) / 2
    local startY = VIRTUAL_HEIGHT - cardHeight - 20
    
    for i, card in ipairs(self.game.hand) do
        local cx = startX + (i - 1) * (cardWidth + spacing)
        local cy = startY
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
                
                if card.executionType == ExecutionType.Global then
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
                elseif card.executionType == ExecutionType.Targeted then
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
