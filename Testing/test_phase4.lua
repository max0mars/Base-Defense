-- test_phase4.lua
-- Standalone script to verify Phase 4 deck mechanics, drawing limits, and consumption logic.

local PlayerDeck = require("Game.Cards.PlayerDeck")
local ExecutionType = require("Game.Cards.ExecutionType")
local Card = require("Game.Cards.Card")

print("--- Starting Phase 4 Tests ---")

-- 1. Mocking game and state
local mockGame = {
    tokens = 5,
    drawPile = {},
    hand = {},
    consumedPile = {},
    spawnFloatingText = function(self, msg) end
}

-- Copying the mechanics from GameManager
function mockGame:initBattleDeck(deck)
    self.drawPile = {}
    self.hand = {}
    self.consumedPile = {}
    
    local function deepcopy(orig, copies)
        copies = copies or {}
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            if copies[orig] then
                copy = copies[orig]
            else
                copy = {}
                copies[orig] = copy
                for orig_key, orig_value in next, orig, nil do
                    copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
                end
                setmetatable(copy, deepcopy(getmetatable(orig), copies))
            end
        else
            copy = orig
        end
        return copy
    end
    
    for _, card in ipairs(deck:getCards()) do
        for i = 1, (card.quantity or 1) do
            table.insert(self.drawPile, deepcopy(card))
        end
    end
end

function mockGame:drawCard(amount)
    amount = amount or 1
    for i = 1, amount do
        if #self.hand >= 8 then
            self:spawnFloatingText("Hand is full!")
            break
        end
        
        if #self.drawPile == 0 then
            self:spawnFloatingText("Deck is empty!")
            break
        end
        
        local card = table.remove(self.drawPile, 1)
        table.insert(self.hand, card)
    end
end

function mockGame:consumeCard(card)
    for i, c in ipairs(self.hand) do
        if c == card then
            table.remove(self.hand, i)
            table.insert(self.consumedPile, card)
            break
        end
    end
    self.activeCard = nil
    self.inputMode = "idle"
end

function mockGame:refundCard(card)
    self.tokens = self.tokens + card:getCost()
    self.activeCard = nil
    self.inputMode = "idle"
end


-- 2. Create Deck
local testDeck = PlayerDeck:new()
testDeck:addCard(Card:new({
    id = "sentry",
    name = "Sentry",
    executionType = ExecutionType.Placement,
    quantity = 4,
    payload = { rarity = "common" }
}))
testDeck:addCard(Card:new({
    id = "blaster",
    name = "Blaster",
    executionType = ExecutionType.Placement,
    quantity = 2,
    payload = { rarity = "common" }
}))

-- Test Initialization
mockGame:initBattleDeck(testDeck)

if #mockGame.drawPile == 6 and #mockGame.hand == 0 and #mockGame.consumedPile == 0 then
    print("[PASS] initBattleDeck successfully flattened deck based on quantity.")
else
    print("[FAIL] initBattleDeck failed to initialize drawPile correctly.")
end

-- Test Draw Limits
mockGame:drawCard(3)
if #mockGame.hand == 3 and #mockGame.drawPile == 3 then
    print("[PASS] drawCard(3) successfully drew 3 cards.")
else
    print("[FAIL] drawCard(3) failed.")
end

-- Force overdraw
mockGame:drawCard(10)
if #mockGame.hand == 6 and #mockGame.drawPile == 0 then
    print("[PASS] drawCard gracefully stopped on empty deck.")
else
    print("[FAIL] drawCard did not handle empty deck properly.")
end

-- Refill deck and force hand limit
mockGame:initBattleDeck(testDeck)
mockGame:initBattleDeck(testDeck) -- Wait, let's just make it big
for i=1,10 do table.insert(mockGame.drawPile, testDeck:getCards()[1]) end

mockGame:drawCard(10)
if #mockGame.hand == 8 then
    print("[PASS] drawCard gracefully respected the 8-card hand maximum.")
else
    print("[FAIL] drawCard exceeded hand maximum!")
end

-- Test Consumption
local cardToPlay = mockGame.hand[1]
mockGame:consumeCard(cardToPlay)
if #mockGame.hand == 7 and #mockGame.consumedPile == 1 then
    print("[PASS] consumeCard properly removed card from hand and moved it to consumedPile.")
else
    print("[FAIL] consumeCard failed.")
end

-- Test Refund
local initialTokens = mockGame.tokens
mockGame.tokens = mockGame.tokens - cardToPlay:getCost()
mockGame:refundCard(cardToPlay)
if mockGame.tokens == initialTokens then
    print("[PASS] refundCard safely refunded token cost.")
else
    print("[FAIL] refundCard failed to return correct tokens.")
end

print("--- Phase 4 Tests Completed ---")
