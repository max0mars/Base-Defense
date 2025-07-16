local EnemyData = require("Enemies.EnemyData")
local Base = require("Buildings.Base")
local Turret = require("Turrets.Turret")
local collision = require("Scripts.collision")

local game = {}
game.__index = game

function game:load(saveData)
    if saveData then
        self.objects = saveData.objects or {} -- Load existing game objects
        self.score = saveData.score or 0 -- Load score from save data
        self.xp = saveData.xp or 0 -- Load XP from save data
        self.money = saveData.money or 0 -- Load money from save data
        self.wave = saveData.wave or 0 -- Load current wave from save data
        self.base = saveData.base or Base:new() -- Load base object from save data
    else
        self.objects = {} -- Table to hold game objects
        self.score = 0 -- Initialize score
        self.xp = 0 -- Initialize XP
        self.money = 0 -- Initialize money
        self.wave = 0 -- Initialize wave
        local baseConfig = {
            x = 50,
            y = 300,
            w = 100,
            h = 400,
            hp = 1000,
            maxHp = 1000
        }
        self.base = Base:new(baseConfig)
    end
    collision:setGrid(800, 600, 16) -- Set collision grid size
    self:addObject(Turret:new({x = 50, y = 300, mode = 'auto', game = self}, self))
end

function game:addXP(amount)
    self.xp = self.xp + amount
end

function game:addMoney(amount)
    self.money = self.money + amount
end

function game:addObject(obj)
    table.insert(self.objects, obj) -- Add the object to the game's object list
end

function game:takeOutTheTrash()
    for i = #self.objects, 1, -1 do
        if self.objects[i].destroyed then
            table.remove(self.objects, i) -- Remove destroyed objects from the list
        end
    end
end

function game:update(dt)
    collision:resetGrid() -- Reset the collision grid for the new frame
    for _, obj in ipairs(self.objects) do
        if not obj.destroyed and obj.update then
            collision:addToGrid(obj) -- Add the object to the collision grid
            obj:update(dt) -- Update each object if it has an update method
        end
    end
    collision:checkAllCollisions() -- Check for collisions between objects
    self:spawner(dt) -- Handle enemy spawning
    self:takeOutTheTrash() -- Clean up destroyed objects
end

local ground = {
    x = 0,
    y = 100,
    w = 800,
    h = 400,
    color = {love.math.colorFromBytes(30, 82, 12)}
}

function game:draw()
    ground:draw() -- Draw the ground
    self.base:draw() -- Draw the base
    for _, obj in ipairs(self.objects) do
        if not obj.destroyed and obj.draw then
            obj:draw() -- Draw each object if it has a draw method
        end
    end
end

function game:mousepressed()

end

function ground:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
end


-- eventually spawner will be moved to a separate file
local spawnRate = 0.2
local spawntimer = 2
local spawned = 0
local spawnAmount = math.huge -- Number of enemies to spawn per wave
function game:spawner(dt)
    if spawned >= spawnAmount then
        return -- Stop spawning if the wave is complete
    end
    spawntimer = spawntimer - dt
    if spawntimer < 0 then -- Adjust the spawn rate as needed
        self:addObject(EnemyData:new("basic", 800, math.random(110, 490))) -- Add a new enemy at random position
        spawntimer = spawnRate -- Reset the spawn timer
        spawned = spawned + 1
    end
end

return game