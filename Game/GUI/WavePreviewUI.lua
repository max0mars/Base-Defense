-- WavePreviewUI.lua: Shows the composition of the upcoming wave during the
-- 'preparing'/'startup' phases so the player can build counters before committing.

local WavePreviewUI = {}
WavePreviewUI.__index = WavePreviewUI

function WavePreviewUI:new(game)
    local obj = setmetatable({}, self)
    obj.game = game

    -- Swatch colors keyed by enemy id (mirrors each enemy class's base color).
    obj.colors = {
        Basic       = { 1.0, 0.25, 0.25 },
        Speeder     = { 0.8, 1.0, 0.0 },
        Tank        = { 1.0, 1.0, 0.0 },
        Flyer       = { 1.0, 0.5, 0.0 },
        Carrier     = { 0.2, 0.8, 1.0 },
        Armored     = { 0.3, 0.6, 0.9 },
        Guardian    = { 0.2, 0.7, 1.0 },
        Duplicator  = { 0.2, 0.8, 0.4 },
        BeastMaster = { 0.7, 0.2, 0.7 },
    }

    -- Prettier display names (defaults to the id otherwise).
    obj.displayNames = {
        BeastMaster = "Beast Master",
    }

    return obj
end

function WavePreviewUI:update(dt) end

function WavePreviewUI:draw()
    local game = self.game
    if not (game:isState("preparing") or game:isState("startup")) then return end

    local summary, waveNum = game.WaveSpawner:getUpcomingSummary()
    if not summary or #summary == 0 then return end

    local font = love.graphics.getFont()
    local swatch   = 12   -- swatch square side
    local innerPad = 5    -- swatch -> label gap
    local chipPad  = 16   -- gap between chips

    -- Measure chips.
    local chips = {}
    local totalW = 0
    for _, item in ipairs(summary) do
        local name = self.displayNames[item.id] or item.type or item.id
        local label = string.format("%s x%d", name, item.count)
        local cw = swatch + innerPad + font:getWidth(label)
        chips[#chips + 1] = { label = label, color = self.colors[item.id] or { 1, 1, 1 }, w = cw }
        totalW = totalW + cw
    end
    totalW = totalW + chipPad * math.max(0, #chips - 1)

    local titleText = string.format("INCOMING — WAVE %d", waveNum or (game.wave + 1))

    local panelPad = 14
    local panelW = math.max(totalW, font:getWidth(titleText)) + panelPad * 2
    local panelH = 46
    local panelX = (VIRTUAL_WIDTH - panelW) / 2
    local panelY = 106 -- just below the top HUD border (y=100)

    love.graphics.push("all")

    -- Glass panel + pulsing threat-red border.
    local pulse = (math.sin((game.pulseTimer or 0) * 3) + 1) / 2
    love.graphics.setColor(0.02, 0.05, 0.1, 0.85)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 6)
    love.graphics.setColor(1.0, 0.3, 0.3, 0.45 + 0.35 * pulse)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 6)

    -- Title.
    love.graphics.setColor(1.0, 0.45, 0.45, 0.9)
    love.graphics.printf(titleText, panelX, panelY + 5, panelW, "center")

    -- Chip row (centered).
    local rowY = panelY + 24
    local x = panelX + (panelW - totalW) / 2
    for _, chip in ipairs(chips) do
        local c = chip.color
        love.graphics.setColor(c[1], c[2], c[3], 1)
        love.graphics.rectangle("fill", x, rowY + 1, swatch, swatch, 2)
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.rectangle("line", x, rowY + 1, swatch, swatch, 2)
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.print(chip.label, x + swatch + innerPad, rowY)
        x = x + chip.w + chipPad
    end

    love.graphics.pop()
end

return WavePreviewUI
