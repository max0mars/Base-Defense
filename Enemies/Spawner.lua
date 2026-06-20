local Enemy = require("Enemies.Enemy")
local Spawner = setmetatable({}, {__index = Enemy})
Spawner.__index = Spawner

local default = {
    name = "Spawner",
    reward = 150,
    spawnInterval = 7,
    spawnCount = 1,
    staggerDelay = 0.2,
}

function Spawner:new(config)
    config = config or {}
    
    local isTesting = config.game and config.game.testingMode
    local index = isTesting and require("Game.Spawning.TestingEnemyIndex") or require("Game.Spawning.EnemyIndex")
    local name = config.name or default.name
    local base = nil
    for _, entry in ipairs(index) do
        if entry.id == name or entry.type == name then
            base = entry
            break
        end
    end

    if not config.types then config.types = {} end
    for key, value in pairs(default) do
        config[key] = config[key] or (base and base[key]) or value
    end
    
    if base then
        config.spawnFrequency = config.spawnFrequency or base.spawnFrequency
        config.spawnAmount = config.spawnAmount or base.spawnAmount
        config.spawnReference = config.spawnReference or base.spawnReference
    end

    for key in pairs(default.types or {}) do
        config.types[key] = true
    end
    
    config.w = config.size
    config.h = config.size
    
    local instance = Enemy:new(config)
    setmetatable(instance, self)
    
    instance.spawnTimer = 0
    instance.spawnQueue = 0
    instance.staggerTimer = 0
    instance.staggerDelay = config.staggerDelay or 0.2
    return instance
end

function Spawner:update(dt)
    if self.destroyed then return end
    
    -- Call base update for movement and pathfinding
    Enemy.update(self, dt)
    
    if self:getStat("stunned", 0) > 0 then return end
    
    -- Spawning Logic
    self.spawnTimer = self.spawnTimer + dt
    local interval = self:getStat("spawnFrequency") or self:getStat("spawnInterval") or 5
    if self.spawnTimer >= interval then
        self.spawnTimer = 0
        local count = self:getStat("spawnAmount") or self:getStat("spawnCount") or 1
        self.spawnQueue = (self.spawnQueue or 0) + count
    end

    -- Staggered Spawning Logic
    if self.spawnQueue and self.spawnQueue > 0 then
        self.staggerTimer = self.staggerTimer + dt
        if self.staggerTimer >= self.staggerDelay then
            self.staggerTimer = 0
            self.spawnQueue = self.spawnQueue - 1
            self:spawnOneReinforcement()
        end
    end
end

function Spawner:spawnOneReinforcement()
    local offset = 10
    local rx = self.x + (math.random() - 0.5) * offset
    local ry = self.y + (math.random() - 0.5) * offset
    
    local isTesting = self.game and self.game.testingMode
    local nameStr = self:getStat("spawnReference") or (isTesting and "Speeder" or "Scout")
    
    local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
    local enemyClass = Enemy
    if EnemyRegistry and EnemyRegistry.allEnemies then
        for _, e in ipairs(EnemyRegistry.allEnemies) do
            if e.id == nameStr or e.type == nameStr then
                if e.class then enemyClass = e.class end
                break
            end
        end
    end
    
    local spawnedInstance = enemyClass:new({
        game = self.game,
        x = rx,
        y = ry,
        name = nameStr
    })
    
    -- Apply any active upgrades to the spawned enemy
    EnemyRegistry:applyActiveMutations(spawnedInstance)
    
    self.game:addObject(spawnedInstance)
end

function Spawner:draw()
    local r, g, b, a = unpack(self.color or {0.2, 0.8, 1, 1})
    local drawX = self.x
    local drawY = self.y
    local size = self:getStat("size")
    
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
    local scissorH = actualH * fillRatio
    
    -- 3. Draw "Health" Fill (Bright fill restricted by scissor)
    SetGameScissor(math.floor(self.x - size), math.floor(scissorY), math.ceil(size * 2), math.ceil(scissorH))
    love.graphics.setColor(r, g, b, 0.7)
    love.graphics.polygon("fill", hexPoints)
    
    -- Add a bright horizontal line at the health level "cap"
    -- We do this by setting a very thin scissor and redrawing the shape fill
    if fillRatio > 0 and fillRatio < 1 then
        SetGameScissor(math.floor(self.x - size), math.floor(scissorY), math.ceil(size * 2), 2)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.polygon("fill", hexPoints)
        SetGameScissor()
    end
    
    SetGameScissor()
    
    -- Layer 3: Shield Fill (Scissor bottom-up)
    if self.maxShield > 0 and self.shield > 0 then
        local shieldRatio = self.shield / self.maxShield
        local sScissorY = minY + actualH * (1 - shieldRatio)
        local sScissorH = actualH * shieldRatio
        
        SetGameScissor(math.floor(self.x - size), math.floor(sScissorY), math.ceil(size * 2), math.ceil(sScissorH))
        love.graphics.setColor(0.6, 0.6, 0.6, 1) -- Flat Grey
        love.graphics.polygon("fill", hexPoints)
        SetGameScissor()
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

return Spawner
