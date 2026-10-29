-- =============================================================================
-- GAME MANAGER (game.lua)
-- Manages game state, object life cycles, and coordination between systems.
-- =============================================================================

local game = {}
game.__index = game

-- Most cards the hand can hold
game.MAX_HAND_SIZE = 10

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

local Inventory          = require("Game.Inventory.Inventory")
local EffectManager      = require("Game.Effects.EffectManager")
local ArtifactManager    = require("Game.Artifacts.ArtifactManager")
local DevMode            = require("Game.Dev.DevMode")

-- Entities & UI
-- Dynamically load the main turret later
local GUIManager         = require("Game.GUI.GUIManager")
local Layout             = require("Game.GUI.Layout")
local Cursor             = require("Game.GUI.Cursor")
local ArcOverlay         = require("Game.GUI.ArcOverlay")
local DamageStats        = require("Game.Core.DamageStats")
local EnemyRegistry      = require("Game.Spawning.EnemyRegistry")
local enemy              = require("Enemies.Enemy") -- Note: Check if needed here or just in Spawner
local ParticleExplosion = require("Graphics.Animations.ParticleExplosion")
local CircleFade       = require("Graphics.Animations.CircleFade")
local DamageNumber       = require("Graphics.Animations.DamageNumber")
local LightningBolt     = require("Graphics.Animations.LightningBolt")
local ExpandingCircle   = require("Graphics.Animations.ExpandingCircle")
local ArmorBreak        = require("Graphics.Animations.ArmorBreak")
local DebuffProjectile  = require("Graphics.Animations.DebuffProjectile")
local DebuffArrows      = require("Graphics.Animations.DebuffArrows")
local BuffPluses        = require("Graphics.Animations.BuffPluses")
local function drawCircularArrow(cx, cy, r)
    love.graphics.push("all")
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", "open", cx, cy, r, 0.1 * math.pi, 1.7 * math.pi)
    
    -- Arrowhead pointing forward along the arc
    local angle = 1.7 * math.pi
    local ax = cx + math.cos(angle) * r
    local ay = cy + math.sin(angle) * r
    local forwardAngle = angle + math.pi/2
    local backAngle = forwardAngle + math.pi
    local headLength = 7
    local spread = 0.6
    
    -- Push tip slightly forward to cap the line
    local tipX = ax + math.cos(forwardAngle) * 2
    local tipY = ay + math.sin(forwardAngle) * 2

    love.graphics.polygon("fill", 
        tipX, tipY,
        tipX + math.cos(backAngle - spread) * headLength, tipY + math.sin(backAngle - spread) * headLength,
        tipX + math.cos(backAngle + spread) * headLength, tipY + math.sin(backAngle + spread) * headLength
    )
    love.graphics.pop()
end

