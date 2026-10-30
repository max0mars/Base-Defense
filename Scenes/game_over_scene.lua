local game_over_scene = {}
game_over_scene.__index = game_over_scene

local scene = require("Scenes.scene") -- Import the base scene class
setmetatable(game_over_scene, { __index = scene })

local game = require("Game.Core.GameManager")
local Cursor = require("Game.GUI.Cursor")
local SaveGame = require("Game.Core.SaveGame")
local DevMode = require("Game.Dev.DevMode")
local DamageStats = require("Game.Core.DamageStats")
local DeckViewerUI = require("Game.GUI.DeckViewerUI")
local ArtifactViewerUI = require("Game.GUI.ArtifactViewerUI")
local ArtifactManager = require("Game.Artifacts.ArtifactManager")
local Leaderboard = require("Game.Online.Leaderboard")
local TextInput = require("Game.GUI.TextInput")
local Neon = require("Game.GUI.Neon")

-- Damage taken: one row per level, listing the enemies that hit the base on it
-- (a level with more enemies than fit wraps onto extra rows)
local ROWS_PER_PAGE = 4
local ENEMIES_PER_ROW = 11
local LABEL_W = 130
local CELL_W, ROW_H = 74, 62
local ROWS_W = LABEL_W + ENEMIES_PER_ROW * CELL_W
local ROWS_Y = 305
local ICON_MAX = 30 -- big enemies (bosses) are drawn shrunk to fit a cell
local ICON_X = 22   -- the icon's centre in its cell, leaving room for the "x 15" count
-- The run's artifacts: a centred row of icons (wrapping if there are many)
local ARTIFACT_ICON, ARTIFACT_GAP, ARTIFACTS_MAX_W = 26, 8, 1000
local ARTIFACTS_BOTTOM = 262
-- Leaderboard status (or the name box, until the player has picked a name)
local LEADERBOARD_Y = 597

