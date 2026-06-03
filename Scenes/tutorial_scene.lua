local tutorial_scene = {}
tutorial_scene.__index = tutorial_scene
local scene = require("Scenes.scene")
setmetatable(tutorial_scene, { __index = scene })

local game = require("Game.Core.GameManager")
local Layout = require("Game.GUI.Layout")

function tutorial_scene:load()
    love.mouse.setVisible(false)

    -- Load the game singleton
    game:load(nil, false) -- isTesting = false
    game:setState("preparing")
    game.time_mul = 1 -- normal speed
    -- Hide the live "press enter / incoming wave" cues; the tutorial drives the
    -- wave itself and provides its own guidance.
    game.suppressWaveUI = true
    
    -- Force autofire to false initially
    if game.mainLazer then
        game.mainLazer.autofire = false
    end
    
    -- Setup initial state
    game.tokens = 5
    self.stepIndex = 1
    self.shotHooked = false
    self.hoverTime = 0
    
    -- Font for dialog text
    self.dialogFont = love.graphics.newFont(14)
    
    -- Exit button (top right of screen, out of the way of dialog & HUD)
    self.exitButton = {
        x = VIRTUAL_WIDTH - 110,
        y = 10,
        w = 100,
        h = 30,
        label = "Exit to Menu"
    }
    
    -- Define steps. `highlight` is a semantic target (resolved to a live screen
    -- rect in targetRect()) that the spotlight focuses and dims around.
    self.steps = {
        { id = 1, type = "dialog", text = "Welcome to the Base Defense Tutorial!\n\nYou'll learn the basic controls and core strategies to defend your core." },
        { id = 2, type = "dialog", text = "Enemies approach from the RIGHT side of the battlefield.\n\nWatch their lanes to plan your defenses.", highlight = "fieldRight" },
        { id = 3, type = "dialog", text = "This is your Base, on the LEFT. Don't let enemies reach it — if they do, your base health drops.", highlight = "base" },
        { id = 4, type = "shoot", text = "You can fire the main laser manually.\n\nLeft-click anywhere on the battlefield to fire!", highlight = "field" },
        { id = 5, type = "autofire_on", text = "Manual shooting works, but we can automate it.\n\nPress TAB to toggle Auto-Fire ON.", highlight = "autofire" },
        { id = 5.5, type = "autofire_off", text = "Auto-Fire shoots during waves, but you still need to aim! Press TAB again to turn it back off.", highlight = "autofire" },
        { id = 6, type = "buy_sentry", text = "Let's expand our arsenal.\n\nClick 'Buy Upgrade' to see card choices.", highlight = "buy" },
        { id = 6.5, type = "select_sentry", text = "Select the Sentry turret card (the first card).", highlight = "card1" },
        { id = 7, type = "store_sentry", text = "Instead of placing it now, let's store it.\n\nClick the bottom tray to stash it in your inventory.", highlight = "tray" },
        { id = 8, type = "unlock_slot", text = "Locked base slots are marked 'T'.\n\nClick the highlighted slot above the main laser to unlock it (costs 1 Token).", highlight = "slot:26" }, -- slot 26 (col 2, row 7)
        { id = 8.5, type = "dialog", text = "Unlocking slots expands the visible area of your base grid, exposing more neighboring slots." },
        { id = 9, type = "select_inventory", text = "Now retrieve the Sentry from your inventory.\n\nClick the Sentry card in the bottom tray.", highlight = "tray" },
        { id = 10, type = "place_sentry", text = "Place the Sentry in the slot you just unlocked.", highlight = "slot:26" },
        { id = 10.5, type = "dialog", text = "Tip: with enough tokens you can place cards directly onto unlocked base slots without storing them first." },
        { id = 11, type = "aim_sentry", text = "Move the mouse to aim the Sentry's firing arc.\n\nLeft-click to lock its direction.", highlight = "field" },
        { id = 12, type = "hover_sentry", text = "Hover the Sentry (or hold Space) to check its range and firing arc.", highlight = "slot:26" },
        { id = 12.5, type = "dialog", text = "Tip: you can re-aim placed turrets by clicking them between waves — but not while a wave is active." },
        { id = 13, type = "start_wave", text = "Time to test your defenses!\n\nPress ENTER to start the training wave." },
        { id = 13.5, type = "combat", text = "Training wave in progress — defeat the targets!", highlight = "field" },
        { id = 14, type = "dialog", text = "Wave Complete!\n\nYou earn 3 Tokens, plus 10% interest on any unspent tokens at the end of each wave." },
        { id = 15, type = "buy_box", text = "Let's buy another upgrade.\n\nClick 'Buy Upgrade'.", highlight = "buy" },
        { id = 15.5, type = "select_box", text = "Choose the 'Small Box' (first card) to buy a blocker.", highlight = "card1" },
        { id = 16, type = "place_box", text = "Place the Small Box out on the battlefield.\n\nBlockers force enemies to path around them, buying you time!", highlight = "field" },
        { id = 17, type = "buy_luck", text = "Click 'Luck Offering' (costs 1 Token) to raise the chance of rarer cards.", highlight = "luck" },
        { id = 17.5, type = "dialog", text = "Tip: hover the 'Buy Upgrade' button to view the active card rarity odds." },
        { id = 18, type = "buy_cache", text = "Here are 3 extra Tokens. Buy another upgrade to buff your turrets.\n\nClick 'Buy Upgrade'.", highlight = "buy" },
        { id = 18.5, type = "select_cache", text = "Choose the uncommon 'Ammo Cache' card.", highlight = "card1" },
        { id = 19, type = "place_cache", text = "Place the Ammo Cache adjacent to your Sentry.\n\nGreen outlines show which slots receive the buff!", highlight = "base" }, -- slot 27 (col 3, row 7)
        { id = 19.5, type = "dialog", text = "Buildings like the Ammo Cache boost adjacent turrets. Placing them well is key to late-game success." },
        { id = 20, type = "dialog", text = "Excellent! You're ready for the real invasion.\nAs waves progress, enemies mutate and adapt — keep upgrading.\n\nGood luck, Commander!" }
    }
    
    -- Let's backup the methods we will override
    self.originals = {}
    
    local function backup(obj, name)
        if not self.originals[obj] then
            self.originals[obj] = {}
        end
        self.originals[obj][name] = obj[name]
    end
    
    backup(game.rewardSystem, "initializeRewardPool")
    backup(game.rewardSystem, "selectReward")
    backup(game.rewardSystem, "mousepressed")
    backup(game.inputHandler, "mousepressed")
    backup(game.inputHandler, "keypressed")
    backup(game.inputHandler, "mousereleased")
    backup(game.gui, "mousepressed")
    backup(game.gui, "mousereleased")
    backup(game.WaveSpawner, "update")
    backup(game.waveDirector, "generateWaveList")
    backup(game, "isState")
    backup(game, "update")
    
    -- Override isState to allow autofire during tutorial steps
    game.isState = function(this, state)
        if state == "wave" and game.mainLazer and game.mainLazer.autofire then
            local step = self.steps[self.stepIndex]
            if step and (step.type == "autofire_on" or step.type == "autofire_off") then
                return true
            end
        end
        return self.originals[game].isState(this, state)
    end

    -- Override update to keep animations updating even when gameplay is frozen
    game.update = function(this, dt)
        local step = self.steps[self.stepIndex]
        local isFrozen = false
        if step then
            if self:isDialogStep() or
               (game.rewardSystem and game.rewardSystem.isActive) or 
               (game.specialUpgradeManager and game.specialUpgradeManager.isActive) or
               (game.gui.mutation and game.gui.mutation.isActive) or
               (game.gui.confirmation and game.gui.confirmation.active) then
                isFrozen = true
            end
        end
        
        if isFrozen then
            -- Update UI, animations, and inputs with real dt so they continue animating smoothly
            this.pulseTimer = this.pulseTimer + dt
            
            for i = #this.animations, 1, -1 do
                local anim = this.animations[i]
                anim:update(dt)
                if anim.destroyed then
                    table.remove(this.animations, i)
                end
            end
            
            this.gui:update(dt)
            this.inventory:update(dt)
            this.inputHandler:update(dt)
            
            if this.rewardSystem then
                this.rewardSystem:update(dt)
            end
            
            -- Keep gameplay objects/components frozen
            this.WaveSpawner:update(0)
            this.playerEffectManager:update(0)
            this.enemyEffectManager:update(0)
            
            for _, obj in ipairs(this.objects) do
                if not obj.destroyed and obj.update then
                    obj:update(0)
                end
            end
            
            this:takeOutTheTrash()
        else
            -- Call the original update with scaled time
            local effectiveDt = dt * game.time_mul
            self.originals[game].update(this, effectiveDt)
        end
    end
    
    -- Monkey-patch Reward Pool Generation
    game.rewardSystem.initializeRewardPool = function(rewardSys)
        rewardSys.rewardPool = {}
        local step = self.steps[self.stepIndex]
        if not step then return end
        
        local choicesData = {}
        if step.type == "select_sentry" or step.type == "buy_sentry" then
            choicesData = {
                {
                    id = "sentry",
                    name = "Sentry",
                    description = "Standard defense turret.",
                    type = "building",
                    building = require("Buildings.Turrets.Sentry"),
                    rarity = "common"
                },
                {
                    id = "smallbox",
                    name = "Small Box",
                    description = "Basic blocker pathing.",
                    type = "building",
                    building = require("Buildings.Blockers.SmallBox"),
                    rarity = "common"
                },
                {
                    id = "shotgunTurret",
                    name = "Shotgun Turret",
                    description = "Short range spread fire.",
                    type = "building",
                    building = require("Buildings.Turrets.ShotgunTurret"),
                    rarity = "common"
                }
            }
        elseif step.type == "select_box" or step.type == "buy_box" then
            choicesData = {
                {
                    id = "smallbox",
                    name = "Small Box",
                    description = "Basic blocker pathing.",
                    type = "building",
                    building = require("Buildings.Blockers.SmallBox"),
                    rarity = "common"
                },
                {
                    id = "sentry",
                    name = "Sentry",
                    description = "Standard defense turret.",
                    type = "building",
                    building = require("Buildings.Turrets.Sentry"),
                    rarity = "common"
                },
                {
                    id = "shotgunTurret",
                    name = "Shotgun Turret",
                    description = "Short range spread fire.",
                    type = "building",
                    building = require("Buildings.Turrets.ShotgunTurret"),
                    rarity = "common"
                }
            }
        elseif step.type == "select_cache" or step.type == "buy_cache" then
            choicesData = {
                {
                    id = "ammoCache",
                    name = "Ammo Cache",
                    description = "Increase nearby turret damage by 20%",
                    type = "building",
                    building = require("Buildings.Buffs.Buff"),
                    rarity = "uncommon",
                    iconCategory = "buff"
                },
                {
                    id = "sentry",
                    name = "Sentry",
                    description = "Standard defense turret.",
                    type = "building",
                    building = require("Buildings.Turrets.Sentry"),
                    rarity = "common"
                },
                {
                    id = "smallbox",
                    name = "Small Box",
                    description = "Basic blocker pathing.",
                    type = "building",
                    building = require("Buildings.Blockers.SmallBox"),
                    rarity = "common"
                }
            }
        end
        
        local Reward = require("Game.Rewards.Reward")
        local CardReveal = require("Graphics.Animations.CardReveal")

        rewardSys.revealTimer = 0
        rewardSys.nextRevealIndex = 1

        -- Center the row of cards on the canvas (mirrors the real reward system).
        local count = #choicesData
        local totalWidth = (count * rewardSys.cardWidth) + ((count - 1) * rewardSys.cardSpacing)
        rewardSys.startX = (VIRTUAL_WIDTH - totalWidth) / 2

        for i, data in ipairs(choicesData) do
            data.game = game
            local rewardObj = Reward:new(data)
            local x = rewardSys.startX + (i - 1) * (rewardSys.cardWidth + rewardSys.cardSpacing)
            local y = rewardSys.startY
            
            local card = CardReveal:new(rewardObj, x, y, rewardSys.cardWidth, rewardSys.cardHeight)
            table.insert(rewardSys.rewardPool, card)
        end
        rewardSys.currentChoices = rewardSys.rewardPool
    end
    
    -- Monkey-patch selectReward to only allow index 1
    game.rewardSystem.selectReward = function(rewardSys, index)
        if index == 1 then
            self.originals[game.rewardSystem].selectReward(rewardSys, index)
        end
    end
    
    -- Monkey-patch Wave Spawner / Director for Wave 1
    game.waveDirector.generateWaveList = function(director, waveNumber)
        local EnemyClass = require("Enemies.Enemy")
        return { EnemyClass, EnemyClass }
    end
