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
    obj.valueFont = love.graphics.newFont(16)
    obj.coinFont = love.graphics.newFont(12)
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
    
    local drawCost = 25
    local canAffordDraw = (self.game.mana or 0) >= drawCost
    
    local drawPileCount = self.game.drawPile and #self.game.drawPile or 0
    local discardPileCount = self.game.discardPile and #self.game.discardPile or 0
    
    local buttonStartY = VIRTUAL_HEIGHT - 144
    local drawCardBtn = { x = deckX, y = buttonStartY, w = 180, h = 34 }
    local viewDrawBtn = { x = deckX, y = buttonStartY + 42, w = 180, h = 34 }
    local viewDiscardBtn = { x = deckX, y = buttonStartY + 84, w = 180, h = 34 }
    
    local inRegion = function(btn) return mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h end
    
    -- Hand is always visible
    
    -- Draw Tokens gold coin and Mana blue orb above the "Draw Card" button
    love.graphics.push("all")
    
    local centerY = buttonStartY - 20
    local radius = 14
    
    -- 1. Tokens Gold Coin (left side)
    local coinX = deckX + radius + 4
    -- Coin outer neon glow
    love.graphics.setColor(1.0, 0.7, 0.1, 0.2 + 0.1 * math.sin(self.game.pulseTimer * 4))
    love.graphics.circle("fill", coinX, centerY, radius + 4)
    -- Coin gold body
    love.graphics.setColor(0.9, 0.7, 0.15, 1)
    love.graphics.circle("fill", coinX, centerY, radius)
    -- Inner golden rim
    love.graphics.setColor(1.0, 0.88, 0.35, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", coinX, centerY, radius - 3.5)
    -- Coin 'T' label (Tokens)
    if self.coinFont then love.graphics.setFont(self.coinFont) end
    love.graphics.setColor(0.5, 0.3, 0.02, 1)
    love.graphics.printf("T", coinX - 10, centerY - 6, 20, "center")
    
    -- Tokens value text
    if self.valueFont then love.graphics.setFont(self.valueFont) end
    love.graphics.setColor(1.0, 0.9, 0.2, 1.0)
    local tokensStr = tostring(self.game.tokens)
    love.graphics.print(tokensStr, coinX + radius + 8, centerY - 8)
    
    -- Show pending cost subtraction for token usage (cards) and slot unlocks
    local activeCard = self.game.activeCard
    local isSpell = activeCard and (activeCard.executionType == "Spell" or (activeCard.isType and activeCard:isType("spell")) or activeCard.isSpell)
    local pendingCost = 0
    if activeCard and not isSpell then
        pendingCost = pendingCost + activeCard:getCost()
    end
    -- Include slot unlock cost if hovering a locked slot (building placement)
    if self.game.base and self.game.base.hoverTooltip and self.game.base.hoverTooltip.cost then
        pendingCost = pendingCost + self.game.base.hoverTooltip.cost
    end
    if pendingCost > 0 then
        love.graphics.setColor(1.0, 0.3, 0.3, 1.0)
        local valueWidth = self.valueFont:getWidth(tokensStr)
        love.graphics.print("(-" .. tostring(pendingCost) .. ")", coinX + radius + 8 + valueWidth + 4, centerY - 8)
    end
    
    -- 2. Mana Blueish Orb (right side)
    local orbX = deckX + 98 + radius + 4
    -- Orb outer neon glow
    love.graphics.setColor(0.1, 0.6, 1.0, 0.2 + 0.1 * math.sin(self.game.pulseTimer * 4))
    love.graphics.circle("fill", orbX, centerY, radius + 4)
    -- Orb body (deep blue/cyan gradient effect)
    love.graphics.setColor(0.1, 0.45, 0.9, 1.0)
    love.graphics.circle("fill", orbX, centerY, radius)
    -- Inner magical glow circle
    love.graphics.setColor(0.2, 0.75, 1.0, 0.7)
    love.graphics.circle("fill", orbX - 3.5, centerY - 3.5, radius - 6)
    -- Highlight glossy white spot
    love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
    love.graphics.circle("fill", orbX - 4.5, centerY - 4.5, 2.5)
    
    -- Mana value text (displays game.mana or a default value of 100)
    if self.valueFont then love.graphics.setFont(self.valueFont) end
    love.graphics.setColor(0.3, 0.8, 1.0, 1.0)
    local manaStr = tostring(self.game.mana or 100)
    love.graphics.print(manaStr, orbX + radius + 8, centerY - 8)
    
    -- Show pending cost subtraction if spell card is selected (mana)
    if activeCard and isSpell then
        local cost = activeCard:getCost()
        love.graphics.setColor(1.0, 0.3, 0.3, 1.0)
        local valueWidth = self.valueFont:getWidth(manaStr)
        love.graphics.print("(-" .. tostring(cost) .. ")", orbX + radius + 8 + valueWidth + 4, centerY - 8)
    end
    
    love.graphics.pop()
    
    -- Draw Card Button
    drawActionButton(drawCardBtn, "DRAW CARD", drawCost .. " Mana", {0.2, 0.6, 0.9}, inRegion(drawCardBtn), true, canAffordDraw)
    
    -- View Drawpile Button
    drawActionButton(viewDrawBtn, "VIEW DRAW", drawPileCount .. " Cards", {0.3, 0.4, 0.8}, inRegion(viewDrawBtn), drawPileCount > 0, true)
    
    -- View Discards Button
    drawActionButton(viewDiscardBtn, "VIEW DISCARDS", discardPileCount .. " Cards", {0.6, 0.4, 0.6}, inRegion(viewDiscardBtn), discardPileCount > 0, true)
    
    if inRegion(drawCardBtn) or inRegion(viewDrawBtn) or inRegion(viewDiscardBtn) then
        Cursor.wantHand = true
    end
    
    local function drawCard(i, card, isTopPass)
        local cx = handStartX + (i - 1) * (cardWidth + spacing)
        local cy = deckY
        local cost = card:getCost()
        
        -- Highlight active card
        if self.game.activeCard == card then
            cy = cy - 20 -- Pop up
        end
        
        local isHovered = mx >= cx and mx <= cx + cardWidth and my >= cy and my <= cy + cardHeight
        if isHovered then Cursor.wantHand = true end
        
        local isTopCard = (isHovered or self.game.activeCard == card)
        if isTopPass ~= isTopCard then return end
        
        if card.getCardDraw and card:getCardDraw() then
            card:getCardDraw():draw(cx, cy, cardWidth, cardHeight, isTopCard)
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
            
            local cardIsSpell = (card.executionType == "Spell" or (card.isType and card:isType("spell")) or card.isSpell)
            local canAfford = false
            local costUnit = "Tk"
            if cardIsSpell then
                canAfford = (self.game.mana or 0) >= cost
                costUnit = "Mana"
            else
                canAfford = (self.game.tokens or 0) >= cost
            end
            
            if canAfford then love.graphics.setColor(0.2, 0.8, 0.2, 1) else love.graphics.setColor(0.8, 0.2, 0.2, 1) end
            love.graphics.printf(cost .. " " .. costUnit, cx, cy + cardHeight - 20, cardWidth, "center")
        end
    end

    -- First pass: draw normal cards
    for i, card in ipairs(self.game.hand) do
        drawCard(i, card, false)
    end

    -- Second pass: draw hovered/active cards on top
    for i, card in ipairs(self.game.hand) do
        drawCard(i, card, true)
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
    
    -- Hand is always visible
    
    if inRegion(drawCardBtn) then
        local cost = 25
        if (self.game.mana or 0) >= cost then
            local drawn = self.game:drawCard(1)
            if drawn > 0 then
                self.game.mana = self.game.mana - cost
            end
        else
            self.game:spawnFloatingText("Not enough mana!", x, y, {0.2, 0.6, 1.0, 1})
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
            local cardIsSpell = (card.executionType == "Spell" or (card.isType and card:isType("spell")) or card.isSpell)
            local canAfford = false
            if cardIsSpell then
                canAfford = (self.game.mana or 0) >= cost
            else
                canAfford = (self.game.tokens or 0) >= cost
            end
            
            if canAfford then
                self.game.activeCard = card
                
                if card.executionType == ExecutionType.Global or card.executionType == "Global" or card.executionType == ExecutionType.Group or card.executionType == "Group" then
                    self.game.inputMode = "targeting_global"
                elseif card.executionType == ExecutionType.Spell or card.executionType == "Spell" then
                    self.game.inputMode = "targeting_spell"
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
