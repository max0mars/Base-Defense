-- Game/Prep/Alchemist.lua
-- The alchemist transmutes 3 of one typed material into 1 Universal Essence,
-- and sells a few typed materials at the day's market price.

local MaterialRegistry = require("Game.Cards.MaterialRegistry")
local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")
local Cursor = require("Game.GUI.Cursor")

local Alchemist = {}

Alchemist.TRANSMUTE_COST = 3
Alchemist.MAX_OFFERS = 3
Alchemist.MAX_STOCK = 3
Alchemist.PRICE_MIN = 25
Alchemist.PRICE_MAX = 80
Alchemist.PRICE_STEP = 5

local Economy = CardUpgradeConfig.Economy

--- Market offers for this visit: 1-3 distinct typed materials, each with 1-3 in
--- stock at a random price per unit. Rolled the first time it's asked for.
function Alchemist.getOffers(visit)
    if visit.alchemistOffers then return visit.alchemistOffers end
    local typed = MaterialRegistry.getTyped()
    for i = #typed, 2, -1 do
        local j = math.random(i)
        typed[i], typed[j] = typed[j], typed[i]
    end
    local offers = {}
    for i = 1, math.min(math.random(1, Alchemist.MAX_OFFERS), #typed) do
        local steps = (Alchemist.PRICE_MAX - Alchemist.PRICE_MIN) / Alchemist.PRICE_STEP
        offers[i] = {
            materialId = typed[i].id,
            stock = math.random(1, Alchemist.MAX_STOCK),
            price = Alchemist.PRICE_MIN + math.random(0, steps) * Alchemist.PRICE_STEP,
        }
    end
    visit.alchemistOffers = offers
    return offers
end

--- Buys one unit from an offer. Returns true on success.
function Alchemist.buy(offer)
    local ps = _G.PersistentState
    if offer.stock <= 0 or (ps.cash or 0) < offer.price then return false end
    ps.cash = ps.cash - offer.price
    offer.stock = offer.stock - 1
    Economy.addResource(offer.materialId, 1)
    return true
end

function Alchemist.canTransmute(materialId)
    return Economy.getResource(materialId) >= Alchemist.TRANSMUTE_COST
end

--- Turns 3 of one typed material into 1 Universal Essence. Returns true on success.
function Alchemist.transmute(materialId)
    local mat = MaterialRegistry.get(materialId)
    if not mat or mat.universal or not Alchemist.canTransmute(materialId) then return false end
    -- Straight from the material: Universal Essence must never cover the cost
    Economy.addResource(materialId, -Alchemist.TRANSMUTE_COST)
    Economy.addResource(MaterialRegistry.UNIVERSAL, 1)
    return true
end

--- The typed material picked for transmuting (cycled with the arrows).
function Alchemist.selectedMaterial(visit)
    local typed = MaterialRegistry.getTyped()
    visit.alchemistSelected = ((visit.alchemistSelected or 1) - 1) % #typed + 1
    return typed[visit.alchemistSelected]
end

function Alchemist.cycle(visit, step)
    visit.alchemistSelected = (visit.alchemistSelected or 1) + step
    return Alchemist.selectedMaterial(visit)
end

-- -----------------------------------------------------------------------------
-- Screen
-- -----------------------------------------------------------------------------

local function inside(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function panels(area)
    local w = (area.w - 40) / 2
    local top = area.y + 40
    local h = area.h - 60
    return { x = area.x, y = top, w = w, h = h }, { x = area.x + w + 40, y = top, w = w, h = h }
end

local function transmuteLayout(panel)
    local cy = panel.y + 120
    return {
        left = { x = panel.x + 30, y = cy - 20, w = 40, h = 40 },
        right = { x = panel.x + panel.w - 70, y = cy - 20, w = 40, h = 40 },
        nameY = cy - 10,
        button = { x = panel.x + (panel.w - 280) / 2, y = panel.y + 210, w = 280, h = 44 },
    }
end

local function offerButton(panel, i)
    return { x = panel.x + panel.w - 150, y = panel.y + 70 + (i - 1) * 80, w = 120, h = 40 }
end

local function drawPanel(p, title, color)
    love.graphics.setColor(0.06, 0.07, 0.1, 0.9)
    love.graphics.rectangle("fill", p.x, p.y, p.w, p.h, 10)
    love.graphics.setColor(color)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", p.x, p.y, p.w, p.h, 10)
    love.graphics.setLineWidth(1)
    love.graphics.printf(title, p.x, p.y + 16, p.w, "center")
end

local function drawArrow(r, dir, mx, my)
    local hovered = inside(r, mx, my)
    if hovered then Cursor.wantHand = true end
    love.graphics.setColor(hovered and {0.7, 0.5, 1, 1} or {0.5, 0.35, 0.8, 1})
    local cx, cy = r.x + r.w / 2, r.y + r.h / 2
    love.graphics.polygon("fill", cx + dir * 10, cy, cx - dir * 8, cy - 12, cx - dir * 8, cy + 12)
end

local function styleButton(btn, enabled, color, hover, border)
    btn.color = enabled and color or {0.16, 0.16, 0.2, 1}
    btn.hoverColor = enabled and hover or btn.color
    btn.borderColor = enabled and border or {0.35, 0.35, 0.4, 1}
end

function Alchemist.draw(scene, visit, area, mx, my)
    love.graphics.setColor(0.75, 0.55, 1, 1)
    love.graphics.printf("THE ALCHEMIST", area.x, area.y, area.w, "center")
    local left, right = panels(area)

    -- Transmute
    drawPanel(left, "TRANSMUTE", {0.6, 0.4, 1, 1})
    local lay = transmuteLayout(left)
    local mat = Alchemist.selectedMaterial(visit)
    drawArrow(lay.left, -1, mx, my)
    drawArrow(lay.right, 1, mx, my)
    love.graphics.setColor(mat.color)
    love.graphics.printf(mat.name, left.x, lay.nameY, left.w, "center")
    love.graphics.setColor(0.8, 0.8, 0.85, 1)
    love.graphics.printf("You have " .. Economy.getResource(mat.id), left.x, lay.nameY + 24, left.w, "center")
    local universal = MaterialRegistry.get(MaterialRegistry.UNIVERSAL)
    local btn = lay.button
    local enabled = Alchemist.canTransmute(mat.id)
    btn.label = Alchemist.TRANSMUTE_COST .. " " .. mat.shortName .. "  ->  1 " .. universal.name
    styleButton(btn, enabled, {0.32, 0.18, 0.5, 1}, {0.45, 0.26, 0.7, 1}, {0.75, 0.55, 1, 1})
    scene:drawButton(btn, enabled and mx or -1, enabled and my or -1)

    -- Market
    drawPanel(right, "TODAY'S MARKET", {1, 0.8, 0.3, 1})
    local cash = _G.PersistentState.cash or 0
    for i, offer in ipairs(Alchemist.getOffers(visit)) do
        local offerMat = MaterialRegistry.get(offer.materialId)
        local ob = offerButton(right, i)
        love.graphics.setColor(offerMat.color)
        love.graphics.printf(offerMat.name, right.x + 30, ob.y + 4, right.w - 200, "left")
        love.graphics.setColor(0.75, 0.75, 0.8, 1)
        love.graphics.printf(offer.stock .. " in stock", right.x + 30, ob.y + 22, right.w - 200, "left")
        local canBuy = offer.stock > 0 and cash >= offer.price
        ob.label = offer.stock > 0 and ("$" .. offer.price) or "SOLD OUT"
        styleButton(ob, canBuy, {0.1, 0.4, 0.2, 1}, {0.15, 0.58, 0.3, 1}, {0.3, 0.9, 0.5, 1})
        scene:drawButton(ob, canBuy and mx or -1, canBuy and my or -1)
    end
end

function Alchemist.mousepressed(scene, visit, area, x, y)
    local left, right = panels(area)
    local lay = transmuteLayout(left)
    if inside(lay.left, x, y) then Alchemist.cycle(visit, -1) return true end
    if inside(lay.right, x, y) then Alchemist.cycle(visit, 1) return true end
    if inside(lay.button, x, y) then
        Alchemist.transmute(Alchemist.selectedMaterial(visit).id)
        return true
    end
    for i, offer in ipairs(Alchemist.getOffers(visit)) do
        if inside(offerButton(right, i), x, y) then
            Alchemist.buy(offer)
            return true
        end
    end
    return false
end

return Alchemist
