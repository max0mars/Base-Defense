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

-- View-pile buttons under the currency row. While a wave runs the hand is drawn
-- from the spell deck, so the buttons show the spell piles instead.
local function pileButtons(game, deckX)
    local inWave = game:isState("wave")
    local buttonStartY = VIRTUAL_HEIGHT - 102
    return {
        draw = {
            btn = { x = deckX, y = buttonStartY, w = 180, h = 34 },
            label = inWave and "SPELL DRAW" or "VIEW DRAW",
            pileType = inWave and "SpellDrawPile" or "DrawPile",
            cards = (inWave and game.spellDrawPile or game.drawPile) or {},
        },
        discard = {
            btn = { x = deckX, y = buttonStartY + 42, w = 180, h = 34 },
            label = inWave and "SPELL DISCARDS" or "VIEW DISCARDS",
            pileType = inWave and "SpellDiscardPile" or "DiscardPile",
            cards = (inWave and game.spellDiscardPile or game.discardPile) or {},
        },
        startY = buttonStartY,
    }
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
    
    local piles = pileButtons(self.game, deckX)
    local drawPileCount = #piles.draw.cards
    local discardPileCount = #piles.discard.cards
    local buttonStartY = piles.startY
    local viewDrawBtn = piles.draw.btn
    local viewDiscardBtn = piles.discard.btn

    local inRegion = function(btn) return mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h end
    
    -- Hand is always visible
    
    -- Draw Tokens gold coin and Mana blue orb above the pile buttons
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
    
    -- View Drawpile Button
    drawActionButton(viewDrawBtn, piles.draw.label, drawPileCount .. " Cards", {0.3, 0.4, 0.8}, inRegion(viewDrawBtn), drawPileCount > 0, true)

    -- View Discards Button
    drawActionButton(viewDiscardBtn, piles.discard.label, discardPileCount .. " Cards", {0.6, 0.4, 0.6}, inRegion(viewDiscardBtn), discardPileCount > 0, true)

    if inRegion(viewDrawBtn) or inRegion(viewDiscardBtn) then
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

    -- Hotkey badges above each spell card (1 = leftmost spell). Left-aligned so
    -- they stay readable when cards overlap.
    local slot = 0
    love.graphics.push("all")
    if self.coinFont then love.graphics.setFont(self.coinFont) end
    for i, card in ipairs(self.game.hand) do
        if self.game:isSpellCard(card) then
            slot = slot + 1
            local bx = handStartX + (i - 1) * (cardWidth + spacing) + 6
            local by = deckY - 24
            if self.game.activeCard == card then by = by - 20 end
            local affordable = (self.game.mana or 0) >= card:getCost()
            local active = self.game.activeCard == card
            love.graphics.setColor(0.03, 0.08, 0.16, 0.95)
            love.graphics.rectangle("fill", bx, by, 20, 20, 4, 4)
            if active then love.graphics.setColor(1, 1, 1, 1)
            elseif affordable then love.graphics.setColor(0.3, 0.75, 1.0, 1)
            else love.graphics.setColor(0.45, 0.45, 0.5, 1) end
            love.graphics.setLineWidth(active and 2 or 1)
            love.graphics.rectangle("line", bx, by, 20, 20, 4, 4)
            love.graphics.printf(tostring(slot), bx, by + 3, 20, "center")
        end
    end
    love.graphics.pop()
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
    
    local piles = pileButtons(self.game, deckX)

    local inRegion = function(btn) return x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h end

    -- Hand is always visible

    for _, pile in ipairs({ piles.draw, piles.discard }) do
        if inRegion(pile.btn) and #pile.cards > 0 then
            if self.game.gui and self.game.gui.deckViewer then
                self.game.gui.deckViewer:open(pile.pileType, pile.cards, pile.btn)
            end
            return true
        end
    end

    for i = #self.game.hand, 1, -1 do
        local card = self.game.hand[i]
        local cx = handStartX + (i - 1) * (cardWidth + spacing)
        local cy = deckY
        if self.game.activeCard == card then
            cy = cy - 20
        end

        if x >= cx and x <= cx + cardWidth and y >= cy and y <= cy + cardHeight then
            self:selectCard(card, x, y)
            return true
        end
    end

    return false
end

--- Makes `card` the active card (entering its targeting/placing mode), or
--- cancels it if it is already active. (x, y) is where to show a "can't afford" note.
function HandUI:selectCard(card, x, y)
    local game = self.game
    if game.activeCard == card then
        -- Selecting the already active card -> cancel it
        game:refundCard(card)
        return
    end

    -- If we already have a different active card, refund it first
    if game.activeCard then
        game:refundCard(game.activeCard)
    end

    local cost = card:getCost()
    local cardIsSpell = game:isSpellCard(card)
    local canAfford = false
    if cardIsSpell then
        canAfford = (game.mana or 0) >= cost
    else
        canAfford = (game.tokens or 0) >= cost
    end

    if not canAfford then
        if cardIsSpell then
            game:spawnFloatingText("Not enough mana!", x, y, {0.2, 0.6, 1.0, 1})
        else
            game:spawnFloatingText("Not enough tokens!", x, y, {0.8, 0.2, 0.2, 1})
        end
        return
    end

    game.activeCard = card

    if card.executionType == ExecutionType.Global or card.executionType == "Global" or card.executionType == ExecutionType.Group or card.executionType == "Group" then
        game.inputMode = "targeting_global"
    elseif card.executionType == ExecutionType.Spell or card.executionType == "Spell" then
        game.inputMode = "targeting_spell"
    elseif card.executionType == ExecutionType.Placement then
        game.inputMode = "placing"
        if type(card.execute) == "function" then
            game.blueprint = card:execute(game)
        else
            local config = {}
            if card.payload and card.payload.config then
                for k, v in pairs(card.payload.config) do
                    config[k] = v
                end
            end
            config.game = game
            game.blueprint = card.payload.buildingClass:new(config)
        end
        if game.blueprint then
            game.blueprint.showArc = true
        end
    elseif card.executionType == ExecutionType.Targeted or card.executionType == "Targeted" then
        game.inputMode = "targeting_card"
    end
end

--- The spell cards in hand, left to right; their position is their hotkey number.
function HandUI:spellSlots()
    local spells = {}
    for _, card in ipairs(self.game.hand or {}) do
        if self.game:isSpellCard(card) then spells[#spells + 1] = card end
    end
    return spells
end

--- Hotkey: starts targeting the n-th spell in hand (pressing it again cancels).
function HandUI:selectSpellSlot(n)
    local card = self:spellSlots()[n]
    if not card then return false end
    local mx, my = love.mouse.getPosition()
    self:selectCard(card, mx, my)
    return true
end

return HandUI
