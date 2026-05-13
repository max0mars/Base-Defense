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
local EffectManager      = require("Game.Effects.EffectManager")

-- Entities & UI
local StandardMainTurret = require("Buildings.MainTurrets.StandardMainTurret")
local GUIManager         = require("Game.GUI.GUIManager")
local enemy              = require("Enemies.Enemy") -- Note: Check if needed here or just in Spawner
local ParticleExplosion = require("Graphics.Animations.ParticleExplosion")
local CircleFade       = require("Graphics.Animations.CircleFade")
local DamageNumber       = require("Graphics.Animations.DamageNumber")
local LightningBolt     = require("Graphics.Animations.LightningBolt")
local ExpandingCircle   = require("Graphics.Animations.ExpandingCircle")
local ArmorBreak        = require("Graphics.Animations.ArmorBreak")

-- -----------------------------------------------------------------------------
-- Scene Draw Data
-- -----------------------------------------------------------------------------
local ground = {
    x = 0,
    y = 100,
    w = 800,
    h = 400,
    color = {love.math.colorFromBytes(0, 0, 0)}
}
function ground:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
end


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
        self.tokens       = 0
        self.luck         = 1         -- Influences reward quality (Scale 1-10)
        self.wave         = 0
        self.buildingCounts = {}      -- Tracks counts of buildings by type and damageType
        
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
        self.rewardCost           = 2
        self.autoStartWave        = false
        self.specialWaveInterval  = 5 -- Waves between "special" upgrades
        self.mutationInterval     = 5 -- Waves between enemy mutations
        self.inputMode            = "idle"
        self.useHybridSeparation  = false
        self.pulseTimer           = 0
        self.oscillationSpeed     = 1
        
        -- Global Status Effect Managers
        self.playerEffectManager = EffectManager:new(nil, self) 
        self.enemyEffectManager  = EffectManager:new(nil, self)
        self.luckCosts           = {1, 2, 3, 5, 10, 15, 20, 25, 30, 30}
        self.showDamageNumbers   = true

        -- Animation Pool
        self.animations = {}
        self.time_mul = 1
    end
    
    -- Setup Physics/Collision
    collision:setGrid(800, 600, 32)
    
    -- World Setup
    self:addObject(self.base)
    self.ground = ground
    
    -- Spawn Starting Turret via Base
    self.base:initMainTurret(StandardMainTurret)
    self.mainTurret = self.base.mainTurret
    

    
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
    if obj.isType and obj:isType("building") then
        self:updateBuildingCounts()
    end
end

--- Iterates through objects and reapplies buffs (e.g., when a buff building is placed/removed)
function game:recalculateAllBuffs()
    for _, obj in ipairs(self.objects) do
        if obj.clearAllBuffs then obj:clearAllBuffs() end
    end
    
    for _, obj in ipairs(self.objects) do
        if obj.applyBuffs and not obj.destroyed then obj:applyBuffs() end
    end
end

--- Tracks the number of buildings of each type and damage type
function game:updateBuildingCounts()
    self.buildingCounts = {}
    for _, obj in ipairs(self.objects) do
        if obj.isType and obj:isType("building") and not obj.destroyed then
            if obj.types then
                for bType, _ in pairs(obj.types) do
                    self.buildingCounts[bType] = (self.buildingCounts[bType] or 0) + 1
                end
            end
            if obj:isType("turret") then
                local damageType = obj.damageType or "physical"
                self.buildingCounts[damageType] = (self.buildingCounts[damageType] or 0) + 1
            end
        end
    end
end

--- Cleanup: Removes objects marked as 'destroyed' from the master table
function game:takeOutTheTrash()
    local removedBuilding = false
    for i = #self.objects, 1, -1 do
        if self.objects[i].destroyed then
            if self.objects[i]:isType("building") then
                removedBuilding = true
            end
            table.remove(self.objects, i)
        end
    end
    if removedBuilding then
        self:updateBuildingCounts()
    end
end

-- -----------------------------------------------------------------------------
-- Game Loop: Update
-- -----------------------------------------------------------------------------

