local Layout = require("Game.GUI.Layout")

local InputHandler = {}
InputHandler.__index = InputHandler

function InputHandler:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    obj.mouseX = 0
    obj.mouseY = 0
    obj.buildMode = false
    obj.selectedBuilding = nil
    obj.selectedEnemy = nil
    obj.hoveredBuilding = nil
    obj.destructionTarget = nil
    obj.confirmRect = nil
    obj.fireDelay = 0
    obj.isMouseDown = false
    return obj
end

function InputHandler:update(dt)
    local game = self.game
    
    if self.game.base then
        self.game.base.hoverTooltip = nil
        self.game.base.hoveredLockedSlot = nil
        self.game.base.hoveredEmptySlot = nil
    end

    -- Raw (full-canvas) cursor, used for screen-space tooltips and HUD checks.
    self.screenMouseX, self.screenMouseY = love.mouse.getPosition()
    -- Field-local cursor, used for all world/grid interactions.
    self.mouseX, self.mouseY = Layout.mouseToField(self.screenMouseX, self.screenMouseY)


    
    -- Handle space key hold for showing all firing arcs
    local showAllArcs = love.keyboard.isDown("space")
    for _, obj in ipairs(game.objects) do
        if (obj:isType("turret") or (obj:isType("blocker") and obj.range)) and not obj.destroyed then
            if showAllArcs then
                obj.showArc = true
            else
                -- Only keep selected building's arc visible when space not held
                obj.showArc = (obj == self.selectedBuilding)
            end
        end
    end
    
    self:handleBuildingHover()
    
    -- Update selected turret's firing arc direction during preparation phase or when aiming after placement
    if (game:isState("startup") or game:isState("preparing") or game.inputMode == "aiming") and self.selectedBuilding and self.selectedBuilding.firingArc then
        local cx, cy = self.selectedBuilding:getCenterPosition()
        local dx = self.mouseX - cx
        local dy = self.mouseY - cy
        local angleToMouse = math.atan2(dy, dx)
        
        -- Normalize angle to [0, 2π]
        if angleToMouse < 0 then
            angleToMouse = angleToMouse + 2 * math.pi
        end
        
        self.selectedBuilding.firingArc.direction = angleToMouse
    end
    
    if game.inventory.hoveredCardIndex then
        local base = game.base
        base.selectedSlots = nil
        base.invalidSlots = nil
        base.affectedSlots = nil
        base.selectedSlot = nil
    else
        -- Only handle building slot hover when placing
        if game.inputMode == "placing" then
            self:handleBuildingSlotHover()
        elseif game.inputMode == "idle" and not self.destructionTarget then
            self:handleLockedSlotHover()
        end
    end

    self:handleButtonHold()
    
    if self.fireDelay > 0 then
        self.fireDelay = self.fireDelay - dt
    end
end

function InputHandler:handleBuildingHover()
    local gameObjects = self.game.objects
    local showAllArcs = love.keyboard.isDown("space")
    local base = self.game.base
    
    base.buffHoverSlots = nil
    
    -- Find the best hovered building (Prioritize Turrets/Passives over Blockers)
    local bestHover = nil
    for _, obj in ipairs(gameObjects) do
        if (obj:isType("turret") or obj:isType("passive") or obj:isType("blocker")) and not obj.destroyed then
            if self:isMouseOverBuilding(obj) then
                bestHover = obj
                -- If we found a turret or passive, it takes absolute priority
                if obj:isType("turret") or obj:isType("passive") then
                    break
                end
            end
        end
    end

    -- Update hovered building state
    if self.hoveredBuilding and self.hoveredBuilding ~= bestHover then
        self.hoveredBuilding.showEffects = false
    end
    self.hoveredBuilding = bestHover
    
    if bestHover then
        bestHover.showEffects = true
        -- Handle turret-specific hover (firing arcs)
        if bestHover:isType("turret") or (bestHover:isType("blocker") and bestHover.range) then
            bestHover.showArc = true
        end
        
        -- Handle buff building hover (affected slots)
        if bestHover:isType("passive") and bestHover.getAffectedSlotsFromAnchor then
            base.buffHoverSlots = bestHover:getAffectedSlotsFromAnchor(bestHover.slot)
        end
    end

    -- Cleanup arcs for all non-hovered/non-selected buildings
    for _, obj in ipairs(gameObjects) do
        if (obj:isType("turret") or obj:isType("passive") or obj:isType("blocker")) and not obj.destroyed then
            if obj ~= self.hoveredBuilding and obj ~= self.selectedBuilding and not showAllArcs then
                if obj:isType("turret") or (obj:isType("blocker") and obj.range) then
                    obj.showArc = false
                    obj.showEffects = false
                end
            end
        end
    end
