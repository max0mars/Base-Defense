-- Testing/test_hand_draw_anim.lua
-- Hand draw animation: new cards slide in and flip one after another, and can't
-- be clicked until they've landed.

package.path = package.path .. ";./?.lua"

local noop = function() end
local fontStub = { getWidth = function() return 10 end, getHeight = function() return 10 end }
_G.love = setmetatable({
    timer = { getTime = function() return 0 end },
    mouse = { getPosition = function() return -1000, -1000 end },
    graphics = setmetatable({ newFont = function() return fontStub end, getFont = function() return fontStub end },
        { __index = function() return noop end }),
}, { __index = function() return setmetatable({}, { __index = function() return noop end }) end })
_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720

local failures = 0
local function assert(condition, message)
    if not condition then
        print("[FAIL] " .. message)
        failures = failures + 1
    else
        print("[PASS] " .. message)
    end
end

local HandUI = require("Game.GUI.HandUI")

local function newCard(name)
    return { name = name, getCost = function() return 0 end }
end

local game = {
    hand = {}, tokens = 10, mana = 100, pulseTimer = 0,
    isState = function() return false end,
    isSpellCard = function() return false end,
}
local hand = HandUI:new(game)

local function step(seconds)
    for _ = 1, math.floor(seconds * 100 + 0.5) do hand:update(0.01) end
end

-- 1. The starting hand animates in, one card after another
local a, b, c = newCard("a"), newCard("b"), newCard("c")
game.hand = { a, b, c }
hand:update(0)
assert(hand.drawAnims[a] and hand.drawAnims[b] and hand.drawAnims[c], "every new card gets a draw animation")
assert(hand.drawAnims[a] > hand.drawAnims[b] and hand.drawAnims[b] > hand.drawAnims[c], "cards drawn together are staggered")

-- 2. Cards can't be clicked while they're coming in
local deckY = VIRTUAL_HEIGHT - 210 - 20
local clickX, clickY = hand.cardX[a] + 10, deckY + 10
hand:mousepressed(clickX, clickY, 1)
assert(game.activeCard == nil, "a card mid animation can't be selected")

-- 3. Animations finish and the cards become playable
step(2)
assert(next(hand.drawAnims) == nil, "animations finish")
hand:mousepressed(clickX, clickY, 1)
assert(game.activeCard == a, "a landed card can be selected")
game.activeCard = nil

-- 4. Only newly drawn cards animate; the rest glide to their new slot
local oldX, oldBX = hand.cardX[a], hand.cardX[b]
local d = newCard("d")
for _ = 1, 4 do table.insert(game.hand, newCard("filler")) end
table.insert(game.hand, d)
hand:update(0)
assert(hand.drawAnims[d] and not hand.drawAnims[a], "cards already in hand don't animate again")
assert(hand.cardX[a] == oldX, "existing cards start from where they were")
-- The hand spans the tray from 12px in, up to 12px short of its control buttons
local Layout = require("Game.GUI.Layout")
local handWidth = (Layout.tray.x + Layout.tray.w - Layout.trayActionsW) - 12 - (Layout.tray.x + 12)
local newBX = oldX + 150 + (handWidth - 8 * 150) / 7
hand:update(0.02)
assert(hand.cardX[b] < oldBX and hand.cardX[b] > newBX + 1, "cards glide toward the bunched-up layout")
step(1)
assert(math.abs(hand.cardX[b] - newBX) < 0.5, "and settle in their new slot")

-- 5. A card that leaves and comes back animates again
table.remove(game.hand, 1)
hand:update(0)
table.insert(game.hand, a)
hand:update(0)
assert(hand.drawAnims[a], "a card drawn again animates again")