function game:update(dt)
    self.pulseTimer = self.pulseTimer + dt
    if self:isState("gameover") then return end
    -- Update Animations with cleanup
    for i = #self.animations, 1, -1 do
        local anim = self.animations[i]
        anim:update(dt)
        if anim.destroyed then
            table.remove(self.animations, i)
        end
    end

    -- Global Loss Condition
    if self.base.hp <= 0 then
        self:setState("gameover")
        return
    end

    -- Update GUI (will receive dt=0 if game is frozen)
    self.gui:update(dt)

    -- State Transitions: Wave Completion
    if self:isState("wave") and self.WaveSpawner.waveState == "complete" then
        self:waveComplete()
        
        local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
        
        -- Interval 1: New Enemy (5, 10, 15...)
        if self.wave % self.mutationInterval == 0 then
            local options = EnemyRegistry:getMutationOptions(2)
            if #options > 0 then
                self:setState("enemy_mutation")
                self.gui.mutation:activate(options, "enemy")
                return -- Exit early to prioritize this menu
            end
        end

        -- Interval 2: Enemy Upgrade (8, 13, 18...)
        if (self.wave - 3) % 5 == 0 and self.wave ~= 3 then
            local options = EnemyRegistry:getUpgradeOptions(2)
            if #options > 0 then
                self:setState("upgrade_mutation")
                self.gui.mutation:activate(options, "upgrade")
                return -- Exit early to prioritize this menu
            end
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
        self.battlefieldGrid:drawGrid()
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
        if obj.drawStatusEffects then obj:drawStatusEffects() end
    end

    love.graphics.setColor(1, 1, 1, 1)
    
    -- 4. Animations (Drawn over entities but under UI)
    for _, anim in ipairs(self.animations) do
        anim:draw()
    end

    if self.inputMode == "placing" or self.debugMode then
        if self.battlefieldGrid then
            self.battlefieldGrid:drawOverlays()
        end
    end

    -- 5. UI & Placement Previews
    self.gui:draw()
    
    if self.inputMode == "placing" and self.blueprint then
        self.blueprint.isPreview = true
        -- Fallback to mouse coordinates if not snapped to grid
        local drawX = self.inputHandler.snappedX or self.inputHandler.mouseX
        local drawY = self.inputHandler.snappedY or self.inputHandler.mouseY
        self.blueprint:draw(drawX, drawY)
        self.blueprint.isPreview = false
    end
    if self.rewardSystem and self.rewardSystem.isActive then
        self.rewardSystem:draw()
    end
    
    if self.specialUpgradeManager and self.specialUpgradeManager.isActive then
        self.specialUpgradeManager:draw()
    end
    
    -- Absolute Highest Z-Index Layer: Quit & Destruction Modals overlay everything
    if self.gui and self.gui.confirmation then
        self.gui.confirmation:draw()
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
function game:addTokens(amount) self.tokens = self.tokens + amount end

function game:getEnemyDensity(x, y, radius)
    local count = 0
    local r2 = radius * radius
    for _, obj in ipairs(self.objects) do
        if obj:isType("enemy") and not obj.destroyed then
            local dx = obj.x - x
            local dy = obj.y - y
            if dx*dx + dy*dy < r2 then
                count = count + 1
            end
        end
    end
    return count
end
function game:interest()
    self:addTokens(math.floor(self.tokens * 0.1))
end
function game:waveComplete()
    self:interest()
    self:addTokens(3)
    
    -- Trigger onWaveComplete for all buildings (e.g. Bank)
    for _, obj in ipairs(self.objects) do
        if obj.onWaveComplete and not obj.destroyed then
            obj:onWaveComplete()
        end
    end
end

function game:spawnParticleExplosion(color, size, x, y, lifetime, numParticles)
    table.insert(self.animations, ParticleExplosion:new(color, size, x, y, lifetime, numParticles))
end

function game:spawnCircleFade(x, y, radius, color, duration)
    table.insert(self.animations, CircleFade:new(x, y, radius, color, duration))
end

function game:spawnLightningBolt(tx, ty, config)
    table.insert(self.animations, LightningBolt:new(tx, ty, config))
end

function game:spawnExpandingCircle(x, y, startRadius, endRadius, color, duration)
    table.insert(self.animations, ExpandingCircle:new(x, y, startRadius, endRadius, color, duration))
end

function game:spawnArmorBreak(x, y)
    table.insert(self.animations, ArmorBreak:new(x, y))
end

function game:EnemyDied(enemy)
    self:addXP(enemy.reward)
    self:spawnParticleExplosion(enemy.color, enemy.size or enemy.w, enemy.x, enemy.y)
end

function game:spawnDamageNumber(amount, x, y, damageType)
    if self.showDamageNumbers then
        table.insert(self.animations, DamageNumber:new(amount, x, y, damageType))
    end
end

function game:spawnFloatingText(text, x, y, color)
    table.insert(self.animations, DamageNumber:new(text, x, y, nil, color))
end

function game:toggleDamageNumbers()
    self.showDamageNumbers = not self.showDamageNumbers
end

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


function game:getLuckCost()
    if self.luck >= 10 then return nil end
    return self.luckCosts[self.luck]
end

function game:buyLuck()
    local cost = self:getLuckCost()
    if cost and self.tokens >= cost and self.luck < 10 and self.inputMode == "idle" then
        self.tokens = self.tokens - cost
        self.luck = self.luck + 1
        return true
    end
    return false
end

function game:attemptPurchaseReward()
    if self.tokens >= self.rewardCost and not self.rewardSystem.isActive and self.inputMode == "idle" then
        self.tokens = self.tokens - self.rewardCost
        self.rewardSystem:activate()
        return true
    end
    return false
end

return game