end

function tutorial_scene:exitTutorial()
    -- Restore original functions
    if self.originals then
        for obj, originalMethods in pairs(self.originals) do
            for name, func in pairs(originalMethods) do
                obj[name] = func
            end
        end
    end
    game.suppressWaveUI = nil -- restore the live wave cues
    self.scene_manager.switch("menu")
end

function tutorial_scene:isDialogStep()
    local step = self.steps[self.stepIndex]
    if not step then return false end
    return step.type == "dialog"
end

function tutorial_scene:advanceStep()
    if game.inputHandler then
        game.inputHandler.isMouseDown = false
    end

    self.stepIndex = self.stepIndex + 1
    if self.stepIndex > #self.steps then
        self:exitTutorial()
        return
    end
    
    local step = self.steps[self.stepIndex]
    if not step then return end
    
    if step.type == "buy_cache" then
        game.tokens = game.tokens + 3
    elseif step.type == "dialog" and step.id == 14 then
        game.tokens = 3
    end
end

function tutorial_scene:isActionAllowed(action, x, y, button, key)
    local step = self.steps[self.stepIndex]
    if not step then return false end
    
    if step.type == "dialog" then
        return false -- No actions allowed
    end
    
    if step.type == "combat" then
        if action == "mousepressed" then
            -- Allow manual shooting during combat, but block clicking Buy/Luck/Exit UI buttons
            local eb = self.exitButton
            if x >= eb.x and x <= eb.x + eb.w and y >= eb.y and y <= eb.y + eb.h then
                return false
            end
            if x >= game.gui.buyButton.x and x <= game.gui.buyButton.x + game.gui.buyButton.w and
               y >= game.gui.buyButton.y and y <= game.gui.buyButton.y + game.gui.buyButton.h then
                return false
            end
            if x >= game.gui.luckButton.x and x <= game.gui.luckButton.x + game.gui.luckButton.w and
               y >= game.gui.luckButton.y and y <= game.gui.luckButton.y + game.gui.luckButton.h then
                return false
            end
            return true
        elseif action == "keypressed" then
            -- Allow Tab to toggle autofire during combat
            if key == "tab" then
                return true
            end
        end
        return false
    end
    
    if action == "mousepressed" or action == "mousereleased" then
        -- Prevent clicking on Exit Button area since scene handles it
        local eb = self.exitButton
        if x >= eb.x and x <= eb.x + eb.w and y >= eb.y and y <= eb.y + eb.h then
            return false
        end
        
        if step.type == "shoot" then
            -- Can shoot, but block clicking Buy/Luck UI
            if x >= game.gui.buyButton.x and x <= game.gui.buyButton.x + game.gui.buyButton.w and
               y >= game.gui.buyButton.y and y <= game.gui.buyButton.y + game.gui.buyButton.h then
                return false
            end
            if x >= game.gui.luckButton.x and x <= game.gui.luckButton.x + game.gui.luckButton.w and
               y >= game.gui.luckButton.y and y <= game.gui.luckButton.y + game.gui.luckButton.h then
                return false
            end
            return true
            
        elseif step.type == "buy_sentry" or step.type == "buy_box" or step.type == "buy_cache" then
            -- Buy Upgrade button click allowed
            if x >= game.gui.buyButton.x and x <= game.gui.buyButton.x + game.gui.buyButton.w and
               y >= game.gui.buyButton.y and y <= game.gui.buyButton.y + game.gui.buyButton.h then
                return true
            end
            return false
            
        elseif step.type == "select_sentry" or step.type == "select_box" or step.type == "select_cache" then
            -- Card index 1 click allowed
            local i = 1
            local cardX = game.rewardSystem.startX + (i - 1) * (game.rewardSystem.cardWidth + game.rewardSystem.cardSpacing)
            local cardY = game.rewardSystem.startY
            if x >= cardX and x <= cardX + game.rewardSystem.cardWidth and
               y >= cardY and y <= cardY + game.rewardSystem.cardHeight then
                return true
            end
            return false
            
        elseif step.type == "store_sentry" then
            -- Can store in inventory (bottom tray)
            if y >= Layout.tray.y then
                return true
            end
            return false

        elseif step.type == "unlock_slot" then
            -- Unlock slot 26 allowed (world-space hit test).
            if self:overSlot(x, y, 26) then return true end
            return false

        elseif step.type == "select_inventory" then
            -- Can select card from inventory (bottom tray)
            if y >= Layout.tray.y then
                return true
            end
            return false

        elseif step.type == "place_sentry" then
            -- Place in slot 26 allowed (world-space hit test).
            if self:overSlot(x, y, 26) then return true end
            return false

        elseif step.type == "aim_sentry" then
            return true

        elseif step.type == "place_box" then
            -- Can place out on the battlefield, off the base grid (world space).
            local fx, fy = Layout.mouseToField(x, y)
            if not self:overBaseGrid(fx, fy) and fx >= 0 and fx <= Layout.FIELD_W
               and fy >= Layout.WORLD_Y and fy <= Layout.WORLD_Y + Layout.FIELD_H then
                return true
            end
            return false

        elseif step.type == "buy_luck" then
            -- Luck offering button click allowed
            if x >= game.gui.luckButton.x and x <= game.gui.luckButton.x + game.gui.luckButton.w and
               y >= game.gui.luckButton.y and y <= game.gui.luckButton.y + game.gui.luckButton.h then
                return true
            end
            return false

        elseif step.type == "place_cache" then
            -- Must place on the base grid (world space).
            local fx, fy = Layout.mouseToField(x, y)
            if self:overBaseGrid(fx, fy) then
                return true
            end
            return false
        end
    end
    
    if action == "keypressed" then
        if (step.type == "autofire_on" or step.type == "autofire_off") and key == "tab" then
            return true
        elseif step.type == "start_wave" and (key == "return" or key == "kpenter") then
            return true
        end
    end
    
    return false