end

function InputHandler:handleButtonHold()
    local game = self.game
    local mainLazer = game.mainLazer
    
    -- Prevent firing while interacting with UI, placing buildings, or destroying
    if game.inputMode ~= "idle" then return end
    if self.destructionTarget then return end
    if game.rewardSystem and game.rewardSystem.isActive then return end
    if self.fireDelay > 0 then return end

    -- Only fire when the cursor is over the battlefield (not the surrounding HUD).
    if not Layout.inFieldScreen(self.screenMouseX, self.screenMouseY) then return end

    if self.isMouseDown then
        -- Handle left mouse button hold actions here
        mainLazer:PlayerClick(self.mouseX, self.mouseY)
    end
end

function InputHandler:isMouseOverBuilding(building)
    if not building.slot then return false end -- Building not placed yet
    
    -- Get all slots occupied by the building
    local occupiedSlots = building:getSlotsFromPattern(building.slot)
    local buildGrid = building.buildGrid
    
    -- Check if mouse is over any occupied slot
    for _, slot in ipairs(occupiedSlots) do
        local i = ((slot - 1) % buildGrid.width) + 1
        local j = math.ceil(slot / buildGrid.width)
        local slotX = buildGrid.x + (i - 1) * buildGrid.cellSize
        local slotY = buildGrid.y + (j - 1) * buildGrid.cellSize
        
        -- Check if mouse is within this slot
        if self.mouseX >= slotX and self.mouseX <= slotX + buildGrid.cellSize and
           self.mouseY >= slotY and self.mouseY <= slotY + buildGrid.cellSize then
            return true
        end
    end
    
    return false
end

function InputHandler:isMouseOverGrid(grid)
    if not grid then return false end
    return self.mouseX >= grid.x and self.mouseX < grid.x + grid.width * grid.cellSize and
           self.mouseY >= grid.y and self.mouseY < grid.y + grid.height * grid.cellSize
end

function InputHandler:handleBuildingSlotHover()
    local game = self.game
    local base = game.base
    
    if not game.blueprint then return end
    
    local hoverBattlefield = self:isMouseOverGrid(game.battlefieldGrid)
    local isBlocker = game.blueprint:isType("blocker")
    
    -- Pick the grid: Blockers always use battlefield. Turrets use battlefield ONLY if hovering over it.
    local buildGrid = base.buildGrid -- Default
    local isBattlefield = false

    if isBlocker then
        buildGrid = game.battlefieldGrid
        isBattlefield = true
    elseif (game.blueprint:isType("turret") or game.blueprint:isType("passive")) and hoverBattlefield then
        -- Only use battlefield if NOT hovering over the base grid (prioritize base)
        if not self:isMouseOverGrid(base.buildGrid) then
            buildGrid = game.battlefieldGrid
            isBattlefield = true
        end
    end
    
    game.blueprint.buildGrid = buildGrid
    
    local gridX = math.floor((self.mouseX - buildGrid.x) / buildGrid.cellSize) + 1
    local gridY = math.floor((self.mouseY - buildGrid.y) / buildGrid.cellSize) + 1
    
    base.selectedSlot = nil
    base.selectedSlots = nil
    base.invalidSlots = nil
    base.affectedSlots = nil
    if game.battlefieldGrid then
        game.battlefieldGrid.selectedSlot = nil
        game.battlefieldGrid.selectedSlots = nil
        game.battlefieldGrid.invalidSlots = nil
    end

    local activeStateBox = isBattlefield and game.battlefieldGrid or base

    if gridX >= 1 and gridX <= buildGrid.width and
       gridY >= 1 and gridY <= buildGrid.height then
        local anchorSlot = (gridY - 1) * buildGrid.width + gridX
        
        if game.inputMode == "placing" then
            local invalidSlots = {} -- Defined early to avoid nil errors later
            local slotsToOccupy = game.blueprint:getSlotsFromPattern(anchorSlot)
            
            -- Validation: Use the grid's own logic to check for obstacles/locking
            if not activeStateBox:areSlotsAvailable(game.blueprint, slotsToOccupy, anchorSlot) then
                invalidSlots = slotsToOccupy
            end
            
            if #invalidSlots > 0 then
                activeStateBox.selectedSlots = nil
                activeStateBox.invalidSlots = slotsToOccupy
            else
                activeStateBox.selectedSlots = slotsToOccupy
                activeStateBox.invalidSlots = nil
                
                local totalCost = 0
                for _, s in ipairs(slotsToOccupy) do
                    if not buildGrid.unlocked[s] and not isBattlefield then
                        totalCost = totalCost + base:getSlotPrice(s)
                    end
                end
                
                if totalCost > 0 then
                    local unit = (totalCost == 1) and " Token)" or " Tokens)"
                    base.hoverTooltip = {x = self.screenMouseX + 15, y = self.screenMouseY + 15, text = "Unlock slot(s) and place building? (" .. totalCost .. unit, cost = totalCost}
                end
            end
            
            if not isBattlefield and game.blueprint.getAffectedSlotsFromAnchor and #invalidSlots == 0 then
                base.affectedSlots = game.blueprint:getAffectedSlotsFromAnchor(anchorSlot)
            else
                base.affectedSlots = nil
            end

            -- GRID SNAPPING: Calculate center of the anchor slot for the preview
            self.snappedX = buildGrid.x + (gridX - 1) * buildGrid.cellSize + buildGrid.cellSize / 2
            self.snappedY = buildGrid.y + (gridY - 1) * buildGrid.cellSize + buildGrid.cellSize / 2
        else
            activeStateBox.selectedSlot = anchorSlot
            self.snappedX = nil
            self.snappedY = nil
        end
    else
        self.snappedX = nil
        self.snappedY = nil
    end
