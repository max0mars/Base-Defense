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
        self.base = Base:new({game = self})
        self.rewardSystem = RewardSystem:new(self)
        self.WaveSpawner = WaveSpawner:new({game = self})
        self.inputHandler = InputHandler:new(self)
        self.state = "startup" -- Current game state: "startup", "wave", "placing", "reward", "gameover"
    end
    
    collision:setGrid(800, 600, 32) -- Set collision grid size
    self:addObject(self.base) -- Add the base object to the game
    self.ground = ground
    
    -- Transition to preparing state after initialization
    self:setState("preparing")
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
        self:setState("gameover")
        return
    end

    -- Check if wave is complete and transition to reward state
    if self:isState("wave") and self.WaveSpawner.waveState == "complete" then
        self:setState("reward")
        self.rewardSystem:activate()
    end
    
    -- Check if reward phase is over and go to preparing state
    if self:isState("reward") and not self.rewardSystem.isActive then
        self:setState("preparing")
    end
    
    -- Check if in preparing state and enter key pressed to start wave
    if self:isState("preparing") then
        -- Wave start is handled by InputHandler when enter key is pressed
    end

    -- Update input handler
    self.inputHandler:update(dt)

    -- Update game objects continuously (time doesn't freeze during rewards or placement)
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
    
    self:takeOutTheTrash() -- remove references to destroyed objects
end

function game:placeBuilding(building)
    self:setState("placing")
    self.blueprint = building:new({game = self})
end

function game:setState(newState)
    self.state = newState
end

function game:getState()
    return self.state
end

function game:isState(checkState)
    return self.state == checkState
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