local game = {}
game.__index = game

local Base = require("Game.Base")
--local Turret = require("Buildings.Turrets.Turret")
local mortar = require("Buildings.Turrets.Mortar")
local collision = require("Physics.collisionSystem_brute")
local enemy = require("Enemies.Enemy")
local RewardSystem = require("Game.RewardSystem")
local WaveSpawner = require("Game.WaveSpawner")


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

    self:selectedSlot()

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

function game:selectedSlot()
    mouseX, mouseY = love.mouse.getPosition()
    local gridX = math.floor(mouseX / self.base.buildGrid.cellSize) + 1
    local gridY = math.floor((mouseY - self.base.buildGrid.y) / self.base.buildGrid.cellSize) + 1
    if gridX >= 1 and gridX <= self.base.buildGrid.width and
       gridY >= 1 and gridY <= self.base.buildGrid.height then
        local slot = (gridY - 1) * self.base.buildGrid.width + gridX
        self.base.selectedSlot = slot
    else
        self.base.selectedSlot = nil
    end
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

function game:mousepressed(x, y, button)
    -- Pass mouse events to reward system
    if self.rewardSystem then
        self.rewardSystem:mousepressed(x, y, button)
    end
    if self.placing and button == 1 then
        -- Place building if in placing mode
        local gridX = math.floor(x / self.base.buildGrid.cellSize) + 1
        local gridY = math.floor((y - self.base.buildGrid.y) / self.base.buildGrid.cellSize) + 1
        if gridX >= 1 and gridX <= self.base.buildGrid.width and
           gridY >= 1 and gridY <= self.base.buildGrid.height then
            local slot = (gridY - 1) * self.base.buildGrid.width + gridX
            if not self.base.buildGrid.buildings[slot] then
                self:newBuilding(self.blueprint, slot)
                self.placing = false
                self.base.placing = false
                self.blueprint = nil
            else
                print("Slot " .. slot .. " is already occupied!")
            end
        end
    end
end

function game:keypressed(key)
    -- Pass key events to reward system
    if self.rewardSystem then
        self.rewardSystem:keypressed(key)
    end
end

function ground:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
end



--*******************************************************
--*******************************************************
--*******************************************************
--*******************************************************

-- eventually spawner will be moved to a separate file
-- local spawnRate = 0.5 -- Time in seconds between spawns
-- local spawntimer = 0
-- local spawned = 0
-- local spawnAmount = 3 -- Number of enemies to spawn per wave
-- local rewardTriggered = false -- Flag to track if reward was shown for current wave
-- function game:spawner(dt)
--     if spawned >= spawnAmount then
--         -- Check if all enemies are defeated and reward hasn't been triggered
--         local enemiesAlive = 0
--         for _, obj in ipairs(self.objects) do
--             if obj.tag == "enemy" and not obj.destroyed then
--                 enemiesAlive = enemiesAlive + 1
--             end
--         end
        
--         if enemiesAlive == 0 and not rewardTriggered then
--             -- Show reward selection at end of wave
--             self.upgrade = true
--             rewardTriggered = true
--         end

--         if enemiesAlive == 0 and not self.rewardSystem.isActive then
--             wave = wave + 1
--             spawnAmount = spawnAmount + spawnAmount * 1.3
--             spawned = 0 -- Reset spawned counter for new wave
--             rewardTriggered = false -- Reset reward flag for new wave
--         end
--         return -- Stop spawning if the wave is complete
--     end
--     spawntimer = spawntimer - dt
--     if spawntimer < 0 then -- Adjust the spawn rate as needed
--         config = {
--             game = self,
--             x = 800,
--             y = math.random(110, 490)
--         }
--         self:addObject(enemy:new(config)) -- Add a new enemy at random position
--         spawntimer = spawnRate -- Reset the spawn timer
--         spawned = spawned + 1
--     end
-- end

return game