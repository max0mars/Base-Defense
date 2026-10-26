-- DevEnemySpawnerUI.lua: Developer-mode panel listing every enemy in the game.
-- Click one to queue it (shift+click queues several). Stays open so you can build
-- a mix; the battle is frozen while it's open. Once closed (F11 or click outside),
-- the queue is released one enemy at a time, spaced by a fraction of a real
-- wave's delay (DELAY_MULT), so large groups don't spawn on top of each other.

local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
local SpawningUtils = require("Game.Spawning.SpawningUtils")
local DevMode       = require("Game.Dev.DevMode")
local Cursor        = require("Game.GUI.Cursor")

local DevEnemySpawnerUI = {}
DevEnemySpawnerUI.__index = DevEnemySpawnerUI

DevEnemySpawnerUI.BULK = 5 -- Enemies queued per shift+click
DevEnemySpawnerUI.DELAY_MULT = 0.5 -- Multiplier on a wave's spawn delay for queued enemies

-- Layout constants.
local NUM_COLS = 3
local CELL_W   = 200
local CELL_H   = 26
local GAP      = 5
local TITLE_H  = 44
local PAD      = 14

function DevEnemySpawnerUI:new(game)
    local obj = setmetatable({ game = game, isActive = false }, self)
    obj.queued = {}  -- Count per enemy id queued since the panel opened, shown on each cell
    obj.queue = {}   -- Registry entries waiting to spawn, in order
    obj.timer = 0    -- Time until the next queued enemy spawns
    return obj
end

function DevEnemySpawnerUI:open()
    self.isActive = true
    self.queued = {}
end

function DevEnemySpawnerUI:close()
    self.isActive = false
end

function DevEnemySpawnerUI:toggle()
    if self.isActive then self:close() else self:open() end
end

--- Every spawnable enemy (registry entries with a class), in index order.
function DevEnemySpawnerUI:getEnemies()
    local list = {}
    for _, enemy in ipairs(EnemyRegistry.allEnemies or {}) do
        if enemy.class then table.insert(list, enemy) end
    end
    return list
end

function DevEnemySpawnerUI:getPanelRect()
    local rows = math.ceil(#self:getEnemies() / NUM_COLS)
    local w = NUM_COLS * CELL_W + (NUM_COLS - 1) * GAP + PAD * 2
    local h = TITLE_H + rows * (CELL_H + GAP) + PAD
    return (VIRTUAL_WIDTH - w) / 2, (VIRTUAL_HEIGHT - h) / 2, w, h
end

function DevEnemySpawnerUI:cellRect(i)
    local px, py = self:getPanelRect()
    local col = (i - 1) % NUM_COLS
    local row = math.floor((i - 1) / NUM_COLS)
    return px + PAD + col * (CELL_W + GAP), py + TITLE_H + row * (CELL_H + GAP), CELL_W, CELL_H
end

--- Queues `count` of `enemy` (a registry entry) to spawn.
function DevEnemySpawnerUI:enqueue(enemy, count)
    for _ = 1, count do
        table.insert(self.queue, enemy)
    end
    self.queued[enemy.id] = (self.queued[enemy.id] or 0) + count
    DevMode.notify("Queued " .. count .. "x " .. enemy.id .. " (" .. #self.queue .. " waiting)")
end

function DevEnemySpawnerUI:clearQueue()
    self.queue = {}
    self.timer = 0
end

--- Releases queued enemies one at a time, spaced like a wave. Receives dt = 0
--- while the battle is frozen (including while this panel is open).
function DevEnemySpawnerUI:update(dt)
    if dt <= 0 or #self.queue == 0 then return end
    self.timer = self.timer - dt
    while self.timer <= 0 and #self.queue > 0 do
        local enemy = table.remove(self.queue, 1)
        self.game.WaveSpawner:spawnEnemy(enemy.class)
        local nextEnemy = self.queue[1]
        if nextEnemy then
            local globalDiff = _G.PersistentState and _G.PersistentState.globalDifficulty or 1
            self.timer = self.timer + SpawningUtils.getScaledDelay(nextEnemy.baseSpawnDelay or 1.0, globalDiff) * self.DELAY_MULT
        else
            self.timer = 0
        end
    end
end

function DevEnemySpawnerUI:draw()
    if not self.isActive then return end
    local mx, my = love.mouse.getPosition()
    local px, py, pw, ph = self:getPanelRect()
    local font = love.graphics.getFont()

    love.graphics.push("all")
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

    love.graphics.setColor(0.09, 0.04, 0.03, 0.96)
    love.graphics.rectangle("fill", px, py, pw, ph, 6)
    love.graphics.setColor(1, 0.45, 0.25, 0.6)
    love.graphics.rectangle("line", px, py, pw, ph, 6)

    love.graphics.setColor(1, 0.55, 0.3, 1)
    love.graphics.printf("SPAWN ENEMIES", px, py + 8, pw, "center")
    love.graphics.setColor(0.65, 0.6, 0.6, 1)
    love.graphics.printf("click: queue 1   ·   shift+click: queue " .. self.BULK .. "   ·   close (F11 / click outside) to send",
        px, py + 24, pw, "center")

    for i, enemy in ipairs(self:getEnemies()) do
        local x, y, w, h = self:cellRect(i)
        local hovered = mx >= x and mx <= x + w and my >= y and my <= y + h
        if hovered then Cursor.wantHand = true end
        local c = enemy.color or { 1, 1, 1, 1 }

        love.graphics.setColor(0.12, 0.07, 0.06, hovered and 0.95 or 0.7)
        love.graphics.rectangle("fill", x, y, w, h, 3)
        love.graphics.setColor(c[1], c[2], c[3], hovered and 1 or 0.5)
        love.graphics.setLineWidth(hovered and 2 or 1)
        love.graphics.rectangle("line", x, y, w, h, 3)

        -- Colour swatch, name and tier
        love.graphics.setColor(c[1], c[2], c[3], 1)
        love.graphics.rectangle("fill", x + 6, y + h / 2 - 5, 10, 10, 2)
        local textY = y + h / 2 - font:getHeight() / 2
        love.graphics.setColor(1, 1, 1, hovered and 1 or 0.85)
        love.graphics.print(enemy.id, x + 22, textY)
        love.graphics.setColor(0.6, 0.6, 0.65, 1)
        local right = "T" .. (enemy.tier or 0)
        if self.queued[enemy.id] then
            right = "x" .. self.queued[enemy.id] .. "   " .. right
        end
        love.graphics.printf(right, x, textY, w - 8, "right")
    end
    love.graphics.pop()
end

--- Consumes every click while open: spawns on a cell, closes outside the panel.
function DevEnemySpawnerUI:mousepressed(x, y, button)
    if not self.isActive then return false end
    if button ~= 1 then return true end

    local px, py, pw, ph = self:getPanelRect()
    if x < px or x > px + pw or y < py or y > py + ph then
        self:close()
        return true
    end

    for i, enemy in ipairs(self:getEnemies()) do
        local cx, cy, cw, ch = self:cellRect(i)
        if x >= cx and x <= cx + cw and y >= cy and y <= cy + ch then
            local bulk = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
            self:enqueue(enemy, bulk and self.BULK or 1)
            break
        end
    end
    return true
end

return DevEnemySpawnerUI
