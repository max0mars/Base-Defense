local InputHandler = {}
InputHandler.__index = InputHandler

function InputHandler:new(game)
    local obj = setmetatable({}, self)
    obj.game = game
    obj.mouseX = 0
    obj.mouseY = 0
    obj.buildMode = false
    obj.selectedTurret = nil
    obj.hoveredTurret = nil
    return obj
end

function InputHandler:update(dt)
    local game = self.game
    
    self.mouseX, self.mouseY = love.mouse.getPosition()
    
    -- Handle space key hold for showing all firing arcs
    local showAllArcs = love.keyboard.isDown("space")
    for _, obj in ipairs(game.objects) do
        if obj.tag == "turret" and not obj.destroyed then
            if showAllArcs then
                obj.showArc = true
            elseif obj ~= self.selectedTurret and obj ~= self.hoveredTurret then
                obj.showArc = false
            end
        end
    end
    
    self:handleTurretHover()
    
    -- Update selected turret's firing arc direction during preparation phase
    if game:isState("preparing") and self.selectedTurret then
        local dx = self.mouseX - self.selectedTurret.x
        local dy = self.mouseY - self.selectedTurret.y
        local angleToMouse = math.atan2(dy, dx)
        
        -- Normalize angle to [0, 2π]
        if angleToMouse < 0 then
            angleToMouse = angleToMouse + 2 * math.pi
        end
        
        self.selectedTurret.firingArc.direction = angleToMouse
    end
    
    -- Only handle building slot hover when placing
    if game:isState("placing") then
        self:handleBuildingSlotHover()
    end

    self:handleButtonHold()
end

function InputHandler:handleTurretHover()
    local gameObjects = self.game.objects
    local showAllArcs = love.keyboard.isDown("space")
    
    -- Clear previous hover state (but preserve selected turret arc and space override)
    if self.hoveredTurret and self.hoveredTurret ~= self.selectedTurret and not showAllArcs then
        self.hoveredTurret.showArc = false
    end
    self.hoveredTurret = nil
    
    -- Check for turret hover (exclude MainTurret from firing arcs)
    for _, obj in ipairs(gameObjects) do
        if (obj.tag == "turret") and not obj.destroyed then
            if self:isMouseOverTurret(obj) then
                obj.showArc = true
                self.hoveredTurret = obj
                break -- Only hover one turret at a time
            else
                -- Only clear showArc if this turret is not selected and space is not held
                if obj ~= self.selectedTurret and not showAllArcs then
                    obj.showArc = false
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

function InputHandler:isMouseOverTurret(turret)
    local dx = self.mouseX - turret.x
    local dy = self.mouseY - turret.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Slightly larger radius than visual turret for easier hovering
    local hoverRadius = 12
    return distance <= hoverRadius
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
            base.selectedSlots = slotsToOccupy
        else
            base.selectedSlot = anchorSlot
            base.selectedSlots = nil
        end
    else
        base.selectedSlot = nil
        base.selectedSlots = nil
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
            if base:areSlotsAvailable(slotsToOccupy, anchorSlot) then
                game:newBuilding(game.blueprint, anchorSlot)
                game:setState("preparing")
                game.blueprint = nil
            else
                print("Cannot place building: required slots are occupied or out of bounds!")
            end
        end
        return -- Don't process turret selection during building placement
    end
    
    -- Handle turret selection and other mouse interactions
    if button == 1 then -- Left click
        local clickedOnTurret = false
        
        -- Only allow turret selection during preparing phase
        if game:isState("preparing") then
            -- Check if clicking on a turret (exclude MainTurret)
            for _, obj in ipairs(game.objects) do
                if obj.tag == "turret" and obj.tag ~= "mainTurret" and not obj.destroyed then
                    if self:isMouseOverTurret(obj) then
                        self:selectTurret(obj)
                        clickedOnTurret = true
                        break
                    end
                end
            end
        end
        
        -- Handle MainTurret clicking (firing only, not selectable)
        for _, obj in ipairs(game.objects) do
            if obj.tag == "mainTurret" and not obj.destroyed then
                if self:isMouseOverTurret(obj) then
                    -- Handle MainTurret firing (only in wave state)
                    obj:PlayerClick(x, y)
                    clickedOnTurret = true
                    break
                end
            end
        end
        
        -- If not clicking on turret, clear selection
        if not clickedOnTurret then
            self:clearSelection()
        end
    end
end

function InputHandler:selectTurret(turret)
    -- Clear previous selection
    if self.selectedTurret then
        self.selectedTurret.selected = false
        self.selectedTurret.showArc = false
    end
    
    -- Set new selection
    self.selectedTurret = turret
    turret.selected = true
    turret.showArc = true
end

function InputHandler:clearSelection()
    if self.selectedTurret then
        self.selectedTurret.selected = false
        self.selectedTurret.showArc = false
        self.selectedTurret = nil
    end
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