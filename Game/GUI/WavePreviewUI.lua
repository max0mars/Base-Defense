-- WavePreviewUI.lua: Shows the composition of the upcoming wave during the
-- 'preparing'/'startup' phases so the player can build counters before committing.

local Layout = require("Game.GUI.Layout")

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

-- Draws the upcoming-wave composition as a vertical panel whose left edge sits at
-- anchorX and whose vertical center is anchorY (so it tucks against the right of
-- the "press enter to start wave" prompt). The whole panel flashes in and out.
function WavePreviewUI:draw(anchorX, anchorY)
    local game = self.game
    if game.testingMode then return end -- manual spawning in testing mode
    if not (game:isState("preparing") or game:isState("startup")) then return end

    local summary, waveNum = game.WaveSpawner:getUpcomingSummary()
    if not summary or #summary == 0 then return end

    local font = love.graphics.getFont()
    local swatch   = 12   -- swatch square side
    local innerPad = 6    -- swatch -> label gap
    local lineH    = 18   -- row height
    local titleText = string.format("INCOMING — WAVE %d", waveNum or (game.wave + 1))

    -- Measure rows (one enemy type per line).
    local rows, maxW = {}, font:getWidth(titleText)
    for _, item in ipairs(summary) do
        local name = self.displayNames[item.id] or item.type or item.id
        local label = string.format("%s x%d", name, item.count)
        local w = swatch + innerPad + font:getWidth(label)
        if w > maxW then maxW = w end
        rows[#rows + 1] = { label = label, color = self.colors[item.id] or { 1, 1, 1 } }
    end

    local pad = 12
    local panelW = maxW + pad * 2
    local panelH = pad * 2 + 18 + #rows * lineH
    local px = anchorX
    local py = anchorY - panelH / 2

    -- Flash in and out: a ramps roughly 0.15 -> 1.0 with the global pulse timer.
    local pulse = (math.sin((game.pulseTimer or 0) * 3) + 1) / 2
    local a = 0.15 + 0.85 * pulse

    love.graphics.push("all")

    -- Glass panel + threat-red border (whole panel fades with a).
    love.graphics.setColor(0.02, 0.05, 0.1, 0.82 * a)
    love.graphics.rectangle("fill", px, py, panelW, panelH, 6)
    love.graphics.setColor(1.0, 0.3, 0.3, a)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", px, py, panelW, panelH, 6)

    -- Title.
    love.graphics.setColor(1.0, 0.45, 0.45, a)
    love.graphics.printf(titleText, px, py + pad - 4, panelW, "center")

    -- One row per enemy type.
    local rowY = py + pad + 16
    for _, row in ipairs(rows) do
        local c = row.color
        love.graphics.setColor(c[1], c[2], c[3], a)
        love.graphics.rectangle("fill", px + pad, rowY + 2, swatch, swatch, 2)
        love.graphics.setColor(1, 1, 1, 0.25 * a)
        love.graphics.rectangle("line", px + pad, rowY + 2, swatch, swatch, 2)
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.print(row.label, px + pad + swatch + innerPad, rowY)
        rowY = rowY + lineH
    end

    love.graphics.pop()
end

return WavePreviewUI
