local HandUI = {}
HandUI.__index = HandUI

local ExecutionType = require("Game.Cards.ExecutionType")
local Cursor = require("Game.GUI.Cursor")

-- A filled "card" action button: function-colored fill + left accent bar, a
-- left-aligned label and a right-aligned cost (green/red by affordability).
local function drawActionButton(btn, label, costText, baseCol, hovered, enabled, affordable)
    local r, g, b = baseCol[1], baseCol[2], baseCol[3]
    love.graphics.push("all")

    -- Body fill.
    local fillA = enabled and (hovered and 0.24 or 0.13) or 0.06
    love.graphics.setColor(r, g, b, fillA)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 5, 5)

    -- Left accent bar.
    love.graphics.setColor(r, g, b, enabled and 1.0 or 0.4)
    love.graphics.rectangle("fill", btn.x, btn.y + 3, 3, btn.h - 6, 2, 2)

    -- Hover glow.
    if hovered and enabled then
        for i = 1, 2 do
            love.graphics.setColor(r, g, b, 0.07 * (1 - i / 3))
            love.graphics.setLineWidth(2 + i * 3)
            love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 5, 5)
        end
    end
    -- Border.
    love.graphics.setColor(r, g, b, enabled and (hovered and 0.95 or 0.5) or 0.25)
    love.graphics.setLineWidth(hovered and 2 or 1)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 5, 5)

    -- Label (left) + cost (right).
    local ty = btn.y + btn.h / 2 - 6
    love.graphics.setColor(1, 1, 1, enabled and 1.0 or 0.45)
    love.graphics.print(label, btn.x + 14, ty)
    if costText then
        local font = love.graphics.getFont()
        if not enabled then love.graphics.setColor(0.6, 0.6, 0.65, 0.6)
        elseif affordable then love.graphics.setColor(0.4, 1.0, 0.5, 1)
        else love.graphics.setColor(1.0, 0.4, 0.4, 1) end
        love.graphics.print(costText, btn.x + btn.w - 12 - font:getWidth(costText), ty)
    end

    love.graphics.pop()
