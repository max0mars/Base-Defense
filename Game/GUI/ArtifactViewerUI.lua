-- =============================================================================
-- ARTIFACT VIEWER (ArtifactViewerUI.lua)
-- Shows the run's artifacts: a compact icon strip with hover tooltips, and a
-- full-screen panel listing every owned artifact with its effect.
-- =============================================================================

local Cursor = require("Game.GUI.Cursor")
local ArtifactManager = require("Game.Artifacts.ArtifactManager")
local ArtifactIndex = require("Game.Artifacts.ArtifactIndex")

local ArtifactViewerUI = {}
ArtifactViewerUI.__index = ArtifactViewerUI

-- Panel frame (matches the preparation scene's deck / upgrade windows)
local PANEL_X, PANEL_Y = 100, 45
local COLS, ROWS = 3, 5
local TILE_H, TILE_GAP = 92, 14
local STRIP_ICON, STRIP_GAP = 30, 8

function ArtifactViewerUI:new()
    return setmetatable({ isActive = false, page = 1 }, self)
end

function ArtifactViewerUI:open()
    self.isActive = true
    self.page = 1
end

function ArtifactViewerUI:close()
    self.isActive = false
end

local function inRect(x, y, r)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function panelRect()
    return { x = PANEL_X, y = PANEL_Y, w = VIRTUAL_WIDTH - 2 * PANEL_X, h = VIRTUAL_HEIGHT - 2 * PANEL_Y }
end

-- -----------------------------------------------------------------------------
-- Icons
-- -----------------------------------------------------------------------------

local function regularPolygon(cx, cy, r, sides, rotation)
    local pts = {}
    for i = 0, sides - 1 do
        local a = rotation + i * (2 * math.pi / sides)
        table.insert(pts, cx + math.cos(a) * r)
        table.insert(pts, cy + math.sin(a) * r)
    end
    return pts
end

local function starPoints(cx, cy, outer, inner, points)
    local pts = {}
    for i = 0, points * 2 - 1 do
        local r = (i % 2 == 0) and outer or inner
        local a = -math.pi / 2 + i * math.pi / points
        table.insert(pts, cx + math.cos(a) * r)
        table.insert(pts, cy + math.sin(a) * r)
    end
    return pts
end

--- Glyph for an icon id, drawn as line art centred on (cx, cy) with half-size s.
local function drawGlyph(icon, cx, cy, s)
    if icon == "bolt" then
        love.graphics.polygon("line", cx + 0.2 * s, cy - s, cx - 0.55 * s, cy + 0.1 * s, cx - 0.05 * s, cy + 0.1 * s,
            cx - 0.2 * s, cy + s, cx + 0.55 * s, cy - 0.15 * s, cx + 0.05 * s, cy - 0.15 * s)
    elseif icon == "bullet" then
        love.graphics.rectangle("line", cx - 0.3 * s, cy - 0.2 * s, 0.6 * s, 1.1 * s)
        love.graphics.arc("line", "open", cx, cy - 0.2 * s, 0.3 * s, math.pi, 2 * math.pi)
        love.graphics.line(cx - 0.3 * s, cy + 0.6 * s, cx + 0.3 * s, cy + 0.6 * s)
    elseif icon == "burst" then
        love.graphics.polygon("line", starPoints(cx, cy, s, 0.45 * s, 8))
    elseif icon == "drop" then
        love.graphics.circle("line", cx, cy + 0.3 * s, 0.55 * s)
        love.graphics.line(cx - 0.5 * s, cy + 0.08 * s, cx, cy - s, cx + 0.5 * s, cy + 0.08 * s)
    elseif icon == "spread" then
        for _, a in ipairs({ -0.5, -0.17, 0.17, 0.5 }) do
            love.graphics.line(cx - 0.8 * s, cy + 0.2 * s, cx + math.cos(a - math.pi / 2) * s * 0.9, cy + 0.2 * s + math.sin(a - math.pi / 2) * s)
        end
    elseif icon == "crystal" then
        love.graphics.polygon("line", cx, cy - s, cx + 0.55 * s, cy - 0.2 * s, cx, cy + s, cx - 0.55 * s, cy - 0.2 * s)
        love.graphics.line(cx - 0.55 * s, cy - 0.2 * s, cx + 0.55 * s, cy - 0.2 * s)
        love.graphics.line(cx, cy - s, cx, cy + s)
    elseif icon == "hexagon" then
        love.graphics.polygon("line", regularPolygon(cx, cy, s, 6, 0))
        love.graphics.polygon("line", regularPolygon(cx, cy, 0.45 * s, 6, math.pi / 6))
    elseif icon == "chevron" then
        love.graphics.line(cx - 0.7 * s, cy - 0.1 * s, cx, cy - 0.8 * s, cx + 0.7 * s, cy - 0.1 * s)
        love.graphics.line(cx - 0.7 * s, cy + 0.6 * s, cx, cy - 0.1 * s, cx + 0.7 * s, cy + 0.6 * s)
    elseif icon == "diamond" then
        love.graphics.polygon("line", cx, cy - s, cx + 0.7 * s, cy, cx, cy + s, cx - 0.7 * s, cy)
        love.graphics.circle("fill", cx, cy, 0.18 * s)
    elseif icon == "coin" then
        love.graphics.circle("line", cx, cy, 0.85 * s)
        love.graphics.circle("line", cx, cy, 0.55 * s)
    elseif icon == "flame" then
        love.graphics.polygon("line", cx, cy - s, cx + 0.3 * s, cy - 0.35 * s, cx + 0.65 * s, cy + 0.2 * s,
            cx + 0.45 * s, cy + 0.8 * s, cx, cy + s, cx - 0.45 * s, cy + 0.8 * s, cx - 0.65 * s, cy + 0.2 * s,
            cx - 0.25 * s, cy - 0.2 * s)
        love.graphics.polygon("line", cx, cy + 0.1 * s, cx + 0.25 * s, cy + 0.6 * s, cx, cy + 0.85 * s, cx - 0.25 * s, cy + 0.6 * s)
    elseif icon == "shield" then
        love.graphics.polygon("line", cx - 0.75 * s, cy - 0.75 * s, cx + 0.75 * s, cy - 0.75 * s, cx + 0.75 * s, cy,
            cx, cy + s, cx - 0.75 * s, cy)
    else
        love.graphics.polygon("line", starPoints(cx, cy, s, 0.5 * s, 5))
    end
end

--- Neon badge for an artifact: a ring and glyph in the artifact's colour.
function ArtifactViewerUI.drawIcon(def, cx, cy, radius)
    local r, g, b = unpack(def.color or { 1, 1, 1, 1 })
    local ring = def.color or { 1, 1, 1, 1 }

    love.graphics.push("all")
    love.graphics.setColor(0.06, 0.06, 0.09, 1)
    love.graphics.circle("fill", cx, cy, radius)
    love.graphics.setColor(ring[1], ring[2], ring[3], 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy, radius)

    -- Glow pass, then crisp core line
    love.graphics.setLineWidth(4)
    love.graphics.setColor(r, g, b, 0.2)
    drawGlyph(def.icon, cx, cy, radius * 0.55)
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(r, g, b, 1)
    drawGlyph(def.icon, cx, cy, radius * 0.55)
    love.graphics.pop()
end

-- -----------------------------------------------------------------------------
-- Compact strip (always visible on the preparation screen)
-- -----------------------------------------------------------------------------

--- Strip bounds for the owned artifacts, laid out left to right from (x, y).
function ArtifactViewerUI:getStripRect(x, y)
    local n = #ArtifactManager.getOwnedIds()
    local w = math.max(0, n * (STRIP_ICON + STRIP_GAP) - STRIP_GAP)
    return { x = x, y = y, w = w, h = STRIP_ICON }
end

--- Draws the strip and returns the hovered artifact definition (if any).
function ArtifactViewerUI:drawStrip(x, y, mx, my)
    local defs = ArtifactManager.getOwnedDefinitions()
    love.graphics.setColor(0.75, 0.7, 0.95, 1)
    love.graphics.print("Artifacts:", x, y - 18)
    if #defs == 0 then
        love.graphics.setColor(0.5, 0.5, 0.55, 1)
        love.graphics.print("None yet", x, y + 8)
        return nil
    end

    local hovered = ArtifactViewerUI.drawRow(x, y, STRIP_ICON, STRIP_GAP, mx, my)
    if hovered then Cursor.wantHand = true end
    return hovered
end

--- Owned artifacts as a row of `size`px icons from (x, y). Returns the hovered one.
function ArtifactViewerUI.drawRow(x, y, size, gap, mx, my)
    local hovered
    for i, def in ipairs(ArtifactManager.getOwnedDefinitions()) do
        local ix = x + (i - 1) * (size + gap)
        ArtifactViewerUI.drawIcon(def, ix + size / 2, y + size / 2, size / 2)
        if inRect(mx, my, { x = ix, y = y, w = size, h = size }) then hovered = def end
    end
    return hovered
end

--- Owned artifacts (or the definitions in `defs`) in rows of up to `maxW` wide,
--- stacked upward so the last row ends at `bottomY`. Returns the hovered
--- artifact definition, or nil.
function ArtifactViewerUI.drawBlock(x, bottomY, maxW, size, gap, mx, my, defs)
    local owned = defs or ArtifactManager.getOwnedDefinitions()
    if #owned == 0 then return nil end
    local perRow = math.max(1, math.floor((maxW + gap) / (size + gap)))
    local rows = math.ceil(#owned / perRow)
    local top = bottomY - rows * size - (rows - 1) * gap
    local hovered
    for i, def in ipairs(owned) do
        local ix = x + ((i - 1) % perRow) * (size + gap)
        local iy = top + math.floor((i - 1) / perRow) * (size + gap)
        ArtifactViewerUI.drawIcon(def, ix + size / 2, iy + size / 2, size / 2)
        if inRect(mx, my, { x = ix, y = iy, w = size, h = size }) then hovered = def end
    end
    return hovered
end

--- Small floating card with an artifact's name and effect, near (mx, my):
--- above the cursor, or below it when `below` is set.
function ArtifactViewerUI.drawTooltip(def, mx, my, below)
    local font = love.graphics.getFont()
    local w = 260
    local _, lines = font:getWrap(def.description, w - 20)
    local h = 32 + #lines * font:getHeight()
    local x = math.min(mx + 14, VIRTUAL_WIDTH - w - 6)
    local y = below and (my + 20) or math.max(6, my - h - 10)

    love.graphics.push("all")
    love.graphics.setColor(0.07, 0.07, 0.1, 0.96)
    love.graphics.rectangle("fill", x, y, w, h, 6)
    love.graphics.setColor(def.color)
    love.graphics.rectangle("line", x, y, w, h, 6)
    love.graphics.print(def.name, x + 10, y + 8)
    love.graphics.setColor(0.9, 0.9, 0.92, 1)
    love.graphics.printf(def.description, x + 10, y + 26, w - 20, "left")
    love.graphics.pop()
end

-- -----------------------------------------------------------------------------
-- Full panel
-- -----------------------------------------------------------------------------

function ArtifactViewerUI:getPageCount()
    return math.max(1, math.ceil(#ArtifactManager.getOwnedIds() / (COLS * ROWS)))
end

function ArtifactViewerUI:draw(mx, my)
    if not self.isActive then return end
    local panel = panelRect()
    local defs = ArtifactManager.getOwnedDefinitions()

    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 10)
    love.graphics.setColor(0.75, 0.55, 1, 1)
    love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 10)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("ARTIFACTS", panel.x, panel.y + 12, panel.w, "center")
    love.graphics.setColor(0.7, 0.7, 0.8, 1)
    love.graphics.printf(string.format("Collected: %d / %d", #defs, #ArtifactIndex.list),
        panel.x + 20, panel.y + 12, 200, "left")

    if #defs == 0 then
        love.graphics.setColor(0.7, 0.7, 0.75, 1)
        love.graphics.printf("You have no artifacts yet.\nArtifacts grant powerful passive effects for the rest of the run.",
            panel.x, panel.y + panel.h / 2 - 20, panel.w, "center")
    end

    local perPage = COLS * ROWS
    self.page = math.max(1, math.min(self.page, self:getPageCount()))
    local first = (self.page - 1) * perPage + 1
    local tileW = (panel.w - 40 - (COLS - 1) * TILE_GAP) / COLS
    local font = love.graphics.getFont()

    for i = first, math.min(#defs, first + perPage - 1) do
        local def = defs[i]
        local idx = i - first
        local tx = panel.x + 20 + (idx % COLS) * (tileW + TILE_GAP)
        local ty = panel.y + 44 + math.floor(idx / COLS) * (TILE_H + TILE_GAP)
        local isHover = inRect(mx, my, { x = tx, y = ty, w = tileW, h = TILE_H })

        love.graphics.setColor(0.09, 0.09, 0.13, 1)
        love.graphics.rectangle("fill", tx, ty, tileW, TILE_H, 8)
        love.graphics.setColor(def.color[1], def.color[2], def.color[3], isHover and 1 or 0.55)
        love.graphics.setLineWidth(isHover and 2 or 1)
        love.graphics.rectangle("line", tx, ty, tileW, TILE_H, 8)
        love.graphics.setLineWidth(1)

        ArtifactViewerUI.drawIcon(def, tx + 34, ty + TILE_H / 2, 24)

        local textX, textW = tx + 68, tileW - 78
        love.graphics.setColor(def.color)
        love.graphics.print(def.name, textX, ty + 8)
        love.graphics.setColor(0.88, 0.88, 0.92, 1)
        love.graphics.printf(def.description, textX, ty + 8 + font:getHeight() + 6, textW, "left")
    end

    -- Pagination (only when there's more than one page)
    local pages = self:getPageCount()
    self.prevBtn, self.nextBtn = nil, nil
    if pages > 1 then
        local by = panel.y + panel.h - 48
        if self.page > 1 then
            self.prevBtn = { x = panel.x + 20, y = by, w = 120, h = 34 }
        end
        if self.page < pages then
            self.nextBtn = { x = panel.x + panel.w - 140, y = by, w = 120, h = 34 }
        end
        for _, btn in ipairs({ self.prevBtn or false, self.nextBtn or false }) do
            if btn then
                local h = inRect(mx, my, btn)
                if h then Cursor.wantHand = true end
                love.graphics.setColor(h and { 0.5, 0.35, 0.8, 1 } or { 0.35, 0.25, 0.6, 1 })
                love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 5)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.printf(btn == self.prevBtn and "Prev Page" or "Next Page", btn.x, btn.y + 10, btn.w, "center")
            end
        end
        love.graphics.printf("Page " .. self.page .. " / " .. pages, panel.x, by + 10, panel.w, "center")
    end

    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.printf("Click outside to close", panel.x, panel.y + panel.h - 22, panel.w, "center")
end

--- Handles a click while open. Closes when clicking outside the panel.
function ArtifactViewerUI:mousepressed(x, y)
    if not self.isActive then return false end
    if inRect(x, y, self.prevBtn) then
        self.page = self.page - 1
    elseif inRect(x, y, self.nextBtn) then
        self.page = self.page + 1
    elseif not inRect(x, y, panelRect()) then
        self:close()
    end
    return true
end

return ArtifactViewerUI
