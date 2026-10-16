local PlayerDeck = {}
PlayerDeck.__index = PlayerDeck

function PlayerDeck:new()
    local obj = setmetatable({}, self)
    obj.cards = {}
    return obj
end

function PlayerDeck:addCard(card)
    local cardTier = card.tier or 1
    -- Check if we already have a card with the same ID and tier to stack them
    for _, existingCard in ipairs(self.cards) do
        local existingTier = existingCard.tier or 1
        if existingCard.id == card.id and existingTier == cardTier then
            existingCard.quantity = (existingCard.quantity or 1) + (card.quantity or 1)
            return
        end
    end
    
    -- Otherwise add as a new card
    table.insert(self.cards, card)
end

function PlayerDeck:getCards()
    return self.cards
end

function PlayerDeck:removeCard(cardId, amount, tier)
    amount = amount or 1
    for i = #self.cards, 1, -1 do
        local card = self.cards[i]
        local cardTier = card.tier or 1
        if card.id == cardId and (tier == nil or cardTier == tier) then
            card.quantity = (card.quantity or 1) - amount
            if card.quantity <= 0 then
                table.remove(self.cards, i)
            end
            return true
        end
    end
    return false
end

function PlayerDeck:removeCardInstance(targetCard)
    if not targetCard then return false end
    for i = #self.cards, 1, -1 do
        local card = self.cards[i]
        if card == targetCard then
            local qty = card.quantity or 1
            if qty > 1 then
                card.quantity = qty - 1
                if card.payload then card.payload.rewardCard = nil end
                card.rewardCard = nil
            else
                table.remove(self.cards, i)
            end
            return true
        end
    end
    return self:removeCard(targetCard.id, 1, targetCard.tier)
end

return PlayerDeck