end

function InputHandler:handleLockedSlotHover()
    local base = self.game.base
    local buildGrid = base.buildGrid
    
    local gridX = math.floor(self.mouseX / buildGrid.cellSize) + 1
    local gridY = math.floor((self.mouseY - buildGrid.y) / buildGrid.cellSize) + 1
    
    if gridX >= 1 and gridX <= buildGrid.width and
       gridY >= 1 and gridY <= buildGrid.height then
        local anchorSlot = (gridY - 1) * buildGrid.width + gridX
        -- Expansion Logic: Only allow interaction if visible
        if not buildGrid.buildings[anchorSlot] and base:isSlotVisible(anchorSlot) then
            if not buildGrid.unlocked[anchorSlot] then
                local cost = base:getSlotPrice(anchorSlot)
                local unit = (cost == 1) and " Token)" or " Tokens)"
                base.hoverTooltip = {x = self.screenMouseX + 15, y = self.screenMouseY + 15, text = "Unlock slot? (" .. cost .. unit, cost = cost}
                base.hoveredLockedSlot = {slot = anchorSlot, price = cost}
            else
                base.hoveredEmptySlot = anchorSlot
            end
        end
    end
end

function InputHandler:mousepressed(x, y, button)
    local game = self.game
    if button == 1 then self.isMouseDown = true end
    
    if game:isState("mulligan") then
        game:handleMulliganClick(x, y, button)
        return
    end

    -- Check GUI consumption first
    if game.gui:mousepressed(x, y, button) then
        return
    end
    
    -- Reward system check (if not consumed by GUIManager)
    if game.rewardSystem and game.rewardSystem.isActive then
        game.rewardSystem:mousepressed(x, y, button)
        return
    end
    
    if game.specialUpgradeManager and game.specialUpgradeManager.isActive then
        game.specialUpgradeManager:mousepressed(x, y, button)
        return
    end

    -- Everything below operates in WORLD space (grids, turrets). Convert the
    -- click to field-local coords; clicks outside the field fail grid bounds.
    x, y = Layout.mouseToField(x, y)

    local base = game.base
    local mainLazer = game.mainLazer
    
    if button == 2 then
        if game.inputMode == "placing" or game.inputMode == "targeting_card" or game.inputMode == "targeting_global" or game.inputMode == "targeting_spell" then
            if game.activeCard then
                game:refundCard(game.activeCard)
            end
            if game.blueprint then
                game.blueprint = nil
            end
            game.inputMode = "idle"
            return
        end

        local bestTarget = nil
        for _, obj in ipairs(game.objects) do
            if (obj:isType("turret") or obj:isType("passive") or obj:isType("blocker")) and not obj:isType("mainturret") and not obj.destroyed then
                if self:isMouseOverBuilding(obj) then
                    bestTarget = obj
                    if obj:isType("turret") or obj:isType("passive") then
                        break
                    end
                end
            end
        end
        -- Right-click picks the building up and returns it to the deck.
        if bestTarget then
            game:pickUpBuilding(bestTarget)
        end
        return
    end

    -- Destruction handled by GUI, but we can still cancel here if needed
    if self.destructionTarget and button == 1 then
        self.destructionTarget = nil
    end
    
    -- Handle aiming after placement
    if game.inputMode == "aiming" and button == 1 then
        game.inputMode = "idle"
        self.fireDelay = 0.15 -- Small delay to prevent accidental firing
        self:clearSelection()
        return
    end
    
    -- Handle global targeting execution
    if game.inputMode == "targeting_global" and button == 1 then
        local hoverBattlefield = self:isMouseOverGrid(game.battlefieldGrid)
        local hoverBase = self:isMouseOverGrid(game.base.buildGrid)
        
        if hoverBattlefield or hoverBase then
            local card = game.activeCard
            if card then
                if type(card.execute) == "function" then
                    local success = card:execute(game)
                    if success ~= false then
                        game:consumeCard(card)
                    else
                        game:refundCard(card)
                    end
                else
                    game:refundCard(card)
                end
            end
        else
            if game.activeCard then
                game:refundCard(game.activeCard)
            end
        end
        game.inputMode = "idle"
        return
    end

    -- Handle spell targeting execution
    if game.inputMode == "targeting_spell" and button == 1 then
        local mx, my = love.mouse.getPosition()
        if Layout.inFieldScreen(mx, my) then
            local card = game.activeCard
            if card then
                local success = card:execute(x, y, game)
                if success then
                    game:consumeCard(card)
                else
                    game:spawnFloatingText("Invalid target!", mx, my, {0.8, 0.2, 0.2, 1})
                    game:refundCard(card)
                end
            end
        else
            if game.activeCard then
                game:refundCard(game.activeCard)
            end
        end
        game.inputMode = "idle"
        return
    end

    -- Handle targeting execution
    if game.inputMode == "targeting_card" and button == 1 then
        local clickedTarget = nil
        for _, obj in ipairs(game.objects) do
            if (obj:isType("turret") or obj:isType("passive") or obj:isType("blocker")) and not obj.destroyed then
                if self:isMouseOverBuilding(obj) then
                    clickedTarget = obj
                    if obj:isType("turret") or obj:isType("passive") then
                        break
                    end
                end
            end
        end
        
        if clickedTarget then
            local card = game.activeCard
            if card then
                if card.payload then
                    if card.payload.isMainUpgrade then
                        if clickedTarget:isType("mainturret") then
                            clickedTarget:applyUpgrade({ id = card.id, name = card.name })
                            game:consumeCard(card)
                        else
                            game:spawnFloatingText("Must be used on Main Turret!", x, y, {0.8, 0.2, 0.2, 1})
                            game:refundCard(card)
                        end
                    elseif card.payload.effect then
                        if card.payload.requiredType and not clickedTarget:isType(card.payload.requiredType) then
                            game:spawnFloatingText("Must be used on " .. card.payload.requiredType, x, y, {0.8, 0.2, 0.2, 1})
                            game:refundCard(card)
                        elseif clickedTarget.effectManager then
                            clickedTarget.effectManager:applyEffect(card.payload.effect)
                            game:consumeCard(card)
                        else
                            game:spawnFloatingText("Invalid target!", x, y, {0.8, 0.2, 0.2, 1})
                            game:refundCard(card)
                        end
                    else
                        game:refundCard(card)
                    end
                elseif type(card.execute) == "function" then
                    -- This is likely an Instant card
                    local success = card:execute(clickedTarget)
                    if success then
                        game:consumeCard(card)
                    else
                        game:spawnFloatingText("Invalid target!", x, y, {0.8, 0.2, 0.2, 1})
                        game:refundCard(card)
                    end
                else
                    game:refundCard(card)
                end
            end
        else
            if game.activeCard then
                game:refundCard(game.activeCard)
            end
        end
        return
    end
    
    -- Handle building placement
    if game.inputMode == "placing" and button == 1 then
        local hoverBattlefield = self:isMouseOverGrid(game.battlefieldGrid)
        local isBlocker = game.blueprint:isType("blocker")
        
        local buildGrid = base.buildGrid
        local isBattlefield = false
        if isBlocker then
            buildGrid = game.battlefieldGrid
            isBattlefield = true
        elseif (game.blueprint:isType("turret") or game.blueprint:isType("passive")) and hoverBattlefield then
            if not self:isMouseOverGrid(base.buildGrid) then
                buildGrid = game.battlefieldGrid
                isBattlefield = true
            end
        end
        local activeStateBox = isBattlefield and game.battlefieldGrid or base

        local gridX = math.floor((x - buildGrid.x) / buildGrid.cellSize) + 1
        local gridY = math.floor((y - buildGrid.y) / buildGrid.cellSize) + 1
        if gridX >= 1 and gridX <= buildGrid.width and
           gridY >= 1 and gridY <= buildGrid.height then
            local anchorSlot = (gridY - 1) * buildGrid.width + gridX
            
            -- Check if all required slots are available
            local slotsToOccupy = game.blueprint:getSlotsFromPattern(anchorSlot)
            if activeStateBox:areSlotsAvailable(game.blueprint, slotsToOccupy, anchorSlot) then
            
                local totalCost = 0
                for _, s in ipairs(slotsToOccupy) do
                    if not buildGrid.unlocked[s] and not isBattlefield then
                        totalCost = totalCost + base:getSlotPrice(s)
                    end
                end
                
                if totalCost > 0 then
                    if game.tokens >= totalCost then
                        game.tokens = game.tokens - totalCost
        if game.tokens < 0 then game.tokens = 0 end
                        for _, s in ipairs(slotsToOccupy) do
                            buildGrid.unlocked[s] = true
                        end
                    else
                        print("Cannot place building: Not enough tokens to unlock slots!")
                        return
                    end
                end
            
                local placedBuilding = game.blueprint
                placedBuilding.buildGrid = buildGrid
                if isBattlefield then
                    placedBuilding.slot = anchorSlot
                    placedBuilding.slotsOccupied = placedBuilding:getSlotsFromPattern(anchorSlot)
                    placedBuilding.x, placedBuilding.y = placedBuilding:getX() + buildGrid.cellSize/2, placedBuilding:getY() + buildGrid.cellSize/2
                    game.battlefieldGrid:addBuilding(placedBuilding, anchorSlot)
                    game:addObject(placedBuilding)
                else
                    game:newBuilding(placedBuilding, anchorSlot)
                end
                
                if placedBuilding:isType("turret") then
                    game.inputMode = "aiming"
                    self:selectBuilding(placedBuilding)
                else
                    game.inputMode = "idle"
                end
                
                game.blueprint = nil
                game:recalculateAllBuffs()
                if game.activeCard then
                    game:consumeCard(game.activeCard)
                end
            else
                print("Cannot place building: required slots are occupied or out of bounds!")
                if game.activeCard then
                    game:refundCard(game.activeCard)
                    game.blueprint = nil
                end
            end
        end
        return -- Don't process turret selection during building placement
    end
    
    -- Handle single slot unlocking
    if (game.inputMode == "idle" or game:isState("preparing")) and button == 1 then
        local buildGrid = base.buildGrid
        local gridX = math.floor(x / buildGrid.cellSize) + 1
        local gridY = math.floor((y - buildGrid.y) / buildGrid.cellSize) + 1
        if gridX >= 1 and gridX <= buildGrid.width and gridY >= 1 and gridY <= buildGrid.height then
            local anchorSlot = (gridY - 1) * buildGrid.width + gridX
            -- Expansion Logic: Only allow click-to-unlock if visible
            if not buildGrid.buildings[anchorSlot] and not buildGrid.unlocked[anchorSlot] and base:isSlotVisible(anchorSlot) then
                local cost = base:getSlotPrice(anchorSlot)
                if game.tokens >= cost then
                    game.tokens = game.tokens - cost
        if game.tokens < 0 then game.tokens = 0 end
                    buildGrid.unlocked[anchorSlot] = true
                else
                    print("Not enough tokens to unlock slot!")
                end
                return -- Stop propagation so we don't select a building or shoot
            end
        end
    end
    
    -- Handle building selection and other mouse interactions
    if button == 1 then -- Left click
        local clickedOnBuilding = false
        
        -- Click a placed building to focus it (shows in the INSPECT pane and stays
        -- focused); clicking empty field clears the focus. Works in any state.
        local selected = nil
        for _, obj in ipairs(game.objects) do
            if (obj:isType("turret") or obj:isType("passive") or obj:isType("blocker")) and not obj.destroyed then
                if self:isMouseOverBuilding(obj) then
                    selected = obj
                    if obj:isType("turret") or obj:isType("passive") then
                        break
                    end
                end
            end
        end

        if selected then
            self:selectBuilding(selected)
            clickedOnBuilding = true
        else
            -- No building under the cursor: focus a hovered enemy instead, so it
            -- stays highlighted and pinned in the INSPECT pane.
            local he = game.gui and game.gui.tooltips and game.gui.tooltips.hoveredEnemy
            if he and not he.destroyed then
                self:clearSelection()
                self.selectedEnemy = he
                clickedOnBuilding = true
            end
        end
        
        -- Handle MainLazer clicking (firing only, not selectable)
        for _, obj in ipairs(game.objects) do
            if obj:isType("mainturret") and not obj.destroyed then
                if self:isMouseOverBuilding(obj) then
                    -- Handle MainLazer firing (only in wave state)
                    obj:PlayerClick(x, y)
                    clickedOnBuilding = true
                    break
                end
            end
        end
        
        -- If not clicking on building, clear selection
        if not clickedOnBuilding then
            self:clearSelection()
        end
    end
