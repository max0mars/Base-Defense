local ArmorBreak = {}
ArmorBreak.__index = ArmorBreak

function ArmorBreak:new(x, y)
    local obj = setmetatable({}, self)
    
    obj.x = x
    obj.y = y
    obj.color = {0.8, 0.8, 0.8} -- Greyish color
    obj.maxLifetime = 0.5
    obj.lifetime = obj.maxLifetime
    obj.destroyed = false
    
    obj.shards = {}
    local n = 8
    
    for i = 1, n do
        local angle = love.math.random() * math.pi * 2
        local speed = love.math.random(150, 300)
        local shard = {
            offX = 0,
            offY = 0,
            velX = math.cos(angle) * speed,
            velY = math.sin(angle) * speed,
            angle = love.math.random() * math.pi * 2,
            rotSpeed = love.math.random(-20, 20),
            size = love.math.random(6, 12)
        }
        table.insert(obj.shards, shard)
    end
    
    return obj
end

function ArmorBreak:update(dt)
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self.destroyed = true
        return
    end
    
    for _, shard in ipairs(self.shards) do
        shard.offX = shard.offX + shard.velX * dt
        shard.offY = shard.offY + shard.velY * dt
        shard.angle = shard.angle + shard.rotSpeed * dt
        shard.velX = shard.velX * 0.92
        shard.velY = shard.velY * 0.92
    end
end

function ArmorBreak:draw()
    local alpha = self.lifetime / self.maxLifetime
    local r, g, b = unpack(self.color)
    
    love.graphics.setColor(r, g, b, alpha)
    love.graphics.setLineWidth(2)
    
    for _, shard in ipairs(self.shards) do
        love.graphics.push()
        love.graphics.translate(self.x + shard.offX, self.y + shard.offY)
        love.graphics.rotate(shard.angle)
        
        -- Triangle/Shard shape
        love.graphics.line(-shard.size/2, shard.size/4, 0, -shard.size/2, shard.size/2, shard.size/4, -shard.size/2, shard.size/4)
        
        love.graphics.pop()
    end
    
    -- Add a small white flash at the center
    love.graphics.setColor(1, 1, 1, alpha * 0.5)
    love.graphics.circle("fill", self.x, self.y, (1 - alpha) * 20)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

return ArmorBreak
