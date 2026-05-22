local Enemy = require("Enemies.Enemy")
local tank = setmetatable({}, {__index = Enemy})
tank.__index = tank

local default = {
    name = "Tank",
    speed = 15, -- Set speed for tank
    maxHp = 1000,
    damage = 30,
    color = {1, 1, 0, 1}, -- Default color for basic enemies
    types = { tank = true },
    size = 30,
    reward = 100
}

function tank:new(config)
    if not config.types then config.types = {} end
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    for key in pairs(default.types) do
        config.types[key] = true
    end
    local instance = Enemy:new(config)
    setmetatable(instance, tank)
    
    return instance
end

function tank:drawCustomShape(mode, cx, cy)
    local scale = self:getStat("size", 22) / 22
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)
    
    -- Draw tank as a single hollow polygon to prevent overlapping lines
    local pts = {
        -11, -10, -- Top left of top tread
        11, -10,  -- Top right of top tread
        11, -7,   -- Bottom right of top tread
        9, -7,    -- Top right of body
        9, 7,     -- Bottom right of body
        11, 7,    -- Top right of bottom tread
        11, 10,   -- Bottom right of bottom tread
        -11, 10,  -- Bottom left of bottom tread
        -11, 7,   -- Top left of bottom tread
        -9, 7,    -- Bottom left of body
        -9, -7,   -- Top left of body
        -11, -7   -- Bottom left of top tread
    }
    
    love.graphics.polygon(mode, pts)
    
    love.graphics.pop()
end

return tank