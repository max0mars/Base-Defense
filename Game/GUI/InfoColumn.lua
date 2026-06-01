-- InfoColumn.lua: the lower portion of the left command column.
--   * HORDE   - the incoming wave's enemies, as cards.
--   * INSPECT - a live preview of the hovered/selected turret or hovered enemy,
--               drawn with the shared reward-card visual language.
-- Sits below the stats panel; the roll/purchase buttons live in the tray.

local Reward = require("Game.Rewards.Reward")
local Layout = require("Game.GUI.Layout")
local Cursor = require("Game.GUI.Cursor")

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
    normal = "Normal", poison = "Poison", armourPiercing = "Armor Pierce", trueDamage = "True",
    fire = "Fire", explosive = "Explosive", energy = "Energy", electric = "Electric",
}

local RARITY_ORDER = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5 }
local RARITY_COLORS = {
    common = {0.7, 0.7, 0.7}, uncommon = {0.2, 0.9, 0.3}, rare = {0.3, 0.6, 1.0},
    epic = {0.7, 0.3, 1.0}, legendary = {1.0, 0.8, 0.1},
}

function InfoColumn:new(game)
    local col = Layout.leftColumn
    local x, w = col.x + 12, col.w - 24
    local btnH = 42
    local btnY = (col.y + col.h) - 14 - btnH
    return setmetatable({
        game = game,
        journalButton = { x = x, y = btnY, w = w, h = btnH },
    }, self)
end

function InfoColumn:update(dt) end

-- ---------------------------------------------------------------------------
-- Drawing helpers
-- ---------------------------------------------------------------------------

local function sectionHeader(text, x, y, w, col)
    love.graphics.push("all")
    love.graphics.setColor(col[1], col[2], col[3], 0.85)
    love.graphics.print(text, x, y)
    love.graphics.setColor(col[1], col[2], col[3], 0.3)
    love.graphics.setLineWidth(1)
    love.graphics.line(x, y + 16, x + w, y + 16)
    love.graphics.pop()
end

local function enemyGlyph(cx, cy, r, g, b)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", cx - 6, cy - 6, 12, 12, 2)
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.rectangle("line", cx - 6, cy - 6, 12, 12, 2)
end

-- Reward-style card frame. Draws an optional glyph in the band and an optional
-- name/sub stacked below it. Returns the band height AND the Y coordinate where
-- body content may begin (below the name/sub), so callers don't overlap them.
local function cardFrame(x, y, w, h, col, glyphFn, name, sub)
    local r, g, b = col[1], col[2], col[3]
    local bandH = math.max(20, math.min(32, math.floor(h * 0.34)))
    local lineH = love.graphics.getFont():getHeight() + 3
    love.graphics.push("all")
    love.graphics.setColor(0.07, 0.08, 0.11, 1)
    love.graphics.rectangle("fill", x, y, w, h, 4)
    love.graphics.setColor(r, g, b, 0.13)
    love.graphics.rectangle("fill", x + 2, y + 2, w - 4, bandH)
    love.graphics.setColor(r, g, b, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(x, y + bandH, x + w, y + bandH)
    if glyphFn then glyphFn(x + w / 2, y + bandH / 2 + 1, r, g, b) end
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x, y, w, h, 4)

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
function InfoColumn:previewTarget()
    local game = self.game
    local ih = game.inputHandler
    -- A focused (clicked) target is sticky and wins over hover; the user must
    -- click elsewhere to dismiss it. A focused enemy keeps showing even if dead.
    if ih and ih.selectedBuilding and not ih.selectedBuilding.destroyed then
        return "building", ih.selectedBuilding
    end
    if ih and ih.selectedEnemy then
        return "enemy", ih.selectedEnemy
    end
    -- Otherwise, transient hover preview.
    if ih and ih.hoveredBuilding and not ih.hoveredBuilding.destroyed then
        return "building", ih.hoveredBuilding
    end
    local he = game.gui and game.gui.tooltips and game.gui.tooltips.hoveredEnemy
    if he and not he.destroyed then
        return "enemy", he
    end
    -- A hovered locked (token) slot, when nothing else is hovered.
    local ls = game.base and game.base.hoveredLockedSlot
    if ls then
        return "tokenSlot", ls
    end
    -- A hovered empty (unlocked) build slot.
    if game.base and game.base.hoveredEmptySlot then
        return "emptySlot", game.base.hoveredEmptySlot
    end
    return nil
