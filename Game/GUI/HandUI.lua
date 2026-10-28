local HandUI = {}
HandUI.__index = HandUI

local ExecutionType = require("Game.Cards.ExecutionType")
local Cursor = require("Game.GUI.Cursor")
local CardReveal = require("Graphics.Animations.CardReveal")
local Layout = require("Game.GUI.Layout")

local CARD_W, CARD_H = 150, 210

-- Draw animation: a new card slides up face down from below the screen into its
-- slot, then flips over. Cards drawn together come in one after another.
local SLIDE_TIME = 0.3
local FLIP_TIME = 0.25
local DRAW_STAGGER = 0.12
-- How fast cards glide to their new slot when the hand spreads or bunches up
local SHIFT_RATE = 18
-- Hand swap: the old hand hops up and tumbles off the bottom of the screen, and
-- the new hand starts coming in partway through the fall
local DROP_STAGGER = 0.05
local DROP_HOP = 220     -- initial upward speed
local DROP_GRAVITY = 2400
local DROP_DRIFT = 80    -- max sideways speed
local DROP_SPIN = 2.5    -- max spin, radians per second
local DROP_HOLD = 0.45   -- delay before the new hand starts drawing in
-- Battle start: the cards kept in the mulligan fly from the mulligan screen down
-- into the hand, speeding up then slowing into their slot
local FLY_TIME = 0.6
local FLY_STAGGER = 0.07
-- The selected card shakes until it's played or put back
local SHAKE_ANGLE = math.rad(1.5)
local SHAKE_SHIFT = 1    -- pixels
local SHAKE_SPEED = 30

-- Shared by drawing, clicks and the draw animation. Tokens, mana and the pile
-- buttons sit at the bottom of the left column (deckX); the hand fills the tray
-- to the right, up to its control buttons.
local function handLayout(numCards)
    local deckX = Layout.leftColumn.x + 12
    local deckY = VIRTUAL_HEIGHT - CARD_H - 20
    local handStartX = Layout.tray.x + 12
    local maxHandWidth = (Layout.tray.x + Layout.tray.w - Layout.trayActionsW) - 12 - handStartX

    local spacing = 10
    if numCards > 1 then
        local requiredWidth = numCards * CARD_W + (numCards - 1) * spacing
        if requiredWidth > maxHandWidth then
            spacing = (maxHandWidth - numCards * CARD_W) / (numCards - 1)
        end
    end
    return deckX, deckY, handStartX, spacing
end

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

-- Pile buttons span the left column
local function pileWidth() return Layout.leftColumn.w - 24 end