-- Outlines just the PERIMETER of a placed building's occupied cells.
local function drawBuildingOutline(b, color)
    if not (b.slot and b.buildGrid and not b.destroyed and b.getSlotsFromPattern) then return end
    local bg = b.buildGrid
    local cs = bg.cellSize
    local occ, cells = {}, {}
    for _, slot in ipairs(b:getSlotsFromPattern(b.slot)) do
        local i = ((slot - 1) % bg.width) + 1
        local j = math.ceil(slot / bg.width)
        occ[i .. "," .. j] = true
        cells[#cells + 1] = { i = i, j = j }
    end
    love.graphics.push("all")
    love.graphics.setColor(color)
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
        self.state        = "mulligan" -- States: "mulligan", "startup", "preparing", "wave", "gameover"
        self.objects      = {}        -- Entity master list
        self.corpses      = {}        -- Recent deaths a Reanimator can raise (recordCorpse)
        self.score        = 0
        self.xp           = 0
        self.mulliganLockedSlots = {} -- Hand slots already rerolled (each gets one reroll)
        
        self.testingMode  = isTesting or false
        if self.testingMode then
            self.tokens   = 1000
        else
            self.tokens   = _G.PersistentState and _G.PersistentState.startingTokens or 3
        end
        self.maxTokens    = _G.PersistentState and _G.PersistentState.startingTokens or 3
        self.maxMana      = _G.PersistentState and _G.PersistentState.maxMana or 100
        self.manaRegenPerWave = _G.PersistentState and _G.PersistentState.manaRegenPerWave or 15 -- Mana refilled after every wave (capped at maxMana)
        self.mana         = self.maxMana
        EnemyRegistry:reset(self)
        self.wave         = 0
        self.buildingCounts = {}      -- Tracks counts of buildings by type and damageType
        self.damageStats  = DamageStats.new() -- Per-turret damage / kills this battle (MVP)
        self.newArtifacts = {}        -- Artifacts won this battle, revealed after the summary
        self.pendingCardDraws = 0     -- Card picks won this battle, offered after the summary
        self.artifactFallbackCash = 0 -- Cash paid instead of an artifact (every artifact owned)
        self.iceMarketIncome = 0              -- Cash from Ice Markets this battle (summary line)
        self.vaultIncome = 0                  -- Cash from Vaults when the battle is won (summary line)
        
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

        
        -- Configuration
        self.rewardCost           = 2
        self.spellHandSize        = 4 -- Spells drawn when a wave starts
        self.specialWaveInterval  = 5 -- Waves between "special" upgrades
        self.inputMode            = "idle"
        self.useHybridSeparation  = false
        self.pulseTimer           = 0
        self.oscillationSpeed     = 1
        
        -- Global Status Effect Managers
        self.playerEffectManager = EffectManager:new(nil, self) 
        self.enemyEffectManager  = EffectManager:new(nil, self)
        self.artifacts           = ArtifactManager:new(self)
        -- self.luckCosts removed since it's no longer purchasable in-game
        self.showDamageNumbers   = true

        -- Animation Pool
        self.animations = {}
        self.time_mul = 1

        -- Global Deckbuilder Mechanics
        self.activeGlobalBuffs = {}
        
        self:initBattleDeck()
        -- Starting Draw
        self:drawCard(_G.PersistentState and _G.PersistentState.startingHandSize or 4)

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
    local MainTurretClass
    if _G.PersistentState and _G.PersistentState.selectedMainTurret then
        MainTurretClass = require("Buildings.MainTurrets." .. _G.PersistentState.selectedMainTurret)
    else
        MainTurretClass = require("Buildings.MainTurrets.MainLazer")
    end
    self.base:initMainLazer(MainTurretClass)
    self.mainLazer = self.base.mainLazer

    self.artifacts:refresh()
    self.artifacts:trigger("onBattleStart")
    
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

function game:recalculateAllBuffs()
    for _, obj in ipairs(self.objects) do
        if obj.clearAllBuffs then obj:clearAllBuffs() end
    end
    
    if self.playerEffectManager and self.playerEffectManager.activeEffects then
        for i = #self.playerEffectManager.activeEffects, 1, -1 do
            local effect = self.playerEffectManager.activeEffects[i]
            if effect.isBuffTotem then
                table.remove(self.playerEffectManager.activeEffects, i)
            end
        end
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
    -- Board changed: re-evaluate artifacts whose effects depend on it
    if self.artifacts then self.artifacts:refresh() end
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

--- Advances visual animations (explosions, particles, damage numbers, rings).
function game:updateAnimations(dt)
    for i = #self.animations, 1, -1 do
        local anim = self.animations[i]
        anim:update(dt)
        if anim.destroyed then
            table.remove(self.animations, i)
        end
    end
end

function game:update(dt)
    self.pulseTimer = self.pulseTimer + dt
    if self:isState("gameover") then return end
    self:updateAnimations(dt)

    -- Global Loss Condition
    if self.base.hp <= 0 then
        self:setState("gameover")
        return
    end

    DevMode.update(self)

    -- Update GUI (will receive dt=0 if game is frozen)
    self.gui:update(dt)

    -- State Transitions: Wave Completion
    if self:isState("wave") and self.WaveSpawner.waveState == "complete" then
        local finished = not (_G.PersistentState and _G.PersistentState.upcomingWaves and #_G.PersistentState.upcomingWaves > 0)
        if finished then
            -- winBattle runs the last wave's completion itself
            self:winBattle()
            return
        end
        self:waveComplete()

        -- Enemy discovery and mutations happen between battles (preparation_scene)
        self:setState("preparing")
    end
    
    -- State Transitions: Start Next Wave
    if self:isState("preparing") then
        -- Auto-wave is disabled; the user must manually trigger the wave via the UI.
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
    self:updateCorpses(dt)

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

--- Draws only the base and the buildings on it, over a plain background
--- (the battle summary, so the player can look over their setup).
function game:drawBaseView()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, Layout.W, Layout.H)
    SetGameScissor(Layout.field.x, Layout.field.y, Layout.field.w, Layout.field.h)
    Layout.pushWorld()
    if self.base then self.base:draw(true) end
    for _, obj in ipairs(self.objects) do
        if not obj.destroyed and obj ~= self.base and obj.isType and obj:isType("building") and obj.draw then
            obj:draw()
        end
    end
    Layout.popWorld()
    SetGameScissor()
    love.graphics.setColor(1, 1, 1, 1)
end

--- The placed building covering world point (wx, wy), if any.
function game:buildingAt(wx, wy)
    for _, obj in ipairs(self.objects) do
        if not obj.destroyed and obj.slot and obj.buildGrid and obj.isType and obj:isType("building") then
            local grid = obj.buildGrid
            for _, slot in ipairs(obj:getSlotsFromPattern(obj.slot)) do
                local sx = grid.x + ((slot - 1) % grid.width) * grid.cellSize
                local sy = grid.y + (math.ceil(slot / grid.width) - 1) * grid.cellSize
                if wx >= sx and wx < sx + grid.cellSize and wy >= sy and wy < sy + grid.cellSize then
                    return obj
                end
            end
        end
    end
end

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

    -- 1b. Firing arcs, coloured by overlap count (under entities)
    local arcs = {}
    for _, obj in ipairs(self.objects) do
        obj.arcDrawnByOverlay = ArcOverlay.wants(obj) or nil
        if obj.arcDrawnByOverlay then table.insert(arcs, obj) end
    end
    ArcOverlay.draw(arcs, self.ground.x, self.ground.y, self.ground.w, self.ground.h)

    -- 2. Entities (enemies with their trails, hover and ability animations)
    for _, obj in ipairs(self.objects) do
        if not obj.destroyed and obj.draw then
            if obj.drawAnimated then obj:drawAnimated() else obj:draw() end
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

    -- Area card: outline the square it would hit and the turrets inside it
    if self.inputMode == "targeting_area" and self.activeCard then
        local area = self.inputHandler:getAreaTarget(self.activeCard.areaSize or 2)
        if area then
            love.graphics.push("all")
            local hasTurrets = #area.turrets > 0
            local col = hasTurrets and {0.3, 1, 0.4} or {0.9, 0.3, 0.3}
            love.graphics.setColor(col[1], col[2], col[3], 0.12)
            love.graphics.rectangle("fill", area.x, area.y, area.w, area.h)
            love.graphics.setColor(col[1], col[2], col[3], 0.9)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", area.x, area.y, area.w, area.h)
            for _, t in ipairs(area.turrets) do
                local cx, cy = t:getCenterPosition()
                love.graphics.circle("line", cx, cy, (t.size or 10) * 0.9)
            end
            love.graphics.pop()
        end
    end

    if self.inputMode == "targeting_spell" and self.activeCard then
        local radius = self.activeCard:getStat("radius") or 50
        local drawX = self.inputHandler.mouseX
        local drawY = self.inputHandler.mouseY
        
        love.graphics.push("all")
        
        -- Draw the 'x' at target location
        love.graphics.setColor(0.9, 0.1, 0.1, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.line(drawX - 8, drawY - 8, drawX + 8, drawY + 8)
        love.graphics.line(drawX - 8, drawY + 8, drawX + 8, drawY - 8)
        
        -- Draw dotted circle indicating radius (only if NOT a global spell)
        if not self.activeCard.isGlobalSpell then
            local circumference = 2 * math.pi * radius
            local dashLength = 6
            local gapLength = 6
            local totalSegments = math.floor(circumference / (dashLength + gapLength))
            if totalSegments > 0 then
                local angleStep = (2 * math.pi) / totalSegments
                for i = 0, totalSegments - 1 do
                    local startAngle = i * angleStep
                    local endAngle = startAngle + (angleStep * (dashLength / (dashLength + gapLength)))
                    
                    local x1 = drawX + math.cos(startAngle) * radius
                    local y1 = drawY + math.sin(startAngle) * radius
                    local x2 = drawX + math.cos(endAngle) * radius
                    local y2 = drawY + math.sin(endAngle) * radius
                    
                    love.graphics.line(x1, y1, x2, y2)
                end
            end
        end
        
        love.graphics.pop()
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
    if hb then drawBuildingOutline(hb, {1, 1, 1, 0.9}) end

    -- Edit mode: drag-select box and outlines on the turrets being aimed.
    if ih then ih:drawEditOverlay(drawBuildingOutline) end

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

    if self:isState("mulligan") then
        -- 1. Dim background
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, Layout.W, Layout.H)
        
        local layout = self:getMulliganLayout()
        local mx, my = love.mouse.getPosition()
        
        -- 2. Draw Title
        love.graphics.setColor(0, 0.85, 1.0, 1)
        local titleFont = love.graphics.getFont()
        love.graphics.printf("STARTING HAND", 0, layout.cards[1].y - 70, Layout.W, "center")
        love.graphics.setColor(0.7, 0.8, 0.9, 0.8)
        love.graphics.printf("Reroll starting hand", 0, layout.cards[1].y - 40, Layout.W, "center")
        
        -- 3. Draw starting cards & their circular arrow buttons
        for i, card in ipairs(self.hand) do
            local c = layout.cards[i]
            local cardDrawObj = card:getCardDraw()
            local isCardHovered = mx >= c.x and mx <= c.x + layout.cardW and my >= c.y and my <= c.y + layout.cardH
            cardDrawObj:draw(c.x, c.y, layout.cardW, layout.cardH, isCardHovered)
            
            if not (self.mulliganLockedSlots and self.mulliganLockedSlots[i]) then
                local dist2 = (mx - c.arrowX)^2 + (my - c.arrowY)^2
                local hoverArrow = dist2 <= c.arrowR^2
                if hoverArrow then
                    Cursor.wantHand = true
                    love.graphics.setColor(0.1, 0.6, 0.9, 0.8)
                else
                    love.graphics.setColor(0.05, 0.1, 0.2, 0.6)
                end
                love.graphics.circle("fill", c.arrowX, c.arrowY, c.arrowR)
                love.graphics.setColor(0, 0.85, 1.0, 1)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", c.arrowX, c.arrowY, c.arrowR)
                love.graphics.setLineWidth(1)
                
                love.graphics.setColor(1, 1, 1, 1)
                drawCircularArrow(c.arrowX, c.arrowY, 10)
            end
        end
        
        -- 4. Draw Skip / Start Battle Button
        local sb = layout.skipBtn
        local hoverSkip = mx >= sb.x and mx <= sb.x + sb.w and my >= sb.y and my <= sb.y + sb.h
        if hoverSkip then
            Cursor.wantHand = true
            love.graphics.setColor(0.2, 0.5, 0.3, 0.85)
        else
            love.graphics.setColor(0.1, 0.3, 0.2, 0.6)
        end
        love.graphics.rectangle("fill", sb.x, sb.y, sb.w, sb.h, 6)
        love.graphics.setColor(0.2, 0.9, 0.4, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sb.x, sb.y, sb.w, sb.h, 6)
        love.graphics.setLineWidth(1)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("START BATTLE", sb.x, sb.y + sb.h/2 - titleFont:getHeight()/2, sb.w, "center")

    else
        self.gui:draw()
        if self.rewardSystem and self.rewardSystem.isActive then
            self.rewardSystem:draw()
        end
        

        
        -- Absolute Highest Z-Index Layer: Quit & Destruction Modals overlay everything
        if self.gui and self.gui.confirmation then
            self.gui.confirmation:draw()
        end
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
            or (self.gui and self.gui.mutation and self.gui.mutation.isActive)
            or (self.gui and self.gui.enemyEntry and self.gui.enemyEntry.isActive)
            or (self.gui and self.gui.enemySpawner and self.gui.enemySpawner.isActive)
            or (self.gui and self.gui.itemPicker and self.gui.itemPicker.isActive)
            or (self.gui and self.gui.devSpawner and self.gui.devSpawner.isActive)
            or self:isState("enemy_mutation") or self:isState("upgrade_mutation")
            or self:isState("mulligan") or self.battleComplete
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

function game:getMaxTokens()
    local max = self.maxTokens or 3
    for _, obj in ipairs(self.objects) do
        if obj.name == "Bank" and not obj.destroyed and obj.getTokenBonus then
            max = max + obj:getTokenBonus()
        end
    end
    if self.artifacts then
        max = self.artifacts:modify("modifyMaxTokens", max)
    end
    return max
end

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
--- End-of-wave upkeep. `battleOver` skips drawing the next hand: the battle
--- has no next wave.
function game:waveComplete(battleOver)
    -- Wave-Transition Economy (Token Reset, Mana Regen)
    self.tokens = self:getMaxTokens()
    self:addMana(self.manaRegenPerWave or 0)

    -- Wave-Transition Hand Wiping (the spell hand goes back to the spell deck)
    self:discardHand()
    
    if self.gui and self.gui.incomeFeedback then
        self.gui.incomeFeedback:triggerSequence()
    end
    
    -- Draw new cards for the next wave based on upgrade stats
    if not battleOver then
        self:drawCard(_G.PersistentState and _G.PersistentState.waveCompleteDrawSize or 4)
    end
    
    -- Trigger onWaveComplete for other objects (if any)
    for _, obj in ipairs(self.objects) do
        if obj.onWaveComplete and not obj.destroyed then
            obj:onWaveComplete()
        end
        if obj.effectManager and not obj.destroyed then
            obj.effectManager:triggerEvent("onWaveComplete", obj)
            obj.effectManager:clearWaveEffects()
            obj.effectManager:recalculateStats()
        end
    end
    
    if self.playerEffectManager then
        self.playerEffectManager:triggerEvent("onWaveComplete", self.base)
        self.playerEffectManager:clearWaveEffects()
        self.playerEffectManager:recalculateStats()
    end
    if self.enemyEffectManager then
        self.enemyEffectManager:triggerEvent("onWaveComplete", nil)
        self.enemyEffectManager:clearWaveEffects()
        self.enemyEffectManager:recalculateStats()
    end

    if self.artifacts then
        self.artifacts:trigger("onWaveComplete")
    end
end

--- A frozen enemy died: every placed Ice Market pays out its cash right away.
--- The total is also tallied for the battle summary.
function game:onFrozenEnemyDied(enemy)
    local payout = 0
    for _, obj in ipairs(self.objects) do
        if obj.cashPerFrozenKill and obj.slot and not obj.destroyed then
            payout = payout + obj.cashPerFrozenKill
        end
    end
    if payout <= 0 then return end

    if _G.PersistentState then
        _G.PersistentState.cash = (_G.PersistentState.cash or 0) + payout
    end
    self.iceMarketIncome = (self.iceMarketIncome or 0) + payout
    self:spawnFloatingText("+$" .. payout, enemy.x, enemy.y, {0.3, 1.0, 0.5, 1})
end

--- The battle was won: every placed Vault still standing pays out its cash.
--- The total is also tallied for the battle summary.
function game:payVaults()
    local payout = 0
    for _, obj in ipairs(self.objects) do
        if obj.cashOnBattleWon and obj.slot and not obj.destroyed then
            payout = payout + obj.cashOnBattleWon
            self:spawnFloatingText("+$" .. obj.cashOnBattleWon, obj.x, obj.y - 20, {1, 0.82, 0.3, 1})
        end
    end
    if payout <= 0 then return end

    if _G.PersistentState then
        _G.PersistentState.cash = (_G.PersistentState.cash or 0) + payout
    end
    self.vaultIncome = (self.vaultIncome or 0) + payout
end

function game:spawnParticleExplosion(color, size, x, y, lifetime, numParticles)
    table.insert(self.animations, ParticleExplosion:new(color, size, x, y, lifetime, numParticles))
end

function game:spawnDebuffArrows(x, y)
    table.insert(self.animations, DebuffArrows:new(x, y))
end

function game:spawnBuffPluses(x, y)
    table.insert(self.animations, BuffPluses:new(x, y))
end

function game:spawnDebuffProjectile(x, y, target, onHitCallback, color)
    table.insert(self.animations, DebuffProjectile:new(x, y, target, onHitCallback, color))
end

function game:spawnCircleFade(x, y, radius, color, duration)
    table.insert(self.animations, CircleFade:new(x, y, radius, color, duration))
end

function game:spawnLightningBolt(tx, ty, config)
    table.insert(self.animations, LightningBolt:new(tx, ty, config))
end

function game:spawnExpandingCircle(x, y, startRadius, endRadius, color, duration, delay)
    table.insert(self.animations, ExpandingCircle:new(x, y, startRadius, endRadius, color, duration, delay))
end

function game:spawnArmorBreak(x, y)
    table.insert(self.animations, ArmorBreak:new(x, y))
end

function game:EnemyDied(enemy)
    self:addXP(enemy.reward)
    self:spawnParticleExplosion(enemy.color, enemy.size or enemy.w, enemy.x, enemy.y)
    self:recordCorpse(enemy)
    -- Drain this enemy's slot from the in-progress wave panel (with a flash).
    -- Raised zombies were already counted the first time they died.
    if not enemy.isZombie and self.WaveSpawner and self.WaveSpawner.notifyEnemyKilled then
        self.WaveSpawner:notifyEnemyKilled(enemy)
    end
    if not enemy.reachedBase then
        -- The run's kill count (shown on the game over screen)
        if _G.PersistentState then
            _G.PersistentState.totalKills = (_G.PersistentState.totalKills or 0) + 1
        end
        if self.artifacts then
            self.artifacts:trigger("onEnemyKilled", enemy, enemy.killingBlow)
        end
    end
end

-- Enemies killed in battle leave a corpse for CORPSE_LIFETIME seconds that a
-- Reanimator can raise. Zombies, bosses and enemies that reached the base leave none.
game.CORPSE_LIFETIME = 10
game.MAX_CORPSES = 150

function game:recordCorpse(enemy)
    if enemy.reachedBase or enemy.isZombie or (enemy.tier or 0) >= 5 then return end
    local id = enemy.enemyId or enemy.name
    if not id then return end
    self.corpses = self.corpses or {}
    table.insert(self.corpses, {
        id = id, x = enemy.x, y = enemy.y, tier = enemy.tier or 0, age = 0,
        -- A Slime comes back as the same generation (size, health, splits left) it died as
        overrides = enemy.generation and {
            generation = enemy.generation, maxHp = enemy.maxHp, size = enemy.size,
            damage = enemy.damage, speed = enemy.speed,
        } or nil,
    })
    if #self.corpses > self.MAX_CORPSES then table.remove(self.corpses, 1) end
end

function game:updateCorpses(dt)
    local corpses = self.corpses or {}
    for i = #corpses, 1, -1 do
        corpses[i].age = corpses[i].age + dt
        if corpses[i].age >= self.CORPSE_LIFETIME then table.remove(corpses, i) end
    end
end

--- Removes a corpse once it has been raised.
function game:takeCorpse(corpse)
    for i, c in ipairs(self.corpses or {}) do
        if c == corpse then table.remove(self.corpses, i); return end
    end
end

function game:spawnDamageNumber(amount, x, y, damageType, effectiveness, damageTags)
    if self.showDamageNumbers and amount >= 1 then
        local displayAmount = math.floor(amount + 0.5)
        table.insert(self.animations, DamageNumber:new(displayAmount, x, y, damageType, nil, nil, effectiveness, damageTags))
    end
end

-- Message text centred on (x, y), drifting up. Unlike damage numbers it isn't
-- jittered, so it starts exactly where it's aimed.
local function messageText(text, x, y, color)
    local t = DamageNumber:new(text, x, y, nil, color)
    t.x, t.y, t.velX, t.centered = x, y, 0, true
    return t
end

--- Message text at a world point.
function game:spawnFloatingText(text, x, y, color)
    table.insert(self.animations, messageText(text, x, y, color))
end

--- Message text at a screen point (e.g. the mouse over the hand), drawn over the HUD.
function game:spawnScreenText(text, x, y, color)
    local t = messageText(text, x, y, color)
    t.isUI = true
    table.insert(self.animations, t)
end

-- Game speed: the -/+ buttons, the -/+ keys and Q/E step it between these
game.SPEED_MIN, game.SPEED_MAX, game.SPEED_STEP = 0.5, 2, 0.5

--- Steps the game speed down (direction -1) or up (+1).
function game:changeSpeed(direction)
    self.time_mul = math.max(self.SPEED_MIN, math.min(self.SPEED_MAX, self.time_mul + direction * self.SPEED_STEP))
end

function game:toggleDamageNumbers()
    self.showDamageNumbers = not self.showDamageNumbers
end

function game:isRewardSystemActive()
    return (self.rewardSystem and self.rewardSystem.isActive)
end

function game:placeBuilding(building, sourceReward)
    self.inputMode = "placing"
    
    local config = {game = self}
    local raw = (sourceReward and sourceReward.rawConfig) or sourceReward or {}
    for k, v in pairs(raw) do
        if config[k] == nil then
            config[k] = v
        end
    end
    config.game = self
    
    if sourceReward and sourceReward.shapePattern then
        config.shapePattern = sourceReward.shapePattern
    end
    if sourceReward and sourceReward.color then
        config.color = sourceReward.color
    end
    
    self.blueprint = building:new(config)
    self.blueprint.rewardCard = sourceReward
    self.blueprint.showArc = true
end

--- Picks up a placed building, removing it from the field and returning it to the
--- inventory deck as a fresh card. The main turret (no reward card) can't be
--- picked up. Returns true on success.
function game:pickUpBuilding(building)
    if not building or (building.isType and building:isType("mainturret")) then return false end
    local reward = building.rewardCard
    if not reward or not reward.building then return false end -- nothing to re-card

    -- Remove the placed instance (frees grid slots / reservations + destroys it).
    building:remove()

    -- Recreate a fresh blueprint from the reward and drop it back in the deck.
    local config = { game = self }
    if reward.shapePattern then config.shapePattern = reward.shapePattern end
    if reward.color then config.color = reward.color end

    local bp = reward.building:new(config)
    bp.rewardCard = reward
    self.inventory:add(bp)

    self:recalculateAllBuffs()
    return true
end

function game:getMulliganLayout()
    local N = #self.hand
    local cardW = 200
    local cardH = 280
    local spacing = 20
    local totalW = N * cardW + (N - 1) * spacing
    local startX = (Layout.W - totalW) / 2
    local startY = (Layout.H - cardH) / 2 - 20
    
    local layout = {
        cardW = cardW,
        cardH = cardH,
        cards = {},
        skipBtn = {
            x = (Layout.W - 200) / 2,
            y = Layout.H - 80,
            w = 200,
            h = 50
        }
    }
    
    for i = 1, N do
        local cx = startX + (i - 1) * (cardW + spacing) + cardW / 2
        local cy = startY + cardH + 25
        table.insert(layout.cards, {
            x = startX + (i - 1) * (cardW + spacing),
            y = startY,
            arrowX = cx,
            arrowY = cy,
            arrowR = 20
        })
    end
    
    return layout
end

function game:handleMulliganClick(x, y, button)
    if button ~= 1 then return end
    local layout = self:getMulliganLayout()
    
    -- Check skip button
    local sb = layout.skipBtn
    if x >= sb.x and x <= sb.x + sb.w and y >= sb.y and y <= sb.y + sb.h then
        self:setState("startup")
        return
    end
    
    -- Check card reroll buttons
    for i, c in ipairs(layout.cards) do
        if not (self.mulliganLockedSlots and self.mulliganLockedSlots[i]) then
            local dist2 = (x - c.arrowX)^2 + (y - c.arrowY)^2
            if dist2 <= c.arrowR^2 then
                self:rerollCard(i)
                break
            end
        end
    end
end

function game:rerollCard(cardIndex)
    if not self.hand or not self.hand[cardIndex] then return end
    if #self.drawPile == 0 then return end -- No cards to draw
    
    local oldCard = self.hand[cardIndex]
    table.remove(self.hand, cardIndex)
    
    local newCard = table.remove(self.drawPile, 1)
    
    table.insert(self.drawPile, oldCard)
    
    -- Shuffle drawPile
    for i = #self.drawPile, 2, -1 do
        local j = math.random(i)
        self.drawPile[i], self.drawPile[j] = self.drawPile[j], self.drawPile[i]
    end
    
    if newCard.payload and newCard.payload.effect then
        local EffectManager = require("Game.Effects.EffectManager")
        newCard.effectManager = EffectManager:new(newCard, self)
        newCard.effectManager.game = self
        newCard.effectManager.owner = newCard
        if self.playerEffectManager then
            newCard.effectManager.parent = self.playerEffectManager
        end
        newCard.effectManager:recalculateStats()
    end
    table.insert(self.hand, cardIndex, newCard)
    
    if not self.mulliganLockedSlots then self.mulliganLockedSlots = {} end
    self.mulliganLockedSlots[cardIndex] = true
    if AUDIO then
        AUDIO:playSFX("upgrade_01")
    end
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
    self.discardPile = {}
    self.exiledPile = {}
    -- Spells live in their own deck, drawn only while a wave is running.
    self.spellDrawPile = {}
    self.spellDiscardPile = {}

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
            local pile = self:isSpellCard(card) and self.spellDrawPile or self.drawPile
            for i = 1, (card.quantity or 1) do
                table.insert(pile, deepcopy(card))
            end
        end
    end

    -- Shuffle
    for _, pile in ipairs({ self.drawPile, self.spellDrawPile }) do
        for i = #pile, 2, -1 do
            local j = math.random(i)
            pile[i], pile[j] = pile[j], pile[i]
        end
    end
end

function game:isSpellCard(card)
    return card.executionType == "Spell" or (card.isType and card:isType("spell")) or card.isSpell or false
end

--- Adds mana, capped at maxMana (a dev-mode top-up above the cap is kept, not cut).
function game:addMana(amount)
    local cap = math.max(self.maxMana or math.huge, self.mana or 0)
    self.mana = math.min(cap, (self.mana or 0) + amount)
end

--- Names of the draw/discard piles for the build deck or the spell deck.
local function pileKeys(spells)
    if spells then return "spellDrawPile", "spellDiscardPile" end
    return "drawPile", "discardPile"
end

--- Moves every card in hand to its own deck's discard pile, cancelling any active card.
function game:discardHand()
    if self.activeCard then
        self:refundCard(self.activeCard)
    end
    if self.gui and self.gui.hand and self.gui.hand.dropCards then
        self.gui.hand:dropCards(self.hand)
    end
    for _, card in ipairs(self.hand) do
        local _, discardKey = pileKeys(self:isSpellCard(card))
        self[discardKey] = self[discardKey] or {}
        table.insert(self[discardKey], card)
    end
    self.hand = {}
end

--- Starts the next wave (or a custom dev wave). Sending a wave swaps the build
--- hand for a hand drawn from the spell deck.
function game:startWave(customWaveList)
    self:recalculateAllBuffs() -- Recalculate all buffs before wave starts
    self.corpses = {}
    if customWaveList then
        self.WaveSpawner:startCustomWave(customWaveList)
    else
        self.WaveSpawner:startNextWave()
    end
    self:setState("wave")
    self:discardHand()
    self:drawCard(self.spellHandSize or 4, true)
    if self.artifacts then self.artifacts:trigger("onWaveStart") end
end

--- Draws from the build deck, or from the spell deck when `spells` is true.
function game:drawCard(amount, spells)
    amount = amount or 1
    local drawKey, discardKey = pileKeys(spells)
    self[drawKey] = self[drawKey] or {}
    self[discardKey] = self[discardKey] or {}
    local drawn = 0
    for i = 1, amount do
        if #self.hand >= game.MAX_HAND_SIZE then
            self:spawnFloatingText("Hand is full!", 400, 300, {0.8, 0.2, 0.2, 1})
            break
        end

        local drawPile = self[drawKey]
        if #drawPile == 0 then
            local discardPile = self[discardKey]
            if #discardPile > 0 then
                -- Reshuffle Discard Pile into Draw Pile
                for _, c in ipairs(discardPile) do
                    table.insert(drawPile, c)
                end
                self[discardKey] = {}

                for j = #drawPile, 2, -1 do
                    local r = math.random(j)
                    drawPile[j], drawPile[r] = drawPile[r], drawPile[j]
                end

            else
                -- Both piles empty
                break
            end
        end
        
        self:addCardToHand(table.remove(drawPile, 1))
        drawn = drawn + 1
    end
    return drawn
end

--- Puts a card in the hand, hooking its effects up to this battle.
function game:addCardToHand(card)
    card.game = self
    if card.effectManager then
        card.effectManager.game = self
        card.effectManager.owner = card
        if self.playerEffectManager then
            card.effectManager.parent = self.playerEffectManager
        end
        card.effectManager:recalculateStats()
    end
    table.insert(self.hand, card)
end

function game:consumeCard(card)
    local isSpell = self:isSpellCard(card)
    if isSpell then
        self.mana = (self.mana or 0) - card:getCost()
    else
        self.tokens = self.tokens - card:getCost()
    end
    for i, c in ipairs(self.hand) do
        if c == card then
            table.remove(self.hand, i)
            
            local execType = card.executionType
            local ExecutionType = require("Game.Cards.ExecutionType")
            
            if card.isExile then
                if type(card.Exile) == "function" then
                    card:Exile(self)
                else
                    if not self.exiledPile then self.exiledPile = {} end
                    table.insert(self.exiledPile, card)
                end
            elseif card.isConsume or execType == ExecutionType.Placement or execType == "Placement" then
                if type(card.Consume) == "function" then
                    card:Consume(self)
                else
                    table.insert(self.consumedPile, card)
                end
            elseif isSpell then
                self.spellDiscardPile = self.spellDiscardPile or {}
                table.insert(self.spellDiscardPile, card)
            else
                table.insert(self.discardPile, card)
            end
            break
        end
    end
    self.activeCard = nil
    if self.inputMode ~= "aiming" then
        self.inputMode = "idle"
    end
end

--- Tokens the active card will spend when it resolves (spells spend mana instead).
function game:getActiveCardTokenCost()
    local card = self.activeCard
    if not card then return 0 end
    if self:isSpellCard(card) then return 0 end
    return card:getCost()
end

--- Placement spends slot unlocks and then the card itself (in consumeCard), so both must fit.
function game:canAffordPlacement(unlockCost)
    return self.tokens >= unlockCost + self:getActiveCardTokenCost()
end

function game:refundCard(card)
    -- Assuming the card wasn't removed from the hand array until consumeCard
    -- We no longer refund tokens here since they are not subtracted on selection anymore
    self.activeCard = nil
    self.blueprint = nil
    self.inputMode = "idle"
end

-- -----------------------------------------------------------------------------
-- Ground Object Implementation
function game:attemptPurchaseReward()
    if self.tokens >= self.rewardCost and not self.rewardSystem.isActive and self.inputMode == "idle" then
        self.tokens = self.tokens - self.rewardCost
        self.rewardSystem:activate("normal", 3)
        return true
    end
    return false
end

function game:winBattle()
    -- Close any active mid-battle menus or targeting
    if self.activeCard then
        self:refundCard(self.activeCard)
    end
    if self.rewardSystem then
        self.rewardSystem.isActive = false
    end
    if self.gui and self.gui.mutation then
        self.gui.mutation.isActive = false
    end
    if self.gui and self.gui.enemySpawner then
        self.gui.enemySpawner.isActive = false
    end
    if self.gui and self.gui.itemPicker then
        self.gui.itemPicker.isActive = false
    end
    if self.gui and self.gui.devSpawner then
        self.gui.devSpawner:close()
        self.gui.devSpawner:clearQueue()
    end

    -- Clear all enemies and enemy bullets
    for i = #self.objects, 1, -1 do
        local obj = self.objects[i]
        if obj.isType and (obj:isType("enemy") or obj.untargetable or (obj:isType("bullet") and obj.targetType == "building")) then
            obj.destroyed = true
            table.remove(self.objects, i)
        end
    end

    if self.WaveSpawner then
        self.WaveSpawner.waveList = {}
        self.WaveSpawner.waveState = "idle"
    end

    if _G.PersistentState then
        _G.PersistentState.upcomingWaves = {}
        _G.PersistentState.upcomingSummaries = {}
    end

    self:waveComplete(true)
    self:payVaults()

    self.battleComplete = true
    self:clearGlobalBuffs()
    
    local BattleManager = require("Game.Core.BattleManager")
    local bm = BattleManager:new()
    
    if _G.PersistentState then
        _G.PersistentState.baseHP = self.base and self.base.hp or 100
        
        local activeBattle = _G.PersistentState.selectedBattle
        local rewards = activeBattle and activeBattle.rewards
        
        -- Find gold reward amount for UI summary screen ($0 when the battle gave no cash)
        local goldReward = 0
        if rewards and #rewards > 0 then
            for _, r in ipairs(rewards) do
                if r.type == BattleManager.REWARD_TYPES.GOLD then
                    goldReward = r.amount or goldReward
                    break
                end
            end
            self.battleReward = goldReward
            self.awardedBattleRewards = rewards
            bm:applyRewards(rewards, self)
        else
            -- Default legacy behavior / fallback
            self.battleReward = 100
            _G.PersistentState.cash = (_G.PersistentState.cash or 0) + 100
        end
    else
        self.battleReward = 100
    end
end

return game
