-- =============================================================================
-- GAME MANAGER (game.lua)
-- Manages game state, object life cycles, and coordination between systems.
-- =============================================================================

local game = {}
game.__index = game

-- -----------------------------------------------------------------------------
-- Dependencies
-- -----------------------------------------------------------------------------
-- Core Systems
local Base               = require("Game.Core.Base")
local BattlefieldGrid    = require("Game.Core.BattlefieldGrid")
local collision          = require("Physics.collisionSystem_brute")
local InputHandler       = require("Game.Input.InputHandler")

-- Gameplay Mechanics
local WaveSpawner        = require("Game.Spawning.WaveSpawner")
local WaveDirector       = require("Game.Spawning.WaveDirector")
local RewardSystem       = require("Game.Rewards.RewardSystem")
local SpecialUpgradeMgr  = require("Game.Rewards.SpecialUpgradeManager")
local Inventory          = require("Game.Inventory.Inventory")
local EffectManager      = require("Game.StatusEffects.EffectManager")

-- Entities & UI
local MainTurret         = require("Buildings.Turrets.MainTurret")
local GUIManager         = require("Game.GUI.GUIManager")
local enemy              = require("Enemies.Enemy") -- Note: Check if needed here or just in Spawner

-- -----------------------------------------------------------------------------
-- Environment Data
-- -----------------------------------------------------------------------------
local ground = {
    x = 0,
    y = 100,
    w = 800,
    h = 400,
    color = {love.math.colorFromBytes(30, 82, 12)}
}

-- -----------------------------------------------------------------------------
-- Initialization
-- -----------------------------------------------------------------------------
function game:load(saveData)
    if saveData then 
        -- Future Implementation: Handle save game loading here
    else
        -- Initialize Game State
        self.state        = "startup" -- States: "startup", "preparing", "wave", "gameover"
        self.objects      = {}        -- Entity master list
        self.score        = 0
        self.xp           = 0
        self.money        = 75
        self.luck         = 1         -- Influences reward quality (Scale 1-10)
        self.wave         = 0
        
        -- Initialize Core Gameplay Systems
        self.base            = Base:new({game = self})
        self.battlefieldGrid = BattlefieldGrid:new(self)
        self.inventory       = Inventory:new(self)
        self.inputHandler    = InputHandler:new(self)
        self.gui             = GUIManager:new(self)
        
        -- Spawning & Progression Systems
        self.WaveSpawner     = WaveSpawner:new({game = self})
        self.waveDirector    = WaveDirector:new(self)
        self.rewardSystem    = RewardSystem:new(self)
        self.specialUpgradeManager = SpecialUpgradeMgr:new(self)
        
        -- Configuration
        self.rewardCost           = 50
        self.autoStartWave        = false
        self.specialWaveInterval  = 5 -- Waves between "special" upgrades
        self.inputMode            = "idle"
        
        -- Global Status Effect Managers
        self.playerEffectManager = EffectManager:new() 
        self.enemyEffectManager  = EffectManager:new()
    end
    
    -- Setup Physics/Collision
    collision:setGrid(800, 600, 32)
    
    -- World Setup
    self:addObject(self.base)
    self.ground = ground
    
    -- Spawn Starting Turret in the center of the build grid
    self.mainTurret = MainTurret:new({game = self})
    local gridWidth  = self.base.buildGrid.width
    local gridHeight = self.base.buildGrid.height
    local centerRow  = math.ceil(gridHeight / 2)
    local centerCol  = math.ceil(gridWidth / 2)

    local centerSlot = (centerRow - 1) * gridWidth + centerCol
    self.base.buildGrid.unlocked[centerSlot] = true 
    self:newBuilding(self.mainTurret, centerSlot)
    
    love.mouse.setVisible(false)
end

-- -----------------------------------------------------------------------------
-- Building & Object Management
-- -----------------------------------------------------------------------------

function game:newBuilding(building, slot)
    self.base:addBuilding(building, slot)
    self:addObject(building)
end

function game:addObject(obj)
    table.insert(self.objects, obj)
end

--- Iterates through objects and reapplies buffs (e.g., when a buff building is placed/removed)
function game:recalculateAllBuffs()
    for _, obj in ipairs(self.objects) do
        if obj.clearAllBuffs then obj:clearAllBuffs() end
    end
    
    for _, obj in ipairs(self.objects) do
        if obj.applyBuffs then obj:applyBuffs() end
    end
end

