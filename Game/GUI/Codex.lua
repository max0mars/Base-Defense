-- Codex.lua: the enemy / turret encyclopedia overlay. Entries are revealed by
-- discovery -- enemies once seen in a wave (game.seenEnemies), turrets once owned
-- (game.ownedTurrets). Enemy detail lists "artifacts" (the enemy's mutations),
-- revealed once that mutation has been activated (EnemyRegistry.activeUpgrades).
-- Opened from the HUD codex buttons or by clicking a Horde / Inspect card.

local NormalEnemyIndex  = require("Game.Spawning.NormalEnemyIndex")
local NormalRewardIndex = require("Game.Rewards.NormalRewardIndex")
local EnemyRegistry     = require("Game.Spawning.EnemyRegistry")
local Reward            = require("Game.Rewards.Reward")
local Cursor            = require("Game.GUI.Cursor")

local Codex = {}
Codex.__index = Codex

local ENEMY_COLORS = {
    Basic = {1.0, 0.25, 0.25}, Speeder = {0.8, 1.0, 0.0}, Tank = {1.0, 1.0, 0.0},
    Flyer = {1.0, 0.5, 0.0}, Carrier = {0.2, 0.8, 1.0}, Armored = {0.3, 0.6, 0.9},
    Guardian = {0.2, 0.7, 1.0}, Duplicator = {0.2, 0.8, 0.4}, BeastMaster = {0.7, 0.2, 0.7},
}
local ENEMY_NAMES = { BeastMaster = "Beast Master" }
local RARITY_ORDER = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5 }

function Codex:new(game)
    local obj = setmetatable({ game = game, isActive = false, tab = "enemies", selected = nil }, self)

    obj.panel = { w = 920, h = 580 }
    obj.panel.x = math.floor((VIRTUAL_WIDTH - obj.panel.w) / 2)
    obj.panel.y = math.floor((VIRTUAL_HEIGHT - obj.panel.h) / 2)

    -- Enemy entries from the index pools.
    obj.enemyEntries = {}
    local function addEnemies(pool)
        for _, e in ipairs(pool or {}) do
            obj.enemyEntries[#obj.enemyEntries + 1] = {
                id = e.id, name = ENEMY_NAMES[e.id] or e.id, description = e.description,
                color = ENEMY_COLORS[e.id] or {0.8, 0.3, 0.3}, mutations = e.mutations or {},
            }
        end
    end
    addEnemies(NormalEnemyIndex.activePool)
    addEnemies(NormalEnemyIndex.inactivePool)

    -- Turret entries from the reward index (build a drawable Reward for each).
    obj.turretEntries = {}
    local seen = {}
    for rarity, entries in pairs(NormalRewardIndex) do
        if type(entries) == "table" then
            for _, e in ipairs(entries) do
                if e.type == "building" and e.iconCategory == "turret" and e.id and not seen[e.id] then
                    seen[e.id] = true
                    local cfg = {}
                    for k, v in pairs(e) do cfg[k] = v end
                    cfg.game, cfg.rarity = game, rarity
                    obj.turretEntries[#obj.turretEntries + 1] =
                        { id = e.id, name = e.name, description = e.description, rarity = rarity, reward = Reward:new(cfg) }
                end
            end
        end
    end
    table.sort(obj.turretEntries, function(a, b)
        local ra, rb = RARITY_ORDER[a.rarity] or 0, RARITY_ORDER[b.rarity] or 0
        if ra ~= rb then return ra < rb end
        return (a.name or "") < (b.name or "")
    end)

    return obj
end

function Codex:open(tab, id)
    self.isActive = true
    self.tab = tab or "enemies"
    self.selected = nil
    if id then
        for _, e in ipairs(self:entries()) do
            if e.id == id then self.selected = e; break end
        end
    end
end

function Codex:close() self.isActive = false; self.selected = nil end
function Codex:entries() return self.tab == "enemies" and self.enemyEntries or self.turretEntries end

function Codex:isRevealed(entry)
    if self.tab == "enemies" then
        return self.game.seenEnemies and self.game.seenEnemies[entry.id]
    end
    return self.game.ownedTurrets and self.game.ownedTurrets[entry.id]
end

-- ---------------------------------------------------------------------------
-- Geometry (shared by draw + input)
-- ---------------------------------------------------------------------------

function Codex:tabRects()
    local p = self.panel
    return {
        enemies = { x = p.x + 24, y = p.y + 46, w = 130, h = 30 },
        turrets = { x = p.x + 162, y = p.y + 46, w = 130, h = 30 },
    }
end

function Codex:closeRect()
    local p = self.panel
    return { x = p.x + p.w - 40, y = p.y + 14, w = 26, h = 26 }
end

function Codex:backRect()
    local p = self.panel
    return { x = p.x + 24, y = p.y + p.h - 50, w = 110, h = 34 }
end

function Codex:gridRects()
    local p = self.panel
    local cols, gap = 6, 12
    local x0, y0 = p.x + 24, p.y + 92
    local cw = math.floor((p.w - 48 - (cols - 1) * gap) / cols)
    local ch = 118
    local rects = {}
    for i, e in ipairs(self:entries()) do
        local ci, ri = (i - 1) % cols, math.floor((i - 1) / cols)
        rects[#rects + 1] = { entry = e, x = x0 + ci * (cw + gap), y = y0 + ri * (ch + gap), w = cw, h = ch }
    end
    return rects
end

-- ---------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------

local function entryCard(self, r, hovered)
    local e = r.entry
    local revealed = self:isRevealed(e)
    love.graphics.push("all")
    if not revealed then
        love.graphics.setColor(0.1, 0.11, 0.14, 1)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5)
        love.graphics.setColor(0.25, 0.27, 0.32, 1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5)
        love.graphics.setColor(0.35, 0.38, 0.45, 1)
        love.graphics.printf("?", r.x, r.y + r.h / 2 - 18, r.w, "center")
        love.graphics.setColor(0.3, 0.33, 0.4, 1)
        love.graphics.printf("UNDISCOVERED", r.x + 4, r.y + r.h - 22, r.w - 8, "center")
        love.graphics.pop()
        return
    end

    if self.tab == "turrets" and e.reward and e.reward.draw then
        e.reward:draw(r.x, r.y, r.w, r.h, hovered)
        love.graphics.pop()
        return
    end

    -- Enemy card.
    local c = e.color
    love.graphics.setColor(0.07, 0.08, 0.11, 1)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5)
    love.graphics.setColor(c[1], c[2], c[3], 0.14)
    love.graphics.rectangle("fill", r.x + 2, r.y + 2, r.w - 4, 34)
    love.graphics.setColor(c[1], c[2], c[3], 1)
    love.graphics.rectangle("fill", r.x + r.w / 2 - 8, r.y + 11, 16, 16, 2)
    love.graphics.setColor(c[1], c[2], c[3], hovered and 1 or 0.8)
    love.graphics.setLineWidth(hovered and 2 or 1.5)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5)
    love.graphics.setColor(0.92, 0.95, 1.0, 1)
    love.graphics.printf(e.name, r.x + 3, r.y + 44, r.w - 6, "center")
    love.graphics.pop()
