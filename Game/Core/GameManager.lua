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
local Layout             = require("Game.GUI.Layout")
local Cursor             = require("Game.GUI.Cursor")
local EnemyRegistry      = require("Game.Spawning.EnemyRegistry")
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
function game:load(saveData, isTesting)
    if saveData then 
        -- Future Implementation: Handle save game loading here
    else
        -- Initialize Game State
        self.state        = "startup" -- States: "startup", "preparing", "wave", "gameover"
        self.objects      = {}        -- Entity master list
        self.score        = 0
        self.xp           = 0
        
        self.testingMode  = isTesting or false
        if self.testingMode then
            self.tokens   = 1000
        else
            self.tokens   = _G.PersistentState and _G.PersistentState.startingTokens or 3
        end
        EnemyRegistry:reset(self)
        self.luck         = 1         -- Influences reward quality (Scale 1-10)
        self.wave         = 0
        self.buildingCounts = {}      -- Tracks counts of buildings by type and damageType
        
        -- Initialize Core Gameplay Systems
        self.base            = Base:new({game = self})
        if _G.PersistentState and _G.PersistentState.baseHP then
            self.base.hp = _G.PersistentState.baseHP
        end
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
        self.blockerCost          = 3
        self.drawCost             = 1
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

        -- Global Deckbuilder Mechanics
        self.activeGlobalBuffs = {}
        
        self:initBattleDeck()
        -- Starting Draw
        self:drawCard(_G.PersistentState and _G.PersistentState.startingHandSize or 3)

        -- Codex discovery tracking: enemies seen in a wave, turrets ever owned.
        self.seenEnemies = {}
        self.ownedTurrets = {}
    end
    
    -- Setup Physics/Collision
    collision:setGrid(800, 600, 32)
    
    -- World Setup
    self:addObject(self.base)
    self.ground = ground
    
    -- Spawn Starting Turret via Base
    self.base:initMainLazer(StandardMainTurret)
    self.mainLazer = self.base.mainLazer
    

    
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
        
        if self.wave >= 5 then
            self.battleComplete = true
            self:clearGlobalBuffs()
            if _G.PersistentState then
                _G.PersistentState.baseHP = self.base.hp
                local reward = 100
                if not self.damageTakenThisBattle or self.damageTakenThisBattle == 0 then
                    reward = reward + 25
                end
                _G.PersistentState.cash = (_G.PersistentState.cash or 0) + reward
            end
            return
        end
        
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
    if self.rewardSystem then
        self.rewardSystem:update(dt)
    end
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
    Cursor.reset() -- hover flag is re-set by UI components during this frame's draw

    -- World rendering (steps 1-5) happens inside the centered field viewport so
    -- existing world coordinates map onto the 16:9-centered battlefield. The HUD
    -- (gui:draw and below) is drawn afterwards in full-canvas screen space.
    SetGameScissor(Layout.field.x, Layout.field.y, Layout.field.w, Layout.field.h)
    Layout.pushWorld()

    -- 1. Environment & Grid
    self.ground:draw()
    
    if self.battlefieldGrid then
        self.battlefieldGrid:drawGrid()
    end
    
    if self.WaveSpawner and self.WaveSpawner.draw then
        self.WaveSpawner:draw()
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
    
    -- 4. World Animations (Drawn over entities but under UI)
    for _, anim in ipairs(self.animations) do
        if not anim.isUI then
            anim:draw()
        end
    end

    -- 5. UI & Placement Previews
    
    if self.inputMode == "placing" and self.blueprint then
        self.blueprint.isPreview = true
        -- Fallback to mouse coordinates if not snapped to grid
        local drawX = self.inputHandler.snappedX or self.inputHandler.mouseX
        local drawY = self.inputHandler.snappedY or self.inputHandler.mouseY
        self.blueprint:draw(drawX, drawY)
        self.blueprint.isPreview = false
    end
    
    if self.inputMode == "placing" or self.debugMode then
        if self.battlefieldGrid then
            self.battlefieldGrid:drawOverlays()
        end
    end

    -- Highlight target: a focused (clicked) building/enemy is sticky and wins
    -- over hover (the user must click elsewhere to dismiss). Only one highlights.
    local ih = self.inputHandler
    local hb, he
    if ih and ih.selectedBuilding and not ih.selectedBuilding.destroyed then
        hb = ih.selectedBuilding
    elseif ih and ih.selectedEnemy then
        he = ih.selectedEnemy
    else
        hb = ih and ih.hoveredBuilding
        he = self.gui and self.gui.tooltips and self.gui.tooltips.hoveredEnemy
    end

    -- Building: white outline around just the PERIMETER of its occupied cells.
    if hb and hb.slot and hb.buildGrid and not hb.destroyed and hb.getSlotsFromPattern then
        local bg = hb.buildGrid
        local cs = bg.cellSize
        local occ, cells = {}, {}
        for _, slot in ipairs(hb:getSlotsFromPattern(hb.slot)) do
            local i = ((slot - 1) % bg.width) + 1
            local j = math.ceil(slot / bg.width)
            occ[i .. "," .. j] = true
            cells[#cells + 1] = { i = i, j = j }
        end
        love.graphics.push("all")
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setLineWidth(2)
        for _, c in ipairs(cells) do
            local x0 = bg.x + (c.i - 1) * cs
            local y0 = bg.y + (c.j - 1) * cs
            if not occ[c.i .. "," .. (c.j - 1)] then love.graphics.line(x0, y0, x0 + cs, y0) end           -- top
            if not occ[c.i .. "," .. (c.j + 1)] then love.graphics.line(x0, y0 + cs, x0 + cs, y0 + cs) end  -- bottom
            if not occ[(c.i - 1) .. "," .. c.j] then love.graphics.line(x0, y0, x0, y0 + cs) end            -- left
            if not occ[(c.i + 1) .. "," .. c.j] then love.graphics.line(x0 + cs, y0, x0 + cs, y0 + cs) end  -- right
        end
        love.graphics.pop()
    end

    -- Enemy: lighten it by overlaying a faint white fill in its own shape.
    if he and not he.destroyed and he.drawCustomShape then
        love.graphics.push("all")
        love.graphics.setColor(1, 1, 1, 0.22)
        he:drawCustomShape("fill", he.x, he.y)
        love.graphics.pop()
    end

    -- End the field viewport; HUD and overlays draw in screen space.
    Layout.popWorld()
    SetGameScissor()

    self.gui:draw()
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

    -- 6. UI Animations (Drawn over HUD and menu elements)
    for _, anim in ipairs(self.animations) do
        if anim.isUI then
            anim:draw()
        end
    end

    -- 7. Custom Cursor
    if self.testingMode then
        love.graphics.setColor(1, 0, 0, 0.4) -- semi-transparent red
        local font = love.graphics.getFont()
        local text = "Testing Mode"
        local textW = font:getWidth(text)
        local textH = font:getHeight()
        local cx = (VIRTUAL_WIDTH or 800) / 2
        local cy = (VIRTUAL_HEIGHT or 600) / 2
        love.graphics.print(text, cx - textW / 2, cy - textH / 2)
    end

    -- Cursor. Skipped while paused (the pause menu draws its own). Over the live
    -- battlefield we hide the OS cursor and draw a red aim dot; over the HUD and
    -- any open menu/modal we fall back to the real OS hand/arrow cursor (the same
    -- crisp pointer the main menu uses).
    if not (paused == 1) then
        local mx, my = love.mouse.getPosition()
        local menuActive = (self.rewardSystem and self.rewardSystem.isActive)
            or (self.specialUpgradeManager and self.specialUpgradeManager.isActive)
            or (self.gui and self.gui.mutation and self.gui.mutation.isActive)
            or (self.gui and self.gui.codex and self.gui.codex.isActive)
            or (self.gui and self.gui.enemySpawner and self.gui.enemySpawner.isActive)
            or (self.gui and self.gui.itemPicker and self.gui.itemPicker.isActive)
            or self:isState("enemy_mutation") or self:isState("upgrade_mutation")
        -- Over the base build area, use the OS pointer (hand for clickable slots)
        -- rather than the battlefield crosshair.
        local overBase = self:isMouseOverBase(mx, my)
        if overBase and self.base and self.base.hoveredLockedSlot then
            Cursor.wantHand = true
        end
        if (not Cursor.wantHand) and (not menuActive) and (not overBase) and Layout.inFieldScreen(mx, my) then
            love.mouse.setVisible(false)
            Cursor.drawAim(mx, my)
        else
            Cursor.applyOS()
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

function game:addXP(amount)    self.xp = self.xp + amount end
function game:addTokens(amount) self.tokens = self.tokens + amount end

-- True when the (screen-space) cursor is over the base's build area, used to
-- swap the battlefield crosshair for the normal OS pointer there.
function game:isMouseOverBase(screenX, screenY)
    local b = self.base
    if not b then return false end
    local fx, fy = Layout.mouseToField(screenX, screenY)
    return fx >= b.x - b.w / 2 and fx <= b.x + b.w / 2
       and fy >= b.y - b.h / 2 and fy <= b.y + b.h / 2
end

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
    self.drawCost = 1
    if self.gui and self.gui.incomeFeedback then
        self.gui.incomeFeedback:triggerSequence()
    else
        -- Fallback if GUI/manager isn't initialized yet
        local baseIncome = _G.PersistentState and _G.PersistentState.incomeTokens or 3
        local interestAmount = math.floor(self.tokens * 0.1)
        self:addTokens(baseIncome)
        self:addTokens(interestAmount)
    end
    
    if self.wave < 5 then
        self:drawCard(1)
    end
    
    -- Trigger onWaveComplete for other objects (if any)
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
    -- Drain this enemy's slot from the in-progress wave panel (with a flash).
    if self.WaveSpawner and self.WaveSpawner.notifyEnemyKilled then
        self.WaveSpawner:notifyEnemyKilled(enemy)
    end
end

function game:spawnDamageNumber(amount, x, y, damageType, effectiveness)
    if self.showDamageNumbers and amount >= 1 then
        local displayAmount = math.floor(amount + 0.5)
        table.insert(self.animations, DamageNumber:new(displayAmount, x, y, damageType, nil, nil, effectiveness))
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
    
    local config = {game = self}
    if sourceReward and sourceReward.shapePattern then
        config.shapePattern = sourceReward.shapePattern
    end
    if sourceReward and sourceReward.color then
        config.color = sourceReward.color
    end
    if sourceReward and sourceReward.turretSlots then
        config.turretSlots = sourceReward.turretSlots
    end
    if sourceReward and sourceReward.isSlotted ~= nil then
        config.isSlotted = sourceReward.isSlotted
    end
    
    self.blueprint = building:new(config)
    self.blueprint.rewardCard = sourceReward
    self.blueprint.showArc = true
end

--- Picks up a placed building, removing it from the field and returning it to the
--- inventory deck as a fresh card. The main turret (no reward card) can't be
--- picked up. Returns true on success.
function game:pickUpBuilding(building)
    if not building or (building.isType and building:isType("mainLazer")) then return false end
    local reward = building.rewardCard
    if not reward or not reward.building then return false end -- nothing to re-card

    -- Remove the placed instance (frees grid slots / reservations + destroys it).
    building:remove()

    -- Recreate a fresh blueprint from the reward and drop it back in the deck.
    local config = { game = self }
    if reward.shapePattern then config.shapePattern = reward.shapePattern end
    if reward.color then config.color = reward.color end
    if reward.turretSlots then config.turretSlots = reward.turretSlots end
    if reward.isSlotted ~= nil then config.isSlotted = reward.isSlotted end

    local bp = reward.building:new(config)
    bp.rewardCard = reward
    self.inventory:add(bp)

    self:recalculateAllBuffs()
    return true
end

function game:setState(newState)    self.state = newState end
function game:getState()            return self.state end
function game:isState(checkState)   return self.state == checkState end

function game:registerActiveGlobalBuff(effect)
    if not self.activeGlobalBuffs then
        self.activeGlobalBuffs = {}
    end
    table.insert(self.activeGlobalBuffs, effect)
end

function game:clearGlobalBuffs()
    if self.activeGlobalBuffs and self.playerEffectManager then
        for _, effect in ipairs(self.activeGlobalBuffs) do
            self.playerEffectManager:removeEffect(effect)
        end
    end
    self.activeGlobalBuffs = {}
end

function game:initBattleDeck()
    self.drawPile = {}
    self.hand = {}
    self.consumedPile = {}
    
    if _G.PersistentState and _G.PersistentState.deck then
        local function deepcopy(orig, copies)
            copies = copies or {}
            local orig_type = type(orig)
            local copy
            if orig_type == 'table' then
                if copies[orig] then
                    copy = copies[orig]
                else
                    copy = {}
                    copies[orig] = copy
                    for orig_key, orig_value in next, orig, nil do
                        copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
                    end
                    setmetatable(copy, deepcopy(getmetatable(orig), copies))
                end
            else
                copy = orig
            end
            return copy
        end
        
        for _, card in ipairs(_G.PersistentState.deck:getCards()) do
            for i = 1, (card.quantity or 1) do
                table.insert(self.drawPile, deepcopy(card))
            end
        end
    end
    
    -- Shuffle
    for i = #self.drawPile, 2, -1 do
        local j = math.random(i)
        self.drawPile[i], self.drawPile[j] = self.drawPile[j], self.drawPile[i]
    end
end

function game:drawCard(amount)
    amount = amount or 1
    local drawn = 0
    for i = 1, amount do
        if #self.hand >= 8 then
            self:spawnFloatingText("Hand is full!", 400, 300, {0.8, 0.2, 0.2, 1})
            break
        end
        
        if #self.drawPile == 0 then
            self:spawnFloatingText("Deck is empty!", 400, 300, {0.8, 0.2, 0.2, 1})
            break
        end
        
        local card = table.remove(self.drawPile, 1)
        table.insert(self.hand, card)
        drawn = drawn + 1
    end
    return drawn
end

function game:consumeCard(card)
    for i, c in ipairs(self.hand) do
        if c == card then
            table.remove(self.hand, i)
            table.insert(self.consumedPile, card)
            break
        end
    end
    self.activeCard = nil
    self.inputMode = "idle"
end

function game:refundCard(card)
    -- Assuming the card wasn't removed from the hand array until consumeCard
    -- We just refund tokens and clear active card
    self.tokens = self.tokens + card:getCost()
    self.activeCard = nil
    self.inputMode = "idle"
end

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
        
        -- Visual & Audio Feedback
        local btn = self.gui.luckButton
        local cx, cy = btn.x + btn.w/2, btn.y + btn.h/2
        
        -- 1. Particle Effect (Golden Explosion)
        local explosion = ParticleExplosion:new({1, 0.8, 0.2}, 40, cx, cy, 0.6, 30)
        explosion.isUI = true
        table.insert(self.animations, explosion)
        
        -- 2. Audio Feedback
        if AUDIO then AUDIO:playSFX("money_01") end
        
        -- 3. Rarity Numbers (Staggered Floating Text)
        local probs = self.rewardSystem.poolLogic:getLuckProbabilities(self.luck)
        for i, p in ipairs(probs) do
            local text = string.format("%d%%", math.floor(p.percent + 0.5))
            -- Staggered positions and appearance (To the right of the button, horizontally aligned)
            local delay = (i - 1) * 0.15
            local spawnX = btn.x + 50 + (i - 1) * 38
            local spawnY = cy + 90
            
            local floatingText = DamageNumber:new(text, spawnX, spawnY, nil, p.color, delay)
            floatingText.isUI = true
            floatingText.x = spawnX -- Override random offset from constructor
            floatingText.y = spawnY
            floatingText.velX = 0  -- No horizontal drift
            floatingText.velY = -25 -- Much slower float
            table.insert(self.animations, floatingText)
        end
        
        return true
    end
    return false
end

function game:attemptPurchaseReward()
    if self.tokens >= self.rewardCost and not self.rewardSystem.isActive and self.inputMode == "idle" then
        self.tokens = self.tokens - self.rewardCost
        self.rewardSystem:activate("normal", 3)
        return true
    end
    return false
end

function game:attemptPurchaseBlocker()
    if self.tokens >= self.blockerCost and not self.rewardSystem.isActive and self.inputMode == "idle" then
        self.tokens = self.tokens - self.blockerCost
        self.rewardSystem:activate("blocker", 1)
        return true
    end
    return false
end

return game