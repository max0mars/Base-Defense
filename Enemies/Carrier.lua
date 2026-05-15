local Enemy = require("Enemies.Enemy")
local Speeder = require("Enemies.Speeder")
local Carrier = setmetatable({}, {__index = Enemy})
Carrier.__index = Carrier

local default = {
    speed = 18, -- Slower than standard 25
    maxHp = 300,
    damage = 20,
    color = {0.2, 0.8, 1, 1}, -- Neon Cyan
    types = { carrier = true, tank = true },
    size = 35, -- Balanced size
    reward = 150,
    spawnInterval = 7,
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
    local maxHp = self:getStat("maxHp")
    local fillRatio = self.hp / maxHp
    
    -- Calculate actual vertical bounds of the hexagon to avoid "dead space"
    local minY, maxY = hexPoints[2], hexPoints[2]
    for i = 4, #hexPoints, 2 do
        local y = hexPoints[i]
        if y < minY then minY = y end
        if y > maxY then maxY = y end
    end
    local actualH = maxY - minY
    
    local scissorY = minY + actualH * (1 - fillRatio)
    
    -- Guarantee at least a 1px visual drop/presence
    if self.hp < maxHp and self.hp > 0 then
        scissorY = math.max(minY + 1, math.min(maxY - 1, scissorY))
    end
    
    local scissorH = maxY - scissorY
    
    -- 3. Draw "Health" Fill (Bright fill restricted by scissor)
    love.graphics.setScissor(math.floor(self.x - size), math.floor(scissorY), math.ceil(size * 2), math.ceil(scissorH))
    love.graphics.setColor(r, g, b, 0.7)
    love.graphics.polygon("fill", hexPoints)
    
    -- Add a bright horizontal line at the health level "cap"
    -- We do this by setting a very thin scissor and redrawing the shape fill
    if fillRatio > 0 and fillRatio < 1 then
        love.graphics.setScissor(math.floor(self.x - size), math.floor(scissorY), math.ceil(size * 2), 2)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.polygon("fill", hexPoints)
        love.graphics.setScissor()
    end
    
    love.graphics.setScissor()
    
    -- Layer 3: Shield Fill (Scissor bottom-up)
    if self.maxShield > 0 and self.shield > 0 then
        local shieldRatio = self.shield / self.maxShield
        local sScissorY = minY + actualH * (1 - shieldRatio)
        local sScissorH = maxY - sScissorY
        
        love.graphics.setScissor(math.floor(self.x - size), math.floor(sScissorY), math.ceil(size * 2), math.ceil(sScissorH))
        love.graphics.setColor(0.6, 0.6, 0.6, 1) -- Flat Grey
        love.graphics.polygon("fill", hexPoints)
        love.graphics.setScissor()
    end
    
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