end

function tutorial_scene:mousepressed(x, y, button)
    if button == 1 then
        -- Check Exit Button
        local eb = self.exitButton
        if x >= eb.x and x <= eb.x + eb.w and y >= eb.y and y <= eb.y + eb.h then
            -- Sound removed per user request
            self:exitTutorial()
            return
        end
        
        -- Check Dialog click (anywhere in the dialog card advances it).
        if self:isDialogStep() then
            local step = self.steps[self.stepIndex]
            local d = self:dialogRect(self:targetRect(step))
            if x >= d.x and x <= d.x + d.w and y >= d.y and y <= d.y + d.h then
                self:advanceStep()
                return
            end
        end
    end
    
    if self:isActionAllowed("mousepressed", x, y, button) then
        self.originals[game.inputHandler].mousepressed(game.inputHandler, x, y, button)
    end
end

function tutorial_scene:mousereleased(x, y, button)
    if self.originals[game.inputHandler].mousereleased then
        self.originals[game.inputHandler].mousereleased(game.inputHandler, x, y, button)
    end
end

function tutorial_scene:keypressed(key)
    if key == "escape" then
        self:exitTutorial()
        return
    end
    
    if self:isDialogStep() and (key == "return" or key == "kpenter" or key == "space") then
        self:advanceStep()
        return
    end
    
    if self:isActionAllowed("keypressed", nil, nil, nil, key) then
        self.originals[game.inputHandler].keypressed(game.inputHandler, key)
    end
