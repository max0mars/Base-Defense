local game = {}
game.__index = game

local Base = require("Game.Base")
local collision = require("Physics.collisionSystem_brute")
local enemy = require("Enemies.Enemy")
local RewardSystem = require("Game.RewardSystem")
local WaveSpawner = require("Game.WaveSpawner")
local InputHandler = require("Game.InputHandler")


local ground = {
    x = 0,
    y = 100,
    w = 800,
    h = 400,
    color = {love.math.colorFromBytes(30, 82, 12)}
}

function game:load(saveData)
    if saveData then --no save system implemented yet
        
    else
        self.objects = {} -- Table to hold game objects
        self.score = 0 -- Initialize score
        self.xp = 0 -- Initialize XP
        self.money = 0 -- Initialize money
        self.wave = 0 -- Initialize wave
        self.base = Base:new()
        self.rewardSystem = RewardSystem:new(self)
        self.WaveSpawner = WaveSpawner:new({game = self})
        self.inputHandler = InputHandler:new(self)
        self.placing = false
        self.upgrade = true
    end
    
    collision:setGrid(800, 600, 32) -- Set collision grid size
    self:addObject(self.base) -- Add the base object to the game
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

function game:isRewardSystemActive()
    return self.rewardSystem and self.rewardSystem.isActive
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
    if self.base.hp <= 0 then
        self.gameover = true
        return
    end
    if self.upgrade then
        self.rewardSystem:activate()
        self.upgrade = false
    end

    -- Update input handler
    self.inputHandler:update(dt)

    -- Only update game objects if reward system is not active
    if not self.rewardSystem.isActive and not self.placing then
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
        self.WaveSpawner:update(dt)
    end
    self:takeOutTheTrash() -- remove references to destroyed objects
end

function game:placeBuilding(building)
    self.base.placing = true
    self.placing = true
    self.blueprint = building:new({game = self})
end

local wave = 1
function game:draw()
    healthyboys = {}
    ground:draw() -- Draw the ground
    for _, obj in ipairs(self.objects) do
        if not obj.destroyed and obj.draw then
            obj:draw() -- Draw each object if it has a draw method
            if obj.drawHealthBar then
                table.insert(healthyboys, obj)
            end
        end
    end
    for _, obj in ipairs(healthyboys) do
        obj:drawHealthBar() -- Draw health bars for living objects
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Score: " .. self.xp, 10, 10)
    love.graphics.print("Wave: " .. wave, 10, 50)
    
    -- Draw reward system on top of everything
    if self.rewardSystem then
        self.rewardSystem:draw()
    end
end


function ground:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
end

return game