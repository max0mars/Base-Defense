local Enemy = require("Enemies.Enemy")
local Speeder = require("Enemies.Speeder")
local Carrier = setmetatable({}, {__index = Enemy})
Carrier.__index = Carrier

local default = {
    speed = 18, -- Slower than standard 25
    maxHp = 300,
    color = {0.2, 0.8, 1, 1}, -- Neon Cyan
    types = { carrier = true, tank = true },
    size = 35, -- Balanced size
    reward = 150,
    spawnInterval = 5,
    spawnCount = 2,
}

function Carrier:new(config)
    config = config or {}
    if not config.types then config.types = {} end
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    for key in pairs(default.types) do
        config.types[key] = true
    end
    
    config.w = config.size
    config.h = config.size
    
    local instance = Enemy:new(config)
    setmetatable(instance, Carrier)
    
    instance.spawnTimer = 0
    return instance
end

function Carrier:update(dt)
    if self.destroyed then return end
    
    -- Call base update for movement and pathfinding
    Enemy.update(self, dt)
    
    -- Spawning Logic
    self.spawnTimer = self.spawnTimer + dt
    local interval = self:getStat("spawnInterval") or 4
    if self.spawnTimer >= interval then
        self.spawnTimer = 0
        self:spawnReinforcements()
    end
end

function Carrier:spawnReinforcements()
    for i = 1, self:getStat("spawnCount") do
        local offset = 10
        local rx = self.x + (math.random() - 0.5) * offset
        local ry = self.y + (math.random() - 0.5) * offset
        
        local speederInstance = Speeder:new({
            game = self.game,
            x = rx,
            y = ry
        })
        
        -- Apply any active upgrades to the spawned speeder
        local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
        EnemyRegistry:applyActiveMutations(speederInstance)
        
        self.game:addObject(speederInstance)
    end
end

function Carrier:draw()
    local r, g, b, a = unpack(self.color or {0.2, 0.8, 1, 1})
    local drawX = self.x
    local drawY = self.y
    local size = self.size
    
    -- Calculate Hexagon Points
    local function getHexPoints(cx, cy, s)
        local points = {}
        for i = 0, 5 do
            local angle = i * (math.pi / 3)
            table.insert(points, cx + math.cos(angle) * s)
            table.insert(points, cy + math.sin(angle) * s)
        end
        return points
    end
    
    local hexRadius = size * 0.5 -- Match radius to footprint
    local hexPoints = getHexPoints(drawX, drawY, hexRadius)
    
    -- 1. Draw "Empty" Base State (Dim fill)
    love.graphics.setColor(r, g, b, 0.15)
    love.graphics.polygon("fill", hexPoints)
    
    -- 2. Calculate Scissor Box for Health Fill (Draining effect)
    local fillRatio = self.hp / self:getStat("maxHp")
    local footprintW = self.w
    local footprintH = self.h
    local fx = self.x - footprintW/2
    local fy = self.y - footprintH/2
    
    local scissorY = fy + footprintH * (1 - fillRatio)
    local scissorH = footprintH * fillRatio
    
    -- 3. Draw "Health" Fill (Bright fill restricted by scissor)
    love.graphics.setScissor(math.floor(fx), math.floor(scissorY), math.ceil(footprintW), math.ceil(scissorH))
    love.graphics.setColor(r, g, b, 0.7)
    love.graphics.polygon("fill", hexPoints)
    love.graphics.setScissor()
    
    -- 4. Glow Layers (Outside scissor)
    for i = 5, 1, -1 do
        local alpha = 0.05 * (1 - i/6)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.setLineWidth(i * 3)
        love.graphics.polygon("line", hexPoints)
    end
    
    -- 5. Main Neon Border
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(3)
    love.graphics.polygon("line", hexPoints)
end

return Carrier
