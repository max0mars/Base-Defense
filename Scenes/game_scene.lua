local game_scene = {}

local time_mul = 1
require("explosions")
local Auto_Mortar = require("Auto_Mortar")
local Enemy = require("Enemy")

local wave = 0
local money = 0 -- Initialize money variable
base = require("Base")

local ground = {
    x = 0,
    y = 100,
    w = 800,
    h = 400,
    color = {love.math.colorFromBytes(30, 82, 12)}
}

function game_scene:load()
    base.x = 0
    base.y = 100
    base.w = 100
    base.h = 400
    base.hp = 1000
    base.maxHp = 1000

    Auto_Turrets = {}
    Main_Weapon = {}
    effects = {}
    enemies = {} -- Initialize an empty tables
    time_mul = 0 -- game starts frozen
end

function game_scene:mousepressed(x, y, button)
    
end

function game_scene:update(dt)
    local dt = dt * time_mul -- Apply time multiplier to dt
    spawner(dt)
    base:update(dt)
    if(Main_Weapon and Main_Weapon.update) then
        Main_Weapon:update(dt) -- Update the main weapon if it exists
    end
    for _, turret in ipairs(Auto_Turrets) do
        turret:update(dt, enemies, effects) -- Pass enemies and effects to each Auto_Turret
    end
    for i = #enemies, 1, -1 do
        local enemy = enemies[i]
        enemy:update(dt)
        if enemy.destroyed then
            if enemy.death then
                enemy:death()
            end
            --xp = xp + enemy.xp -- Add money from defeated enemy
            table.remove(enemies, i) -- Remove enemy if HP is zero or less
        end
    end
    for i = #effects, 1, -1 do
        effects[i]:update(dt)
        if effects[i].timer >= effects[i].duration then
            table.remove(effects, i) -- Remove effect if timer exceeds duration
        end
    end
end

function game_scene:draw()
    --love.graphics.clear(0.5, 0.5, 0.5) -- Clear the screen with a dark color
    ground:draw()
    base:draw()
    for _, turret in ipairs(Auto_Turrets) do
        turret:draw()
    end
    for _, enemy in ipairs(enemies) do
        enemy:draw()
    end
    for _, effect in ipairs(effects) do
        effect:draw()
    end
end

function ground:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
end

function love.keypressed(key)
    if key == "space" then
        mortar.mode = (mortar.mode + 1) % 2 -- Toggle mortar mode between 0 and 1
    elseif key == "escape" then
        love.event.quit() -- Exit the game when Escape is pressed
    end
end

function math.normalize(x,y) local l=(x*x+y*y)^.5 if l==0 then return 0,0,0 else return x/l,y/l,l end end
local spawnRate = 0.5
local spawntimer = 1

function spawner(dt)
    spawntimer = spawntimer - dt
    if spawntimer < 0 then -- Adjust the spawn rate as needed
        local x = 800
        local y = love.math.random(120, 480)
        table.insert(enemies, Enemy:new(x, y, 5, 100, 10, 10, base)) -- Add a new enemy at random position
        spawntimer = spawnRate -- Reset the spawn timer
    end
end

return game_scene