end

function tutorial_scene:update(dt)
    game:update(dt)
    
    -- Track Step Progression
    local step = self.steps[self.stepIndex]
    if step then
        if step.type == "shoot" then
            if not self.shotHooked and game.mainLazer then
                local originalFire = game.mainLazer.fire
                game.mainLazer.fire = function(this, ...)
                    originalFire(this, ...)
                    if self.steps[self.stepIndex] and self.steps[self.stepIndex].type == "shoot" then
                        self:advanceStep()
                    end
                end
                self.shotHooked = true
            end
            
        elseif step.type == "autofire_on" then
            if game.mainLazer and game.mainLazer.autofire then
                self:advanceStep()
            end
            
        elseif step.type == "autofire_off" then
            if game.mainLazer and not game.mainLazer.autofire then
                self:advanceStep()
            end
            
        elseif step.type == "buy_sentry" or step.type == "buy_box" or step.type == "buy_cache" then
            if game.rewardSystem and game.rewardSystem.isActive then
                self:advanceStep()
            end
            
        elseif step.type == "select_sentry" or step.type == "select_box" or step.type == "select_cache" then
            if game.rewardSystem and not game.rewardSystem.isActive then
                self:advanceStep()
            end
            
        elseif step.type == "store_sentry" then
            if game.inventory and #game.inventory.items > 0 and game.inputMode == "idle" then
                self:advanceStep()
            end
            
        elseif step.type == "unlock_slot" then
            if game.base and game.base.buildGrid.unlocked[26] then
                self:advanceStep()
            end
            
        elseif step.type == "select_inventory" then
            if game.inputMode == "placing" then
                self:advanceStep()
            end
            
        elseif step.type == "place_sentry" then
            if game.base and game.base.buildGrid.buildings[26] and game.inputMode == "aiming" then
                self:advanceStep()
            end
            
        elseif step.type == "aim_sentry" then
            if game.inputMode == "idle" then
                self:advanceStep()
            end
            
        elseif step.type == "hover_sentry" then
            local spaceHeld = love.keyboard.isDown("space")
            local isHovered = game.inputHandler.hoveredBuilding and game.inputHandler.hoveredBuilding.slot == 26
            if spaceHeld or isHovered then
                self.hoverTime = self.hoverTime + dt
                if self.hoverTime >= 0.5 then
                    self:advanceStep()
                end
            else
                self.hoverTime = 0
            end
            
        elseif step.type == "start_wave" then
            if game:isState("wave") then
                self:advanceStep()
            end
            
        elseif step.type == "combat" then
            local enemiesAlive = 0
            for _, obj in ipairs(game.objects) do
                if obj:isType("enemy") and not obj.destroyed then
                    enemiesAlive = enemiesAlive + 1
                end
            end
            if game.WaveSpawner.waveState == "idle" and enemiesAlive == 0 and game:isState("preparing") then
                self:advanceStep()
            end
            
        elseif step.type == "place_box" then
            local count = 0
            for _ in pairs(game.battlefieldGrid.buildings) do
                count = count + 1
            end
            if game.inputMode == "idle" and count > 0 then
                self:advanceStep()
            end
            
        elseif step.type == "buy_luck" then
            if game.luck >= 2 then
                self:advanceStep()
            end
            
        elseif step.type == "place_cache" then
            local hasCache = false
            for _, b in pairs(game.base.buildGrid.buildings) do
                if b:isType("passive") then
                    hasCache = true
                    break
                end
            end
            if hasCache and game.inputMode == "idle" then
                self:advanceStep()
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Geometry helpers (resolve semantic targets to live SCREEN-space rects)
-- ---------------------------------------------------------------------------

