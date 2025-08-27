local Base = {
}
local living_object = require("Classes.living_object") -- Import the living_object module
setmetatable(Base, { __index = living_object }) -- Inherit from the object class

local default = {
    x = 50,
    y = 300,
    w = 100,
    h = 400,
    shape = "rectangle",
    color = {love.math.colorFromBytes(69, 69, 69)},
    hitbox = {shape = "rectangle"},
    hp = 1000,
    maxHp = 1000,
    tag = "base",
    game = self,
    big = true,
    buildGrid = {
        cellSize = 25,
        width = 4,
        height = 16,
        buildings = {}
    }
}

function Base:new(config)
    local config = config or default
    if not config.buildGrid then
        error("buildGrid is required for Base")
    end
    local obj = living_object:new(config)
    setmetatable(obj, { __index = self })
    obj.buildGrid = {
        x = config.buildGrid.x or 0,
        y = config.buildGrid.y or 100,
        cellSize = config.buildGrid.cellSize or 25,
        width = config.buildGrid.width,
        height = config.buildGrid.height,
        buildings = {}
    }
    return obj
end

function Base:draw()
    love.graphics.setColor(self.color or {1, 1, 1, 1})
    love.graphics.rectangle("fill", self.x - self.w / 2, self.y - self.h / 2, self.w, self.h)

    for i = 1, self.buildGrid.width do
        for j = 1, self.buildGrid.height do
            local slot = (j - 1) * self.buildGrid.width + i
            if not self.buildGrid.buildings[slot] then
                love.graphics.setColor(0.5, 0.5, 0.5, 0.5) -- Gray color for empty slots
                love.graphics.rectangle("line", self.buildGrid.x + (i - 1) * self.buildGrid.cellSize, self.buildGrid.y + (j - 1) * self.buildGrid.cellSize, self.buildGrid.cellSize, self.buildGrid.cellSize)
                love.graphics.print(slot, self.buildGrid.x + (i - 1) * self.buildGrid.cellSize, self.buildGrid.y + (j - 1) * self.buildGrid.cellSize)
            end
        end
    end

    for _, building in pairs(self.buildGrid.buildings) do
        building:draw()
    end
end

function Base:addBuilding(building, slot)
    if not building or not slot or self.buildGrid.buildings[slot] then
        error("Invalid building or slot is missing or the slot is already occupied")
    end
    self.buildGrid.buildings[slot] = building
    building.slot = slot
    building.x, building.y = building:getX() + building.buildGrid.cellSize/2, building:getY() + building.buildGrid.cellSize/2
end

return Base