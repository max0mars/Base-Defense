require("explosions")
local Auto_Mortar = require("Auto_Mortar")
local Enemy = require("Enemy")

local ground = {
    x = 0,
    y = 100,
    w = 800,
    h = 400,
    color = {love.math.colorFromBytes(30, 82, 12)}
}

function love.load()
    love.window.setTitle("Enemy and Base Example")
    love.window.setMode(800, 600, { resizable = false, vsync = true })
    base = require("Base")
    base.x = 0
    base.y = 100
    base.w = 100
    base.h = 400
    base.hp = 1000
    base.maxHp = 1000
    
    mortar = require("Mortar")
    mortar.x = 50
    mortar.y = 300
    mortar.bullets = {}

    Auto_Turrets = {}

    Auto_Mortar = Auto_Mortar:new(50, 200, 4) -- Create an instance of Auto_Mortar with a fire rate of 4 seconds
    
    Auto_Mortar2 = Auto_Mortar:new(50, 400, 10) -- Create another instance of Auto_Mortar with a fire rate of 4 seconds
    Auto_Mortar2.damage = 150 -- Set the damage for Auto_Mortar3
    Auto_Mortar2.color = {0.1, 0.1, 0.1} -- Set the color for Auto_Mortar3
    Auto_Mortar2.bullet.color = {0.2, 0.2, 0.2} -- Set the bullet color for Auto_Mortar3
    Auto_Mortar2.bullet.r = 7
    Auto_Mortar2.bullet.explosion_radius = 200 -- Set the explosion radius for Auto_Mortar3
    Auto_Mortar2.bullet.flytime = 2


    Auto_Mortar3 = Auto_Mortar:new(50, 300, 0.2) -- Create a third instance of Auto_Mortar with a fire rate of 4 seconds
    Auto_Mortar3.damage = 5 -- Set the damage for Auto_Mortar3
    Auto_Mortar3.color = {0, 0, 1} -- Set the color for Auto_Mortar3
    Auto_Mortar3.bullet.color = {0, 0, 1} -- Set the bullet color for Auto_Mortar3
    Auto_Mortar3.bullet.r = 3
    Auto_Mortar3.bullet.explosion_radius = 40 -- Set the explosion radius for Auto_Mortar3
    Auto_Mortar3.bullet.flytime = 0.5 -- Set the explosion duration for Auto_Mortar3
    
    table.insert(Auto_Turrets, Auto_Mortar) -- Add Auto_Mortar to the Auto_Turrets table
    --table.insert(Auto_Turrets, Auto_Mortar2) -- Add Auto_Mortar2 to the Auto_Turrets table
    --table.insert(Auto_Turrets, Auto_Mortar3) -- Add Auto_Mortar3 to the Auto_Turrets table

    effects = {}
    enemies = {} -- Initialize an empty table for enemies
end

function love.mousepressed(x, y, button)
    mortar:mousepressed(x, y, button)
end

function love.update(dt)
    spawner(dt)
    base:update(dt)
    for _, turret in ipairs(Auto_Turrets) do
        turret:update(dt, enemies, effects) -- Pass enemies and effects to each Auto_Turret
    end
    mortar:update(dt, enemies, effects) -- Pass an empty table for enemies as we don't have any in this example
    for i = #enemies, 1, -1 do
        local enemy = enemies[i]
        enemy:update(dt)
        if enemy.destroyed then
            if enemy.death then
                enemy:death()
            end
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

function love.draw()
    love.graphics.clear(0.1, 0.1, 0.1) -- Clear the screen with a dark color
    ground:draw()
    base:draw()
    --mortar:draw()
    for _, turret in ipairs(Auto_Turrets) do
        turret:draw() -- Pass enemies and effects to each Auto_Turret
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
    end
end

function math.normalize(x,y) local l=(x*x+y*y)^.5 if l==0 then return 0,0,0 else return x/l,y/l,l end end
local spawnRate = 0.5
local spawntimer = 1
function spawner(dt)
    spawntimer = spawntimer - dt
    if spawntimer < 0 then -- Adjust the spawn rate as needed
        local x = 800
        local y = love.math.random(100, 500)
        table.insert(enemies, Enemy:new(x, y, 5, 100, 10, 10, base)) -- Add a new enemy at random position
        spawntimer = spawnRate -- Reset the spawn timer
    end
end