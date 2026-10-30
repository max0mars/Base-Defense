-- =============================================================================
-- LEADERBOARD SCENE (leaderboard_scene.lua)
-- The online leaderboard's top runs, a page at a time. Each run's VIEW button
-- opens its details: stats, artifacts (hover for their effect) and its deck.
-- Opened from the title screen and the game over screen; BACK returns there.
-- =============================================================================

local leaderboard_scene = {}
leaderboard_scene.__index = leaderboard_scene

local scene = require("Scenes.scene")
setmetatable(leaderboard_scene, { __index = scene })

local Leaderboard = require("Game.Online.Leaderboard")
local Cursor = require("Game.GUI.Cursor")
local Neon = require("Game.GUI.Neon")
local TextInput = require("Game.GUI.TextInput")
local DeckViewerUI = require("Game.GUI.DeckViewerUI")
local ArtifactViewerUI = require("Game.GUI.ArtifactViewerUI")
local ArtifactIndex = require("Game.Artifacts.ArtifactIndex")
local DamageStats = require("Game.Core.DamageStats")

local ROWS_PER_PAGE = 10
local TABLE_X, TABLE_W = 140, 1000
local HEADER_Y, ROWS_Y, ROW_H = 118, 140, 40
-- Columns: x offset in the table, width, header, alignment
local COLUMNS = {
    { key = "rank", x = 0, w = 50, title = "#", align = "center" },
    { key = "name", x = 60, w = 200, title = "NAME", align = "left" },
    { key = "level", x = 270, w = 80, title = "LEVEL", align = "center" },
    { key = "turret", x = 360, w = 170, title = "MAIN TURRET", align = "left" },
    { key = "damage", x = 540, w = 130, title = "DAMAGE DEALT", align = "center" },
    { key = "kills", x = 680, w = 100, title = "KILLS", align = "center" },
    { key = "date", x = 790, w = 110, title = "DATE", align = "center" },
}
local VIEW_X, VIEW_W, VIEW_H = 910, 80, 28

-- Run details panel
local PANEL = { x = 240, y = 90, w = 800, h = 520 }
local ARTIFACT_ICON, ARTIFACT_GAP = 30, 10
local ARTIFACTS_BOTTOM = PANEL.y + 330

