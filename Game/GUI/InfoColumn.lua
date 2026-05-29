-- InfoColumn.lua: the lower portion of the left command column.
--   * HOARD   - the incoming wave's enemies, as cards.
--   * INSPECT - a live preview of the hovered/selected turret or hovered enemy,
--               drawn with the shared reward-card visual language.
-- Sits below the stats panel; the roll/purchase buttons live in the tray.

local Reward = require("Game.Rewards.Reward")
local Layout = require("Game.GUI.Layout")

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

-- Reward-style card frame; returns the header band height so callers can place
-- body content. Draws an optional glyph in the band and an optional name/sub.
local function cardFrame(x, y, w, h, col, glyphFn, name, sub)
    local r, g, b = col[1], col[2], col[3]
    local bandH = math.max(20, math.min(32, math.floor(h * 0.34)))
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
    if name then
        love.graphics.setColor(0.92, 0.95, 1.0, 1)
        love.graphics.printf(name, x + 3, y + bandH + 5, w - 6, "center")
    end
    if sub then
        love.graphics.setColor(r, g, b, 1)
        love.graphics.printf(sub, x + 3, y + bandH + 19, w - 6, "center")
    end
    love.graphics.pop()
    return bandH
end

-- ---------------------------------------------------------------------------
-- Hoard (incoming enemies)
-- ---------------------------------------------------------------------------

function InfoColumn:drawHoard(x, y, w, h)
    sectionHeader("HOARD", x, y, w, {1.0, 0.4, 0.4})
    local gy = y + 26

    local summary = self.game.WaveSpawner and self.game.WaveSpawner:getUpcomingSummary()
    if not summary or #summary == 0 then
        love.graphics.setColor(0.4, 0.45, 0.52, 0.8)
        love.graphics.printf("No incoming wave", x, gy + 16, w, "center")
        return
    end

    local cols = 3
    local gap = 8
    local cardW = math.floor((w - (cols - 1) * gap) / cols)
    local cardH = 60
    for i, item in ipairs(summary) do
        local ci = (i - 1) % cols
        local ri = math.floor((i - 1) / cols)
        local cx = x + ci * (cardW + gap)
        local cy = gy + ri * (cardH + gap)
        if cy + cardH > y + h then break end -- don't overflow the region
        local col = ENEMY_COLORS[item.id] or {1, 1, 1}
        local name = ENEMY_NAMES[item.id] or item.type or item.id
        cardFrame(cx, cy, cardW, cardH, col, enemyGlyph, name, "x" .. tostring(item.count))
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
    local bandH = cardFrame(x, y, w, h, col, nil, b.name or "Building", nil)
    local strings = {}
    if b.getTooltipStrings then strings = b:getTooltipStrings()
    elseif b.effectManager and b.effectManager.getTooltipStrings then strings = b.effectManager:getTooltipStrings() end
    love.graphics.push("all")
    love.graphics.setColor(0.85, 0.9, 1.0, 1)
    local ty = y + bandH + 8
    for _, s in ipairs(strings) do
        if ty > y + h - 14 then break end
        love.graphics.printf(s, x + 8, ty, w - 16, "left")
        ty = ty + 16
    end
    love.graphics.pop()
end

function InfoColumn:drawEnemyCard(e, x, y, w, h)
    local col = e.color or {1.0, 0.3, 0.3}
    local bandH = cardFrame(x, y, w, h, col, enemyGlyph, e.name or "Enemy", nil)

    love.graphics.push("all")
    local tx, ty = x + 12, y + bandH + 8

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

-- Lists the building's stacked main-turret upgrades and active buffs (e.g. a
-- nearby range-buff tower's "Range = +25%") below its card.
function InfoColumn:drawBuildingExtras(b, x, y, w, h)
    if h < 24 then return end
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

function InfoColumn:drawPreview(x, y, w, h)
    sectionHeader("INSPECT", x, y, w, {0.0, 0.85, 1.0})
    local py = y + 26
    local cardW = math.min(190, w)
    local cardH = math.min(h - 30, 200)
    local cx = x + math.floor((w - cardW) / 2)

    local kind, obj = self:previewTarget()
    if not kind then
        love.graphics.setColor(0.4, 0.45, 0.52, 0.8)
        love.graphics.printf("Hover a turret or enemy", x, py + math.floor(cardH / 2) - 10, w, "center")
        return
    end

    if kind == "building" then
        self:drawBuildingCard(obj, cx, py, cardW, cardH)
        self:drawBuildingExtras(obj, x, py + cardH + 10, w, (y + h) - (py + cardH + 10))
    else
        self:drawEnemyCard(obj, cx, py, cardW, cardH)
    end
end

function InfoColumn:draw()
    local col = Layout.leftColumn
    local x = col.x + 12
    local w = col.w - 24
    -- Stats panel occupies ~y 12..96; hoard then preview fill the rest.
    self:drawHoard(x, 104, w, 264)
    self:drawPreview(x, 376, w, (col.y + col.h) - 376 - 12)
end

return InfoColumn