end

function Codex:drawDetail()
    local p = self.panel
    local e = self.selected
    local cardX, cardY, cardW, cardH = p.x + 30, p.y + 96, 200, 270
    local infoX = cardX + cardW + 30
    local infoW = p.x + p.w - infoX - 30

    love.graphics.push("all")
    if self.tab == "turrets" and e.reward and e.reward.draw then
        e.reward:draw(cardX, cardY, cardW, cardH, false)
        love.graphics.setColor(0.85, 0.9, 1.0, 1)
        love.graphics.printf(e.description or "", infoX, cardY + 10, infoW, "left")
    else
        -- Enemy detail card.
        local c = e.color
        love.graphics.setColor(0.07, 0.08, 0.11, 1)
        love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 6)
        love.graphics.setColor(c[1], c[2], c[3], 0.14)
        love.graphics.rectangle("fill", cardX + 2, cardY + 2, cardW - 4, 48)
        love.graphics.setColor(c[1], c[2], c[3], 1)
        love.graphics.rectangle("fill", cardX + cardW / 2 - 14, cardY + 13, 28, 28, 3)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 6)
        love.graphics.setColor(0.95, 0.97, 1, 1)
        love.graphics.printf(e.name, cardX, cardY + 60, cardW, "center")
        love.graphics.setColor(0.8, 0.85, 0.92, 1)
        love.graphics.printf(e.description or "", cardX + 12, cardY + 90, cardW - 24, "center")

        -- Artifacts (mutations), revealed once activated.
        local activeIds = {}
        for _, up in ipairs(EnemyRegistry.activeUpgrades or {}) do if up.id then activeIds[up.id] = true end end
        love.graphics.setColor(1.0, 0.8, 0.3, 0.9)
        love.graphics.print("ARTIFACTS", infoX, cardY + 6)
        love.graphics.setColor(1.0, 0.8, 0.3, 0.3)
        love.graphics.line(infoX, cardY + 24, infoX + infoW, cardY + 24)
        local ay = cardY + 34
        if #e.mutations == 0 then
            love.graphics.setColor(0.5, 0.55, 0.62, 1)
            love.graphics.print("None", infoX, ay)
        end
        for _, m in ipairs(e.mutations) do
            if activeIds[m.id] then
                love.graphics.setColor(1.0, 0.85, 0.4, 1)
                love.graphics.print(m.name, infoX, ay)
                love.graphics.setColor(0.78, 0.82, 0.88, 1)
                local _, wrapped = love.graphics.getFont():getWrap(m.description or "", infoW)
                for _, wl in ipairs(wrapped) do ay = ay + 15; love.graphics.print(wl, infoX + 8, ay) end
            else
                love.graphics.setColor(0.4, 0.43, 0.5, 1)
                love.graphics.print("??? — undiscovered artifact", infoX, ay)
            end
            ay = ay + 24
        end
    end
    love.graphics.pop()

    -- Back button.
    local b = self:backRect()
    local mx, my = love.mouse.getPosition()
    local hov = mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h
    love.graphics.setColor(0.2, 0.22, 0.26, 1)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 5)
    love.graphics.setColor(hov and 0.6 or 0.4, 0.7, 0.9, 1)
    love.graphics.setLineWidth(hov and 2 or 1)
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h, 5)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("< BACK", b.x, b.y + b.h / 2 - 6, b.w, "center")
end