end

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
    
    local cardWidth = 150
    local cardHeight = 210
    
    local inventoryStartX = 320
    local inventoryMaxWidth = 740
    
    local deckX = inventoryStartX
    local deckY = VIRTUAL_HEIGHT - cardHeight - 20
    
    local handStartX = deckX + 180 + 20
    local maxHandWidth = inventoryMaxWidth - 180 - 20
    
    local spacing = 10
    if numCards > 1 then
        local requiredWidth = numCards * cardWidth + (numCards - 1) * spacing
        if requiredWidth > maxHandWidth then
            spacing = (maxHandWidth - numCards * cardWidth) / (numCards - 1)
        end
    end
    
    local mx, my = love.mouse.getPosition()
    if self.game.gui and self.game.gui:overlayActive() then mx, my = -1000, -1000 end
    
    local drawCost = self.game.drawCost or 1
    local canAffordDraw = (self.game.tokens or 0) >= drawCost
    
    local drawPileCount = self.game.drawPile and #self.game.drawPile or 0
    local discardPileCount = self.game.discardPile and #self.game.discardPile or 0
    
    local buttonStartY = VIRTUAL_HEIGHT - 144
    local drawCardBtn = { x = deckX, y = buttonStartY, w = 180, h = 34 }
    local viewDrawBtn = { x = deckX, y = buttonStartY + 42, w = 180, h = 34 }
    local viewDiscardBtn = { x = deckX, y = buttonStartY + 84, w = 180, h = 34 }
    
    local inRegion = function(btn) return mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h end
    
    -- Draw Card Button
    drawActionButton(drawCardBtn, "DRAW CARD", drawCost .. " Tk", {0.2, 0.6, 0.9}, inRegion(drawCardBtn), true, canAffordDraw)
    
    -- View Drawpile Button
    drawActionButton(viewDrawBtn, "VIEW DRAW", drawPileCount .. " C", {0.3, 0.4, 0.8}, inRegion(viewDrawBtn), drawPileCount > 0, true)
    
    -- View Discards Button
    drawActionButton(viewDiscardBtn, "VIEW DISCARDS", discardPileCount .. " C", {0.6, 0.4, 0.6}, inRegion(viewDiscardBtn), discardPileCount > 0, true)
    
    if inRegion(drawCardBtn) or inRegion(viewDrawBtn) or inRegion(viewDiscardBtn) then
        Cursor.wantHand = true
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
        
        if card.getCardDraw and card:getCardDraw() then
            card:getCardDraw():draw(cx, cy, cardWidth, cardHeight, isHovered or (self.game.activeCard == card))
            
            -- Draw unaffordable tint on top if necessary
            -- local canAfford = self.game.tokens >= cost
            -- if not canAfford then
            --     love.graphics.setColor(1, 0, 0, 0.3)
            --     love.graphics.rectangle("fill", cx, cy, cardWidth, cardHeight, 5)
            --     local scaleX = cardWidth / 250
            --     local scaleY = cardHeight / 350
            --     love.graphics.circle("fill", cx + 15 * scaleX, cy + 35 * scaleY, 25 * scaleX)
            --     love.graphics.setColor(1, 1, 1, 1)
            -- end
        else
            -- Fallback
            love.graphics.setColor(0.2, 0.2, 0.2, 0.95)
            love.graphics.rectangle("fill", cx, cy, cardWidth, cardHeight, 5)
            if self.game.activeCard == card then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.setLineWidth(3)
            elseif isHovered then
                love.graphics.setColor(0.5, 0.5, 0.5, 1)
                love.graphics.setLineWidth(2)
            else
                love.graphics.setColor(0.3, 0.3, 0.3, 1)
                love.graphics.setLineWidth(1)
            end
            love.graphics.rectangle("line", cx, cy, cardWidth, cardHeight, 5)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(card.name, cx + 5, cy + 10, cardWidth - 10, "center")
            
            local canAfford = self.game.tokens >= cost
            if canAfford then love.graphics.setColor(0.2, 0.8, 0.2, 1) else love.graphics.setColor(0.8, 0.2, 0.2, 1) end
            love.graphics.printf(cost .. " Tk", cx, cy + cardHeight - 20, cardWidth, "center")
        end
    end
end

function HandUI:mousepressed(x, y, button)
    if button ~= 1 then return false end
    if not self.game.hand then return false end
    
    local numCards = self.game.hand and #self.game.hand or 0
    
    local cardWidth = 150
    local cardHeight = 210
    
    local inventoryStartX = 320
    local inventoryMaxWidth = 740
    
    local deckX = inventoryStartX
    local deckY = VIRTUAL_HEIGHT - cardHeight - 20
    
    local handStartX = deckX + 180 + 20
    local maxHandWidth = inventoryMaxWidth - 180 - 20
    
    local spacing = 10
    if numCards > 1 then
        local requiredWidth = numCards * cardWidth + (numCards - 1) * spacing
        if requiredWidth > maxHandWidth then
            spacing = (maxHandWidth - numCards * cardWidth) / (numCards - 1)
        end
    end
    
    local buttonStartY = VIRTUAL_HEIGHT - 144
    local drawCardBtn = { x = deckX, y = buttonStartY, w = 180, h = 34 }
    local viewDrawBtn = { x = deckX, y = buttonStartY + 42, w = 180, h = 34 }
    local viewDiscardBtn = { x = deckX, y = buttonStartY + 84, w = 180, h = 34 }
    
    local inRegion = function(btn) return x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h end
    
    if inRegion(drawCardBtn) then
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
    
    if inRegion(viewDrawBtn) and self.game.drawPile and #self.game.drawPile > 0 then
        if self.game.gui and self.game.gui.deckViewer then
            self.game.gui.deckViewer:open("DrawPile", self.game.drawPile, viewDrawBtn)
        end
        return true
    end
    
    if inRegion(viewDiscardBtn) and self.game.discardPile and #self.game.discardPile > 0 then
        if self.game.gui and self.game.gui.deckViewer then
            self.game.gui.deckViewer:open("DiscardPile", self.game.discardPile, viewDiscardBtn)
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
                    self.game.inputMode = "targeting_global"
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
