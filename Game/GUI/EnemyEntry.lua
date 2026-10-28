-- Game/GUI/EnemyEntry.lua
-- One enemy's entry, opened by clicking it in the INCOMING list. Shows only that
-- enemy: its name, a short description and a looping demo of how it behaves.
-- The battle is paused while it's open; click outside it or press Esc to close.

local EnemyIndex = require("Game.Spawning.EnemyIndex")
local EnemyDemo = require("Game.GUI.EnemyDemo")

local EnemyEntry = {}
EnemyEntry.__index = EnemyEntry

local W = 560
local PAD = 20
local DEMO_W, DEMO_H = W - 2 * PAD, 170
local NAMES = { PortalMaster = "Portal Master" }

function EnemyEntry:new(game)
    return setmetatable({ game = game, isActive = false }, self)
end

local function entryFor(id)
    for _, e in ipairs(EnemyIndex) do
        if e.id == id then return e end
    end
end

--- Mutations active on this enemy, for listing in its entry. Mutations aren't
--- in the game right now, so this is empty and nothing is listed; once they're
--- back, return the active ones here (e.g. from PersistentState.activeMutations)
--- and draw() will show them under the description.
function EnemyEntry:activeMutations(enemyId)
    return {}
end

function EnemyEntry:open(enemyId)
    local entry = entryFor(enemyId)
    if not entry then return end
    self.entry = entry
    self.name = NAMES[entry.id] or entry.id
    self.isActive = true
    self.demo = nil -- built on the first draw, once the window's size is known
end

function EnemyEntry:close()
    self.isActive = false
    self.entry, self.demo = nil, nil
end

--- Window rect, sized to fit the description (and any mutation lines).
function EnemyEntry:rect()
    local font = love.graphics.getFont()
    local _, lines = font:getWrap(self.entry.description or "", W - 2 * PAD)
    local textH = #lines * font:getHeight()
    local mutationsH = #self:activeMutations(self.entry.id) * (font:getHeight() + 4)
    local h = PAD + 26 + textH + 14 + mutationsH + DEMO_H + PAD
    return { x = math.floor((VIRTUAL_WIDTH - W) / 2), y = math.floor((VIRTUAL_HEIGHT - h) / 2), w = W, h = h, textH = textH }
end

function EnemyEntry:update(dt)
    if not self.isActive or not self.demo then return end
    -- Real time: the battle (and its dt) is paused while the entry is open
    dt = love.timer.getDelta and love.timer.getDelta() or dt
    self.demo:update(math.min(dt, 0.1))
end

function EnemyEntry:draw()
    if not self.isActive then return end
    local r = self:rect()
    local entry = self.entry
    local color = entry.color or { 1, 0.3, 0.3, 1 }

    love.graphics.push("all")
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    love.graphics.setColor(0.06, 0.07, 0.1, 0.98)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 10)
    love.graphics.setColor(color[1], color[2], color[3], 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10)

    local y = r.y + PAD
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.print(self.name:upper(), r.x + PAD, y)
    love.graphics.setColor(0.5, 0.55, 0.62, 1)
    love.graphics.printf("ESC to close", r.x + PAD, y, r.w - 2 * PAD, "right")
    y = y + 26
    love.graphics.setColor(0.85, 0.88, 0.95, 1)
    love.graphics.printf(entry.description or "", r.x + PAD, y, r.w - 2 * PAD, "left")
    y = y + r.textH + 14

    local font = love.graphics.getFont()
    for _, m in ipairs(self:activeMutations(entry.id)) do
        love.graphics.setColor(1, 0.8, 0.3, 1)
        love.graphics.print(m.name .. ": " .. (m.description or ""), r.x + PAD, y)
        y = y + font:getHeight() + 4
    end
    love.graphics.pop()

    local demoRect = { x = r.x + PAD, y = y, w = DEMO_W, h = DEMO_H }
    if not self.demo then self.demo = EnemyDemo.new(entry.id, demoRect) end
    self.demo.rect = demoRect
    self.demo:draw()
end

function EnemyEntry:mousepressed(x, y, button)
    if not self.isActive then return false end
    local r = self:rect()
    if x < r.x or x > r.x + r.w or y < r.y or y > r.y + r.h then self:close() end
    return true -- captures all clicks while open
end

function EnemyEntry:keypressed(key)
    if not self.isActive then return false end
    if key == "escape" then self:close() end
    return true
end

return EnemyEntry