-- View-pile buttons under the currency row. While a wave runs the hand is drawn
-- from the spell deck, so the buttons show the spell piles instead.
local function pileButtons(game, deckX)
    local inWave = game:isState("wave")
    local buttonStartY = VIRTUAL_HEIGHT - 102
    return {
        draw = {
            btn = { x = deckX, y = buttonStartY, w = pileWidth(), h = 34 },
            label = inWave and "SPELL DRAW" or "VIEW DRAW",
            pileType = inWave and "SpellDrawPile" or "DrawPile",
            cards = (inWave and game.spellDrawPile or game.drawPile) or {},
        },
        discard = {
            btn = { x = deckX, y = buttonStartY + 42, w = pileWidth(), h = 34 },
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
    obj.inHand = {}     -- cards seen in the hand last frame
    obj.drawAnims = {}  -- card -> seconds into its draw animation (negative while waiting its turn)
    obj.cardX = {}      -- card -> displayed x, gliding toward its slot
    obj.falling = {}    -- discarded cards tumbling off screen
    obj.drawHold = 0    -- seconds before newly drawn cards start coming in
    obj.flyAnims = {}   -- card -> flight from the mulligan screen
    return obj
end

--- True while `card` is still coming into the hand (it can't be picked yet).
function HandUI:isArriving(card)
    return self.drawAnims[card] ~= nil or self.flyAnims[card] ~= nil
end

-- Starts the kept mulligan cards flying from where the mulligan screen showed them
function HandUI:flyFromMulligan()
    local layout = self.game.getMulliganLayout and self.game:getMulliganLayout()
    if not layout then return end
    for i, card in ipairs(self.game.hand) do
        local c = layout.cards[i]
        if c then
            self.flyAnims[card] = { t = -(i - 1) * FLY_STAGGER, x = c.x, y = c.y, w = layout.cardW, h = layout.cardH }
            self.inHand[card] = true -- already seen, so no draw animation
        end
    end
end

--- Sends `cards` (the hand being discarded) tumbling off the bottom of the screen.
function HandUI:dropCards(cards)
    local _, deckY, handStartX, spacing = handLayout(#cards)
    local dropped = 0
    for i, card in ipairs(cards) do
        local t = self.drawAnims[card]
        -- A card still waiting to come in was never on screen
        if not (t and t < 0) then
            table.insert(self.falling, {
                card = card,
                x = self.cardX[card] or handStartX + (i - 1) * (CARD_W + spacing),
                y = deckY,
                vx = (math.random() * 2 - 1) * DROP_DRIFT,
                vy = -DROP_HOP,
                rot = 0,
                spin = (math.random() * 2 - 1) * DROP_SPIN,
                delay = dropped * DROP_STAGGER,
            })
            dropped = dropped + 1
        end
        self.drawAnims[card] = nil
        self.flyAnims[card] = nil
    end
    if dropped > 0 then self.drawHold = DROP_HOLD end
end

function HandUI:update(dt)
    local hand = self.game.hand
    if not hand then return end
    -- The mulligan screen shows the hand itself; it flies down once the battle starts
    if self.game:isState("mulligan") then
        self.inMulligan = true
        return
    end
    if self.inMulligan then
        self.inMulligan = false
        self:flyFromMulligan()
    end

    -- Real time, so game speed and pausing don't hold the animation up
    dt = love.timer.getDelta and love.timer.getDelta() or dt

    for i = #self.falling, 1, -1 do
        local f = self.falling[i]
        if f.delay > 0 then
            f.delay = f.delay - dt
        else
            f.vy = f.vy + DROP_GRAVITY * dt
            f.x, f.y = f.x + f.vx * dt, f.y + f.vy * dt
            f.rot = f.rot + f.spin * dt
            -- Gone once even a rotated corner is past the bottom edge
            if f.y > VIRTUAL_HEIGHT + CARD_H * 0.3 then table.remove(self.falling, i) end
        end
    end

    local _, _, handStartX, spacing = handLayout(#hand)
    local inHand, cardX, queued = {}, {}, 0
    for i, card in ipairs(hand) do
        inHand[card] = true
        if not self.inHand[card] then
            self.drawAnims[card] = -self.drawHold - queued * DRAW_STAGGER
            queued = queued + 1
        end
        local target = handStartX + (i - 1) * (CARD_W + spacing)
        local x = self.cardX[card]
        cardX[card] = x and target + (x - target) * math.exp(-SHIFT_RATE * dt) or target
    end
    self.inHand, self.cardX = inHand, cardX
    self.drawHold = math.max(0, self.drawHold - dt)

    for card, t in pairs(self.drawAnims) do
        t = t + dt
        if not inHand[card] or t >= SLIDE_TIME + FLIP_TIME then
            self.drawAnims[card] = nil
        else
            self.drawAnims[card] = t
        end
    end
    for card, fly in pairs(self.flyAnims) do
        fly.t = fly.t + dt
        if not inHand[card] or fly.t >= FLY_TIME then self.flyAnims[card] = nil end
    end
end

-- Discarded cards falling away, drawn over the hand
function HandUI:drawFalling()
    for _, f in ipairs(self.falling) do
        local cardDraw = f.card.getCardDraw and f.card:getCardDraw()
        love.graphics.push("all")
        love.graphics.translate(f.x + CARD_W / 2, f.y + CARD_H / 2)
        love.graphics.rotate(f.rot)
        if cardDraw then
            cardDraw:draw(-CARD_W / 2, -CARD_H / 2, CARD_W, CARD_H, false)
        else
            CardReveal.drawBack(CARD_W, CARD_H)
        end
        love.graphics.pop()
    end
end

-- A card flying in from the mulligan screen toward its slot (x, y)
function HandUI:drawFlying(card, fly, x, y, w, h)
    local p = math.max(0, math.min(fly.t / FLY_TIME, 1))
    -- Cubic ease-in-out: accelerates away, decelerates into the slot
    local e = p < 0.5 and 4 * p ^ 3 or 1 - (2 - 2 * p) ^ 3 / 2
    local cardDraw = card.getCardDraw and card:getCardDraw()
    if not cardDraw then return end
    cardDraw:draw(fly.x + (x - fly.x) * e, fly.y + (y - fly.y) * e,
        fly.w + (w - fly.w) * e, fly.h + (h - fly.h) * e, false)
end

-- A card mid draw animation, at its slot (x, y) once it has slid in
function HandUI:drawIncoming(card, t, x, y, w, h)
    if t < 0 then return end -- still waiting its turn
    local slide = math.min(t / SLIDE_TIME, 1)
    local startY = VIRTUAL_HEIGHT + 10
    local cy = startY + (y - startY) * (1 - (1 - slide) ^ 3)
    local flip = math.max(0, (t - SLIDE_TIME) / FLIP_TIME)

    love.graphics.push("all")
    love.graphics.translate(x + w / 2, cy + h / 2)
    -- Squash to nothing and back out, swapping to the face halfway
    love.graphics.scale(math.max(math.abs(1 - 2 * flip), 0.01), 1)
    local cardDraw = flip >= 0.5 and card.getCardDraw and card:getCardDraw()
    if cardDraw then
        cardDraw:draw(-w / 2, -h / 2, w, h, false)
    else
        CardReveal.drawBack(w, h)
    end
    love.graphics.pop()
end

function HandUI:draw()
    if not self.game.hand then return end
    
    local cardWidth, cardHeight = CARD_W, CARD_H
    local deckX, deckY, handStartX, spacing = handLayout(#self.game.hand)
    
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
        local cx = self.cardX[card] or handStartX + (i - 1) * (cardWidth + spacing)
        local cy = deckY
        local anim = self.drawAnims[card]
        if anim then
            if not isTopPass then self:drawIncoming(card, anim, cx, cy, cardWidth, cardHeight) end
            return
        end
        local fly = self.flyAnims[card]
        if fly then
            -- Over the rest of the hand
            if isTopPass then self:drawFlying(card, fly, cx, cy, cardWidth, cardHeight) end
            return
        end
        local cost = card:getCost()
        
        -- Highlight active card
        if self.game.activeCard == card then
            cy = cy - 20 -- Pop up
        end
        
        local isHovered = mx >= cx and mx <= cx + cardWidth and my >= cy and my <= cy + cardHeight
        if isHovered then Cursor.wantHand = true end
        
        local isTopCard = (isHovered or self.game.activeCard == card)
        if isTopPass ~= isTopCard then return end
        
        local shaking = self.game.activeCard == card
        if shaking then
            -- Wobble about the card's center; the two waves are out of step so it doesn't look mechanical
            local t = love.timer.getTime() * SHAKE_SPEED
            love.graphics.push()
            love.graphics.translate(cx + cardWidth / 2 + math.sin(t * 1.37) * SHAKE_SHIFT, cy + cardHeight / 2)
            love.graphics.rotate(math.sin(t) * SHAKE_ANGLE)
            love.graphics.translate(-cx - cardWidth / 2, -cy - cardHeight / 2)
        end

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

        if shaking then love.graphics.pop() end
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
        end
        if self.game:isSpellCard(card) and not self:isArriving(card) then
            local bx = (self.cardX[card] or handStartX + (i - 1) * (cardWidth + spacing)) + 6
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

    self:drawFalling()
end

function HandUI:mousepressed(x, y, button)
    if button ~= 1 then return false end
    if not self.game.hand then return false end
    
    local cardWidth, cardHeight = CARD_W, CARD_H
    local deckX, deckY, handStartX, spacing = handLayout(#self.game.hand)
    
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
        local cx = self.cardX[card] or handStartX + (i - 1) * (cardWidth + spacing)
        local cy = deckY
        if self.game.activeCard == card then
            cy = cy - 20
        end

        if not self:isArriving(card) and x >= cx and x <= cx + cardWidth and y >= cy and y <= cy + cardHeight then
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
            game:spawnScreenText("Not enough mana!", x, y, {0.2, 0.6, 1.0, 1})
        else
            game:spawnScreenText("Not enough tokens!", x, y, {0.8, 0.2, 0.2, 1})
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

--- The cards number keys pick from, left to right: the spells during a wave
--- (their hotkey badges show the number), otherwise the whole hand (no badges).
function HandUI:hotkeyCards()
    if self.game:isState("wave") then return self:spellSlots() end
    return self.game.hand or {}
end

--- Hotkey: selects the n-th hotkey card (pressing it again cancels).
function HandUI:selectHotkeyCard(n)
    local card = self:hotkeyCards()[n]
    if not card or self:isArriving(card) then return false end
    local mx, my = love.mouse.getPosition()
    self:selectCard(card, mx, my)
    return true
end

return HandUI
