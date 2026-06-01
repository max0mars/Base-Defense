-- test_phase2.lua
-- A standalone script to verify Phase 2 deep copying and economy/buff mechanics.

local ExecutionType = require("Game.Cards.ExecutionType")
local Card = require("Game.Cards.Card")
local PlayerDeck = require("Game.Cards.PlayerDeck")

print("--- Starting Phase 2 Tests ---")

-- Test 1: Deep Copy Integrity
local dummyBuildingClass = {
    new = function(self, config)
        return config
    end
}

local testCard = Card:new({
    id = "turret_1",
    name = "Basic Turret",
    executionType = ExecutionType.Placement,
    payload = {
        buildingClass = dummyBuildingClass,
        config = {
            damage = 10,
            nestedData = {
                range = 5
            }
        }
    }
})

local gameMock = {}
local instantiatedInstance = testCard:execute(gameMock)

instantiatedInstance.damage = 999
instantiatedInstance.nestedData.range = 100

local originalPayload = testCard.payload.config
if originalPayload.damage == 10 and originalPayload.nestedData.range == 5 then
    print("[PASS] Deep copy integrity maintained! Original payload was not mutated.")
else
    print("[FAIL] Deep copy failed. Original payload was mutated.")
end

-- Test 2: Player Deck Operations
local deck = PlayerDeck:new()
deck:addCard(testCard)
deck:addCard(testCard) -- Should stack

local cards = deck:getCards()
if #cards == 1 and cards[1].quantity == 2 then
    print("[PASS] Deck correctly stacks cards with the same ID.")
else
    print("[FAIL] Deck failed to stack cards.")
end

-- Test 3: Card Execution (Global) & Global Buff Clear Logic
local GameManagerMock = {
    activeGlobalBuffs = {},
    playerEffectManager = {
        appliedEffects = {},
        applyEffect = function(self, effect)
            table.insert(self.appliedEffects, effect)
        end,
        removeEffect = function(self, effect)
            effect.removed = true
        end
    }
}

function GameManagerMock:registerActiveGlobalBuff(effect)
    table.insert(self.activeGlobalBuffs, effect)
end

function GameManagerMock:clearGlobalBuffs()
    for _, effect in ipairs(self.activeGlobalBuffs) do
        self.playerEffectManager:removeEffect(effect)
    end
    self.activeGlobalBuffs = {}
end

local buffEffect = { name = "Fire Rate Buff", removed = false }
local globalCard = Card:new({
    id = "buff_1",
    executionType = ExecutionType.Global,
    payload = {
        effect = buffEffect
    }
})

-- Play the Global card
local playResult = globalCard:execute(GameManagerMock)

if playResult == true and #GameManagerMock.activeGlobalBuffs == 1 and #GameManagerMock.playerEffectManager.appliedEffects == 1 then
    print("[PASS] Global Card played successfully, buff applied and tracked.")
else
    print("[FAIL] Global Card execution failed to track buffs.")
end

-- Clear the buffs
GameManagerMock:clearGlobalBuffs()

-- Check that the effect was cleared on the instantiated deepcopy, and that original wasn't mutated
if GameManagerMock.playerEffectManager.appliedEffects[1].removed and #GameManagerMock.activeGlobalBuffs == 0 then
    print("[PASS] Global buffs successfully cleared.")
else
    print("[FAIL] Global buffs clearing failed.")
end

if buffEffect.removed == false then
    print("[PASS] Deep copy integrity maintained for Global cards! Original effect not mutated.")
else
    print("[FAIL] Original global effect was mutated.")
end

print("--- Phase 2 Tests Completed ---")
