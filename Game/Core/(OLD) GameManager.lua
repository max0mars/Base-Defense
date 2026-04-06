local game = {}
game.__index = game

local Base = require("Game.Core.Base")
local collision = require("Physics.collisionSystem_brute")
local enemy = require("Enemies.Enemy")
local RewardSystem = require("Game.Rewards.RewardSystem")
local WaveSpawner = require("Game.Spawning.WaveSpawner")
local InputHandler = require("Game.Input.InputHandler")
local Inventory = require("Game.Inventory.Inventory")
local MainTurret = require("Buildings.Turrets.MainTurret")
local EffectManager = require("Game.StatusEffects.EffectManager")
local BattlefieldGrid = require("Game.Core.BattlefieldGrid")
local WaveDirector = require("Game.Spawning.WaveDirector")
local GUIManager = require("Game.GUI.GUIManager")
local SpecialUpgradeManager = require("Game.Rewards.SpecialUpgradeManager")


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
        self.money = 75 -- Initialize money
        self.luck = 1  -- Default Luck level (1-10)
        self.wave = 0 -- Initialize wave
        self.base = Base:new({game = self})
        self.battlefieldGrid = BattlefieldGrid:new(self)
        self.rewardSystem = RewardSystem:new(self)
        self.WaveSpawner = WaveSpawner:new({game = self})
        self.waveDirector = WaveDirector:new(self)
        self.inputHandler = InputHandler:new(self)
        self.state = "startup" -- Current game state: "startup", "wave", "gameover"
        self.inputMode = "idle"
        self.rewardCost = 50
        self.autoStartWave = false
        self.inventory = Inventory:new(self)
        self.gui = GUIManager:new(self)
        self.specialWaveInterval = 5 -- How many waves per special upgrade
        self.playerEffectManager = EffectManager:new() -- Global player manager
        self.enemyEffectManager = EffectManager:new()  -- Global enemy manager
        self.specialUpgradeManager = SpecialUpgradeManager:new(self)
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

    local centerSlot = (centerRow - 1) * gridWidth + centerCol
    self:newBuilding(self.mainTurret, centerSlot)
    self.base.buildGrid.unlocked[centerSlot] = true -- Starting visibility anchor
    
    love.mouse.setVisible(false) -- Hide the system cursor
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
    return (self.rewardSystem and self.rewardSystem.isActive) or 
           (self.specialUpgradeManager and self.specialUpgradeManager.isActive)
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
    if self.specialUpgradeManager and self.specialUpgradeManager.isActive then return end

    if self:isState("startup") then
        
    end
    -- Check if wave is complete and transition
    if self:isState("wave") and self.WaveSpawner.waveState == "complete" then
        if self.wave % self.specialWaveInterval == 0 then
            self.specialUpgradeManager:activate()
        end
        self:setState("preparing")
    end
    
    -- Check if in preparing state and enter key pressed to start wave
    if self:isState("preparing") then
        if self:isRewardSystemActive() then return end
        
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
    self.playerEffectManager:update(dt)
    self.enemyEffectManager:update(dt)
    self.gui:update(dt)
    
    if self.specialUpgradeManager and self.specialUpgradeManager.isActive then
        -- We can add specific update logic for special upgrades here if needed
    end
    
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
    if self.battlefieldGrid then
        self.battlefieldGrid:draw()
    end
    for _, obj in ipairs(self.objects) do
        if not obj.destroyed and obj.draw then
            obj:draw() -- Draw each object if it has a draw method
            if obj.drawHealthBar or obj.drawReloadBar then
                table.insert(healthyboys, obj)
            end
        end
    end
    for _, obj in ipairs(healthyboys) do
        if obj.drawHealthBar then
            obj:drawHealthBar() -- Draw health bars for living objects
        end
        if obj.effectManager then
            obj.effectManager:drawStatusEffects() -- Draw status effects for living objects
        end
        if obj.drawReloadBar then
            obj:drawReloadBar()
        end
    end

    

    -- Reset color at end of draw to be safe
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw UI (on top of world)
    self.gui:draw()
    
    -- Draw building preview directly at mouse position (using its own draw method)
    if self.inputMode == "placing" and self.blueprint then
        --self.blueprint.x, self.blueprint.y = self.inputHandler.mouseX, self.inputHandler.mouseY
        self.blueprint.isPreview = true
        self.blueprint:draw(self.inputHandler.mouseX, self.inputHandler.mouseY)
        self.blueprint.isPreview = false
    end

    -- Draw reward system on top of everything
    if self.rewardSystem and self.rewardSystem.isActive then
        self.rewardSystem:draw()
    end
    
    if self.specialUpgradeManager and self.specialUpgradeManager.isActive then
        self.specialUpgradeManager:draw()
    end

    -- Draw custom cursor (Red X)
    local mx, my = love.mouse.getPosition()
    local halfSize = 10
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.circle("fill", mx, my, 3, 5)
    love.graphics.setColor(1, 1, 1, 1)
end


function ground:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
end

return game