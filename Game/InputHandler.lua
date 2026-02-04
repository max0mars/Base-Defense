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
    self:handleTurretHover()
    
    -- Only handle building slot hover when placing
    if game:isState("placing") then
        self:handleBuildingSlotHover()
    end
end

function InputHandler:handleTurretHover()
    local gameObjects = self.game.objects
    
    -- Clear previous hover state
    if self.hoveredTurret then
        self.hoveredTurret.showArc = false
        self.hoveredTurret = nil
    end
    
    -- Check for turret hover
    for _, obj in ipairs(gameObjects) do
        if obj.tag == "turret" and not obj.destroyed then
            if self:isMouseOverTurret(obj) then
                obj.showArc = true
                self.hoveredTurret = obj
                break -- Only hover one turret at a time
            else
                obj.showArc = false
            end
        end
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
    
    local gridX = math.floor(self.mouseX / buildGrid.cellSize) + 1
    local gridY = math.floor((self.mouseY - buildGrid.y) / buildGrid.cellSize) + 1
    
    if gridX >= 1 and gridX <= buildGrid.width and
       gridY >= 1 and gridY <= buildGrid.height then
        local slot = (gridY - 1) * buildGrid.width + gridX
        base.selectedSlot = slot
    else
        base.selectedSlot = nil
    end
end

function InputHandler:mousepressed(x, y, button)
    local game = self.game
    local rewardSystem = game.rewardSystem
    local base = game.base
    
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
            local slot = (gridY - 1) * buildGrid.width + gridX
            if not buildGrid.buildings[slot] then
                game:newBuilding(game.blueprint, slot)
                game:setState("wave")
                game.blueprint = nil
            else
                print("Slot " .. slot .. " is already occupied!")
            end
        end
        return -- Don't process turret selection during building placement
    end
    
    -- Handle turret selection and other mouse interactions
    if button == 1 then -- Left click
        -- Check if clicking on a turret
        for _, obj in ipairs(game.objects) do
            if obj.tag == "turret" and not obj.destroyed then
                if self:isMouseOverTurret(obj) then
                    self:selectTurret(obj)
                    return
                end
            end
        end
        
        -- If not clicking on turret, clear selection
        self:clearSelection()
    end
end

function InputHandler:selectTurret(turret)
    -- Clear previous selection
    if self.selectedTurret then
        self.selectedTurret.selected = false
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
    local rewardSystem = game.rewardSystem
    
    -- Handle reward system input first
    if rewardSystem then
        rewardSystem:keypressed(key)
    end
    
    -- Handle turret target reset
    if key == "space" then
        for _, obj in ipairs(game.objects) do
            if obj.tag == "turret" then
                obj.target = nil -- Reset turret targets on space press
            end
        end
    end
    
    -- Handle selection clearing
    if key == "escape" then
        self:clearSelection()
    end
end

return InputHandler