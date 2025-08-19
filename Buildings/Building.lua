local obj = require("Classes.object")

local building = {}
building.__index = building

function building:new(config)
    if(not config.slot) then
        error("Slot is required")
    end
    if(config.type ~= "unit" and config.type ~= "turret" and config.type ~= "passive") then
        error("Type must be either 'unit', 'turret', or 'passive'")
    end
    if(b.type == "passive") then
        if(not config.passiveShape) then
            error("Passive shape is required for passive buildings")
        end
        b.passiveShape = config.passiveShape
    end
    if(not config.game) then
        error("Game reference is required")
    end
    local b = setmetatable(obj:new(config), {__index = self})
    b.slot = config.slot
    b.type = config.type
    
    b.buildGrid = config.game.base.buildGrid
    return b
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