end

function InputHandler:mousereleased(x, y, button)
    if button == 1 then self.isMouseDown = false end
end

function InputHandler:selectBuilding(building)
    -- Clear previous selection
    self:clearSelection()
    
    -- Set new selection
    self.selectedBuilding = building
    building.selected = true
    
    -- Handle building-specific selection behavior
    if building:isType("turret") or (building:isType("blocker") and building.range) then
        building.showArc = true
    elseif building:isType("passive") and building.getAffectedSlotsFromAnchor then
        -- Show affected slots for buff buildings
        self.game.base.buffHoverSlots = building:getAffectedSlotsFromAnchor(building.slot)
    end
end

function InputHandler:clearSelection()
    if self.selectedBuilding then
        self.selectedBuilding.selected = false
        
        -- Handle building-specific clearing
        if self.selectedBuilding:isType("turret") or (self.selectedBuilding:isType("blocker") and self.selectedBuilding.range) then
            self.selectedBuilding.showArc = false
        end
        
        self.selectedBuilding = nil
    end

    self.selectedEnemy = nil

    -- Clear buff hover visualization
    self.game.base.buffHoverSlots = nil
end

function InputHandler:keypressed(key)
    local game = self.game

    if game:isState("mulligan") then
        if key == "return" or key == "enter" then
            game:setState("startup")
        end
        return
    end

    if key == "1" then
        game.debugMode = not game.debugMode
    end

    if key == "0" then
        game:toggleDamageNumbers()
    end

    -- elseif key == "a" then
    --     game.autoStartWave = not game.autoStartWave

    if game.testingMode then
        if key == "u" then
            game.baseInvincible = not game.baseInvincible
            return
        end
        if key == "e" then
            if game.gui.enemySpawner then
                game.gui.enemySpawner.isActive = not game.gui.enemySpawner.isActive
            end
            return
        end
        if key == "g" then
            if game.gui.itemPicker then
                game.gui.itemPicker.isActive = not game.gui.itemPicker.isActive
            end
            return
        end
        if game.gui.enemySpawner and game.gui.enemySpawner.isActive and (key == "return" or key == "enter") then
            local total = 0
            local customWaveList = {}
            for eName, count in pairs(game.gui.enemySpawner.spawnCounts) do
                total = total + count
                if count > 0 then
                    local eClass = require("Enemies." .. eName)
                    for i = 1, count do
                        table.insert(customWaveList, eClass)
                    end
                end
            end
            
            if total > 0 then
                game.WaveSpawner:startCustomWave(customWaveList)
                game:setState("wave")
            end
            game.gui.enemySpawner.isActive = false
            return
        end
    end
    
    -- Handle turret target reset
    if key == "space" then
        -- Space key now handled in update() for showing all firing arcs
    elseif key == "return" or key == "enter" then
        -- Start the wave directly from either the initial startup screen or the
        -- between-wave preparing screen (both show the same single prompt).
        if game:isState("startup") or game:isState("preparing") then
            game:recalculateAllBuffs() -- Recalculate all buffs before wave starts
            game.WaveSpawner:startNextWave()
            game:setState("wave")
        end
    elseif key == "tab" then
        -- Toggle autofire
        if game.mainLazer then
            game.mainLazer.autofire = not game.mainLazer.autofire
        end
    elseif key == "h" then
        if game.gui and game.gui.hand then
            game.gui.hand.isHidden = not game.gui.hand.isHidden
        end
    end
    
    -- Handle selection clearing
    if key == "escape" then
        self:clearSelection()
    end
end

return InputHandler
