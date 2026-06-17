-- Testing/test_consume_exile.lua
-- Standalone script to verify the Consume and Exile card logic

package.path = package.path .. ";./?.lua"

local Card = require("Game.Cards.Card")
local Instant = require("Instants.instant")
local Spell = require("Spells.Spell")
local ExecutionType = require("Game.Cards.ExecutionType")

print("--- Starting Consume and Exile System Tests ---")

-- Mock Persistent State and Deck
_G.PersistentState = {
    deck = {
        cards = {
            { id = "test_card", quantity = 3 }
        },
        removeCard = function(self, cardId, amount)
            amount = amount or 1
            for i = #self.cards, 1, -1 do
                local c = self.cards[i]
                if c.id == cardId then
                    c.quantity = c.quantity - amount
                    if c.quantity <= 0 then
                        table.remove(self.cards, i)
                    end
                    return true
                end
            end
            return false
        end
    }
}

local failures = 0

local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

local function mockConsumeCard(game, card)
    for i, c in ipairs(game.hand) do
        if c == card then
            table.remove(game.hand, i)
            
            local execType = card.executionType
            
            if card.isExile then
                if type(card.Exile) == "function" then
                    card:Exile(game)
                else
                    if not game.exiledPile then game.exiledPile = {} end
                    table.insert(game.exiledPile, card)
                end
            elseif card.isConsume or execType == ExecutionType.Placement or execType == "Placement" then
                if type(card.Consume) == "function" then
                    card:Consume(game)
                else
                    table.insert(game.consumedPile, card)
                end
            else
                table.insert(game.discardPile, card)
            end
            break
        end
    end
    game.activeCard = nil
    game.inputMode = "idle"
end

-- Mock GameManager instance
local function createMockGame()
    local game = {
        hand = {},
        consumedPile = {},
        discardPile = {},
        exiledPile = {},
        activeCard = nil,
        inputMode = "idle"
    }
    
    game.consumeCard = mockConsumeCard
    return game
end

-- 1. Test standard instant card (no flags) -> routes to discard pile
do
    local game = createMockGame()
    local card = Instant.new({
        id = "standard_instant",
        executionType = ExecutionType.Global
    })
    
    table.insert(game.hand, card)
    game.activeCard = card
    
    game:consumeCard(card)
    
    assert(#game.hand == 0, "Card removed from hand")
    assert(#game.discardPile == 1, "Standard card went to discardPile")
    assert(game.discardPile[1] == card, "Correct card in discardPile")
end

-- 2. Test default building card (Placement) -> routes to consumed pile by default
do
    local game = createMockGame()
    local card = Card:new({
        id = "standard_building",
        executionType = ExecutionType.Placement
    })
    
    table.insert(game.hand, card)
    game.activeCard = card
    
    game:consumeCard(card)
    
    assert(#game.hand == 0, "Card removed from hand")
    assert(#game.consumedPile == 1, "Default placement card went to consumedPile")
    assert(game.consumedPile[1] == card, "Correct card in consumedPile")
end

-- 3. Test consume flag on an Instant card -> routes to consumed pile
do
    local game = createMockGame()
    local card = Instant.new({
        id = "consume_instant",
        executionType = ExecutionType.Global,
        isConsume = true
    })
    
    table.insert(game.hand, card)
    game.activeCard = card
    
    game:consumeCard(card)
    
    assert(#game.hand == 0, "Card removed from hand")
    assert(#game.consumedPile == 1, "Consumable card went to consumedPile")
    assert(game.consumedPile[1] == card, "Correct card in consumedPile")
end

-- 4. Test exile flag on a Spell card -> routes to exiled pile & removes from persistent deck
do
    -- Set up deck quantity for test_card to 3
    _G.PersistentState.deck.cards[1] = { id = "test_card", quantity = 3 }
    
    local game = createMockGame()
    local card = Spell.new({
        id = "test_card",
        isExile = true
    })
    
    table.insert(game.hand, card)
    game.activeCard = card
    
    game:consumeCard(card)
    
    assert(#game.hand == 0, "Card removed from hand")
    assert(#game.exiledPile == 1, "Exiled card went to exiledPile")
    assert(game.exiledPile[1] == card, "Correct card in exiledPile")
    
    -- Verify persistent deck quantity decreased
    local deckCard = _G.PersistentState.deck.cards[1]
    assert(deckCard.quantity == 2, "Persistent deck card quantity decreased from 3 to 2")
end

-- 5. Test both exile and consume flags on a card -> Exile takes priority
do
    -- Set up deck quantity for test_card to 1
    _G.PersistentState.deck.cards[1] = { id = "test_card", quantity = 1 }
    
    local game = createMockGame()
    local card = Spell.new({
        id = "test_card",
        isExile = true,
        isConsume = true
    })
    
    table.insert(game.hand, card)
    game.activeCard = card
    
    game:consumeCard(card)
    
    assert(#game.hand == 0, "Card removed from hand")
    assert(#game.exiledPile == 1, "Double-flagged card went to exiledPile (Exile priority)")
    assert(#game.consumedPile == 0, "Double-flagged card did not go to consumedPile")
    
    -- Verify persistent deck card is completely removed (since quantity was 1)
    assert(#_G.PersistentState.deck.cards == 0, "Persistent deck card is completely removed")
end

print("--- Consume and Exile System Tests Completed with " .. failures .. " failures ---")
os.exit(failures == 0 and 0 or 1)