-- 6. Hand swap: the old hand falls off screen, then the new hand comes in
step(2)
local old = game.hand
local oldA = old[1]
local oldAX = hand.cardX[oldA]
hand:dropCards(old)
game.hand = { newCard("s1"), newCard("s2") }
hand:update(0)
assert(#hand.falling == #old, "every discarded card falls")
assert(hand.falling[1].card == oldA and hand.falling[1].x == oldAX, "cards fall from where they were")
assert(hand.drawAnims[game.hand[1]] <= -0.45, "the new hand waits for the old one to start falling")
step(0.05)
assert(hand.falling[1].y < VIRTUAL_HEIGHT - 210 - 20, "discarded cards hop up first")
step(1.5)
assert(#hand.falling == 0, "discarded cards are gone once off screen")
assert(next(hand.drawAnims) == nil, "the new hand has landed")

-- A card that never came on screen doesn't fall
local waiting = newCard("waiting")
game.hand = { waiting }
hand:update(0)
hand.drawAnims[waiting] = -1
hand:dropCards(game.hand)
assert(#hand.falling == 0, "a card still waiting to come in doesn't fall")

-- 7. Battle start: the kept mulligan cards fly from the mulligan screen into the hand
local drawnAt = {}
local function drawnCard(name)
    local card = newCard(name)
    card.getCardDraw = function()
        return { draw = function(_, x, y, w, h) drawnAt[card] = { x = x, y = y, w = w, h = h } end }
    end
    return card
end
local state = "mulligan"
local mg = {
    hand = { drawnCard("m1"), drawnCard("m2") }, tokens = 10, mana = 100, pulseTimer = 0,
    isState = function(_, s) return s == state end,
    isSpellCard = function() return false end,
    getMulliganLayout = function()
        return { cardW = 200, cardH = 280, cards = { { x = 400, y = 200 }, { x = 620, y = 200 } } }
    end,
}
local mh = HandUI:new(mg)
local function mstep(seconds)
    for _ = 1, math.floor(seconds * 100 + 0.5) do mh:update(0.01) end
end
mstep(1)
assert(next(mh.drawAnims) == nil and next(mh.flyAnims) == nil, "nothing animates during the mulligan")
state = "startup"
mh:update(0)
local m1, m2 = mg.hand[1], mg.hand[2]
assert(mh.flyAnims[m1] and mh.flyAnims[m2], "kept cards fly in when the battle starts")
assert(next(mh.drawAnims) == nil, "and don't also do the draw animation")
mh:draw()
assert(drawnAt[m1].x == 400 and drawnAt[m1].w == 200, "a card starts where the mulligan showed it")
mh:mousepressed(mh.cardX[m1] + 10, VIRTUAL_HEIGHT - 210 - 20 + 10, 1)
assert(mg.activeCard == nil, "a card in flight can't be selected")

-- Ease in and out: slow at both ends, fast in the middle
local function flownAfter(seconds)
    mh.flyAnims[m1].t = seconds
    mh:draw()
    return (400 - drawnAt[m1].x) / (400 - mh.cardX[m1])
end
local early, mid, late = flownAfter(0.06), flownAfter(0.3), flownAfter(0.54)
assert(early < 0.02, "it starts slowly (" .. early .. ")")
assert(math.abs(mid - 0.5) < 0.01, "it's halfway at the midpoint")
assert(late > 0.98, "and settles gently into its slot (" .. late .. ")")

mstep(1)
assert(next(mh.flyAnims) == nil, "the flight finishes")
mh:mousepressed(mh.cardX[m1] + 10, VIRTUAL_HEIGHT - 210 - 20 + 10, 1)
assert(mg.activeCard == m1, "a landed card can be selected")

-- 8. A hand drawn after the hand's update in a frame (e.g. the build hand at the
--    end of a wave) isn't shown face-up for that frame before animating in
mstep(1)
local fresh1, fresh2 = drawnCard("f1"), drawnCard("f2")
mg.hand = { fresh1, fresh2 }
drawnAt = {}
mh:draw()
assert(drawnAt[fresh1] == nil and drawnAt[fresh2] == nil, "freshly drawn cards aren't drawn at their slots before animating")
mh:update(0)
assert(mh.drawAnims[fresh1] and mh.drawAnims[fresh2], "they come in with the draw animation")

print(string.format("\n%d failure(s)", failures))
if failures > 0 then os.exit(1) end
