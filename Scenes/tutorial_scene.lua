local tutorial_scene = {}
tutorial_scene.__index = tutorial_scene
local scene = require("Scenes.scene")
setmetatable(tutorial_scene, { __index = scene })

local game = require("Game.Core.GameManager")

function tutorial_scene:load()
    love.mouse.setVisible(true)
    
    -- Load the game singleton
    game:load(nil, false) -- isTesting = false
    game:setState("preparing")
    game.time_mul = 1 -- normal speed
    
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
    self.dialogFont = love.graphics.newFont(12)
    
    -- Exit button (top right of screen, out of the way of dialog & HUD)
    self.exitButton = {
        x = VIRTUAL_WIDTH - 110,
        y = 10,
        w = 100,
        h = 30,
        label = "Exit to Menu"
    }
    
    -- Define steps
    self.steps = {
        { id = 1, type = "dialog", text = "Welcome to the Base Defense Tutorial!\n\nHere, you will learn the basic controls and core strategies to defend your core." },
        { id = 2, type = "dialog", text = "Enemies will approach from the right side of the screen.\n\nKeep a close eye on their lanes to plan your defenses.", target = {x = 750, y = 300, angle = 0} },
        { id = 3, type = "dialog", text = "This is your Base. Do not let enemies reach it!\nIf they do, your base health will decrease.", target = {x = 120, y = 300, angle = 0} },
        { id = 4, type = "shoot", text = "You can fire the main laser manually from the base.\n\nLeft-click anywhere on the screen to fire standard laser beams!", target = {x = 50, y = 287, angle = 0} },
        { id = 5, type = "autofire_on", text = "Manual shooting is great, but we can automate it.\n\nPress the TAB key to toggle Auto-Fire on.", target = {x = 660, y = 40, angle = math.pi/2} },
        { id = 5.5, type = "autofire_off", text = "Auto-Fire will target and fire at enemies automatically during waves. Now let's toggle it back off.\n\nPress the TAB key again to turn it off.", target = {x = 660, y = 40, angle = math.pi/2} },
        { id = 6, type = "buy_sentry", text = "Now let's expand our arsenal.\n\nClick the 'Buy Upgrade' button to see card choices.", target = {x = 285, y = 65, angle = math.pi/2} },
        { id = 6.5, type = "select_sentry", text = "We must select the Sentry turret card.\n\nClick on the Sentry (first card) to select it." },
        { id = 7, type = "store_sentry", text = "Instead of placing it immediately, let's store it.\n\nMove the mouse to the bottom bar and click to store it in your inventory.", target = {x = 400, y = 550, angle = -math.pi/2} },
        { id = 8, type = "unlock_slot", text = "Visible locked slots on your base are marked with 'T'.\n\nClick on the slot directly above the main laser to unlock it (costs 1 Token).", target = {x = 55, y = 262.5, angle = 0} }, -- slot 26 (col 2, row 7)
        { id = 8.5, type = "dialog", text = "Awesome! Unlocking slots expands the visible area of your base grid, exposing more neighboring slots." },
        { id = 9, type = "select_inventory", text = "Let's retrieve the Sentry card from the inventory.\n\nClick on the Sentry card in the bottom bar.", target = {x = 400, y = 550, angle = -math.pi/2} },
        { id = 10, type = "place_sentry", text = "Now place the Sentry in the slot you just unlocked.", target = {x = 55, y = 262.5, angle = 0} },
        { id = 10.5, type = "dialog", text = "Tip: If you have enough tokens, you can place cards directly onto unlocked slots on the base without storing them first." },
        { id = 11, type = "aim_sentry", text = "Move your mouse to adjust the Sentry's firing arc direction.\n\nLeft-click to lock its direction and finish placing." },
        { id = 12, type = "hover_sentry", text = "Hover your mouse over the Sentry turret (or hold Space) to check its range and firing arc.", target = {x = 55, y = 262.5, angle = 0} },
        { id = 12.5, type = "dialog", text = "Tip: You can re-aim placed turrets by clicking them between waves, but not while a combat wave is active." },
        { id = 13, type = "start_wave", text = "Let's test your defenses!\n\nPress ENTER to start the training wave." },
        { id = 13.5, type = "combat", text = "Training Wave in progress! Defeat the training targets." },
        { id = 14, type = "dialog", text = "Wave Complete!\n\nYou receive 3 Tokens plus 10% interest on any unspent tokens at the end of each wave." },
        { id = 15, type = "buy_box", text = "Let's buy another upgrade.\n\nClick 'Buy Upgrade'.", target = {x = 285, y = 65, angle = math.pi/2} },
        { id = 15.5, type = "select_box", text = "Choose the 'Small Box' (first card) to buy a blocker." },
        { id = 16, type = "place_box", text = "Place the Small Box on the battlefield (e.g. column 12, row 8).\n\nBlockers force enemies to path around them, buying you time!", target = {x = 287.5, y = 260, angle = -math.pi/2} },
        { id = 17, type = "buy_luck", text = "Now click 'Luck Offering' (costs 1 Token) to increase the chance of getting rarer cards.", target = {x = 285, y = 25, angle = math.pi/2} },
        { id = 17.5, type = "dialog", text = "Tip: Hover over the '?' icon next to 'Buy Upgrade' to view the active card rarity probabilities." },
        { id = 18, type = "buy_cache", text = "Let's grant you 3 extra Tokens! Now buy another upgrade to buff your turrets.\n\nClick 'Buy Upgrade'.", target = {x = 285, y = 65, angle = math.pi/2} },
        { id = 18.5, type = "select_cache", text = "Choose the uncommon 'Ammo Cache' card." },
        { id = 19, type = "place_cache", text = "Place the Ammo Cache adjacent to your Sentry turret.\n\nThe green outlines indicate the slots that receive the damage buff!", target = {x = 80, y = 262.5, angle = 0} }, -- slot 27 (col 3, row 7)
        { id = 19.5, type = "dialog", text = "Nice! Buildings like the Ammo Cache boost the stats of any adjacent turrets. Placing them strategically is key to late-game success." },
        { id = 20, type = "dialog", text = "Excellent! You are now ready for the real invasion.\nAs waves progress, enemies mutate and adapt, requiring constant upgrades.\n\nGood luck, Commander!" }
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
        for _, data in ipairs(choicesData) do
            data.game = game
            table.insert(rewardSys.rewardPool, Reward:new(data))
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
            -- Can store in inventory (bottom area)
            if y >= 500 then
                return true
            end
            return false
            
        elseif step.type == "unlock_slot" then
            -- Unlock slot 26 allowed
            local col = 2
            local row = 7
            local sx = game.base.buildGrid.x + (col - 1) * game.base.buildGrid.cellSize
            local sy = game.base.buildGrid.y + (row - 1) * game.base.buildGrid.cellSize
            if x >= sx and x <= sx + game.base.buildGrid.cellSize and
               y >= sy and y <= sy + game.base.buildGrid.cellSize then
                return true
            end
            return false
            
        elseif step.type == "select_inventory" then
            -- Can select card from inventory (bottom area)
            if y >= 500 then
                return true
            end
            return false
            
        elseif step.type == "place_sentry" then
            -- Place in slot 26 allowed
            local col = 2
            local row = 7
            local sx = game.base.buildGrid.x + (col - 1) * game.base.buildGrid.cellSize
            local sy = game.base.buildGrid.y + (row - 1) * game.base.buildGrid.cellSize
            if x >= sx and x <= sx + game.base.buildGrid.cellSize and
               y >= sy and y <= sy + game.base.buildGrid.cellSize then
                return true
            end
            return false
            
        elseif step.type == "aim_sentry" then
            return true
            
        elseif step.type == "place_box" then
            -- Can place outside the base grid, inside battlefield area (y between 100 and 500)
            local baseGrid = game.base.buildGrid
            local onBase = x >= baseGrid.x and x <= baseGrid.x + baseGrid.width * baseGrid.cellSize and
                           y >= baseGrid.y and y <= baseGrid.y + baseGrid.height * baseGrid.cellSize
            if not onBase and y >= 100 and y <= 500 then
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
            -- Must place on the base grid
            local baseGrid = game.base.buildGrid
            local onBase = x >= baseGrid.x and x <= baseGrid.x + baseGrid.width * baseGrid.cellSize and
                           y >= baseGrid.y and y <= baseGrid.y + baseGrid.height * baseGrid.cellSize
            if onBase then
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
            if AUDIO then AUDIO:playSFX("money_01") end
            self:exitTutorial()
            return
        end
        
        -- Check Dialog click
        if self:isDialogStep() then
            -- Bounding box of the dialog box
            local dy = 440
            local step = self.steps[self.stepIndex]
            if step and step.target and step.target.y > 400 then
                dy = 110
            end
            local dx = 100
            local dw = 600
            local dh = 110
            
            if x >= dx and x <= dx + dw and y >= dy and y <= dy + dh then
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

function tutorial_scene:drawBouncingArrow(tx, ty, angle)
    local t = love.timer.getTime()
    local bounce = math.sin(t * 8) * 8
    
    love.graphics.push()
    love.graphics.translate(tx, ty)
    love.graphics.rotate(angle)
    
    local ox = 25 + bounce
    
    love.graphics.setLineWidth(3)
    love.graphics.setColor(1, 0.2, 0.6, 1) -- magenta
    love.graphics.line(ox, 0, ox + 15, 0)
    love.graphics.line(ox, 0, ox + 6, -6)
    love.graphics.line(ox, 0, ox + 6, 6)
    
    love.graphics.setLineWidth(7)
    love.graphics.setColor(1, 0.2, 0.6, 0.3) -- glow
    love.graphics.line(ox, 0, ox + 15, 0)
    love.graphics.line(ox, 0, ox + 6, -6)
    love.graphics.line(ox, 0, ox + 6, 6)
    
    love.graphics.pop()
    love.graphics.setLineWidth(1)
end

function tutorial_scene:draw()
    game:draw()
    
    local step = self.steps[self.stepIndex]
    if not step then return end
    
    -- Draw bouncing arrow if targeted
    if step.target then
        self:drawBouncingArrow(step.target.x, step.target.y, step.target.angle)
    end
    
    -- Draw dialog box
    local dy = 440
    if step.target and step.target.y > 400 then
        dy = 110
    end
    local dx = 100
    local dw = 600
    local dh = 110
    
    -- Semi-transparent dark background
    love.graphics.setColor(0.08, 0.08, 0.12, 0.95)
    love.graphics.rectangle("fill", dx, dy, dw, dh, 10, 10)
    
    -- Glowing borders
    local pulse = (math.sin(love.timer.getTime() * 4) + 1) / 2
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0, 0.8, 1, 0.5 + pulse * 0.3)
    love.graphics.rectangle("line", dx, dy, dw, dh, 10, 10)
    love.graphics.setLineWidth(1)
    
    -- Title
    love.graphics.setColor(0, 0.8, 1, 1)
    if self.dialogFont then
        love.graphics.setFont(self.dialogFont)
    end
    love.graphics.print("TUTORIAL - STEP " .. self.stepIndex .. " / " .. #self.steps, dx + 20, dy + 12)
    
    -- Instruction text
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.printf(step.text, dx + 20, dy + 32, dw - 40, "left")
    
    -- Prompt helper at bottom right
    love.graphics.setColor(0.6, 0.6, 0.6, 0.8)
    local prompt = ""
    if step.type == "dialog" then
        prompt = "[ Press ENTER or click here to continue ]"
    elseif step.type == "shoot" then
        prompt = "[ Left click to shoot target ]"
    elseif step.type == "autofire_on" then
        prompt = "[ Press TAB to toggle Auto-Fire ON ]"
    elseif step.type == "autofire_off" then
        prompt = "[ Press TAB to toggle Auto-Fire OFF ]"
    elseif step.type == "buy_sentry" or step.type == "buy_box" or step.type == "buy_cache" then
        prompt = "[ Click 'Buy Upgrade' ]"
    elseif step.type == "select_sentry" or step.type == "select_box" or step.type == "select_cache" then
        prompt = "[ Choose the first card ]"
    elseif step.type == "store_sentry" then
        prompt = "[ Click the bottom bar to store card ]"
    elseif step.type == "unlock_slot" then
        prompt = "[ Click slot above main laser to unlock ]"
    elseif step.type == "select_inventory" then
        prompt = "[ Click the Sentry card in inventory ]"
    elseif step.type == "place_sentry" then
        prompt = "[ Click unlocked slot to place Sentry ]"
    elseif step.type == "aim_sentry" then
        prompt = "[ Move mouse to aim, Click to lock ]"
    elseif step.type == "hover_sentry" then
        prompt = "[ Hover over turret or hold Space ]"
    elseif step.type == "start_wave" then
        prompt = "[ Press ENTER to start wave ]"
    elseif step.type == "combat" then
        prompt = "[ Defeat the training targets ]"
    elseif step.type == "place_box" then
        prompt = "[ Place the box on the battlefield ]"
    elseif step.type == "buy_luck" then
        prompt = "[ Click 'Luck Offering' ]"
    elseif step.type == "place_cache" then
        prompt = "[ Place Ammo Cache adjacent to turret ]"
    end
    
    love.graphics.printf(prompt, dx + 20, dy + dh - 20, dw - 40, "right")
    
    -- Exit button
    local eb = self.exitButton
    local mx, my = love.mouse.getPosition()
    local isHovered = mx >= eb.x and mx <= eb.x + eb.w and my >= eb.y and my <= eb.y + eb.h
    
    if isHovered then
        love.graphics.setColor(0.8, 0.2, 0.2, 1)
    else
        love.graphics.setColor(0.5, 0.1, 0.1, 0.9)
    end
    love.graphics.rectangle("fill", eb.x, eb.y, eb.w, eb.h, 6, 6)
    
    love.graphics.setColor(1, 0.5, 0.5, 1)
    love.graphics.rectangle("line", eb.x, eb.y, eb.w, eb.h, 6, 6)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(eb.label, eb.x, eb.y + 7, eb.w, "center")
    
    -- Draw the red mouse cursor on top of the tutorial overlay
    local mx, my = love.mouse.getPosition()
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.circle("fill", mx, my, 3)
    love.graphics.setColor(1, 1, 1, 1)
end

return tutorial_scene