-- World rect of a build-grid slot, on screen.
function tutorial_scene:slotRect(n)
    local bg = game.base.buildGrid
    local col = ((n - 1) % bg.width) + 1
    local row = math.ceil(n / bg.width)
    local sx, sy = Layout.worldToScreen(bg.x + (col - 1) * bg.cellSize, bg.y + (row - 1) * bg.cellSize)
    local s = Layout.scale * bg.cellSize
    return { x = sx, y = sy, w = s, h = s }
end

-- True if field-local (world) point is on the base build grid.
function tutorial_scene:overBaseGrid(fx, fy)
    local bg = game.base.buildGrid
    return fx >= bg.x and fx <= bg.x + bg.width * bg.cellSize
       and fy >= bg.y and fy <= bg.y + bg.height * bg.cellSize
end

-- True if a screen click falls on the given base slot.
function tutorial_scene:overSlot(x, y, n)
    local bg = game.base.buildGrid
    local col = ((n - 1) % bg.width) + 1
    local row = math.ceil(n / bg.width)
    local fx, fy = Layout.mouseToField(x, y)
    local wx = bg.x + (col - 1) * bg.cellSize
    local wy = bg.y + (row - 1) * bg.cellSize
    return fx >= wx and fx <= wx + bg.cellSize and fy >= wy and fy <= wy + bg.cellSize
