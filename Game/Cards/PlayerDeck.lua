local PlayerDeck = {}
PlayerDeck.__index = PlayerDeck

function PlayerDeck:new()
    local obj = setmetatable({}, self)
    obj.cards = {}
    return obj
end

function PlayerDeck:addCard(card)
    -- Check if we already have a card with the same ID to stack them
    for _, existingCard in ipairs(self.cards) do
        if existingCard.id == card.id then
            existingCard.quantity = existingCard.quantity + (card.quantity or 1)
            return
        end
    end
    
    -- Otherwise add as a new card
    table.insert(self.cards, card)
end

function PlayerDeck:getCards()
    return self.cards
end

function PlayerDeck:removeCard(cardId, amount)
    amount = amount or 1
    for i = #self.cards, 1, -1 do
        local card = self.cards[i]
        if card.id == cardId then
            card.quantity = card.quantity - amount
            if card.quantity <= 0 then
                table.remove(self.cards, i)
            end
            return true
        end
    end
    return false
end

return PlayerDeck
