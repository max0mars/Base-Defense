-- DevEnemySpawnerUI.lua: Developer-mode panel listing every enemy in the game.
-- Click one to spawn it at the right edge of the battlefield right away
-- (shift+click spawns several). Stays open so you can build a mix; the battle
-- is frozen while it's open. Toggle with F11, or click outside to close.

local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
local DevMode       = require("Game.Dev.DevMode")
local Cursor        = require("Game.GUI.Cursor")

local DevEnemySpawnerUI = {}
DevEnemySpawnerUI.__index = DevEnemySpawnerUI

DevEnemySpawnerUI.BULK = 5 -- Enemies spawned per shift+click

-- Layout constants.
local NUM_COLS = 3
local CELL_W   = 200
local CELL_H   = 26
local GAP      = 5
local TITLE_H  = 44
local PAD      = 14

function DevEnemySpawnerUI:new(game)
    local obj = setmetatable({ game = game, isActive = false }, self)
    obj.spawned = {} -- Count per enemy id, shown on each cell
    return obj
end

function DevEnemySpawnerUI:open()
    self.isActive = true
    self.spawned = {}
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

--- Spawns `count` of `enemy` (a registry entry) on the battlefield.
function DevEnemySpawnerUI:spawn(enemy, count)
    for _ = 1, count do
        self.game.WaveSpawner:spawnEnemy(enemy.class)
    end
    self.spawned[enemy.id] = (self.spawned[enemy.id] or 0) + count
    DevMode.notify("Spawned " .. count .. "x " .. enemy.id)
end

function DevEnemySpawnerUI:update(dt) end

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
    love.graphics.printf("click: spawn 1   ·   shift+click: spawn " .. self.BULK .. "   ·   F11 or click outside to close",
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
        if self.spawned[enemy.id] then
            right = "x" .. self.spawned[enemy.id] .. "   " .. right
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
            self:spawn(enemy, bulk and self.BULK or 1)
            break
        end
    end
    return true
end

return DevEnemySpawnerUI
