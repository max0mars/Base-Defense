-- ItemPickerUI.lua: Testing-mode menu listing every turret / buff / blocker /
-- main-lazer upgrade in the game. Click a building to drop into placement mode,
-- or an upgrade to apply it instantly. Toggle with 'g' (testing mode only).

local NormalRewardIndex  = require("Game.Rewards.RewardIndex")

local Reward             = require("Game.Rewards.Reward")

local ItemPickerUI = {}
ItemPickerUI.__index = ItemPickerUI

-- Category swatch colors.
local CATEGORY_COLORS = {
    turret  = { 0.0, 0.85, 1.0 },
    buff    = { 0.2, 0.9, 0.4 },
    blocker = { 0.95, 0.55, 0.15 },
    upgrade = { 1.0, 0.8, 0.2 },
}

local RARITIES = { "common", "uncommon", "rare", "epic", "legendary" }

-- Layout constants.
local NUM_COLS  = 3
local CELL_W    = 228
local CELL_H    = 24
local GAP       = 5
local TITLE_H   = 36
local PAD       = 14

local function labelFor(item)
    if item.name == "BLOCKER" then
        local shape = (item.id or "blocker"):gsub("blocker_", "")
        return "Blocker (" .. shape .. ")"
    end
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
            category = item.iconCategory or "turret",
            rarity = item.rarity or rarity or "common",
        }
    end

    for _, rarity in ipairs(RARITIES) do
        for _, item in ipairs(NormalRewardIndex[rarity] or {}) do add(item, rarity) end
    end
    -- Blocker index duplicates the same list across all rarities; common holds the set.


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
    if not self.isActive or not self.game.testingMode then return end

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
    love.graphics.printf("click an item   ·   'g' to close", self.panelX, self.panelY + 22, self.panelW, "center")

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

function ItemPickerUI:select(entry)
    local game = self.game
    local item = entry.item

    if item.type == "building" then
        -- Wrap the index entry in a real Reward so the placed building carries a
        -- drawable card (matching reward-placed buildings on hover).
        local cfg = {}
        for k, v in pairs(item) do cfg[k] = v end
        cfg.game = game
        cfg.rarity = entry.rarity or "common"
        local rewardObj = Reward:new(cfg)
        game:placeBuilding(item.building, rewardObj)
    elseif item.type == "main_upgrade" then
        local mainLazer = game.base and game.base.mainLazer
        if mainLazer and mainLazer.applyUpgrade then
            mainLazer:applyUpgrade(item)
        end
    end

    self.isActive = false
end

function ItemPickerUI:mousepressed(x, y, button)
    if not self.isActive or not self.game.testingMode then return false end

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