--- Cleanup: Removes objects marked as 'destroyed' from the master table
function game:takeOutTheTrash()
    for i = #self.objects, 1, -1 do
        if self.objects[i].destroyed then
            table.remove(self.objects, i)
        end
    end
end

-- -----------------------------------------------------------------------------
-- Game Loop: Update
-- -----------------------------------------------------------------------------

function game:update(dt)
    -- Global Loss Condition
    if self.base.hp <= 0 then
        self:setState("gameover")
        return
    end

    -- Pause update logic if a modal menu (Rewards) is active
    if (self.rewardSystem and self.rewardSystem.isActive) or 
       (self.specialUpgradeManager and self.specialUpgradeManager.isActive) then 
        return 
    end

    -- State Transitions: Wave Completion
    if self:isState("wave") and self.WaveSpawner.waveState == "complete" then
        if self.wave % self.specialWaveInterval == 0 then
            self.specialUpgradeManager:activate()
        end
        self:setState("preparing")
    end
    
    -- State Transitions: Start Next Wave
    if self:isState("preparing") then
        if self.autoStartWave and self.WaveSpawner.waveState == "idle" then
            self:recalculateAllBuffs()
            self.WaveSpawner:startNextWave()
            self:setState("wave")
        end
    end

    -- Component Updates
    self.inventory:update(dt)
    self.inputHandler:update(dt)
    self.WaveSpawner:update(dt)
    self.playerEffectManager:update(dt)
    self.enemyEffectManager:update(dt)
    self.gui:update(dt)

    -- Entity Updates
    for _, obj in ipairs(self.objects) do
        if not obj.destroyed and obj.update then
            obj:update(dt)
        end
    end
    
    -- Physics & Cleanup
    collision:bruteforceByType(self.objects, "bullet", "enemy")
    self:takeOutTheTrash()
end

-- -----------------------------------------------------------------------------
-- Game Loop: Drawing
-- -----------------------------------------------------------------------------

function game:draw()
    local healthyboys = {} -- Temporary list for drawing overlays (health bars, etc.)

    -- 1. Environment & Grid
    self.ground:draw()
    if self.battlefieldGrid then
        self.battlefieldGrid:draw()
    end

    -- 2. Entities
    for _, obj in ipairs(self.objects) do
        if not obj.destroyed and obj.draw then
            obj:draw()
            -- Collect objects that need UI overlays (drawn in next pass)
            if obj.drawHealthBar or obj.drawReloadBar or obj.effectManager then
                table.insert(healthyboys, obj)
            end
        end
    end

    -- 3. Overlays (Drawn after entities so they don't get overlapped)
    for _, obj in ipairs(healthyboys) do
        if obj.drawHealthBar then obj:drawHealthBar() end
        if obj.drawReloadBar then obj:drawReloadBar() end
        if obj.effectManager then obj.effectManager:drawStatusEffects() end
    end

    love.graphics.setColor(1, 1, 1, 1)
    
    -- 4. UI & Placement Previews
    self.gui:draw()
    
    if self.inputMode == "placing" and self.blueprint then
        self.blueprint.isPreview = true
        self.blueprint:draw(self.inputHandler.mouseX, self.inputHandler.mouseY)
        self.blueprint.isPreview = false
    end

    -- 5. Modals (Topmost)
    if self.rewardSystem and self.rewardSystem.isActive then
        self.rewardSystem:draw()
    end
    
    if self.specialUpgradeManager and self.specialUpgradeManager.isActive then
        self.specialUpgradeManager:draw()
    end

    -- 6. Custom Cursor
    local mx, my = love.mouse.getPosition()
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.circle("fill", mx, my, 3)
    love.graphics.setColor(1, 1, 1, 1)
end

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

function game:addXP(amount)    self.xp = self.xp + amount end
function game:addMoney(amount) self.money = self.money + amount end

function game:isRewardSystemActive()
    return (self.rewardSystem and self.rewardSystem.isActive) or 
           (self.specialUpgradeManager and self.specialUpgradeManager.isActive)
end

function game:placeBuilding(building, sourceReward)
    self.inputMode = "placing"
    self.blueprint = building:new({game = self})
    self.blueprint.rewardCard = sourceReward
end

function game:setState(newState)    self.state = newState end
function game:getState()            return self.state end
function game:isState(checkState)   return self.state == checkState end

-- -----------------------------------------------------------------------------
-- Ground Object Implementation
-- -----------------------------------------------------------------------------
function ground:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
end

return game