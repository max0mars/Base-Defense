local obj = require("Classes.object")

local building = {}
building.__index = building

function building:new(config)
    if(config.type ~= "unit" and config.type ~= "turret" and config.type ~= "passive") then
        error("Type must be either 'unit', 'turret', or 'passive'")
    end
    if(config.type == "passive") then
        if(not config.passiveShape) then
            error("Passive shape is required for passive buildings")
        end
        b.passiveShape = config.passiveShape
    end
    if(not config.game) then
        error("Game reference is required")
    end
    local b = setmetatable(obj:new(config), {__index = self})
    b.type = config.type
    
    -- shapePattern is now required - defines building shape as {x,y} coordinate offsets
    if not config.shapePattern then
        error("shapePattern is required for all buildings. Define as array of {x,y} coordinates with {0,0} as anchor.")
    end
    b.shapePattern = config.shapePattern
    
    b.buildGrid = config.game.base.buildGrid
    return b
end

function building:getSlotsFromPattern(anchorSlot)
    -- Convert shapePattern coordinates to actual slot numbers relative to anchorSlot
    local slots = {}
    local gridWidth = self.buildGrid.width
    
    -- Calculate anchor position in grid coordinates
    local anchorX = ((anchorSlot - 1) % gridWidth)
    local anchorY = math.floor((anchorSlot - 1) / gridWidth)
    
    for _, coord in ipairs(self.shapePattern) do
        local offsetX, offsetY = coord[1], coord[2]
        local actualX = anchorX + offsetX
        local actualY = anchorY + offsetY
        
        -- Check bounds
        if actualX >= 0 and actualX < gridWidth and actualY >= 0 and actualY < self.buildGrid.height then
            local slot = actualY * gridWidth + actualX + 1
            table.insert(slots, slot)
        end
    end
    
    return slots
end

function building:generateSlotsFromPattern()
    -- Legacy method for compatibility - uses current slotsOccupied if available
    return self.slotsOccupied or {1}
end

function building:getAnchorSlot()
    -- Find the {0,0} coordinate in shapePattern as the anchor
    for _, coord in ipairs(self.shapePattern) do
        if coord[1] == 0 and coord[2] == 0 then
            return self.slot -- The anchor slot where building was placed
        end
    end
    error("Building shapePattern must contain {0, 0} coordinate as anchor point")
end

function building:getXY()
    local anchorSlot = self:getAnchorSlot()
    local x = ((anchorSlot - 1) % self.buildGrid.width) * self.buildGrid.cellSize + self.buildGrid.x
    local y = math.ceil(anchorSlot / self.buildGrid.width - 1) * self.buildGrid.cellSize + self.buildGrid.y
    return x, y
end

function building:getX()
    local anchorSlot = self:getAnchorSlot()
    local x = ((anchorSlot - 1) % self.buildGrid.width) * self.buildGrid.cellSize + self.buildGrid.x
    return x
end

function building:getY()
    local anchorSlot = self:getAnchorSlot()
    local y = (math.ceil(anchorSlot / self.buildGrid.width) - 1) * self.buildGrid.cellSize + self.buildGrid.y
    return y
end

function building:occupiesSlot(slot)
    if not self.slot then return false end
    local slots = self:getSlotsFromPattern(self.slot)
    for _, occupiedSlot in ipairs(slots) do
        if occupiedSlot == slot then
            return true
        end
    end
    return false
end

function building:getType()
    return self.type
end

function building:getAdjacent()    
    local adjacent = {}
    if self.slot > self.buildGrid.width then
        table.insert(adjacent, self.buildGrid.buildings[self.slot - self.buildGrid.width])-- building above
    end
    if self.slot <= self.buildGrid.width * (self.buildGrid.height - 1) then
        table.insert(adjacent, self.buildGrid.buildings[self.slot + self.buildGrid.width])-- building below
    end
    if self.slot % self.buildGrid.width ~= 1 then
        table.insert(adjacent, self.buildGrid.buildings[self.slot - 1])-- building left
    end
    if self.slot % self.buildGrid.width ~= 0 then
        table.insert(adjacent, self.buildGrid.buildings[self.slot + 1])-- building right
    end
    return adjacent
end

function building:getSurrounding()
    local surrounding = {}
    if self.slot > self.buildGrid.width then
        table.insert(surrounding, self.buildGrid.buildings[self.slot - self.buildGrid.width])-- building above
        if self.slot % self.buildGrid.width ~= 1 then
            table.insert(surrounding, self.buildGrid.buildings[self.slot - 1 - self.buildGrid.width])-- building top left
        end
        if self.slot % self.buildGrid.width ~= 0 then
            table.insert(surrounding, self.buildGrid.buildings[self.slot + 1 - self.buildGrid.width])-- building top right
        end
    end
    if self.slot <= self.buildGrid.width * (self.buildGrid.height - 1) then
        table.insert(surrounding, self.buildGrid.buildings[self.slot + self.buildGrid.width])-- building below
        if self.slot % self.buildGrid.width ~= 1 then
            table.insert(surrounding, self.buildGrid.buildings[self.slot - 1 + self.buildGrid.width])-- building bottom left
        end
        if self.slot % self.buildGrid.width ~= 0 then
            table.insert(surrounding, self.buildGrid.buildings[self.slot + 1 + self.buildGrid.width])-- building bottom right
        end
    end

    if self.slot % self.buildGrid.width ~= 1 then
        table.insert(surrounding, self.buildGrid.buildings[self.slot - 1])-- building left
    end
    if self.slot % self.buildGrid.width ~= 0 then
        table.insert(surrounding, self.buildGrid.buildings[self.slot + 1])-- building right
    end
    return surrounding
end

function building:draw()
    local x = self.slot % self.buildGrid.width
    local y = math.ceil(self.slot / self.buildGrid.width)
    love.graphics.setColor(self.color or {1, 1, 1, 1})
    love.graphics.rectangle("fill", x * 25, y * 25, 25, 25)
end

return building