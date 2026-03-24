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
    return obj
end

function InputHandler:update(dt)
    local game = self.game
    
    self.mouseX, self.mouseY = love.mouse.getPosition()
    
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
    
    -- Update selected turret's firing arc direction during preparation phase
    if game:isState("preparing") and self.selectedBuilding and self.selectedBuilding.firingArc then
        local dx = self.mouseX - self.selectedBuilding.x
        local dy = self.mouseY - self.selectedBuilding.y
        local angleToMouse = math.atan2(dy, dx)
        
        -- Normalize angle to [0, 2π]
        if angleToMouse < 0 then
            angleToMouse = angleToMouse + 2 * math.pi
        end
        
        self.selectedBuilding.firingArc.direction = angleToMouse
    end
    
    -- Only handle building slot hover when placing
    if game:isState("placing") then
        self:handleBuildingSlotHover()
    end

    self:handleButtonHold()
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
    local mainTurret = self.game.mainTurret
    -- Placeholder for handling button hold actions if needed
    -- Currently not implemented
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

function InputHandler:handleBuildingSlotHover()
    local base = self.game.base
    local buildGrid = base.buildGrid
    local game = self.game
    
    local gridX = math.floor(self.mouseX / buildGrid.cellSize) + 1
    local gridY = math.floor((self.mouseY - buildGrid.y) / buildGrid.cellSize) + 1
    
    if gridX >= 1 and gridX <= buildGrid.width and
       gridY >= 1 and gridY <= buildGrid.height then
        local anchorSlot = (gridY - 1) * buildGrid.width + gridX
        
        -- If placing, show all slots the building would occupy
        if game:isState("placing") and game.blueprint then
            local slotsToOccupy = game.blueprint:getSlotsFromPattern(anchorSlot)
            local invalidSlots = game.blueprint:getInvalidSlotsFromPattern(anchorSlot, base.buildGrid)
            
            if #invalidSlots > 0 then
                -- Invalid placement - show ALL building slots as red
                base.selectedSlots = nil
                base.invalidSlots = slotsToOccupy -- Show all slots the building would occupy as invalid
            else
                -- Valid placement - show yellow highlights
                base.selectedSlots = slotsToOccupy
                base.invalidSlots = nil
            end
            
            -- If placing a buff building, also show affected slots in green (only if placement is valid)
            if game.blueprint.getAffectedSlotsFromAnchor and #invalidSlots == 0 then
                base.affectedSlots = game.blueprint:getAffectedSlotsFromAnchor(anchorSlot)
            else
                base.affectedSlots = nil
            end
        else
            base.selectedSlot = anchorSlot
            base.selectedSlots = nil
            base.affectedSlots = nil
            base.invalidSlots = nil
        end
    else
        base.selectedSlot = nil
        base.selectedSlots = nil
        base.affectedSlots = nil
        base.invalidSlots = nil
    end
end

function InputHandler:mousepressed(x, y, button)
    local game = self.game
    local rewardSystem = game.rewardSystem
    local base = game.base
    local mainTurret = game.mainTurret
    
    -- Handle reward system input first
    if rewardSystem then
        rewardSystem:mousepressed(x, y, button)
    end
    
    -- Handle building placement
    if game:isState("placing") and button == 1 then
        local buildGrid = base.buildGrid
        local gridX = math.floor(x / buildGrid.cellSize) + 1
        local gridY = math.floor((y - buildGrid.y) / buildGrid.cellSize) + 1
        if gridX >= 1 and gridX <= buildGrid.width and
           gridY >= 1 and gridY <= buildGrid.height then
            local anchorSlot = (gridY - 1) * buildGrid.width + gridX
            
            -- Check if all required slots are available
            local slotsToOccupy = game.blueprint:getSlotsFromPattern(anchorSlot)
            if base:areSlotsAvailable(game.blueprint, slotsToOccupy, anchorSlot) then
                game:newBuilding(game.blueprint, anchorSlot)
                game:setState("preparing")
                game.blueprint = nil
                game:recalculateAllBuffs()
            else
                print("Cannot place building: required slots are occupied or out of bounds!")
            end
        end
        return -- Don't process turret selection during building placement
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
    -- local rewardSystem = game.rewardSystem
    
    -- -- Handle reward system input first
    -- if rewardSystem then
    --     rewardSystem:keypressed(key)
    -- end
    
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
    end
    
    -- Handle selection clearing
    if key == "escape" then
        self:clearSelection()
    end
end

return InputHandler