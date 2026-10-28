-- InfoColumn.lua: the lower portion of the left command column.
--   * HORDE   - the incoming wave's enemies, as cards.
--   * INSPECT - a live preview of the hovered/selected turret or hovered enemy,
--               drawn with the shared reward-card visual language.
-- Sits below the stats panel; the roll/purchase buttons live in the tray.

local Reward = require("Game.Rewards.Reward")
local Layout = require("Game.GUI.Layout")
local Cursor = require("Game.GUI.Cursor")
local Neon = require("Game.GUI.Neon")
local DamageStats = require("Game.Core.DamageStats")
local CardDraw = require("Game.Cards.CardDraw")
local CardUpgradeConfig = require("Game.Cards.CardUpgradeConfig")

local InfoColumn = {}
InfoColumn.__index = InfoColumn

-- Enemy accent colors by id (mirrors WavePreviewUI / each enemy's base color).
local ENEMY_COLORS = {
    Basic = {1.0, 0.25, 0.25}, Speeder = {0.8, 1.0, 0.0}, Tank = {1.0, 1.0, 0.0},
    Flyer = {1.0, 0.5, 0.0}, Carrier = {0.2, 0.8, 1.0}, Armored = {0.3, 0.6, 0.9},
    Guardian = {0.2, 0.7, 1.0}, Duplicator = {0.2, 0.8, 0.4}, BeastMaster = {0.7, 0.2, 0.7},
}
local ENEMY_NAMES = { BeastMaster = "Beast Master" }

local DAMAGE_TYPE_NAMES = {
    ballistic = "Ballistic", energy = "Energy", explosive = "Explosive",
    fire = "Fire", poison = "Poison", ice = "Ice", trueDamage = "True",
}

local RARITY_ORDER = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5 }
local RARITY_COLORS = {
    common = {0.7, 0.7, 0.7}, uncommon = {0.2, 0.9, 0.3}, rare = {0.3, 0.6, 1.0},
    epic = {0.7, 0.3, 1.0}, legendary = {1.0, 0.8, 0.1},
}

function InfoColumn:new(game)
    return setmetatable({ game = game }, self)
end

function InfoColumn:update(dt) end

-- ---------------------------------------------------------------------------
-- Drawing helpers
-- ---------------------------------------------------------------------------

local function sectionHeader(text, x, y, w, col)
    love.graphics.push("all")
    love.graphics.setColor(col[1], col[2], col[3], 0.85)
    love.graphics.print(text, x, y)
    love.graphics.pop()
    Neon.line(x, y + 16, x + w, y + 16, col, 1.5, 0.7)
end

local function enemyGlyph(cx, cy, r, g, b)
    love.graphics.setColor(r, g, b, 0.3)
    love.graphics.rectangle("fill", cx - 6, cy - 6, 12, 12, 2)
    Neon.rect(cx - 6, cy - 6, 12, 12, { r, g, b }, { radius = 2, width = 2 })
end