local function inside(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function formatDuration(seconds)
    seconds = tonumber(seconds) or 0
    local h, m = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
    if h > 0 then return string.format("%dh %02dm", h, m) end
    return string.format("%dm %02ds", m, math.floor(seconds % 60))
end

local function formatDate(ms)
    ms = tonumber(ms)
    return ms and os.date("%d %b %Y", math.floor(ms / 1000)) or ""
end

-- -----------------------------------------------------------------------------
-- Loading
-- -----------------------------------------------------------------------------

--- @param returnTo string|nil the scene BACK goes to (default: the title screen)
function leaderboard_scene:load(returnTo)
    self.returnTo = returnTo or "menu"
    self.page = 1
    self.entries = {}
    self.selected = nil
    self.deckViewer = DeckViewerUI:new(nil)
    self.editingName = false
    self.nameInput = TextInput:new({
        x = VIRTUAL_WIDTH / 2 - 150, y = 330, w = 300, h = 40,
        maxLength = Leaderboard.NAME_MAX, placeholder = "Your name",
        onSubmit = function(text) self:saveName(text) end,
    })

    local mx = VIRTUAL_WIDTH / 2
    self.buttons = {
        { x = mx - 305, y = 640, w = 190, h = 45, label = "BACK", action = "back", borderColor = Neon.RED },
        { x = mx - 95, y = 640, w = 190, h = 45, label = "REFRESH", action = "refresh", borderColor = Neon.CYAN },
        { x = mx + 115, y = 640, w = 190, h = 45, label = "CHANGE NAME", action = "name", borderColor = Neon.MAGENTA },
    }
    self.pageButtons = {
        prev = { x = mx - 130, y = 556, w = 34, h = 30, label = "<", borderColor = Neon.CYAN },
        next = { x = mx + 96, y = 556, w = 34, h = 30, label = ">", borderColor = Neon.CYAN },
    }
    self.nameButtons = {
        { x = mx - 150, y = 395, w = 140, h = 40, label = "SAVE", action = "save", borderColor = Neon.GREEN },
        { x = mx + 10, y = 395, w = 140, h = 40, label = "CANCEL", action = "cancel", borderColor = Neon.RED },
    }
    self.detailButtons = {
        deck = { x = PANEL.x + PANEL.w / 2 - 210, y = PANEL.y + PANEL.h - 70, w = 200, h = 45, label = "VIEW DECK", borderColor = Neon.CYAN },
        close = { x = PANEL.x + PANEL.w / 2 + 10, y = PANEL.y + PANEL.h - 70, w = 200, h = 45, label = "BACK", borderColor = Neon.RED },
    }

    self:refresh()
end

function leaderboard_scene:refresh()
    self.loading = true
    self.error = nil
    -- A response for an older visit to this scene is dropped
    local request = {}
    self.request = request
    Leaderboard.fetchTop(function(entries, err)
        if self.request ~= request then return end
        self.loading = false
        self.error = err
        self.entries = entries or {}
        for i, entry in ipairs(self.entries) do entry.rank = i end
        self.page = math.min(self.page, self:getPageCount())
    end)
end

function leaderboard_scene:getPageCount()
    return math.max(1, math.ceil(#self.entries / ROWS_PER_PAGE))
end

-- -----------------------------------------------------------------------------
-- Run details
-- -----------------------------------------------------------------------------

function leaderboard_scene:openDetails(entry)
    local defs = {}
    for _, id in ipairs(entry.artifacts or {}) do
        local def = type(id) == "string" and ArtifactIndex.get(id)
        if def then table.insert(defs, def) end
    end
    self.selected = { entry = entry, artifacts = defs, cards = Leaderboard.buildDeckCards(entry) }
    self.detailButtons.deck.label = "VIEW DECK (" .. #self.selected.cards .. ")"
end

function leaderboard_scene:drawDetails(mx, my)
    local sel = self.selected
    local entry = sel.entry
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    Neon.panel(PANEL.x, PANEL.y, PANEL.w, PANEL.h, Neon.MAGENTA)

    Neon.title("#" .. entry.rank .. "  " .. tostring(entry.name), PANEL.x, PANEL.y + 22, PANEL.w, "center", Neon.hot(Neon.MAGENTA, 0.3), 2)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Reached Level " .. tostring(entry.level) .. "   with the " .. Leaderboard.mainTurretName(entry.mainTurret),
        PANEL.x, PANEL.y + 72, PANEL.w, "center")

    -- Stats
    local stats = {
        { "DAMAGE DEALT", DamageStats.formatNumber(tonumber(entry.damageDealt) or 0), Neon.AMBER },
        { "KILLS", DamageStats.formatNumber(tonumber(entry.kills) or 0), Neon.GREEN },
        { "RUN TIME", formatDuration(entry.durationSeconds), Neon.CYAN },
        { "DATE", formatDate(entry.createdAt), Neon.MAGENTA },
    }
    local tileW, tileH, gap = 170, 56, 16
    local tx = PANEL.x + (PANEL.w - (#stats * tileW + (#stats - 1) * gap)) / 2
    for i, s in ipairs(stats) do
        local x = tx + (i - 1) * (tileW + gap)
        Neon.rect(x, PANEL.y + 105, tileW, tileH, s[3], { bg = 0.9, tint = 0.05, width = 1.5, alpha = 0.7 })
        love.graphics.setColor(0.7, 0.75, 0.85, 1)
        love.graphics.printf(s[1], x, PANEL.y + 113, tileW, "center")
        love.graphics.setColor(s[3][1], s[3][2], s[3][3], 1)
        love.graphics.printf(s[2], x, PANEL.y + 135, tileW, "center")
    end

    -- Artifacts
    local hovered
    love.graphics.setColor(0.75, 0.7, 0.95, 1)
    if #sel.artifacts == 0 then
        love.graphics.printf("ARTIFACTS:  none", PANEL.x, ARTIFACTS_BOTTOM - 40, PANEL.w, "center")
    else
        local maxW = PANEL.w - 80
        local perRow = math.max(1, math.floor((maxW + ARTIFACT_GAP) / (ARTIFACT_ICON + ARTIFACT_GAP)))
        local rows = math.ceil(#sel.artifacts / perRow)
        local blockW = math.min(#sel.artifacts, perRow) * (ARTIFACT_ICON + ARTIFACT_GAP) - ARTIFACT_GAP
        local blockTop = ARTIFACTS_BOTTOM - rows * ARTIFACT_ICON - (rows - 1) * ARTIFACT_GAP
        love.graphics.printf("ARTIFACTS (" .. #sel.artifacts .. ")", PANEL.x, blockTop - 24, PANEL.w, "center")
        hovered = ArtifactViewerUI.drawBlock(PANEL.x + (PANEL.w - blockW) / 2, ARTIFACTS_BOTTOM, maxW,
            ARTIFACT_ICON, ARTIFACT_GAP, mx, my, sel.artifacts)
    end

    for _, btn in pairs(self.detailButtons) do
        local hover = not self.deckViewer.isActive and inside(btn, mx, my)
        if hover then Cursor.wantHand = true end
        Neon.button(btn, { hovered = hover })
    end

    if hovered and not self.deckViewer.isActive then
        ArtifactViewerUI.drawTooltip(hovered, mx, my, true)
    end
end

-- -----------------------------------------------------------------------------
-- Name
-- -----------------------------------------------------------------------------

function leaderboard_scene:startEditingName()
    self.editingName = true
    self.nameError = nil
    self.nameInput.text = Leaderboard.getName() or ""
    self.nameInput:focus()
end

function leaderboard_scene:stopEditingName()
    self.editingName = false
    self.nameInput:unfocus()
end

function leaderboard_scene:saveName(text)
    if Leaderboard.setName(text) then
        self:stopEditingName()
    else
        self.nameError = "Enter a name first."
    end
end

function leaderboard_scene:drawNameEditor(mx, my)
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    Neon.panel(VIRTUAL_WIDTH / 2 - 200, 250, 400, 210, Neon.MAGENTA)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Your name on the leaderboard", 0, 285, VIRTUAL_WIDTH, "center")
    self.nameInput:draw()
    for _, btn in ipairs(self.nameButtons) do
        local hover = inside(btn, mx, my)
        if hover then Cursor.wantHand = true end
        Neon.button(btn, { hovered = hover })
    end
    if self.nameError then
        love.graphics.setColor(0.95, 0.55, 0.45, 1)
        love.graphics.printf(self.nameError, 0, 440, VIRTUAL_WIDTH, "center")
    end
end

-- -----------------------------------------------------------------------------
-- Drawing
-- -----------------------------------------------------------------------------

function leaderboard_scene:update(dt)
    self.nameInput:update(dt)
end

function leaderboard_scene:drawTable(mx, my, blocked)
    local playerName = Leaderboard.getName()
    love.graphics.setColor(0, 0.85, 1.0, 0.8)
    for _, col in ipairs(COLUMNS) do
        love.graphics.printf(col.title, TABLE_X + col.x, HEADER_Y, col.w, col.align)
    end
    Neon.line(TABLE_X, ROWS_Y - 4, TABLE_X + TABLE_W, ROWS_Y - 4, Neon.CYAN, 1, 0.5)

    self.viewButtons = {}
    local first = (self.page - 1) * ROWS_PER_PAGE + 1
    for i = first, math.min(first + ROWS_PER_PAGE - 1, #self.entries) do
        local entry = self.entries[i]
        local y = ROWS_Y + (i - first) * ROW_H
        local ty = y + ROW_H / 2 - love.graphics.getFont():getHeight() / 2

        if playerName and entry.name == playerName then
            love.graphics.setColor(1, 0.25, 0.85, 0.1) -- the player's own runs
            love.graphics.rectangle("fill", TABLE_X, y + 2, TABLE_W, ROW_H - 4, 4)
        end
        love.graphics.setColor(0, 0.85, 1.0, 0.12)
        love.graphics.rectangle("line", TABLE_X, y + 2, TABLE_W, ROW_H - 4, 4)

        local values = {
            rank = tostring(entry.rank),
            name = tostring(entry.name),
            level = tostring(entry.level),
            turret = Leaderboard.mainTurretName(entry.mainTurret),
            damage = DamageStats.formatNumber(tonumber(entry.damageDealt) or 0),
            kills = DamageStats.formatNumber(tonumber(entry.kills) or 0),
            date = formatDate(entry.createdAt),
        }
        for _, col in ipairs(COLUMNS) do
            if col.key == "rank" and entry.rank <= 3 then
                love.graphics.setColor(Neon.hot(Neon.AMBER, 0.3))
            elseif col.key == "level" then
                love.graphics.setColor(Neon.hot(Neon.GREEN, 0.3))
            else
                love.graphics.setColor(0.88, 0.9, 0.95, 1)
            end
            love.graphics.printf(values[col.key], TABLE_X + col.x, ty, col.w, col.align)
        end

        local btn = { x = TABLE_X + VIEW_X, y = y + (ROW_H - VIEW_H) / 2, w = VIEW_W, h = VIEW_H,
            label = "VIEW", borderColor = Neon.MAGENTA, entry = entry }
        table.insert(self.viewButtons, btn)
        local hover = not blocked and inside(btn, mx, my)
        if hover then Cursor.wantHand = true end
        Neon.button(btn, { hovered = hover })
    end
end

function leaderboard_scene:draw()
    Cursor.reset()
    local mx, my = love.mouse.getPosition()

    love.graphics.setColor(0.1, 0.2, 0.35, 0.3)
    for gx = 0, VIRTUAL_WIDTH, 40 do love.graphics.line(gx, 0, gx, VIRTUAL_HEIGHT) end
    for gy = 0, VIRTUAL_HEIGHT, 40 do love.graphics.line(0, gy, VIRTUAL_WIDTH, gy) end

    Neon.title("LEADERBOARD", 0, 30, VIRTUAL_WIDTH, "center", Neon.hot(Neon.MAGENTA, 0.35), 2.5)
    love.graphics.setColor(0.55, 0.6, 0.7, 1)
    love.graphics.printf("Highest level reached", 0, 82, VIRTUAL_WIDTH, "center")

    local blocked = self.selected or self.editingName
    love.graphics.setColor(0.7, 0.75, 0.85, 0.9)
    if self.loading then
        love.graphics.printf("Loading...", 0, 300, VIRTUAL_WIDTH, "center")
    elseif self.error then
        love.graphics.setColor(0.95, 0.55, 0.45, 1)
        love.graphics.printf(self.error, 0, 300, VIRTUAL_WIDTH, "center")
    elseif #self.entries == 0 then
        love.graphics.printf("No runs yet. Be the first!", 0, 300, VIRTUAL_WIDTH, "center")
    else
        self:drawTable(mx, my, blocked)
    end

    -- Pages
    local pages = self:getPageCount()
    if pages > 1 then
        for key, btn in pairs(self.pageButtons) do
            local enabled = (key == "prev" and self.page > 1) or (key == "next" and self.page < pages)
            local hover = enabled and not blocked and inside(btn, mx, my)
            if hover then Cursor.wantHand = true end
            Neon.button(btn, { hovered = hover, disabled = not enabled })
        end
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.printf("Page " .. self.page .. " / " .. pages, 0, 564, VIRTUAL_WIDTH, "center")
    end

    love.graphics.setColor(0.55, 0.6, 0.7, 1)
    local name = Leaderboard.getName()
    love.graphics.printf(name and ("Playing as " .. name) or "You haven't picked a name yet", 0, 610, VIRTUAL_WIDTH, "center")

    for _, btn in ipairs(self.buttons) do
        local hover = not blocked and inside(btn, mx, my)
        if hover then Cursor.wantHand = true end
        Neon.button(btn, { hovered = hover })
    end

    if self.selected then self:drawDetails(mx, my) end
    if self.editingName then self:drawNameEditor(mx, my) end
    if self.deckViewer.isActive then self.deckViewer:draw() end
end

-- -----------------------------------------------------------------------------
-- Input
-- -----------------------------------------------------------------------------

function leaderboard_scene:back()
    self.request = nil -- ignore a fetch still on its way
    self.scene_manager.switch(self.returnTo)
end

function leaderboard_scene:mousepressed(x, y, button)
    if self.deckViewer.isActive then
        self.deckViewer:mousepressed(x, y, button)
        return
    end
    if button ~= 1 then return end

    if self.editingName then
        if self.nameInput:mousepressed(x, y, button) then return end
        for _, btn in ipairs(self.nameButtons) do
            if inside(btn, x, y) then
                if btn.action == "save" then self:saveName(self.nameInput.text) else self:stopEditingName() end
                return
            end
        end
        self.nameInput:focus() -- clicking the backdrop keeps typing in the box
        return
    end

    if self.selected then
        if inside(self.detailButtons.deck, x, y) then
            self.deckViewer:open("Deck", self.selected.cards)
        elseif inside(self.detailButtons.close, x, y) or not inside(PANEL, x, y) then
            self.selected = nil
        end
        return
    end

    for _, btn in ipairs(self.viewButtons or {}) do
        if inside(btn, x, y) then
            self:openDetails(btn.entry)
            return
        end
    end

    local pages = self:getPageCount()
    if inside(self.pageButtons.prev, x, y) and self.page > 1 then
        self.page = self.page - 1
    elseif inside(self.pageButtons.next, x, y) and self.page < pages then
        self.page = self.page + 1
    end

    for _, btn in ipairs(self.buttons) do
        if inside(btn, x, y) then
            if btn.action == "back" then
                self:back()
            elseif btn.action == "refresh" then
                self:refresh()
            elseif btn.action == "name" then
                self:startEditingName()
            end
            return
        end
    end
end

function leaderboard_scene:textinput(text)
    if self.editingName then self.nameInput:textinput(text) end
end

function leaderboard_scene:keypressed(key)
    if self.deckViewer.isActive then
        if key == "escape" then self.deckViewer:close() end
        return
    end
    if self.editingName then
        if key == "escape" then
            self:stopEditingName()
        else
            self.nameInput:keypressed(key)
        end
        return
    end
    if self.selected then
        if key == "escape" then self.selected = nil end
        return
    end
    if key == "escape" then
        self:back()
    elseif key == "left" and self.page > 1 then
        self.page = self.page - 1
    elseif key == "right" and self.page < self:getPageCount() then
        self.page = self.page + 1
    end
end

return leaderboard_scene
