local push = require("Libraries.push")

local InputHandler = {}
InputHandler.__index = InputHandler

function InputHandler:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    obj.mouseX = 0
    obj.mouseY = 0
    obj.buildMode = false
    obj.selectedBuilding = nil
    obj.hoveredBuilding = nil
    obj.destructionTarget = nil
    obj.confirmRect = nil
    obj.fireDelay = 0
    return obj
end

function InputHandler:update(dt)
    local game = self.game
    
    if self.game.base then
        self.game.base.hoverTooltip = nil
    end

    local mx, my = push:toGame(love.mouse.getPosition())
    if mx and my then
        self.mouseX, self.mouseY = mx, my
    end

    -- Handle space key hold for showing all firing arcs
    local showAllArcs = love.keyboard.isDown("space")
    for _, obj in ipairs(game.objects) do
        if obj:isType("turret") and not obj.destroyed then
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
    if (game:isState("preparing") or game.inputMode == "aiming") and self.selectedBuilding and self.selectedBuilding.firingArc then
        local dx = self.mouseX - self.selectedBuilding.x
        local dy = self.mouseY - self.selectedBuilding.y
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
    if self.hoveredBuilding then
        self.hoveredBuilding.showEffects = false
        self.hoveredBuilding.showArc = false
    end
    self.hoveredBuilding = nil
    
    -- Check for building hover
    for _, obj in ipairs(gameObjects) do
        if (obj:isType("turret") or obj:isType("passive")) and not obj.destroyed then
            if self:isMouseOverBuilding(obj) then
                self.hoveredBuilding = obj
                obj.showEffects = true
                -- Handle turret-specific hover (firing arcs)
                if obj:isType("turret") then
                    obj.showArc = true
                end
                
                -- Handle buff building hover (affected slots)
                if obj:isType("passive") and obj.getAffectedSlotsFromAnchor then
                    base.buffHoverSlots = obj:getAffectedSlotsFromAnchor(obj.slot)
                end
                
                break -- Only hover one building at a time
            else
                -- Clear effects if not hovered and not selected
                if obj ~= self.selectedBuilding and not showAllArcs then
                    if obj:isType("turret") then
                        obj.showArc = false
                        obj.showEffects = false
                    end
                end
            end
        end
    end
end

function InputHandler:handleButtonHold()
    local game = self.game
    local mainTurret = game.mainTurret
    
    -- Prevent firing while interacting with UI, placing buildings, or destroying
    if game.inputMode ~= "idle" then return end
    if self.destructionTarget then return end
    if game.rewardSystem and game.rewardSystem.isActive then return end
    if self.fireDelay > 0 then return end
    
    -- Prevent firing if mouse is over the inventory area (bottom 100 pixels)
    -- local invHeight = 100
    -- if self.mouseY >= love.graphics.getHeight() - invHeight then return end

    if love.mouse.isDown(1) then
        -- Handle left mouse button hold actions here
        mainTurret:PlayerClick(self.mouseX, self.mouseY)
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
    elseif game.blueprint:isType("turret") and hoverBattlefield then
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
                    base.hoverTooltip = {x = self.mouseX + 15, y = self.mouseY + 15, text = "Unlock slot(s) and place building? ($" .. totalCost .. ")", cost = totalCost}
                end
            end
            
            if not isBattlefield and game.blueprint.getAffectedSlotsFromAnchor and #invalidSlots == 0 then
                base.affectedSlots = game.blueprint:getAffectedSlotsFromAnchor(anchorSlot)
            else
                base.affectedSlots = nil
            end
        else
            activeStateBox.selectedSlot = anchorSlot
        end
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
        if not buildGrid.buildings[anchorSlot] and not buildGrid.unlocked[anchorSlot] and base:isSlotVisible(anchorSlot) then
            local cost = base:getSlotPrice(anchorSlot)
            base.hoverTooltip = {x = self.mouseX + 15, y = self.mouseY + 15, text = "Unlock slot? ($" .. cost .. ")", cost = cost}
        end
    end
end

