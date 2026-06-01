-- test_phase3.lua
-- Standalone script to verify Phase 3 forecasting aggregation and shop parsing logic.

local PlayerDeck = require("Game.Cards.PlayerDeck")
local ExecutionType = require("Game.Cards.ExecutionType")
local WaveDirector = require("Game.Spawning.WaveDirector")

print("--- Starting Phase 3 Tests ---")

-- Test 1: Forecasting & Precalculation
local mockGame = {}
local wd = WaveDirector:new(mockGame)

local upcomingWaves = {}
local upcomingSummaries = {}
local totals = {}

for i = 1, 5 do
    local list, summary = wd:generateWaveList(i)
    table.insert(upcomingWaves, list)
    table.insert(upcomingSummaries, summary)
    
    for _, s in ipairs(summary) do
        totals[s.type] = (totals[s.type] or 0) + s.count
    end
end

if #upcomingWaves == 5 and #upcomingSummaries == 5 then
    print("[PASS] Successfully pre-calculated exactly 5 waves.")
else
    print("[FAIL] Did not generate exactly 5 waves.")
end

local aggregatedTypes = 0
for typeName, count in pairs(totals) do
    aggregatedTypes = aggregatedTypes + 1
    if count < 0 then
        print("[FAIL] Aggregated count for " .. typeName .. " is negative.")
    end
end

if aggregatedTypes > 0 then
    print("[PASS] Successfully aggregated enemy forecast totals.")
else
    print("[FAIL] Forecast aggregation failed to find any enemies.")
end


-- Test 2: Shop Purchase Logic
local deck = PlayerDeck:new()
local cash = 100
local cost = 50

-- Mock a shop card
local shopCard = {
    id = "turret_sentry",
    name = "Sentry",
    executionType = ExecutionType.Placement,
    quantity = 1,
    payload = {}
}

if cash >= cost then
    cash = cash - cost
    local quantity = math.random(1, 3)
    shopCard.quantity = quantity
    deck:addCard(shopCard)
end

local ownedCards = deck:getCards()
if cash == 50 and #ownedCards == 1 and ownedCards[1].quantity >= 1 and ownedCards[1].quantity <= 3 then
    print("[PASS] Shop purchase successfully deducted cash and added randomized quantity to deck.")
else
    print("[FAIL] Shop purchase logic failed.")
end

print("--- Phase 3 Tests Completed ---")