-- Reward-style card frame. Draws an optional glyph in the band and an optional
-- name/sub stacked below it. Returns the band height AND the Y coordinate where
-- body content may begin (below the name/sub), so callers don't overlap them.
local function cardFrame(x, y, w, h, col, glyphFn, name, sub)
    local r, g, b = col[1], col[2], col[3]
    local bandH = math.max(20, math.min(32, math.floor(h * 0.34)))
    local lineH = love.graphics.getFont():getHeight() + 3
    love.graphics.push("all")
    love.graphics.setColor(Neon.BG[1], Neon.BG[2], Neon.BG[3], 1)
    love.graphics.rectangle("fill", x, y, w, h, 4)
    love.graphics.setColor(r, g, b, 0.1)
    love.graphics.rectangle("fill", x + 2, y + 2, w - 4, bandH)
    love.graphics.setColor(r, g, b, 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.line(x, y + bandH, x + w, y + bandH)
    if glyphFn then glyphFn(x + w / 2, y + bandH / 2 + 1, r, g, b) end
    Neon.rect(x, y, w, h, col, { radius = 4, width = 2 })

    local contentY = y + bandH + 5
    if name then
        love.graphics.setColor(0.92, 0.95, 1.0, 1)
        love.graphics.printf(name, x + 3, contentY, w - 6, "center")
        contentY = contentY + lineH
    end
    if sub then
        love.graphics.setColor(r, g, b, 1)
        love.graphics.printf(sub, x + 3, contentY, w - 6, "center")
        contentY = contentY + lineH
    end
    love.graphics.pop()
    return bandH, contentY + 3
end

-- ---------------------------------------------------------------------------
-- Horde (incoming enemies)
-- ---------------------------------------------------------------------------

-- Normalized card list for the wave panel + the wave number + whether the wave
-- is live. During a wave we read the live roster (with remaining counts and
-- death-flash timers); otherwise the upcoming-wave preview summary.
function InfoColumn:hordeCards()
    local game = self.game
    local spawner = game.WaveSpawner
    local cards = {}

    if game:isState("wave") and spawner and spawner.getLiveRoster then
        local roster = spawner:getLiveRoster()
        if roster and #roster > 0 then
            for _, b in ipairs(roster) do
                cards[#cards + 1] = { id = b.id, type = b.type, total = b.total,
                    remaining = math.max(0, b.total - b.killed), flashUntil = b.flashUntil }
            end
            return cards, game.wave, true
        end
    end

    local summary, waveNum = spawner and spawner:getUpcomingSummary()
    if summary then
        for _, item in ipairs(summary) do
            cards[#cards + 1] = { id = item.id, type = item.type, total = item.count,
                remaining = item.count, flashUntil = 0 }
        end
    end
    -- Always show a wave number while planning, even if the summary isn't ready
    -- yet (e.g. just after a wave finishes or during a mutation menu).
    return cards, waveNum or (game.wave + 1), false
end

function InfoColumn:drawHorde(x, y, w, h)
    local cards, waveNum, inProgress = self:hordeCards()

    local title = waveNum and string.format("INCOMING — WAVE %d", waveNum) or "INCOMING"
    sectionHeader(title, x, y, w, {1.0, 0.4, 0.4})
    if inProgress then
        love.graphics.push("all")
        love.graphics.setColor(0.5, 0.55, 0.62, 0.85) -- secondary grey
        love.graphics.printf("in progress…", x, y, w, "right")
        love.graphics.pop()
    end

    local gy = y + 26
    if #cards == 0 then
        love.graphics.setColor(0.4, 0.45, 0.52, 0.8)
        love.graphics.printf("No incoming wave", x, gy + 16, w, "center")
        return
    end

    local cols = 3
    local gap = 8
    local cardW = math.floor((w - (cols - 1) * gap) / cols)
    local cardH = 60
    for i, c in ipairs(cards) do
        local ci = (i - 1) % cols
        local ri = math.floor((i - 1) / cols)
        local cx = x + ci * (cardW + gap)
        local cy = gy + ri * (cardH + gap)
        if cy + cardH > y + h then break end -- don't overflow the region
        local col = ENEMY_COLORS[c.id] or {1, 1, 1}
        local name = ENEMY_NAMES[c.id] or c.type or c.id
        cardFrame(cx, cy, cardW, cardH, col, enemyGlyph, name, "x" .. tostring(c.remaining))

        -- Cleared types fade to a dim "eliminated" state.
        if c.remaining <= 0 then
            love.graphics.push("all")
            love.graphics.setColor(0.04, 0.05, 0.07, 0.62)
            love.graphics.rectangle("fill", cx, cy, cardW, cardH, 4)
            love.graphics.pop()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Inspect (preview of hovered/selected entity)
-- ---------------------------------------------------------------------------

-- Hovered building/enemy wins (transient); otherwise the selected (pinned)
-- building persists.
local STATS_W = 230
local STATS_ROW_H = 15

-- The building's stats (turrets), description (passives), stacked main-turret upgrades + active buffs as a list of
-- {text, col} rows (empty if none). Shared by measuring and drawing.
function InfoColumn:buildingExtrasLines(b)
    local lines = {}

    -- Damage this battle (turrets, incl. the main turret)
    local stats = self.game.damageStats
    if stats and b.isType and b:isType("turret") then
        local s = stats:get(b)
        local gold = {1.0, 0.85, 0.35}
        lines[#lines + 1] = { text = "Damage: " .. DamageStats.formatNumber(s.damage), col = gold }
        lines[#lines + 1] = { text = "Kills: " .. s.kills, col = gold }
        lines[#lines + 1] = { text = string.format("Share: %d%% of total", math.floor(s.share * 100 + 0.5)), col = gold }
    end

    -- Passives: what they do, wrapped to the window (they have no damage stats)
    if b.isType and b:isType("passive") and b.description then
        local _, wrapped = love.graphics.getFont():getWrap(b.description, STATS_W - 20)
        for _, text in ipairs(wrapped) do
            lines[#lines + 1] = { text = text, col = {0.85, 0.88, 0.95} }
        end
    end

    -- Stacked main-turret upgrades (highest rarity first), colored by rarity.
    if b.upgrades then
        local info = self.game.gui.tooltips:mainUpgradeInfo()
        local applied = {}
        for id, on in pairs(b.upgrades) do
            if on and info[id] then applied[#applied + 1] = info[id] end
        end
        table.sort(applied, function(a, c) return (RARITY_ORDER[a.rarity] or 0) > (RARITY_ORDER[c.rarity] or 0) end)
        for _, u in ipairs(applied) do
            lines[#lines + 1] = { text = u.name, col = RARITY_COLORS[u.rarity] or {0.85, 0.9, 1.0} }
        end
    end

    -- Active buffs / effects (from nearby buff towers, totems, ammo caches, ...).
    if b.effectManager and b.effectManager.getTooltipStrings then
        for _, s in ipairs(b.effectManager:getTooltipStrings()) do
            lines[#lines + 1] = { text = s, col = {0.3, 0.85, 1.0} }
        end
    end

    return lines
end




--- The hovered building's stats & modifiers (see buildingExtrasLines) in a
--- window that follows the mouse. Drawn over the HUD by GUIManager.
function InfoColumn:drawHoverStats()
    local game = self.game
    if game.gui and game.gui:overlayActive() then return end
    local ih = game.inputHandler
    local b = ih and ih.hoveredBuilding
    if not b or b.destroyed then return end
    local lines = self:buildingExtrasLines(b)
    if #lines == 0 then return end

    local mx, my = love.mouse.getPosition()
    local w, h = STATS_W, 30 + #lines * STATS_ROW_H + 8
    -- Beside the cursor, flipping to the other side near a screen edge
    local x = mx + 18
    if x + w > VIRTUAL_WIDTH then x = mx - 18 - w end
    local y = my + 18
    if y + h > VIRTUAL_HEIGHT then y = my - 18 - h end

    -- Framed and titled in the building's rarity colour, like its card
    local col = CardDraw.RARITY_COLORS[b.rarity] or b.color or {0.5, 0.7, 0.9}
    love.graphics.push("all")
    Neon.rect(x, y, w, h, col, { bg = 0.95, tint = 0.06, width = 1.5 })
    local title = b.name or "STATS & MODIFIERS"
    sectionHeader(title, x + 10, y + 6, w - 20, col)
    -- Turrets show their card's upgrade tier (I-V) just after the name (main turrets have none)
    if b:isType("turret") and not b:isType("mainturret") then
        local numeral = CardUpgradeConfig.TIER_NAMES[b.tier or 1] or "I"
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print(numeral, x + 10 + love.graphics.getFont():getWidth(title) + 8, y + 6)
    end
    local ty = y + 30
    for _, ln in ipairs(lines) do
        love.graphics.setColor(ln.col[1], ln.col[2], ln.col[3], 1)
        love.graphics.printf(ln.text, x + 10, ty, w - 20, "left")
        ty = ty + STATS_ROW_H
    end
    love.graphics.pop()
end

function InfoColumn:draw()
    local col = Layout.leftColumn
    local x = col.x + 12
    local w = col.w - 24

    -- Stats panel occupies ~y 12..96; the horde sits below it. The bottom of the
    -- column holds the hand's tokens, mana and pile buttons (HandUI).
    self:drawHorde(x, 104, w, 264)

    if not (self.game.gui and self.game.gui:overlayActive()) then
        local mx, my = love.mouse.getPosition()
        if self:clickableAt(mx, my) then Cursor.wantHand = true end
    end
end

-- The enemy id for a point over a Horde enemy card (clicking opens its entry),
-- or nil. (Geometry mirrors drawHorde.)
function InfoColumn:clickableAt(x, y)
    local col = Layout.leftColumn
    local rx, rw = col.x + 12, col.w - 24

    -- Horde cards (region y 104..368).
    local cards = self:hordeCards()
    if cards then
        local gy = 104 + 26
        local cols, gap, cardH = 3, 8, 60
        local cardW = math.floor((rw - (cols - 1) * gap) / cols)
        for i, item in ipairs(cards) do
            local cx = rx + ((i - 1) % cols) * (cardW + gap)
            local cy = gy + math.floor((i - 1) / cols) * (cardH + gap)
            if cy + cardH <= 104 + 264 and x >= cx and x <= cx + cardW and y >= cy and y <= cy + cardH then
                return item.id
            end
        end
    end

    return nil
end

function InfoColumn:mousepressed(x, y, button)
    if button ~= 1 then return nil end
    return self:clickableAt(x, y)
end

return InfoColumn