function InputHandler:mousepressed(x, y, button)
    local game = self.game
    
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
    
    local base = game.base
    local mainTurret = game.mainTurret
    
    if button == 2 then
        local clickedTarget = false
        for _, obj in ipairs(game.objects) do
            if (obj:isType("turret") or obj:isType("passive") or obj:isType("blocker")) and not obj:isType("mainTurret") and not obj.destroyed then
                if self:isMouseOverBuilding(obj) then
                    self.destructionTarget = obj
                    clickedTarget = true
                    break
                end
            end
        end
        if not clickedTarget then
            self.destructionTarget = nil
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
    
    -- Handle building placement
    if game.inputMode == "placing" and button == 1 then
        local hoverBattlefield = self:isMouseOverGrid(game.battlefieldGrid)
        local isBlocker = game.blueprint:isType("blocker")
        
        local buildGrid = base.buildGrid
        local isBattlefield = false
        if isBlocker then
            buildGrid = game.battlefieldGrid
            isBattlefield = true
        elseif game.blueprint:isType("turret") and hoverBattlefield then
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
                    if game.money >= totalCost then
                        game.money = game.money - totalCost
                        for _, s in ipairs(slotsToOccupy) do
                            buildGrid.unlocked[s] = true
                        end
                    else
                        print("Cannot place building: Not enough money to unlock slots!")
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
            else
                print("Cannot place building: required slots are occupied or out of bounds!")
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
                if game.money >= cost then
                    game.money = game.money - cost
                    buildGrid.unlocked[anchorSlot] = true
                else
                    print("Not enough money to unlock slot!")
                end
                return -- Stop propagation so we don't select a building or shoot
            end
        end
    end
    
    -- Handle building selection and other mouse interactions
    if button == 1 then -- Left click
        local clickedOnBuilding = false
        
        -- Only allow building selection during preparing phase
        if game:isState("preparing") then
            -- Check if clicking on a building (exclude MainTurret)
            for _, obj in ipairs(game.objects) do
                if (obj:isType("turret") or obj:isType("passive")) and not obj:isType("mainTurret") and not obj.destroyed then
                    if self:isMouseOverBuilding(obj) then
                        self:selectBuilding(obj)
                        clickedOnBuilding = true
                        break
                    end
                end
            end
        end
        
        -- Handle MainTurret clicking (firing only, not selectable)
        for _, obj in ipairs(game.objects) do
            if obj:isType("mainTurret") and not obj.destroyed then
                if self:isMouseOverBuilding(obj) then
                    -- Handle MainTurret firing (only in wave state)
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

function InputHandler:selectBuilding(building)
    -- Clear previous selection
    self:clearSelection()
    
    -- Set new selection
    self.selectedBuilding = building
    building.selected = true
    
    -- Handle building-specific selection behavior
    if building:isType("turret") then
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
        if self.selectedBuilding:isType("turret") then
            self.selectedBuilding.showArc = false
        end
        
        self.selectedBuilding = nil
    end
    
    -- Clear buff hover visualization
    self.game.base.buffHoverSlots = nil
end

function InputHandler:keypressed(key)
    local game = self.game

    if key == "1" then
        game.debugMode = not game.debugMode
    end

    if key == "0" then
        game:toggleDamageNumbers()
    end

    if key == "r" then
        game:attemptPurchaseReward()
    -- elseif key == "a" then
    --     game.autoStartWave = not game.autoStartWave
    end
    
    -- Handle turret target reset
    if key == "space" then
        -- Space key now handled in update() for showing all firing arcs
    elseif key == "return" or key == "enter" then
        -- Start next wave if in preparing state
        if game:isState("startup") then
            game:setState("preparing")
        elseif game:isState("preparing") then
            game:recalculateAllBuffs() -- Recalculate all buffs before wave starts
            game.WaveSpawner:startNextWave()
            game:setState("wave")
        end
    elseif key == "tab" then
        -- Toggle autofire
        if game.mainTurret then
            game.mainTurret.autofire = not game.mainTurret.autofire
        end
    end
    
    -- Handle selection clearing
    if key == "escape" then
        self:clearSelection()
    end
end

return InputHandler