local function inside(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

--- Groups the base's damage history into rows: { level, levelDamage, enemies, first }.
--- `first` marks a level's first row (the one that shows its label).
function game_over_scene.buildRows(history)
    local byLevel, levels = {}, {}
    for _, item in ipairs(history or {}) do
        local level = tonumber(item.level) or item.level
        if not byLevel[level] then
            byLevel[level] = {}
            table.insert(levels, level)
        end
        table.insert(byLevel[level], item)
    end
    table.sort(levels, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)

    local rows = {}
    for _, level in ipairs(levels) do
        local enemies = byLevel[level]
        table.sort(enemies, function(a, b) return a.damage > b.damage end)
        local levelDamage = 0
        for _, e in ipairs(enemies) do levelDamage = levelDamage + e.damage end
        for i = 1, #enemies, ENEMIES_PER_ROW do
            local row = { level = level, levelDamage = levelDamage, enemies = {}, first = (i == 1) }
            for j = i, math.min(i + ENEMIES_PER_ROW - 1, #enemies) do
                table.insert(row.enemies, enemies[j])
            end
            table.insert(rows, row)
        end
    end
    return rows
end

function game_over_scene:load()
    local ps = _G.PersistentState or {}
    self.level = (ps.battlesCompleted or 0) + 1
    self.totalDamage = ps.totalDamageDealt or 0
    self.totalKills = ps.totalKills or 0
    print(string.format("[GameOver] Level %d, wave %d", self.level, game.wave or 0))
    -- The run is over: it can't be continued
    if SaveGame.isEnabled() then
        SaveGame.delete()
        print("[GameOver] Save deleted")
    end
    self.rows = game_over_scene.buildRows(game.base:getProcessedDamageHistory())
    self.page = 1
    self.deckViewer = DeckViewerUI:new(nil)

    -- Onto the leaderboard (already sent if we're back from viewing it)
    self.leaderboardRunId = Leaderboard.submitRun(ps) or (ps.leaderboardSubmitted and ps.leaderboardRunId)
    self.nameInput = TextInput:new({
        x = VIRTUAL_WIDTH / 2 - 90, y = LEADERBOARD_Y, w = 180, h = 28,
        maxLength = Leaderboard.NAME_MAX, placeholder = "Your name",
        onSubmit = function(text) self:submitName(text) end,
    })
end

function game_over_scene:submitName(text)
    if Leaderboard.setName(text) then self.nameInput:unfocus() end
end

--- The run's deck as a flat list of cards (one entry per copy).
function game_over_scene.getDeckCards()
    local deck = _G.PersistentState and _G.PersistentState.deck
    local cards = {}
    if deck and deck.getCards then
        for _, c in ipairs(deck:getCards()) do
            for _ = 1, (c.quantity or 1) do table.insert(cards, c) end
        end
    end
    return cards
end

function game_over_scene:getTotalPages()
    return math.max(1, math.ceil(#self.rows / ROWS_PER_PAGE))
end

--- Rects for the buttons and page arrows (shared by draw and mousepressed).
function game_over_scene:getLayout()
    local btnW, btnH, btnY, gap = 130, 45, 630, 15
    local arrowY = ROWS_Y + ROWS_PER_PAGE * ROW_H + 8
    local left = VIRTUAL_WIDTH / 2 - (4 * btnW + 3 * gap) / 2
    return {
        viewDeck = { x = left, y = btnY, w = btnW, h = btnH },
        leaderboard = { x = left + btnW + gap, y = btnY, w = btnW, h = btnH },
        retry = { x = left + 2 * (btnW + gap), y = btnY, w = btnW, h = btnH },
        quit = { x = left + 3 * (btnW + gap), y = btnY, w = btnW, h = btnH },
        submitName = { x = VIRTUAL_WIDTH / 2 + 100, y = LEADERBOARD_Y, w = 90, h = 28, label = "SUBMIT", borderColor = Neon.GREEN },
        prev = { x = VIRTUAL_WIDTH / 2 - 110, y = arrowY, w = 30, h = 30 },
        next = { x = VIRTUAL_WIDTH / 2 + 80, y = arrowY, w = 30, h = 30 },
    }
end

-- Draws an enemy that hit the base, using its class's own draw where possible
local function drawEnemyIcon(item, cx, cy)
    local scale = math.min(1, ICON_MAX / math.max(item.w or 20, item.h or 20))
    local drawW = (item.w or 20) * scale
    local drawH = (item.h or 20) * scale

    local enemyFileName = item.name
    if enemyFileName == "Basic" then enemyFileName = "Enemy" end
    local success, enemyClass = pcall(require, "Enemies." .. enemyFileName)

    if success and type(enemyClass) == "table" then
        local mockEnemy = {
            x = cx, y = cy, w = drawW, h = drawH,
            hp = 1, maxHp = 1, shield = 0, maxShield = 0,
            color = item.color or {1, 0, 0, 1},
            game = game,
            getStat = function(self, stat)
                if stat == "maxHp" then return self.maxHp end
                if stat == "size" then return self.w end
                return 0
            end
        }
        setmetatable(mockEnemy, { __index = enemyClass })
        local ok = pcall(mockEnemy.draw, mockEnemy)
        if ok then return end
    end

    love.graphics.setColor(item.color or {1, 0, 0, 1})
    if item.shape == "circle" then
        love.graphics.circle("fill", cx, cy, drawW / 2)
    else
        love.graphics.rectangle("fill", cx - drawW / 2, cy - drawH / 2, drawW, drawH)
    end
end

local function drawStatTile(label, value, x, y, w, h, color)
    love.graphics.setColor(0.05, 0.08, 0.12, 0.9)
    love.graphics.rectangle("fill", x, y, w, h, 6)
    love.graphics.setColor(color[1], color[2], color[3], 0.6)
    love.graphics.rectangle("line", x, y, w, h, 6)
    love.graphics.setColor(0.7, 0.75, 0.85, 1)
    love.graphics.printf(label, x, y + 10, w, "center")
    love.graphics.setColor(color)
    love.graphics.printf(value, x, y + 34, w, "center")
end

local function drawButton(r, label, hovered, fill, hoverFill, line)
    love.graphics.setColor(hovered and hoverFill or fill)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 8, 8)
    love.graphics.setColor(line)
    love.graphics.setLineWidth(hovered and 2 or 1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(label, r.x, r.y + 15, r.w, "center")
end

function game_over_scene:draw()
    Cursor.reset()
    game:draw()
    love.graphics.setColor(0, 0, 0, 0.85) -- Dark overlay
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    local mx, my = love.mouse.getPosition()
    local layout = self:getLayout()

    -- Title, and the level the run ended on
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.push()
    love.graphics.scale(2, 2)
    love.graphics.printf("GAME OVER", 0, 25, VIRTUAL_WIDTH / 2, "center")
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Fell on Level " .. self.level, 0, 110, VIRTUAL_WIDTH, "center")

    -- Run totals
    local tileW, tileH, gap = 240, 64, 30
    local tileX = VIRTUAL_WIDTH / 2 - tileW - gap / 2
    drawStatTile("TOTAL DAMAGE DEALT", DamageStats.formatNumber(self.totalDamage), tileX, 140, tileW, tileH, {1, 0.75, 0.3, 1})
    drawStatTile("TOTAL KILLS", DamageStats.formatNumber(self.totalKills), tileX + tileW + gap, 140, tileW, tileH, {0.4, 1, 0.5, 1})

    -- The run's artifacts (hover one for its effect)
    local modalOpen = self.deckViewer.isActive
    local hoveredArtifact
    local owned = #ArtifactManager.getOwnedIds()
    love.graphics.setColor(0.75, 0.7, 0.95, 1)
    if owned == 0 then
        love.graphics.printf("ARTIFACTS:  none", 0, ARTIFACTS_BOTTOM - 20, VIRTUAL_WIDTH, "center")
    else
        local perRow = math.max(1, math.floor((ARTIFACTS_MAX_W + ARTIFACT_GAP) / (ARTIFACT_ICON + ARTIFACT_GAP)))
        local rowCount = math.ceil(owned / perRow)
        local blockW = math.min(owned, perRow) * (ARTIFACT_ICON + ARTIFACT_GAP) - ARTIFACT_GAP
        local blockTop = ARTIFACTS_BOTTOM - rowCount * ARTIFACT_ICON - (rowCount - 1) * ARTIFACT_GAP
        love.graphics.printf("ARTIFACTS", 0, blockTop - 20, VIRTUAL_WIDTH, "center")
        hoveredArtifact = ArtifactViewerUI.drawBlock((VIRTUAL_WIDTH - blockW) / 2, ARTIFACTS_BOTTOM,
            ARTIFACTS_MAX_W, ARTIFACT_ICON, ARTIFACT_GAP, mx, my)
    end

    -- Damage taken, by level
    love.graphics.setColor(0, 0.85, 1.0, 1)
    love.graphics.printf("ENEMIES THAT HIT YOUR BASE", 0, 278, VIRTUAL_WIDTH, "center")

    if #self.rows == 0 then
        love.graphics.setColor(0.7, 0.75, 0.85, 0.8)
        love.graphics.printf("No enemies reached your base.", 0, ROWS_Y + 20, VIRTUAL_WIDTH, "center")
    end

    local ROWS_X = (VIRTUAL_WIDTH - ROWS_W) / 2
    local first = (self.page - 1) * ROWS_PER_PAGE + 1
    for i = first, math.min(first + ROWS_PER_PAGE - 1, #self.rows) do
        local row = self.rows[i]
        local y = ROWS_Y + (i - first) * ROW_H

        love.graphics.setColor(0, 0.85, 1.0, 0.15)
        love.graphics.rectangle("line", ROWS_X, y + 2, ROWS_W, ROW_H - 4, 4)

        -- Level label (on the level's first row, or "cont." on wrapped rows)
        if row.first then
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.printf("LEVEL " .. tostring(row.level), ROWS_X, y + 13, LABEL_W, "center")
            love.graphics.setColor(1, 0.4, 0.4, 1)
            love.graphics.printf("-" .. DamageStats.formatNumber(row.levelDamage) .. " HP", ROWS_X, y + 35, LABEL_W, "center")
        else
            love.graphics.setColor(0.6, 0.65, 0.75, 0.7)
            love.graphics.printf("LEVEL " .. tostring(row.level) .. " (cont.)", ROWS_X, y + 24, LABEL_W, "center")
        end

        for j, item in ipairs(row.enemies) do
            local cellX = ROWS_X + LABEL_W + (j - 1) * CELL_W
            -- The icon with how many of it hit the base beside it ("x 15"); older
            -- saves have no count, so their icon stays centred
            if item.hits then
                drawEnemyIcon(item, cellX + ICON_X, y + 24)
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.print("x " .. item.hits, cellX + ICON_X + ICON_MAX / 2 + 3, y + 24 - love.graphics.getFont():getHeight() / 2)
            else
                drawEnemyIcon(item, cellX + CELL_W / 2, y + 24)
            end
            love.graphics.setColor(1, 0.4, 0.4, 1)
            love.graphics.printf(DamageStats.formatNumber(item.damage), cellX, y + ROW_H - 20, CELL_W, "center")
        end
    end

    -- Pages
    local totalPages = self:getTotalPages()
    if totalPages > 1 then
        local hoverPrev = not modalOpen and inside(layout.prev, mx, my)
        local hoverNext = not modalOpen and inside(layout.next, mx, my)
        if hoverPrev or hoverNext then Cursor.wantHand = true end
        for _, a in ipairs({ { layout.prev, "<", hoverPrev }, { layout.next, ">", hoverNext } }) do
            local r = a[1]
            love.graphics.setColor(a[3] and {0, 0.85, 1.0, 1} or {0, 0.5, 0.6, 1})
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(a[2], r.x, r.y + 8, r.w, "center")
        end
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.printf("Page " .. self.page .. " / " .. totalPages, 0, layout.prev.y + 8, VIRTUAL_WIDTH, "center")
    end

    self:drawLeaderboardStatus(layout, mx, my, modalOpen)

    -- View Deck, Leaderboard, Retry and Quit Buttons
    local isDeckHovered = not modalOpen and inside(layout.viewDeck, mx, my)
    local isBoardHovered = not modalOpen and inside(layout.leaderboard, mx, my)
    local isRetryHovered = not modalOpen and inside(layout.retry, mx, my)
    local isQuitHovered = not modalOpen and inside(layout.quit, mx, my)
    if isDeckHovered or isBoardHovered or isRetryHovered or isQuitHovered then Cursor.wantHand = true end
    drawButton(layout.viewDeck, "View Deck", isDeckHovered, {0.12, 0.25, 0.45, 1}, {0.2, 0.4, 0.7, 1}, {0.4, 0.75, 1, 1})
    drawButton(layout.leaderboard, "Leaderboard", isBoardHovered, {0.35, 0.15, 0.4, 1}, {0.5, 0.22, 0.58, 1}, {1, 0.45, 0.9, 1})
    drawButton(layout.retry, "Retry", isRetryHovered, {0.1, 0.5, 0.1, 1}, {0.2, 0.8, 0.2, 1}, {0.5, 1, 0.5, 1})
    drawButton(layout.quit, "Quit Game", isQuitHovered, {0.5, 0.1, 0.1, 1}, {0.8, 0.2, 0.2, 1}, {1, 0.5, 0.5, 1})

    if modalOpen then
        self.deckViewer:draw()
    elseif hoveredArtifact then
        ArtifactViewerUI.drawTooltip(hoveredArtifact, mx, my, true)
    end

    -- The menu's pointer / hand, not the battle's cursor drawn underneath
    Cursor.usePointer()
end

--- How the run's trip to the leaderboard is going, or a name box if it's waiting for one.
function game_over_scene:drawLeaderboardStatus(layout, mx, my, modalOpen)
    local status = Leaderboard.getRunStatus(self.leaderboardRunId)
    if not status then return end
    local textY = LEADERBOARD_Y + 7

    if status.state == "needs_name" then
        love.graphics.setColor(0.85, 0.75, 1, 1)
        love.graphics.printf("Name for the leaderboard:", 0, textY, self.nameInput.x - 12, "right")
        self.nameInput:draw()
        local hover = not modalOpen and inside(layout.submitName, mx, my)
        if hover then Cursor.wantHand = true end
        Neon.button(layout.submitName, { hovered = hover })
        return
    end

    local text, color = "Sending your run to the leaderboard...", {0.7, 0.75, 0.85, 1}
    if status.state == "sent" then
        text = status.rank and ("Your run is #" .. status.rank .. " on the leaderboard!") or "Your run is on the leaderboard!"
        color = {0.4, 1, 0.5, 1}
    elseif status.state == "offline" then
        text = "Couldn't reach the leaderboard. Your run will be sent when you're back online."
        color = {1, 0.75, 0.3, 1}
    elseif status.state == "rejected" then
        text = "The leaderboard turned this run down: " .. tostring(status.message or "unknown reason")
        color = {0.95, 0.55, 0.45, 1}
    end
    love.graphics.setColor(color)
    love.graphics.printf(text, 0, textY, VIRTUAL_WIDTH, "center")
end

function game_over_scene:update(dt)
    self.nameInput:update(dt)
end

function game_over_scene:textinput(text)
    self.nameInput:textinput(text)
end

function game_over_scene:mousepressed(x, y, button)
    if self.deckViewer.isActive then
        self.deckViewer:mousepressed(x, y, button)
        return
    end
    if button ~= 1 then return end
    local layout = self:getLayout()

    local status = Leaderboard.getRunStatus(self.leaderboardRunId)
    if status and status.state == "needs_name" then
        if self.nameInput:mousepressed(x, y, button) then return end
        if inside(layout.submitName, x, y) then
            self:submitName(self.nameInput.text)
            return
        end
    end

    if inside(layout.viewDeck, x, y) then
        self.deckViewer:open("Deck", game_over_scene.getDeckCards())
    elseif inside(layout.leaderboard, x, y) then
        self.nameInput:unfocus()
        self.scene_manager.switch("leaderboard", "gameover")
    elseif inside(layout.retry, x, y) then
        self.nameInput:unfocus()
        paused = 0
        if game.testingMode then
            self.scene_manager.switch("game") -- the sandbox just restarts
        else
            -- A fresh run from main turret selection (staying in dev mode if it was on)
            self.scene_manager.scenes.menu:startRun(DevMode.isActive())
        end
    elseif inside(layout.quit, x, y) then
        love.event.quit()
    elseif self:getTotalPages() > 1 then
        if inside(layout.prev, x, y) then
            self.page = math.max(1, self.page - 1)
        elseif inside(layout.next, x, y) then
            self.page = math.min(self:getTotalPages(), self.page + 1)
        end
    end
end

function game_over_scene:keypressed(key)
    if self.nameInput:keypressed(key) then return end
    if key == "escape" and self.deckViewer.isActive then
        self.deckViewer:close()
    end
end

return game_over_scene
