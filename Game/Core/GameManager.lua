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
local MainTurret         = require("Buildings.Turrets.MainTurret")
local GUIManager         = require("Game.GUI.GUIManager")
local enemy              = require("Enemies.Enemy") -- Note: Check if needed here or just in Spawner
local DeathAnimation     = require("Graphics.Animations.DeathAnimation")
local DamageNumber       = require("Graphics.Animations.DamageNumber")

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

local topScreen = {
    x = 0,
    y = 0,
    w = 800,
    h = 100,
    color = {love.math.colorFromBytes(255, 0, 0)},
    thickness = 4
}
function topScreen:draw()
    local pulse = (math.sin(game.pulseTimer * game.oscillationSpeed) + 1) / 2
    local r, g, b = self.color[1], self.color[2], self.color[3]
    
    -- Glow layers
    for i = 3, 1, -1 do
        local alpha = (0.15 * (1 - i/4)) * (0.5 + pulse * 0.5)
        local width = self.thickness + i * 4 + pulse * 8
        love.graphics.setLineWidth(width)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.line(self.x, self.y + self.h, self.x + self.w, self.y + self.h)
    end
    
    love.graphics.setColor(r, g, b, 0.8 + pulse * 0.2)
    love.graphics.setLineWidth(self.thickness)
    love.graphics.line(self.x, self.y + self.h, self.x + self.w, self.y + self.h)
    love.graphics.setLineWidth(1)
end
local bottomScreen = {
    x = 0,
    y = 500,
    w = 800,
    h = 100,
    color = {love.math.colorFromBytes(255, 0, 0)},
    thickness = 4
}
function bottomScreen:draw()
    local pulse = (math.sin(game.pulseTimer * game.oscillationSpeed) + 1) / 2
    local r, g, b = self.color[1], self.color[2], self.color[3]
    
    -- Glow layers
    for i = 3, 1, -1 do
        local alpha = (0.15 * (1 - i/4)) * (0.5 + pulse * 0.5)
        local width = self.thickness + i * 4 + pulse * 8
        love.graphics.setLineWidth(width)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.line(self.x, self.y, self.x + self.w, self.y)
    end
    
    love.graphics.setColor(r, g, b, 0.8 + pulse * 0.2)
    love.graphics.setLineWidth(self.thickness)
    love.graphics.line(self.x, self.y, self.x + self.w, self.y)
    love.graphics.setLineWidth(1)
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
        self.money        = 100000
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
        self.rewardCost           = 2
        self.autoStartWave        = false
        self.specialWaveInterval  = 5 -- Waves between "special" upgrades
        self.inputMode            = "idle"
        self.useHybridSeparation  = true
        self.pulseTimer           = 0
        self.oscillationSpeed     = 1
        
        -- Global Status Effect Managers
        self.playerEffectManager = EffectManager:new() 
        self.enemyEffectManager  = EffectManager:new()
        self.luckCosts           = {3, 5, 8, 12, 15, 20, 25, 30, 40, 50}
        self.showDamageNumbers   = true

        -- Animation Pool
        self.animations = {}
    end
    
    -- Setup Physics/Collision
    collision:setGrid(800, 600, 32)
    
    -- World Setup
    self:addObject(self.base)
    self.ground = ground
    self.topScreen = topScreen
    self.bottomScreen = bottomScreen
    
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

    -- Pause update logic if a modal menu (Rewards) is active
    if (self.rewardSystem and self.rewardSystem.isActive) or 
       (self.specialUpgradeManager and self.specialUpgradeManager.isActive) then 
        return 
    end

    -- State Transitions: Wave Completion
    if self:isState("wave") and self.WaveSpawner.waveState == "complete" then
        self:waveComplete()
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
    self.topScreen:draw()
    self.bottomScreen:draw()
    
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
        if obj.effectManager then obj.effectManager:drawStatusEffects() end
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
        self.blueprint:draw(self.inputHandler.mouseX, self.inputHandler.mouseY)
        self.blueprint.isPreview = false
    end
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
    self:addMoney(math.floor(self.money * 0.1))
end
function game:waveComplete()
    self:interest()
    self:addMoney(3)
end

function game:spawnDeathAnimation(color, size, x, y)
    table.insert(self.animations, DeathAnimation:new(color, size, x, y))
end

function game:EnemyDied(enemy)
    self:addXP(enemy.reward)
    self:spawnDeathAnimation(enemy.color, enemy.size or enemy.w, enemy.x, enemy.y)
end

function game:spawnDamageNumber(amount, x, y, damageType)
    if self.showDamageNumbers then
        table.insert(self.animations, DamageNumber:new(amount, x, y, damageType))
    end
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
    if cost and self.money >= cost and self.luck < 10 and self.inputMode == "idle" then
        self.money = self.money - cost
        self.luck = self.luck + 1
        return true
    end
    return false
end

function game:attemptPurchaseReward()
    if self.money >= self.rewardCost and not self.rewardSystem.isActive and self.inputMode == "idle" then
        self.money = self.money - self.rewardCost
        self.rewardSystem:activate()
        return true
    end
    return false
end

return game