end

function InfoColumn:drawBuildingCard(b, x, y, w, h)
    local card = b.rewardCard
    if not (card and card.draw and card.getRarityColor) and b.isType and b:isType("turret") then
        card = self.game.gui.tooltips:turretCardFor(b)
    end
    if card and card.draw and card.getRarityColor then
        -- Point a turret card at the live building so DPS/bars reflect current stats.
        if b.isType and b:isType("turret") then
            local saved = card.dummyBuilding
            card.dummyBuilding = b
            card:draw(x, y, w, h, false)
            card.dummyBuilding = saved
        else
            card:draw(x, y, w, h, false)
        end
        return
    end

    -- Fallback for non-turret buildings (buffs / blockers): a titled text card.
    local col = b.color or {0.6, 0.7, 0.8}
    local _, ty = cardFrame(x, y, w, h, col, nil, b.name or "Building", nil)
    local strings = {}
    if b.getTooltipStrings then strings = b:getTooltipStrings()
    elseif b.effectManager and b.effectManager.getTooltipStrings then strings = b.effectManager:getTooltipStrings() end
    love.graphics.push("all")
    love.graphics.setColor(0.85, 0.9, 1.0, 1)
    for _, s in ipairs(strings) do
        if ty > y + h - 14 then break end
        love.graphics.printf(s, x + 8, ty, w - 16, "left")
        ty = ty + 16
    end
    love.graphics.pop()
end

