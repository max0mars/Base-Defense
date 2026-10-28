-- ItemPickerUI.lua: Testing-mode menu listing every turret / buff / spell /
-- instant / main-lazer upgrade in the game, sorted by type (then rarity, then
-- name). Clicking one adds it to your hand as a card. Toggle with 'g' (testing
-- mode) or F4 (developer mode).

local NormalRewardIndex  = require("Game.Rewards.RewardIndex")

local CardFactory        = require("Game.Cards.CardFactory")
local DevMode            = require("Game.Dev.DevMode")


local ItemPickerUI = {}
ItemPickerUI.__index = ItemPickerUI

-- Category swatch colors.
local CATEGORY_COLORS = {
    turret  = { 0.0, 0.85, 1.0 },
    buff    = { 0.2, 0.9, 0.4 },
    upgrade = { 1.0, 0.8, 0.2 },
    spell   = { 0.7, 0.4, 1.0 },
    instant = { 1.0, 0.45, 0.6 },
}

local RARITIES = { "common", "uncommon", "rare", "epic", "legendary" }

-- Listing order: by type, then rarity, then name
local CATEGORY_ORDER = { turret = 1, buff = 2, spell = 3, instant = 4, upgrade = 5 }
local RARITY_ORDER = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5 }

-- Layout constants.
local NUM_COLS  = 3
local CELL_W    = 228
local CELL_H    = 24
local GAP       = 5
local TITLE_H   = 44
local PAD       = 14

local function labelFor(item)
    return item.name or item.id or "?"
end

function ItemPickerUI:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    obj.isActive = false

    -- Aggregate every item, de-duplicated by id.
    obj.items = {}
    local seen = {}
    local function add(item, rarity)
        if not item or not item.id or seen[item.id] then return end
        seen[item.id] = true
        obj.items[#obj.items + 1] = {
            item = item,
            label = labelFor(item),
            category = item.iconCategory or (CATEGORY_COLORS[item.type] and item.type) or "turret",
            rarity = item.rarity or rarity or "common",
        }
    end

    for _, rarity in ipairs(RARITIES) do
        for _, item in ipairs(NormalRewardIndex[rarity] or {}) do add(item, rarity) end
    end
    table.sort(obj.items, function(a, b)
        local ca, cb = CATEGORY_ORDER[a.category] or 99, CATEGORY_ORDER[b.category] or 99
        if ca ~= cb then return ca < cb end
        local ra, rb = RARITY_ORDER[a.rarity] or 99, RARITY_ORDER[b.rarity] or 99
        if ra ~= rb then return ra < rb end
        return a.label < b.label
    end)

    -- Precompute panel geometry.
    obj.numRows = math.ceil(#obj.items / NUM_COLS)
    local gridW = NUM_COLS * CELL_W + (NUM_COLS - 1) * GAP
    obj.panelW = gridW + PAD * 2
    obj.panelH = TITLE_H + obj.numRows * (CELL_H + GAP) + PAD
    obj.panelX = (VIRTUAL_WIDTH - obj.panelW) / 2
    obj.panelY = (VIRTUAL_HEIGHT - obj.panelH) / 2

    return obj
end

function ItemPickerUI:update(dt) end

-- Returns the screen rect for the i-th item cell.
function ItemPickerUI:cellRect(i)
    local col = (i - 1) % NUM_COLS
    local row = math.floor((i - 1) / NUM_COLS)
    local x = self.panelX + PAD + col * (CELL_W + GAP)
    local y = self.panelY + TITLE_H + row * (CELL_H + GAP)
    return x, y, CELL_W, CELL_H
end

function ItemPickerUI:draw()
    if not self.isActive or not (self.game.testingMode or DevMode.isActive()) then return end

    local mx, my = love.mouse.getPosition()

    -- Dim background.
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

    -- Panel.
    love.graphics.setColor(0.03, 0.05, 0.09, 0.96)
    love.graphics.rectangle("fill", self.panelX, self.panelY, self.panelW, self.panelH, 6)
    love.graphics.setColor(0.0, 0.7, 1.0, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", self.panelX, self.panelY, self.panelW, self.panelH, 6)

    -- Title.
    love.graphics.setColor(0.0, 0.85, 1.0, 0.9)
    love.graphics.printf("ITEM PICKER", self.panelX, self.panelY + 8, self.panelW, "center")
    love.graphics.setColor(0.6, 0.6, 0.65, 1)
    love.graphics.printf("click an item to add it to your hand   ·   'g' / F4 to close", self.panelX, self.panelY + 22, self.panelW, "center")

    -- Cells.
    local font = love.graphics.getFont()
    for i, entry in ipairs(self.items) do
        local x, y, w, h = self:cellRect(i)
        local hovered = mx >= x and mx <= x + w and my >= y and my <= y + h
        local c = CATEGORY_COLORS[entry.category] or { 0.7, 0.7, 0.7 }

        love.graphics.setColor(0.08, 0.1, 0.14, hovered and 0.95 or 0.7)
        love.graphics.rectangle("fill", x, y, w, h, 3)
        love.graphics.setColor(c[1], c[2], c[3], hovered and 1 or 0.5)
        love.graphics.setLineWidth(hovered and 2 or 1)
        love.graphics.rectangle("line", x, y, w, h, 3)

        -- Category swatch.
        love.graphics.setColor(c[1], c[2], c[3], 1)
        love.graphics.rectangle("fill", x + 5, y + h / 2 - 4, 8, 8, 2)

        -- Label (truncated to fit).
        love.graphics.setColor(1, 1, 1, hovered and 1 or 0.85)
        local label = entry.label
        while font:getWidth(label) > w - 24 and #label > 1 do
            label = label:sub(1, #label - 1)
        end
        love.graphics.print(label, x + 18, y + h / 2 - font:getHeight() / 2)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

--- Adds the picked item to the hand as a card (buildings, spells, instants and
--- main-turret upgrades alike), the same card a draft or shop would give. The
--- picker stays open until closed with 'g' / F4.
function ItemPickerUI:select(entry)
    local game = self.game
    local item = entry.item

    if #game.hand >= (game.MAX_HAND_SIZE or 10) then
        DevMode.notify("Hand is full")
    else
        local reward = item
        if not item.rarity then
            reward = {}
            for k, v in pairs(item) do reward[k] = v end
            reward.rarity = entry.rarity
        end
        game:addCardToHand(CardFactory.fromReward(reward))
        DevMode.notify("Added " .. entry.label .. " to hand")
    end
    -- Stays open so several cards can be picked; 'g' / F4 closes it
end

function ItemPickerUI:mousepressed(x, y, button)
    if not self.isActive or not (self.game.testingMode or DevMode.isActive()) then return false end

    if button == 1 then
        for i, entry in ipairs(self.items) do
            local cx, cy, cw, ch = self:cellRect(i)
            if x >= cx and x <= cx + cw and y >= cy and y <= cy + ch then
                self:select(entry)
                return true
            end
        end
    end

    return true -- consume clicks anywhere while open
end

return ItemPickerUI
