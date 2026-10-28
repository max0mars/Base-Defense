_G.love = {
    graphics = {
        getFont = function() return { getHeight = function() return 10 end, getWidth = function() return 10 end } end,
        print = function() end,
        printf = function() end,
        rectangle = function() end,
        setColor = function() end,
        setLineWidth = function() end,
        push = function() end,
        pop = function() end,
        translate = function() end,
        scale = function() end,
        circle = function() end
    },
    mouse = { getPosition = function() return 0, 0 end, setVisible = function() end, setCursor = function() end },
    math = { colorFromBytes = function() return 1, 1, 1, 1 end, random = math.random },
    timer = { getTime = function() return 0 end }
}

_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720
_G.Cursor = { wantHand = false }
_G.PersistentState = { shopLevel = 1, cash = 100 }

local TurretIndex = require("Buildings.TurretIndex")
local Card = require("Game.Cards.Card")
local CardDraw = require("Game.Cards.CardDraw")
local ExecutionType = require("Game.Cards.ExecutionType")

-- 1. Test CardDraw directly from a raw turret reward choice (e.g. Sentry)
local sentryChoice = TurretIndex.common[1]
assert(sentryChoice.id == "sentry", "Expected first common turret to be sentry")
local cd = CardDraw.new(0, 0, sentryChoice)

assert(cd.damageBars > 0, "CardDraw for sentry should have damageBars > 0, got " .. tostring(cd.damageBars))
assert(cd.rangeBars > 0, "CardDraw for sentry should have rangeBars > 0, got " .. tostring(cd.rangeBars))
assert(cd.firerateBars > 0, "CardDraw for sentry should have firerateBars > 0, got " .. tostring(cd.firerateBars))

-- 2. Test Card:getCardDraw with payload.config set to sentryChoice
local cardPayload = {
    rarity = "common",
    buildingClass = sentryChoice.building,
    config = sentryChoice
}
local card = Card:new({
    id = sentryChoice.id,
    name = sentryChoice.name,
    description = sentryChoice.description,
    executionType = ExecutionType.Placement,
    payload = cardPayload
})

local cardDrawFromCard = card:getCardDraw()
assert(cardDrawFromCard.damageBars > 0, "Card:getCardDraw should have damageBars > 0, got " .. tostring(cardDrawFromCard.damageBars))
assert(cardDrawFromCard.rangeBars > 0, "Card:getCardDraw should have rangeBars > 0, got " .. tostring(cardDrawFromCard.rangeBars))
assert(cardDrawFromCard.firerateBars > 0, "Card:getCardDraw should have firerateBars > 0, got " .. tostring(cardDrawFromCard.firerateBars))

-- 3. The merchant's stock has valid stat bars
local Merchant = require("Game.Prep.Merchant")
local stock = Merchant.getStock({})
assert(#stock == 3, "Expected 3 cards from a level 1 merchant")

for _, item in ipairs(stock) do
    if item.card.payload and item.card.payload.buildingClass and item.card.payload.config and item.card.payload.config.iconCategory == "turret" then
        local drawObj = item.card:getCardDraw()
        assert(drawObj.buildingType == "Turret", "Expected buildingType to be Turret")
        assert(drawObj.damageBars > 0, "Shop turret item should have damageBars > 0 for " .. tostring(item.card.name))
        assert(drawObj.rangeBars > 0, "Shop turret item should have rangeBars > 0 for " .. tostring(item.card.name))
        assert(drawObj.firerateBars > 0, "Shop turret item should have firerateBars > 0 for " .. tostring(item.card.name))
    end
end

print("test_shop_turret_stats: All assertions passed!")