function InfoColumn:drawEnemyCard(e, x, y, w, h)
    local col = e.color or {1.0, 0.3, 0.3}
    local _, contentY = cardFrame(x, y, w, h, col, enemyGlyph, e.name or "Enemy", nil)

    love.graphics.push("all")
    local tx, ty = x + 12, contentY

    local maxHp = (e.getStat and e:getStat("maxHp")) or e.maxHp
    if maxHp then
        love.graphics.setColor(0.7, 0.85, 1.0, 1)
        love.graphics.print(string.format("HP %d/%d", math.max(0, math.floor(e.hp or 0)), math.floor(maxHp)), tx, ty)
        ty = ty + 20
    end

    -- Resistances / weaknesses from affinities.
    local resists, weaks = {}, {}
    for dtype, mult in pairs(e.affinities or {}) do
        if type(mult) == "number" and mult ~= 1 then
            local nm = DAMAGE_TYPE_NAMES[dtype] or dtype
            if mult < 1 then resists[#resists + 1] = string.format("%s  -%d%%", nm, math.floor((1 - mult) * 100 + 0.5))
            else weaks[#weaks + 1] = string.format("%s  +%d%%", nm, math.floor((mult - 1) * 100 + 0.5)) end
        end
    end
    table.sort(resists); table.sort(weaks)

    local bottom = y + h - 14
    if #resists == 0 and #weaks == 0 then
        love.graphics.setColor(0.6, 0.6, 0.65, 1)
        love.graphics.print("Takes full damage", tx, ty)
    else
        if #resists > 0 and ty < bottom then
            love.graphics.setColor(0.4, 0.7, 1.0, 1); love.graphics.print("RESISTS", tx, ty); ty = ty + 16
            for _, t in ipairs(resists) do
                if ty > bottom then break end
                love.graphics.setColor(0.55, 0.8, 1.0, 1); love.graphics.print("  " .. t, tx, ty); ty = ty + 15
            end
        end
        if #weaks > 0 and ty < bottom then
            love.graphics.setColor(1.0, 0.5, 0.3, 1); love.graphics.print("WEAK TO", tx, ty); ty = ty + 16
            for _, t in ipairs(weaks) do
                if ty > bottom then break end
                love.graphics.setColor(1.0, 0.65, 0.45, 1); love.graphics.print("  " .. t, tx, ty); ty = ty + 15
            end
        end
    end
    love.graphics.pop()
end

-- The building's stacked main-turret upgrades + active buffs as a list of
-- {text, col} rows (empty if none). Shared by measuring and drawing.
function InfoColumn:buildingExtrasLines(b)
    local lines = {}

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

-- Lists the building's modifiers (see buildingExtrasLines) below its card.
function InfoColumn:drawBuildingExtras(b, x, y, w, h)
    if h < 24 then return end
    local lines = self:buildingExtrasLines(b)
    if #lines == 0 then return end

    sectionHeader("MODIFIERS", x, y, w, {0.5, 0.7, 0.9})
    love.graphics.push("all")
    local ty = y + 22
    for _, ln in ipairs(lines) do
        if ty > y + h - 12 then break end
        love.graphics.setColor(ln.col[1], ln.col[2], ln.col[3], 1)
        love.graphics.printf(ln.text, x + 4, ty, w - 8, "left")
        ty = ty + 15
    end
    love.graphics.pop()
end

-- Horizontally + vertically centered card rect for the current preview, within
-- the inspect content region (below the section header). For buildings the card
-- and its modifier block are centered together. Returns cx, cardY, cardW, cardH.
function InfoColumn:previewCardRect(x, y, w, h, kind, obj)
    local top = y + 26
    local regionH = h - 26
    local cardW = math.min(190, w)
    local cardH = math.min(h - 30, 200)
    local cx = x + math.floor((w - cardW) / 2)

    local extrasH = 0
    if kind == "building" then
        local lines = self:buildingExtrasLines(obj)
        if #lines > 0 then extrasH = 22 + #lines * 15 end -- header + rows
    end
    local blockH = cardH + (extrasH > 0 and (10 + extrasH) or 0)
    local cardY = top + math.max(0, math.floor((regionH - blockH) / 2))
    return cx, cardY, cardW, cardH
end

function InfoColumn:drawPreview(x, y, w, h)
    sectionHeader("INSPECT", x, y, w, {0.0, 0.85, 1.0})

    local kind, obj = self:previewTarget()
    if not kind then
        local top = y + 26
        love.graphics.setColor(0.4, 0.45, 0.52, 0.8)
        love.graphics.printf("Hover a turret or enemy", x, top + math.floor((h - 26) / 2) - 7, w, "center")
        return
    end

    local cx, py, cardW, cardH = self:previewCardRect(x, y, w, h, kind, obj)

    if kind == "building" then
        self:drawBuildingCard(obj, cx, py, cardW, cardH)
        self:drawBuildingExtras(obj, x, py + cardH + 10, w, (y + h) - (py + cardH + 10))
    elseif kind == "tokenSlot" then
        self:drawTokenSlotCard(obj, cx, py, cardW, cardH)
    elseif kind == "emptySlot" then
        self:drawEmptySlotCard(cx, py, cardW, cardH)
    else
        self:drawEnemyCard(obj, cx, py, cardW, cardH)
    end
end

-- Info card for a locked (token) build slot. No rarity — these aren't rolled.
function InfoColumn:drawTokenSlotCard(slotInfo, x, y, w, h)
    local price = slotInfo.price or 0
    local affordable = self.game.tokens >= price
    local col = {0.95, 0.8, 0.2} -- token gold

    local function tokenGlyph(cx, cy, r, g, b)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.circle("line", cx, cy, 8)
        local font = love.graphics.getFont()
        love.graphics.printf("T", cx - 10, cy - font:getHeight() / 2, 20, "center")
    end

    local _, contentY = cardFrame(x, y, w, h, col, tokenGlyph, "Unlock Slot", nil)

    love.graphics.push("all")
    local tx, ty = x + 10, contentY
    local font = love.graphics.getFont()

    local desc = "A locked tile on your base. Spend tokens to unlock it, then deploy a turret or structure here."
    love.graphics.setColor(0.82, 0.86, 0.95, 1)
    love.graphics.printf(desc, tx, ty, w - 20, "left")
    local _, lines = font:getWrap(desc, w - 20)
    ty = ty + #lines * 15 + 10

    if ty < y + h - 16 then
        love.graphics.setColor(0.6, 0.65, 0.72, 1)
        love.graphics.print("Cost", tx, ty)
        local unit = (price == 1) and "Token" or "Tokens"
        if affordable then love.graphics.setColor(0.4, 1.0, 0.5, 1)
        else love.graphics.setColor(1.0, 0.45, 0.45, 1) end
        love.graphics.printf(string.format("%d %s", price, unit), x + 10, ty, w - 20, "right")
    end
    love.graphics.pop()
end

-- Info card for an empty (unlocked) build slot. No rarity.
function InfoColumn:drawEmptySlotCard(x, y, w, h)
    local col = {0.5, 0.8, 1.0} -- build-blue

    local function slotGlyph(cx, cy, r, g, b)
        love.graphics.setColor(r, g, b, 0.9)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", cx - 8, cy - 8, 16, 16, 2)
        love.graphics.line(cx - 4, cy, cx + 4, cy) -- a small "+" to suggest building
        love.graphics.line(cx, cy - 4, cx, cy + 4)
    end

    local _, contentY = cardFrame(x, y, w, h, col, slotGlyph, "Empty Slot", nil)

    love.graphics.push("all")
    local desc = "An unlocked, open tile. Select a turret or structure card from your deck, then click here to deploy it."
    love.graphics.setColor(0.82, 0.86, 0.95, 1)
    love.graphics.printf(desc, x + 10, contentY, w - 20, "left")
    love.graphics.pop()
end

function InfoColumn:draw()
    local col = Layout.leftColumn
    local x = col.x + 12
    local w = col.w - 24
    local sepY = self.journalButton.y - 14

    -- Stats panel occupies ~y 12..96; horde then preview fill the rest, down to
    -- the separator above the Base Journal button.
    self:drawHorde(x, 104, w, 264)
    self:drawPreview(x, 376, w, sepY - 376 - 6)

    -- Separator between the inspect area and the button below it.
    love.graphics.push("all")
    love.graphics.setColor(0.3, 0.5, 0.7, 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.line(x, sepY, x + w, sepY)
    love.graphics.pop()

    self:drawJournalButton()

    if not (self.game.gui and self.game.gui:overlayActive()) then
        local mx, my = love.mouse.getPosition()
        local b = self.journalButton
        local overBtn = mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h
        if overBtn or self:clickableAt(mx, my) then Cursor.wantHand = true end
    end
end

-- "BASE JOURNAL" button at the bottom of the column; opens the codex.
function InfoColumn:drawJournalButton()
    local b = self.journalButton
    local mx, my = love.mouse.getPosition()
    local hov = mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h
        and not (self.game.gui and self.game.gui:overlayActive())

    love.graphics.push("all")
    -- Body + border (violet, brighter on hover).
    love.graphics.setColor(0.42, 0.34, 0.66, hov and 0.34 or 0.18)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 6)
    love.graphics.setColor(0.7, 0.6, 1.0, hov and 1.0 or 0.65)
    love.graphics.setLineWidth(hov and 2 or 1)
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 6)

    -- Little book emblem to the left of the label.
    local cy = b.y + b.h / 2
    local bx = b.x + 18
    love.graphics.setColor(0.85, 0.8, 1.0, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", bx - 8, cy - 7, 16, 14, 1)
    love.graphics.line(bx, cy - 7, bx, cy + 7) -- spine

    love.graphics.setColor(0.92, 0.88, 1.0, 1)
    love.graphics.printf("BASE JOURNAL", b.x + 16, cy - 7, b.w - 16, "center")
    love.graphics.pop()
end

-- The codex action for a point over a Horde enemy card or the Inspect card:
-- returns { tab, id } or nil. (Geometry mirrors draw().)
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
                return { tab = "enemies", id = item.id }
            end
        end
    end

    -- Preview card (region y 376..), using the same centered rect as draw().
    local h = (col.y + col.h) - 376 - 12
    local kind, obj = self:previewTarget()
    if kind then
        local cx, cy, cardW, cardH = self:previewCardRect(rx, 376, rw, h, kind, obj)
        if x >= cx and x <= cx + cardW and y >= cy and y <= cy + cardH then
            if kind == "building" then
                return { tab = "turrets", id = (obj.rewardCard and obj.rewardCard.id) or obj.id }
            elseif kind == "enemy" then
                return { tab = "enemies", id = obj.name }
            end
        end
    end
    return nil
end

function InfoColumn:mousepressed(x, y, button)
    if button ~= 1 then return nil end
    -- Base Journal button → open the codex (enemies tab by default).
    local b = self.journalButton
    if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
        return { tab = "enemies" }
    end
    return self:clickableAt(x, y)
end

return InfoColumn
