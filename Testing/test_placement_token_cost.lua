-- Regression: with exactly enough tokens for a building card, placing it on a locked
-- slot unlocked the slot and then charged the card, leaving the player at -1 tokens.
-- Placement must cover the slot unlock cost plus the card cost, and the hover tooltip
-- must agree with what a click will do.

local function stubNamespace()
    return setmetatable({}, { __index = function()
        return function()
            return setmetatable({}, { __index = function() return function() return 10, 10 end end })
        end
    end })
end
_G.love = {
    graphics = stubNamespace(), mouse = stubNamespace(), keyboard = stubNamespace(), audio = stubNamespace(),
    filesystem = stubNamespace(), window = stubNamespace(), image = stubNamespace(), sound = stubNamespace(),
    math = { random = math.random, colorFromBytes = function(...) return ... end },
    timer = { getTime = os.clock }
}
love.mouse.getPosition = function() return 0, 0 end
love.graphics.getWidth = function() return 1280 end
love.graphics.getHeight = function() return 720 end
love.graphics.getDimensions = function() return 1280, 720 end
_G.VIRTUAL_WIDTH, _G.VIRTUAL_HEIGHT = 1280, 720
_G.SetGameScissor = function() end
_G.unpack = _G.unpack or table.unpack

local realPrint = print
print = function() end -- silence game logging

local Layout = require("Game.GUI.Layout")
local ExecutionType = require("Game.Cards.ExecutionType")
local MainLazer = require("Buildings.MainTurrets.MainLazer")

_G.PersistentState = {
    selectedMainTurret = "MainLazer", globalDifficulty = 1, battlesCompleted = 0, cash = 0,
    discoveredEnemies = { Grunt = true }, deck = MainLazer.getStartingDeck()
}
local game = require("Game.Core.GameManager")
game:load(nil, false)
game:setState("startup")

realPrint("--- STARTING PLACEMENT TOKEN COST VERIFICATION ---")

local base = game.base
local grid = base.buildGrid

-- A 1x1 turret card from the starting deck
local turretCard
for _, pile in ipairs({ game.hand, game.drawPile }) do
    for _, c in ipairs(pile) do
        if c.id == "sentry" then turretCard = c end
    end
end
assert(turretCard, "Starting deck should contain a sentry card")
if not turretCard.game then turretCard.game = game end

-- A locked slot the player can see (adjacent to the unlocked area)
local lockedSlot
for slot = 1, grid.width * grid.height do
    if not grid.unlocked[slot] and not grid.buildings[slot] and base:isSlotVisible(slot) then
        lockedSlot = slot
        break
    end
end
assert(lockedSlot, "Expected a visible locked slot")
local unlockCost = base:getSlotPrice(lockedSlot)

local function slotScreenPos(slot)
    local gx = (slot - 1) % grid.width
    local gy = math.floor((slot - 1) / grid.width)
    local wx = grid.x + gx * grid.cellSize + grid.cellSize / 2
    local wy = grid.y + gy * grid.cellSize + grid.cellSize / 2
    return Layout.worldToScreen(wx, wy)
end

local function selectCard(tokens)
    game.tokens = tokens
    game.activeCard = turretCard
    game.inputMode = "placing"
    game.blueprint = turretCard:execute(game)
    assert(game.blueprint, "Sentry card should produce a blueprint")
end

local function occupied(slot) return grid.buildings[slot] ~= nil end

-- 1. Exactly the card cost: the locked slot must be refused, no tokens spent
local cardCost = turretCard:getCost()
selectCard(cardCost)
local sx, sy = slotScreenPos(lockedSlot)
game.inputHandler:mousepressed(sx, sy, 1)
assert(game.tokens == cardCost, string.format("Tokens should stay at %d, got %d", cardCost, game.tokens))
assert(not grid.unlocked[lockedSlot], "Locked slot must stay locked when the player cannot cover unlock + card")
assert(not occupied(lockedSlot), "Building must not be placed on the locked slot")
assert(game.inputMode == "placing", "Player should stay in placing mode to pick another slot")
realPrint("[PASS] Exactly the card cost cannot unlock a slot (tokens stay at " .. game.tokens .. ").")

-- 1b. While placing, the locked slot is drawn red (can't cover unlock + card),
-- though outside placement the same tokens could unlock it
assert(not base:canAffordUnlock(unlockCost), "While placing, the locked slot counts as unaffordable (red)")
game.inputMode = "idle"
assert(base:canAffordUnlock(unlockCost), "Outside placement, the same tokens can unlock it (green)")
game.inputMode = "placing"
assert(pcall(base.draw, base), "The base draws its red locked slots while placing")
realPrint("[PASS] While placing, slots the player can't afford with the card are shown red.")

-- 2. The hover tooltip agrees: unaffordable
game.inputHandler.mouseX, game.inputHandler.mouseY = Layout.mouseToField(sx, sy)
game.inputHandler.screenMouseX, game.inputHandler.screenMouseY = sx, sy
love.mouse.getPosition = function() return sx, sy end
game.inputHandler:update(0)
local tip = base.hoverTooltip
assert(tip and tip.affordable == false, "Hover tooltip should mark the locked slot unaffordable")
assert(base.invalidSlots and base.invalidSlots[1] == lockedSlot, "Unaffordable slot should preview as invalid (red)")
assert(base.selectedSlots == nil, "Unaffordable slot should not preview as a valid selection")
realPrint("[PASS] Hover marks the locked slot unaffordable and previews it as invalid.")

-- 3. Card cost plus unlock cost: placement succeeds and lands exactly at 0
game.inputHandler:mousepressed(0, 0, 2) -- cancel
selectCard(cardCost + unlockCost)
game.inputHandler:update(0)
assert(base.hoverTooltip and base.hoverTooltip.affordable == true, "Hover tooltip should mark the slot affordable")
assert(base.selectedSlots and base.invalidSlots == nil, "Affordable slot should preview as a valid selection")
game.inputHandler:mousepressed(sx, sy, 1)
assert(occupied(lockedSlot), "Building should be placed once unlock + card are covered")
assert(game.tokens == 0, "Tokens should end at exactly 0, got " .. game.tokens)
realPrint("[PASS] Unlock + card cost places the building and ends at 0 tokens.")

-- 4. Unlocked slot with exactly the card cost still works
local freeSlot
for slot = 1, grid.width * grid.height do
    if grid.unlocked[slot] and not grid.buildings[slot] then freeSlot = slot break end
end
assert(freeSlot, "Expected a free unlocked slot")
for _, pile in ipairs({ game.hand, game.drawPile, game.discardPile }) do
    for _, c in ipairs(pile) do
        if c.id == "sentry" and c ~= turretCard then turretCard = c end
    end
end
if not turretCard.game then turretCard.game = game end
game.inputMode = "idle"
selectCard(cardCost)
local fx, fy = slotScreenPos(freeSlot)
game.inputHandler:mousepressed(fx, fy, 1)
assert(occupied(freeSlot), "Building should place on an unlocked slot with exactly the card cost")
assert(game.tokens == 0, "Tokens should end at 0, got " .. game.tokens)
realPrint("[PASS] Unlocked slot with exactly the card cost places and ends at 0 tokens.")

realPrint("--- ALL PLACEMENT TOKEN COST TESTS PASSED ---")
