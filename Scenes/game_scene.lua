local game_scene = {
    turrets = {}, -- Table to hold turret instances
    enemies = {}, -- Table to hold enemy instances
    effects = {}, -- Table to hold effects
    bullets = {}, -- Table to hold bullet instances
    base = nil, -- Reference to the base object
    wave = 0, -- Current wave number
    money = 0, -- Money available for purchasing turrets
}
game_scene.__index = game_scene
local scene = require("Scenes.scene") -- Import the base scene class
setmetatable(game_scene, { __index = scene })

local time_mul = 1
local Enemy = require("Enemies.Enemy")
local Turret = require("Turrets.Turret")

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
    table.insert(self.turrets, Turret:new({mode = 'poop'}, self))
    time_mul = 1 -- game starts frozen
end

function game_scene:mousepressed(x, y, button)
    
end

function game_scene:update(dt)
    local dt = dt * time_mul -- Apply time multiplier to dt
    self:spawner(dt)
    base:update(dt)
    
    update(self.turrets, dt)
    update(self.enemies, dt)
    update(self.effects, dt)
    update(self.bullets, dt)
    cleanup(self.turrets)
    cleanup(self.enemies)
    cleanup(self.effects)
    cleanup(self.bullets)
end

function game_scene:draw()
    --love.graphics.clear(0.5, 0.5, 0.5) -- Clear the screen with a dark color
    ground:draw()
    base:draw()
    draw(self.turrets)
    draw(self.enemies)
    draw(self.effects)
    draw(self.bullets)
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
local spawnRate = 2
local spawntimer = 2
local spawned = 0
local spawnAmount = 10 -- Number of enemies to spawn per wave

function game_scene:spawner(dt)
    if spawned >= spawnAmount then
        return -- Stop spawning if the wave is complete
    end
    spawntimer = spawntimer - dt
    if spawntimer < 0 then -- Adjust the spawn rate as needed
        local x = 800
        local y = love.math.random(120, 480)
        local enemy1 = {
            radius = 5,
            hp = 50,
            speed = 15,
            damage = 10,
            color = {1, 0, 0}, -- Red color for enemies
            xp = 10
        }
        table.insert(self.enemies, Enemy:new(x, y, base, enemy1)) -- Add a new enemy at random position
        spawntimer = spawnRate -- Reset the spawn timer
        spawned = spawned + 1
    end
end

function update(table, dt)
    for i = #table, 1, -1 do
        local item = table[i]
        if item.update then
            item:update(dt)
        end
    end
end

function draw(t)
    for i = #t, 1, -1 do
        local item = t[i]
        if item.draw then
            item:draw()
        end
    end
end

function cleanup(t)
    for i = #t, 1, -1 do
        local item = t[i]
        if item.destroyed then
            table.remove(t, i) -- Remove item if it is destroyed
        end
    end
end

return game_scene