end

local function rectOf(b) return { x = b.x, y = b.y, w = b.w, h = b.h } end

-- Resolve a step's `highlight` descriptor to a live screen rect (or nil).
function tutorial_scene:targetRect(step)
    local h = step and step.highlight
    if not h then return nil end
    local gui = game.gui
    if h == "buy"  then return rectOf(gui.buyButton) end
    if h == "luck" then return rectOf(gui.luckButton) end
    if h == "autofire" then return rectOf(gui.autoFireButton) end
    if h == "tray" then return rectOf(Layout.trayCards) end
    if h == "field" then return rectOf(Layout.field) end
    if h == "card1" then
        local rs = game.rewardSystem
        return { x = rs.startX, y = rs.startY, w = rs.cardWidth, h = rs.cardHeight }
    end
    if h == "fieldRight" then
        local f = Layout.field
        return { x = f.x + f.w * 0.6, y = f.y, w = f.w * 0.4, h = f.h }
    end
    if h == "base" then
        local sx, sy = Layout.worldToScreen(0, Layout.WORLD_Y)
        local ex, ey = Layout.worldToScreen(100, Layout.WORLD_Y + Layout.FIELD_H)
        return { x = sx, y = sy, w = ex - sx, h = ey - sy }
    end
    local slot = tostring(h):match("^slot:(%d+)$")
    if slot then return self:slotRect(tonumber(slot)) end
    return nil
