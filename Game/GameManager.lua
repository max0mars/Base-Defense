local game = {}
game.__index = game

local Base = require("Game.Base")
local collision = require("Physics.collisionSystem_brute")
local enemy = require("Enemies.Enemy")
local RewardSystem = require("Game.RewardSystem")
local WaveSpawner = require("Game.WaveSpawner")
local InputHandler = require("Game.InputHandler")
local Inventory = require("Game.Inventory")
local MainTurret = require("Buildings.Turrets.MainTurret")
local EffectManager = require("Game.StatusEffects.EffectManager")


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
        self.money = 5000 -- Initialize money
        self.wave = 0 -- Initialize wave
        self.base = Base:new({game = self})
        self.rewardSystem = RewardSystem:new(self)
        self.WaveSpawner = WaveSpawner:new({game = self})
        self.inputHandler = InputHandler:new(self)
        self.state = "startup" -- Current game state: "startup", "wave", "gameover"
        self.inputMode = "idle"
        self.rewardCost = 50
        self.autoStartWave = false
        self.inventory = Inventory:new(self)
        self.globalEffectManager = EffectManager:new() -- Global manager with no owner
        local damageBuff = {
            name = "Damage Buff",
            statModifiers = {damage = {mult = 0.1}},
            description = "Increases damage by 10%",
            duration = math.huge,
        }
        local fireRateDebuff = {
            name = "Fire Rate Debuff",
            statModifiers = {fireRate = {mult = -0.1}},
            description = "Decreases fire rate by 10%",
            duration = math.huge,
        }
        self.globalEffectManager:applyEffect(damageBuff)
        self.globalEffectManager:applyEffect(damageBuff)
        self.globalEffectManager:applyEffect(damageBuff)
        self.globalEffectManager:applyEffect(fireRateDebuff)
    end
    
    collision:setGrid(800, 600, 32) -- Set collision grid size
    self:addObject(self.base) -- Add the base object to the game
    self.ground = ground
    
    -- Place MainTurret in center slot (slot 7: row 2, column 3)
    self.mainTurret = MainTurret:new({game = self})
    local gridWidth = self.base.buildGrid.width
    local gridHeight = self.base.buildGrid.height
    local centerRow = math.ceil(gridHeight / 2)
    local centerCol = math.ceil(gridWidth / 2)

    self:newBuilding(self.mainTurret, (centerRow - 1) * gridWidth + centerCol)
    
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

function game:recalculateAllBuffs()
    -- Clear all existing buffs from turrets
    for _, obj in ipairs(self.objects) do
        if obj.clearAllBuffs then -- This is a turret
            obj:clearAllBuffs()
        end
    end
    
    -- Reapply all buffs from buff buildings
    for _, obj in ipairs(self.objects) do
        if obj.applyBuffs then -- This is a buff building
            obj:applyBuffs()
        end
    end
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
    if self.base.hp <= 0 then -- this should be handled elsewhere
        self:setState("gameover")
        return
    end

    if self.rewardSystem and self.rewardSystem.isActive then return end

    if self:isState("startup") then
        
    end
    -- Check if wave is complete and transition to preparing state
    if self:isState("wave") and self.WaveSpawner.waveState == "complete" then
        self:setState("preparing")
    end
    
    -- Check if in preparing state and enter key pressed to start wave
    if self:isState("preparing") then
        if self.autoStartWave and self.WaveSpawner.waveState == "idle" then
            self:recalculateAllBuffs() -- Recalculate all buffs before wave starts
            self.WaveSpawner:startNextWave()
            self:setState("wave")
        end
    end

    -- Update input handler
    self.inventory:update(dt)
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
    collision:bruteforceByType(self.objects, "bullet", "enemy")
    self.WaveSpawner:update(dt)
    self.globalEffectManager:update(dt)
    
    self:takeOutTheTrash() -- remove references to destroyed objects
end

function game:placeBuilding(building, sourceReward)
    self.inputMode = "placing"
    self.blueprint = building:new({game = self})
    self.blueprint.rewardCard = sourceReward
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
        if obj.effectManager then
            obj.effectManager:drawStatusEffects() -- Draw status effects for living objects
        end
    end

    -- Draw building preview directly at mouse position (using its own draw method)
    if self.inputMode == "placing" and self.blueprint then
        --self.blueprint.x, self.blueprint.y = self.inputHandler.mouseX, self.inputHandler.mouseY
        self.blueprint.isPreview = true
        self.blueprint:draw(self.inputHandler.mouseX, self.inputHandler.mouseY)
        self.blueprint.isPreview = false
    end

    -- Reset color at end of draw to be safe
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw building tooltips on top of everything else (except UI)
    local hovered = self.inputHandler.hoveredBuilding
    if hovered and hovered.showEffects and hovered.effectManager and hovered.effectManager.drawTooltip then
        local tipX, tipY = hovered.x, hovered.y
        if hovered.getCenterPosition then
            tipX, tipY = hovered:getCenterPosition()
        end
        hovered.effectManager:drawTooltip(tipX, tipY)
    end
    
    self.inventory:draw()
    
    -- Draw reward system on top of everything
    if self.rewardSystem then
        self.rewardSystem:draw()
    end
    if self:isState("startup") then
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf("Aim the main turret with mouse. Click to shoot. Other Turrets will fight on their own. Hit Enter to Continue. ", 0, love.graphics.getHeight() / 2 - 20, love.graphics.getWidth(), "center")
    elseif self:isState("preparing") then
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf("Press Enter to Start Wave ", 0, love.graphics.getHeight() / 2 - 20, love.graphics.getWidth(), "center")
    end
    
    -- Draw reward UI prompt
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Press 'R' to Buy Reward ($" .. (self.rewardCost or 0) .. ")", 0, 10, love.graphics.getWidth(), "center")
    
    -- Draw Auto-Start toggle UI prompt
    local autoText = self.autoStartWave and "ON" or "OFF"
    love.graphics.printf("Press 'A' for Auto-Start: " .. autoText, 0, 25, love.graphics.getWidth(), "center")
end


function ground:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
end

return game