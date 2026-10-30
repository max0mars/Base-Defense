-- Mock love environment for headless testing
_G.love = {
    graphics = {
        getFont = function()
            return {
                getHeight = function() return 10 end,
                getWidth = function() return 10 end,
                getWrap = function(_, _) return 10, {"text"} end
            }
        end,
        print = function() end,
        printf = function() end,
        rectangle = function() end,
        setColor = function() end,
        setLineWidth = function() end,
        push = function() end,
        pop = function() end,
        translate = function() end,
        scale = function() end,
        circle = function() end,
        line = function() end,
        polygon = function() end
    },
    mouse = {
        getPosition = function() return 0, 0 end,
        setVisible = function() end,
        setCursor = function() end,
        getSystemCursor = function() return {} end
    },
    math = { colorFromBytes = function() return 1, 1, 1, 1 end, random = math.random },
    timer = { getTime = function() return 0 end }
}

_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720
_G.Cursor = { wantHand = false }
_G.PersistentState = {
    cash = 500,
    materials = { ["Upgrade Material"] = 5, ["Card Removal"] = 2 },
    cardRemovals = 2,
    deck = nil
}

local Card = require("Game.Cards.Card")
local PlayerDeck = require("Game.Cards.PlayerDeck")
local ExecutionType = require("Game.Cards.ExecutionType")
local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
local prepScene = require("Scenes.preparation_scene")

-- ==========================================
-- 1. Test Economy Card Removal Resource
-- ==========================================
assert(CardUpgradeConfig.Economy.getCardRemovals() == 2, "Starting card removals should be 2")
assert(CardUpgradeConfig.Economy.getResource("Card Removal") == 2, "getResource('Card Removal') should return 2")
assert(CardUpgradeConfig.Economy.getResource("trash") == 2, "getResource('trash') should return 2")

CardUpgradeConfig.Economy.addCardRemovals(3)
assert(CardUpgradeConfig.Economy.getCardRemovals() == 5, "Card removals should increase to 5")
assert(_G.PersistentState.cardRemovals == 5, "PersistentState.cardRemovals should be 5")
assert(_G.PersistentState.materials["Card Removal"] == 5, "materials['Card Removal'] should be 5")

local successDeduct = CardUpgradeConfig.Economy.useCardRemoval()
assert(successDeduct == true, "useCardRemoval should succeed")
assert(CardUpgradeConfig.Economy.getCardRemovals() == 4, "Card removals should be 4 after 1 use")

-- ==========================================
-- 2. Test PlayerDeck Single Card Destruction on Duplicate Stacks
-- ==========================================
local deck = PlayerDeck:new()
local cardA = Card:new({
    id = "sentry_turret",
    name = "Sentry Turret",
    quantity = 3,
    executionType = ExecutionType.Placement
})
local cardB = Card:new({
    id = "laser_turret",
    name = "Laser Turret",
    quantity = 1,
    executionType = ExecutionType.Placement
})

deck:addCard(cardA)
deck:addCard(cardB)