end

-- Dialog card rect, kept clear of the highlighted element. Pure dialogs center
-- in the field; otherwise the card sits opposite the highlight (top vs bottom).
function tutorial_scene:dialogRect(hl)
    local f = Layout.field
    local w, h = 620, 116
    local x = f.x + math.floor((f.w - w) / 2)
    local y
    if not hl then
        y = f.y + math.floor((f.h - h) / 2)
    elseif (hl.y + hl.h / 2) < VIRTUAL_HEIGHT / 2 then
        y = VIRTUAL_HEIGHT - h - 22          -- highlight up high → dialog low
    else
        y = f.y + 18                          -- highlight down low → dialog high
    end
    return { x = x, y = y, w = w, h = h }
end

-- Dim everything except `rect` (a spotlight), with a pulsing border. A nil rect
-- dims the whole screen (used for pure dialog steps).
function tutorial_scene:drawSpotlight(rect)
    local W, H = VIRTUAL_WIDTH, VIRTUAL_HEIGHT
    love.graphics.setColor(0, 0, 0, 0.6)
    if not rect then
        love.graphics.rectangle("fill", 0, 0, W, H)
        return
    end
    local pad = 6
    local rx = math.max(0, rect.x - pad)
    local ry = math.max(0, rect.y - pad)
    local rw = math.min(W - rx, rect.w + pad * 2)
    local rh = math.min(H - ry, rect.h + pad * 2)
    -- Four dim bands around the cut-out.
    love.graphics.rectangle("fill", 0, 0, W, ry)
    love.graphics.rectangle("fill", 0, ry + rh, W, math.max(0, H - (ry + rh)))
    love.graphics.rectangle("fill", 0, ry, rx, rh)
    love.graphics.rectangle("fill", rx + rw, ry, math.max(0, W - (rx + rw)), rh)
    -- Pulsing focus border.
    local pulse = (math.sin(love.timer.getTime() * 4) + 1) / 2
    love.graphics.setLineWidth(4)
    love.graphics.setColor(1, 1, 1, 0.55 + pulse * 0.45)
    love.graphics.rectangle("line", rx, ry, rw, rh, 4)
    love.graphics.setLineWidth(1)
