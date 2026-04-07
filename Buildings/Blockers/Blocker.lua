local Building = require("Buildings.Building")

local Blocker = setmetatable({}, Building)
Blocker.__index = Blocker

local default = {
    types = { blocker = true },
    --shape = "rectangle",
    color = {0.8, 0.4, 0.1, 1},
    noBuildRadius = 1,
    cost = 50,
    shapePattern = {
        {0, 0}
    },
}

function Blocker:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    
    local obj = setmetatable(Building.new(self, config), { __index = self })
    return obj
end

function Blocker:draw(x, y)
    local drawX = x or self.x
    local drawY = y or self.y
    local w = self.buildGrid and self.buildGrid.cellSize or 25
    local h = self.buildGrid and self.buildGrid.cellSize or 25
    
    love.graphics.setColor(self.color)
    for _, coord in ipairs(self.shapePattern) do
        local ox = coord[1] * w
        local oy = coord[2] * h
        love.graphics.rectangle("fill", drawX + ox - w/2, drawY + oy - h/2, w, h)
    end
    
    -- Draw no-build zone feedback if placing
    if self.isPreview then
        local game = self.game
        local grid = self.buildGrid or (game and game.battlefieldGrid)
        if grid then
            love.graphics.setColor(1, 0.5, 0, 0.3) -- semi-transparent orange tint
            local r = self.noBuildRadius
            
            local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
            for _, coord in ipairs(self.shapePattern) do
                minX = math.min(minX, coord[1] - r)
                maxX = math.max(maxX, coord[1] + r)
                minY = math.min(minY, coord[2] - r)
                maxY = math.max(maxY, coord[2] + r)
            end
            
            local rx = drawX + (minX * w) - w/2
            local ry = drawY + (minY * h) - h/2
            local rw = (maxX - minX + 1) * w
            local rh = (maxY - minY + 1) * h
            
            love.graphics.rectangle("fill", rx, ry, rw, rh)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

return Blocker