assert(#deck:getCards() == 2, "Deck should have 2 distinct card entries")
assert(deck:getCards()[1].quantity == 3, "Card A should have quantity 3")
assert(deck:getCards()[2].quantity == 1, "Card B should have quantity 1")

-- Remove 1 copy of Card A (duplicate stack)
local removed = deck:removeCardInstance(deck:getCards()[1])
assert(removed == true, "removeCardInstance should return true")
assert(#deck:getCards() == 2, "Deck should still have 2 distinct entries after removing 1 duplicate")
assert(deck:getCards()[1].quantity == 2, "Card A quantity should now be 2")

-- Remove another copy of Card A
deck:removeCardInstance(deck:getCards()[1])
assert(#deck:getCards() == 2, "Deck should still have 2 distinct entries")
assert(deck:getCards()[1].quantity == 1, "Card A quantity should now be 1")

-- Remove the last copy of Card A
deck:removeCardInstance(deck:getCards()[1])
assert(#deck:getCards() == 1, "Card A should now be completely removed from deck")
assert(deck:getCards()[1].id == "laser_turret", "Remaining card should be Card B")

-- Remove single copy of Card B
deck:removeCardInstance(deck:getCards()[1])
assert(#deck:getCards() == 0, "Deck should now be completely empty")

-- ==========================================
-- 3. Test preparation_scene Card Removal Flow
-- ==========================================
_G.PersistentState.deck = PlayerDeck:new()
local sentry = Card:new({ id = "sentry_turret", name = "Sentry Turret", quantity = 3, executionType = ExecutionType.Placement })
local sniper = Card:new({ id = "sniper_turret", name = "Sniper Turret", quantity = 1, executionType = ExecutionType.Placement })
_G.PersistentState.deck:addCard(sentry)
_G.PersistentState.deck:addCard(sniper)
_G.PersistentState.cardRemovals = 2
_G.PersistentState.materials["Card Removal"] = 2

prepScene:load(false)
assert(prepScene.viewingDeck == false, "Deck should be closed initially")
assert(prepScene.deckTrashMode == false, "Trash mode should be off initially")
assert(prepScene.destroyConfirmCard == nil, "No confirmation card initially")

-- Open Deck View
prepScene:mousepressed(prepScene.deckButton.x + 5, prepScene.deckButton.y + 5, 1)
assert(prepScene.viewingDeck == true, "Viewing deck should now be true")

-- Draw deck to initialize buttons
prepScene:drawDeck()
assert(prepScene.deckTrashBtn ~= nil, "Trash button should be initialized in drawDeck")

-- Click the garbage icon button to toggle Removal Mode
local trashBtn = prepScene.deckTrashBtn
prepScene:mousepressed(trashBtn.x + 5, trashBtn.y + 5, 1)
assert(prepScene.deckTrashMode == true, "Removal mode should be active after clicking garbage icon")

-- Redraw in removal mode to populate layout
prepScene:drawDeck()

-- Find Sentry Turret card coordinates (display index 0 -> row 0, col 0)
local cols = 4
local cardW = 190
local cardH = 266
local spacingX = 36
local spacingY = 16
local startX = (VIRTUAL_WIDTH - (cols * cardW + (cols - 1) * spacingX)) / 2
local startY = 96
local cardX = startX
local cardY = startY

-- Click on Sentry Turret card in removal mode -> opens confirmation modal
prepScene:mousepressed(cardX + 10, cardY + 10, 1)
assert(prepScene.destroyConfirmCard ~= nil, "destroyConfirmCard should be set")
assert(prepScene.destroyConfirmCard.id == "sentry_turret", "Confirmed card should be sentry_turret")

-- Draw confirmation modal to populate modal buttons
prepScene:drawDestroyConfirmation(0, 0)
assert(prepScene.confirmDestroyBtn ~= nil, "Confirm button should be initialized")
assert(prepScene.cancelDestroyBtn ~= nil, "Cancel button should be initialized")

-- Test CANCEL button
local cancelBtn = prepScene.cancelDestroyBtn
prepScene:mousepressed(cancelBtn.x + 5, cancelBtn.y + 5, 1)
assert(prepScene.destroyConfirmCard == nil, "Confirmation should be cancelled")
assert(prepScene.deckTrashMode == true, "Should still be in removal mode")
assert(_G.PersistentState.deck:getCards()[1].quantity == 3, "Card quantity should be untouched")
assert(CardUpgradeConfig.Economy.getCardRemovals() == 2, "Removals should not be deducted on cancel")

-- Click Sentry Turret again to re-open confirmation modal
prepScene:mousepressed(cardX + 10, cardY + 10, 1)
assert(prepScene.destroyConfirmCard ~= nil, "destroyConfirmCard should be set again")
prepScene:drawDestroyConfirmation(0, 0)

-- Move mouse over Sniper Turret while confirmation modal is open:
-- Highlight MUST remain locked on Sentry Turret and NOT move to Sniper Turret
local sniperCol = 1
local sniperX = startX + sniperCol * (cardW + spacingX)
local sniperY = startY
_G.love.mouse.getPosition = function() return sniperX + 20, sniperY + 20 end

-- Intercept drawTrashIcon calls to record where card aura is drawn
local auraDrawnAt = {}
local origDrawTrashIcon = prepScene.drawTrashIcon
prepScene.drawTrashIcon = function(self, cx, cy, size, col)
    if size == 42 then
        table.insert(auraDrawnAt, { cx = cx, cy = cy })
    end
    origDrawTrashIcon(self, cx, cy, size, col)
end

prepScene:drawDeck()
prepScene.drawTrashIcon = origDrawTrashIcon

assert(#auraDrawnAt == 1, "Only 1 card should have trash aura drawn, got " .. #auraDrawnAt)
assert(math.abs(auraDrawnAt[1].cx - (cardX + cardW / 2)) < 0.1, "Trash aura must stay locked on Sentry Turret")

-- Click CONFIRM button -> destroy 1 duplicate of Sentry Turret
local confirmBtn = prepScene.confirmDestroyBtn
prepScene:mousepressed(confirmBtn.x + 5, confirmBtn.y + 5, 1)

assert(prepScene.destroyConfirmCard == nil, "Confirmation dialog should close")
assert(prepScene.deckTrashMode == false, "Trash mode should reset after destruction")
assert(CardUpgradeConfig.Economy.getCardRemovals() == 1, "1 removal should be deducted (leaving 1)")
assert(_G.PersistentState.deck:getCards()[1].quantity == 2, "Only a single copy should be destroyed, leaving 2")
assert(#_G.PersistentState.deck:getCards() == 2, "Both cards still in deck")

-- Now destroy Sniper Turret (single copy)
prepScene:drawDeck()
prepScene:mousepressed(prepScene.deckTrashBtn.x + 5, prepScene.deckTrashBtn.y + 5, 1)
assert(prepScene.deckTrashMode == true, "Trash mode active again")
prepScene:drawDeck()

-- Sniper is at display index 1 -> col 1, row 0
local sniperX = startX + 1 * (cardW + spacingX)
local sniperY = startY
prepScene:mousepressed(sniperX + 10, sniperY + 10, 1)
assert(prepScene.destroyConfirmCard ~= nil and prepScene.destroyConfirmCard.id == "sniper_turret", "Sniper selected for removal")
prepScene:drawDestroyConfirmation(0, 0)

-- Confirm destroying Sniper
prepScene:mousepressed(prepScene.confirmDestroyBtn.x + 5, prepScene.confirmDestroyBtn.y + 5, 1)
assert(CardUpgradeConfig.Economy.getCardRemovals() == 0, "Removals should now be 0")
assert(#_G.PersistentState.deck:getCards() == 1, "Deck should now have only 1 card remaining (Sentry with 2 copies)")
assert(_G.PersistentState.deck:getCards()[1].id == "sentry_turret", "Only Sentry remains")

-- With 0 removals, clicking garbage icon should NOT activate removal mode
prepScene:drawDeck()
prepScene:mousepressed(prepScene.deckTrashBtn.x + 5, prepScene.deckTrashBtn.y + 5, 1)
assert(prepScene.deckTrashMode == false, "Removal mode should not activate with 0 removals")

-- Test Escape key handling
prepScene.deckTrashMode = true
prepScene:keypressed("escape")
assert(prepScene.deckTrashMode == false, "Escape should cancel trash mode")

print("[PASS] test_card_removal completed successfully!")