end

function tutorial_scene:draw()
    game:draw()

    local step = self.steps[self.stepIndex]
    if not step then return end

    -- Spotlight: dim the screen, highlighting only the active element.
    local hl = self:targetRect(step)
    self:drawSpotlight(hl)

    -- Dialog card, kept clear of the highlight.
    local d = self:dialogRect(hl)
    love.graphics.setColor(0.08, 0.08, 0.12, 0.96)
    love.graphics.rectangle("fill", d.x, d.y, d.w, d.h, 10, 10)
    local pulse = (math.sin(love.timer.getTime() * 4) + 1) / 2
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0, 0.8, 1, 0.5 + pulse * 0.3)
    love.graphics.rectangle("line", d.x, d.y, d.w, d.h, 10, 10)
    love.graphics.setLineWidth(1)

    if self.dialogFont then love.graphics.setFont(self.dialogFont) end

    -- Title row.
    love.graphics.setColor(0, 0.8, 1, 1)
    love.graphics.print("TUTORIAL — STEP " .. self.stepIndex .. " / " .. #self.steps, d.x + 20, d.y + 12)

    -- Instruction text.
    love.graphics.setColor(0.92, 0.92, 0.92, 1)
    love.graphics.printf(step.text, d.x + 20, d.y + 34, d.w - 40, "left")

    -- Prompt helper (bottom-right of the card).
    local prompt = self:promptFor(step)
    love.graphics.setColor(0.6, 0.65, 0.72, 0.85)
    love.graphics.printf(prompt, d.x + 20, d.y + d.h - 20, d.w - 40, "right")

    -- Exit button.
    local eb = self.exitButton
    local mx, my = love.mouse.getPosition()
    local ebHover = mx >= eb.x and mx <= eb.x + eb.w and my >= eb.y and my <= eb.y + eb.h
    love.graphics.setColor(ebHover and 0.8 or 0.5, ebHover and 0.2 or 0.1, ebHover and 0.2 or 0.1, ebHover and 1 or 0.9)
    love.graphics.rectangle("fill", eb.x, eb.y, eb.w, eb.h, 6, 6)
    love.graphics.setColor(1, 0.5, 0.5, 1)
    love.graphics.rectangle("line", eb.x, eb.y, eb.w, eb.h, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(eb.label, eb.x, eb.y + 7, eb.w, "center")

    -- Single red tutorial cursor on top (OS cursor stays hidden).
    love.mouse.setVisible(false)
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.circle("fill", mx, my, 3)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Short action hint shown at the bottom of the dialog card.
function tutorial_scene:promptFor(step)
    local t = step.type
    if t == "dialog" then return "[ ENTER or click to continue ]"
    elseif t == "shoot" then return "[ Left-click the battlefield to fire ]"
    elseif t == "autofire_on" then return "[ Press TAB to toggle Auto-Fire ON ]"
    elseif t == "autofire_off" then return "[ Press TAB to toggle Auto-Fire OFF ]"
    elseif t == "buy_sentry" or t == "buy_box" or t == "buy_cache" then return "[ Click 'Buy Upgrade' ]"
    elseif t == "select_sentry" or t == "select_box" or t == "select_cache" then return "[ Choose the first card ]"
    elseif t == "store_sentry" then return "[ Click the bottom tray to store ]"
    elseif t == "unlock_slot" then return "[ Click the highlighted slot ]"
    elseif t == "select_inventory" then return "[ Click the Sentry in the tray ]"
    elseif t == "place_sentry" then return "[ Click the unlocked slot ]"
    elseif t == "aim_sentry" then return "[ Move to aim, click to lock ]"
    elseif t == "hover_sentry" then return "[ Hover the turret or hold Space ]"
    elseif t == "start_wave" then return "[ Press ENTER to start the wave ]"
    elseif t == "combat" then return "[ Defeat the training targets ]"
    elseif t == "place_box" then return "[ Place the box on the battlefield ]"
    elseif t == "buy_luck" then return "[ Click 'Luck Offering' ]"
    elseif t == "place_cache" then return "[ Place beside the Sentry ]"
    end
    return ""
end

return tutorial_scene
