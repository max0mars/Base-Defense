local Base = require("Game.Base")
local Turret = require("Buildings.Turrets.Turret")
local collision = require("Physics.collisionSystem_brute")
local enemy = require("Enemies.Enemy")

local game = {}
game.__index = game

local ground = {
    x = 0,
    y = 100,
    w = 800,
    h = 400,
    color = {love.math.colorFromBytes(30, 82, 12)}
}

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
        self.base = Base:new()
    end
    collision:setGrid(800, 600, 32) -- Set collision grid size
    self:addObject(self.base) -- Add the base object to the game
    self:newBuilding(Turret:new({game = self}), 1)
    self:newBuilding(Turret:new({game = self}), 2)
    self:newBuilding(Turret:new({game = self}), 3)
    self:newBuilding(Turret:new({game = self}), 4)
    self:newBuilding(Turret:new({game = self}), 5)
    self:newBuilding(Turret:new({game = self}), 22)
    self:newBuilding(Turret:new({game = self}), 18)
    self:newBuilding(Turret:new({game = self}), 45)
    self:newBuilding(Turret:new({game = self}), 51)
    self:newBuilding(Turret:new({game = self}), 39)
    self.ground = ground
end

function game:newBuilding(building, slot)
    self.base:addBuilding(building, slot)
    self:addObject(building)
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

local printTimer = 0
local printInterval = 1 -- Print every second

function game:update(dt)
    for _, obj in ipairs(self.objects) do
        if not obj.destroyed then
            if obj.update then
                obj:update(dt) -- Update each object if it has an update method
            end
        end
    end
    -- printTimer = printTimer + dt
    -- if printTimer >= printInterval then
    --     printTimer = 0
    -- end
    collision:bruteforceTagged(self.objects, "bullet", "enemy")
    self:spawner(dt) -- Handle enemy spawning
    self:takeOutTheTrash() -- Clean up destroyed objects
end



function game:draw()
    ground:draw() -- Draw the ground
    for _, obj in ipairs(self.objects) do
        if not obj.destroyed and obj.draw then
            obj:draw() -- Draw each object if it has a draw method
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Score: " .. self.xp, 10, 10)
end

function game:mousepressed()

end

function ground:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
end


-- eventually spawner will be moved to a separate file
local spawnRate = 2
local spawntimer = 0
local spawned = 0
local spawnAmount = math.huge -- Number of enemies to spawn per wave
function game:spawner(dt)
    if spawned >= spawnAmount then
        return -- Stop spawning if the wave is complete
    end 
    spawntimer = spawntimer - dt
    if spawntimer < 0 then -- Adjust the spawn rate as needed
        config = {
            game = self,
            x = 800,
            y = math.random(110, 490)
        }
        self:addObject(enemy:new(config)) -- Add a new enemy at random position
        spawntimer = spawnRate -- Reset the spawn timer
        spawned = spawned + 1
    end
end

return game