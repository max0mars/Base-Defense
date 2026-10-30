-- Game/Prep/Merchant.lua
-- The traveling merchant: a fixed stock of cards for the visit (no rerolls).
-- Investing in him once per visit raises his level for the next visit, so he
-- brings more cards and better ones.

local RewardPool = require("Game.Rewards.RewardPool")
local RewardIndex = require("Game.Rewards.RewardIndex")
local CardFactory = require("Game.Cards.CardFactory")
local CardIcons = require("Game.Cards.CardIcons")
local Cursor = require("Game.GUI.Cursor")

local Merchant = {}

Merchant.MAX_LEVEL = 5
Merchant.INVEST_BASE_COST = 100 -- doubles every level
Merchant.CARD_COUNT = { 3, 4, 5, 6, 7 }
-- Rarity weights per merchant level
Merchant.ODDS = {
    { common = 75, uncommon = 25, rare = 0,  epic = 0, legendary = 0 },
    { common = 60, uncommon = 32, rare = 7,  epic = 1, legendary = 0 },
    { common = 50, uncommon = 34, rare = 12, epic = 3, legendary = 1 },
    { common = 40, uncommon = 36, rare = 16, epic = 6, legendary = 2 },
    { common = 30, uncommon = 38, rare = 20, epic = 9, legendary = 3 },
}
Merchant.PRICES = { common = 20, uncommon = 30, rare = 40, epic = 50, legendary = 75 }

function Merchant.getLevel()
    local level = (_G.PersistentState and _G.PersistentState.shopLevel) or 1
    return math.max(1, math.min(Merchant.MAX_LEVEL, level))
end

--- Cost to raise the merchant from `level` to the next one.
function Merchant.investCost(level)
    return Merchant.INVEST_BASE_COST * 2 ^ ((level or Merchant.getLevel()) - 1)
end

function Merchant.canInvest(visit)
    local level = Merchant.getLevel()
    return not visit.invested and level < Merchant.MAX_LEVEL
        and (_G.PersistentState.cash or 0) >= Merchant.investCost(level)
end

--- Pays to level the merchant up for next visit. Returns true on success.
function Merchant.invest(visit)
    if not Merchant.canInvest(visit) then return false end
    local ps = _G.PersistentState
    ps.cash = ps.cash - Merchant.investCost(Merchant.getLevel())
    ps.shopLevel = Merchant.getLevel() + 1
    visit.invested = true
    return true
end

--- This visit's stock, rolled the first time it's asked for.
function Merchant.getStock(visit)
    if visit.merchantStock then return visit.merchantStock end
    local level = Merchant.getLevel()
    -- Mock game for eligibility
    local dummyGame = { base = { mainLazer = { id = "standard_main", upgrades = {} } } }
    local pool = RewardPool:new(RewardIndex, dummyGame)
    local stock = {}
    for _, choice in ipairs(pool:generateChoicesWithWeights(Merchant.CARD_COUNT[level], Merchant.ODDS[level])) do
        table.insert(stock, {
            card = CardFactory.fromReward(choice, choice),
            cost = Merchant.PRICES[choice.rarity or "common"] or 50,
            purchased = false,
        })
    end
    visit.merchantStock = stock
    visit.merchantLevel = level
    return stock
end

--- Buys a card into the deck. Returns true on success.
function Merchant.buy(item)
    local ps = _G.PersistentState
    if item.purchased or (ps.cash or 0) < item.cost then return false end
    ps.cash = ps.cash - item.cost
    item.purchased = true
    item.card.quantity = 1
    ps.deck:addCard(item.card)
    return true
end

-- -----------------------------------------------------------------------------
-- Screen
-- -----------------------------------------------------------------------------

local CARD_GAP = 16
local MAX_CARD_W = 200

