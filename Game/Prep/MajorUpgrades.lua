-- Game/Prep/MajorUpgrades.lua
-- Permanent run upgrades bought after every fifth battle. Buy as many as you
-- can afford. Each upgrade starts at `basePrice` and rises by `priceStep` every
-- time it's bought; some stop after `maxBuys`.

local Scouting = require("Game.Prep.Scouting")
local Neon = require("Game.GUI.Neon")

local MajorUpgrades = {}

MajorUpgrades.list = {
    {
        id = "card_draw", name = "CARD DRAW", basePrice = 150, priceStep = 150, maxBuys = 3,
        desc = "Draw 1 more card at the start of battle and between waves.",
        value = function(ps) return (ps.startingHandSize or 4) .. " cards" end,
        apply = function(ps)
            ps.startingHandSize = (ps.startingHandSize or 4) + 1
            ps.waveCompleteDrawSize = (ps.waveCompleteDrawSize or 4) + 1
        end,
    },
    {
        id = "tokens", name = "TOKEN INCOME", basePrice = 150, priceStep = 150, maxBuys = 3,
        desc = "Start battles and waves with 1 more token.",
        value = function(ps) return (ps.startingTokens or 3) .. " tokens" end,
        apply = function(ps)
            ps.startingTokens = (ps.startingTokens or 3) + 1
            ps.incomeTokens = (ps.incomeTokens or 3) + 1
        end,
    },
    {
        id = "slots", name = "STARTING SLOTS", basePrice = 100, priceStep = 50,
        desc = "Unlock 4 more base slots at the start of each battle.",
        value = function(ps) return "+" .. 4 * (ps.startBattleExtraSlotsUnlocked or 0) .. " slots" end,
        apply = function(ps)
            ps.startBattleExtraSlotsUnlocked = (ps.startBattleExtraSlotsUnlocked or 0) + 1
        end,
    },
    {
        id = "scouting", name = "SCOUTING", basePrice = 100, priceStep = 100,
        desc = "Scouting reports reveal the next tier of enemies.",
        value = function() return "Level " .. Scouting.getLevel() end,
        isMaxed = function() return Scouting.getLevel() >= Scouting.MAX_LEVEL end,
        apply = function(ps) ps.scoutingLevel = Scouting.getLevel() + 1 end,
    },
    {
        id = "max_mana", name = "MAX MANA", basePrice = 80, priceStep = 40, maxBuys = 4,
        desc = "Hold 25 more mana.",
        value = function(ps) return (ps.maxMana or 100) .. " mana" end,
        apply = function(ps) ps.maxMana = (ps.maxMana or 100) + 25 end,
    },
    {
        id = "mana_regen", name = "MANA REGEN", basePrice = 80, priceStep = 40, maxBuys = 4,
        desc = "Regain 10 more mana after each wave.",
        value = function(ps) return (ps.manaRegenPerWave or 15) .. " per wave" end,
        apply = function(ps) ps.manaRegenPerWave = (ps.manaRegenPerWave or 15) + 10 end,
    },
}

local byId = {}
for _, up in ipairs(MajorUpgrades.list) do byId[up.id] = up end

function MajorUpgrades.get(id) return byId[id] end

function MajorUpgrades.timesBought(id)
    local bought = _G.PersistentState.upgradePurchases
    return bought and bought[id] or 0
end

function MajorUpgrades.price(id)
    local up = byId[id]
    return up.basePrice + up.priceStep * MajorUpgrades.timesBought(id)
end

function MajorUpgrades.isMaxed(id)
    local up = byId[id]
    if up.maxBuys and MajorUpgrades.timesBought(id) >= up.maxBuys then return true end
    return up.isMaxed ~= nil and up.isMaxed()
end

function MajorUpgrades.canBuy(id)
    return not MajorUpgrades.isMaxed(id) and (_G.PersistentState.cash or 0) >= MajorUpgrades.price(id)
end

--- Buys one level of an upgrade. Returns true on success.
function MajorUpgrades.buy(id)
    if not MajorUpgrades.canBuy(id) then return false end
    local ps = _G.PersistentState
    ps.cash = ps.cash - MajorUpgrades.price(id)
    byId[id].apply(ps)
    ps.upgradePurchases = ps.upgradePurchases or {}
    ps.upgradePurchases[id] = MajorUpgrades.timesBought(id) + 1
    return true
end

-- -----------------------------------------------------------------------------
-- Screen
-- -----------------------------------------------------------------------------

local COLS = 3
local GAP = 24

local function inside(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function tileRect(area, i)
    local rows = math.ceil(#MajorUpgrades.list / COLS)
    local w = (area.w - (COLS - 1) * GAP) / COLS
    local h = (area.h - 40 - (rows - 1) * GAP) / rows
    local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
    return { x = area.x + col * (w + GAP), y = area.y + 40 + row * (h + GAP), w = w, h = h }
end

local function buyButton(tile)
    return { x = tile.x + 20, y = tile.y + tile.h - 54, w = tile.w - 40, h = 38 }
end

--- Screen rect of the i-th upgrade's buy button.
function MajorUpgrades.buyButtonRect(area, i)
    return buyButton(tileRect(area, i))
end

function MajorUpgrades.draw(scene, visit, area, mx, my)
    love.graphics.setColor(0.4, 0.85, 1, 1)
    love.graphics.printf("MAJOR UPGRADES", area.x, area.y, area.w, "center")
    local ps = _G.PersistentState
    for i, up in ipairs(MajorUpgrades.list) do
        local t = tileRect(area, i)
        Neon.panel(t.x, t.y, t.w, t.h, { 0.3, 0.6, 0.85 })
        love.graphics.setLineWidth(1)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(up.name, t.x, t.y + 14, t.w, "center")
        love.graphics.setColor(0.75, 0.8, 0.9, 1)
        love.graphics.printf(up.desc, t.x + 16, t.y + 40, t.w - 32, "center")
        love.graphics.setColor(0.4, 0.85, 1, 1)
        love.graphics.printf("Now: " .. up.value(ps), t.x, t.y + t.h - 80, t.w, "center")

        local btn = buyButton(t)
        local maxed = MajorUpgrades.isMaxed(up.id)
        local enabled = MajorUpgrades.canBuy(up.id)
        btn.label = maxed and "MAX" or ("BUY  $" .. MajorUpgrades.price(up.id))
        btn.color = enabled and {0.1, 0.4, 0.2, 1} or {0.16, 0.16, 0.2, 1}
        btn.hoverColor = enabled and {0.15, 0.58, 0.3, 1} or btn.color
        btn.borderColor = enabled and {0.3, 0.9, 0.5, 1} or {0.35, 0.35, 0.4, 1}
        scene:drawButton(btn, enabled and mx or -1, enabled and my or -1)
    end
end

function MajorUpgrades.mousepressed(scene, visit, area, x, y)
    for i, up in ipairs(MajorUpgrades.list) do
        if inside(buyButton(tileRect(area, i)), x, y) then
            MajorUpgrades.buy(up.id)
            return true
        end
    end
    return false
end

return MajorUpgrades