function Codex:draw()
    if not self.isActive then return end
    local p = self.panel
    local mx, my = love.mouse.getPosition()

    -- Dim overlay + panel.
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    love.graphics.setColor(0.04, 0.06, 0.09, 0.98)
    love.graphics.rectangle("fill", p.x, p.y, p.w, p.h, 10)
    love.graphics.setColor(0.2, 0.55, 0.8, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", p.x, p.y, p.w, p.h, 10)
    love.graphics.setLineWidth(1)

    -- Title.
    love.graphics.setColor(0.3, 0.7, 1, 1)
    love.graphics.print("CODEX", p.x + 24, p.y + 16)

    -- Tabs.
    local tabs = self:tabRects()
    for _, key in ipairs({ "enemies", "turrets" }) do
        local t = tabs[key]
        local active = (self.tab == key)
        local hov = mx >= t.x and mx <= t.x + t.w and my >= t.y and my <= t.y + t.h
        love.graphics.setColor(active and {0.1, 0.35, 0.5, 1} or {0.12, 0.13, 0.16, 1})
        love.graphics.rectangle("fill", t.x, t.y, t.w, t.h, 5)
        love.graphics.setColor(active and {0.3, 0.8, 1.0, 1} or (hov and {0.5, 0.6, 0.7, 1} or {0.4, 0.42, 0.48, 1}))
        love.graphics.setLineWidth(active and 2 or 1)
        love.graphics.rectangle("line", t.x, t.y, t.w, t.h, 5)
        love.graphics.setColor(1, 1, 1, active and 1 or 0.75)
        love.graphics.printf(key == "enemies" and "ENEMIES" or "TURRETS", t.x, t.y + t.h / 2 - 6, t.w, "center")
    end

    -- Close.
    local cr = self:closeRect()
    local hovC = mx >= cr.x and mx <= cr.x + cr.w and my >= cr.y and my <= cr.y + cr.h
    love.graphics.setColor(hovC and {1, 0.4, 0.4, 1} or {0.6, 0.6, 0.65, 1})
    love.graphics.printf("X", cr.x, cr.y + 4, cr.w, "center")

    if self.selected then
        self:drawDetail()
    else
        for _, r in ipairs(self:gridRects()) do
            local hov = mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
            entryCard(self, r, hov)
        end
    end

    -- Hand cursor over interactive elements.
    Cursor.hover(cr.x, cr.y, cr.w, cr.h)
    Cursor.hover(tabs.enemies.x, tabs.enemies.y, tabs.enemies.w, tabs.enemies.h)
    Cursor.hover(tabs.turrets.x, tabs.turrets.y, tabs.turrets.w, tabs.turrets.h)
    if self.selected then
        local b = self:backRect()
        Cursor.hover(b.x, b.y, b.w, b.h)
    else
        for _, r in ipairs(self:gridRects()) do
            if self:isRevealed(r.entry) then Cursor.hover(r.x, r.y, r.w, r.h) end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

local function hit(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function Codex:mousepressed(x, y, button)
    if not self.isActive or button ~= 1 then return false end

    if hit(self:closeRect(), x, y) then self:close(); return true end

    local tabs = self:tabRects()
    if hit(tabs.enemies, x, y) then self.tab = "enemies"; self.selected = nil; return true end
    if hit(tabs.turrets, x, y) then self.tab = "turrets"; self.selected = nil; return true end

    if self.selected then
        if hit(self:backRect(), x, y) then self.selected = nil end
        return true
    end

    for _, r in ipairs(self:gridRects()) do
        if hit(r, x, y) then
            if self:isRevealed(r.entry) then self.selected = r.entry end
            return true
        end
    end
    return true -- consume all clicks while open
end

function Codex:keypressed(key)
    if not self.isActive then return false end
    if key == "escape" then
        if self.selected then self.selected = nil else self:close() end
        return true
    end
    return false
end

return Codex