local function cardRects(area, count)
    local w = math.min(MAX_CARD_W, (area.w - (count - 1) * CARD_GAP) / count)
    local h = w * 1.4
    local startX = area.x + (area.w - (count * w + (count - 1) * CARD_GAP)) / 2
    local rects = {}
    for i = 1, count do
        rects[i] = { x = startX + (i - 1) * (w + CARD_GAP), y = area.y + 40, w = w, h = h }
    end
    return rects
end

local function investButton(area)
    return { x = area.x + (area.w - 360) / 2, y = area.y + area.h - 70, w = 360, h = 44 }
end

local function inside(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function Merchant.draw(scene, visit, area, mx, my)
    local stock = Merchant.getStock(visit)
    local level = Merchant.getLevel()
    love.graphics.setColor(1, 0.85, 0.4, 1)
    love.graphics.printf("TRAVELING MERCHANT  -  LEVEL " .. visit.merchantLevel, area.x, area.y, area.w, "center")

    local rects = cardRects(area, #stock)
    local cash = _G.PersistentState.cash or 0
    local hoveredIcon, iconX, iconY
    for i, item in ipairs(stock) do
        local r = rects[i]
        if item.purchased then
            love.graphics.setColor(1, 1, 1, 0.08)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8)
            love.graphics.setColor(0.6, 0.6, 0.65, 0.8)
            love.graphics.printf("SOLD", r.x, r.y + r.h / 2 - 7, r.w, "center")
        else
            local hovered = inside(r, mx, my)
            if hovered then
                Cursor.wantHand = true
                Cursor.setIcon("buyCard")
            end
            local cardDraw = item.card.getCardDraw and item.card:getCardDraw()
            if cardDraw then
                cardDraw:draw(r.x, r.y, r.w, r.h, hovered)
                if hovered then
                    hoveredIcon, iconX, iconY = cardDraw:iconAt(mx, my, r.x, r.y, r.w, r.h)
                end
            end
            love.graphics.setColor(cash >= item.cost and {0.2, 0.8, 0.2, 1} or {0.8, 0.2, 0.2, 1})
            love.graphics.printf("$" .. item.cost, r.x, r.y + r.h + 8, r.w, "center")
        end
    end

    -- Hovering a synergy icon explains it (drawn last so it sits over neighbouring cards)
    if hoveredIcon then
        CardIcons.drawTooltip(hoveredIcon, iconX, iconY)
    end

    -- Invest
    local btn = investButton(area)
    local label, enabled
    if visit.invested then
        label, enabled = "INVESTED - LEVEL " .. level .. " NEXT VISIT", false
    elseif level >= Merchant.MAX_LEVEL then
        label, enabled = "MERCHANT AT MAX LEVEL", false
    else
        label = "INVEST $" .. Merchant.investCost(level) .. "  (LEVEL " .. (level + 1) .. " NEXT VISIT)"
        enabled = cash >= Merchant.investCost(level)
    end
    btn.label = label
    btn.color = enabled and {0.45, 0.32, 0.08, 1} or {0.2, 0.18, 0.14, 1}
    btn.hoverColor = enabled and {0.62, 0.45, 0.12, 1} or btn.color
    btn.borderColor = enabled and {0.95, 0.75, 0.3, 1} or {0.45, 0.4, 0.3, 1}
    scene:drawButton(btn, enabled and mx or -1, enabled and my or -1)
    love.graphics.setColor(0.75, 0.75, 0.8, 0.9)
    love.graphics.printf("Investing lets him bring more cards, and rarer ones, on his next visit.",
        area.x, btn.y + btn.h + 8, area.w, "center")
end

function Merchant.mousepressed(scene, visit, area, x, y)
    if inside(investButton(area), x, y) then
        Merchant.invest(visit)
        return true
    end
    local stock = Merchant.getStock(visit)
    for i, r in ipairs(cardRects(area, #stock)) do
        if inside(r, x, y) then
            Merchant.buy(stock[i])
            return true
        end
    end
    return false
end

return Merchant
