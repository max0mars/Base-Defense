local LightningBolt = {}
LightningBolt.__index = LightningBolt

function LightningBolt:new(tx, ty, config)
    local obj = setmetatable({}, self)
    obj.tx = tx
    obj.ty = ty
    
    -- Start point is very high up to ensure it looks like it comes from the sky
    obj.sx = tx + (love.math.random() * 400 - 200)
    obj.sy = -500 
    
    obj.lifespan = 0.5 -- Longer duration
    obj.maxLifespan = 0.5
    obj.destroyed = false
    obj.color = {1, 1, 1, 1} -- Force pure white for now to ensure visibility
    
    -- Generate more jagged segments
    obj.segments = {}
    local currentX, currentY = obj.sx, obj.sy
    local segmentCount = 12
    
    for i = 1, segmentCount do
        local t = i / segmentCount
        local nextX = obj.sx + (obj.tx - obj.sx) * t
        local nextY = obj.sy + (obj.ty - obj.sy) * t
        
        if i < segmentCount then
            nextX = nextX + (love.math.random() * 120 - 60) * (1 - t)
            nextY = nextY + (love.math.random() * 40 - 20) * (1 - t)
        else
            nextX = obj.tx
            nextY = obj.ty
        end
        
        table.insert(obj.segments, {x1 = currentX, y1 = currentY, x2 = nextX, y2 = nextY})
        currentX, currentY = nextX, nextY
    end
    
    return obj
end

function LightningBolt:update(dt)
    self.lifespan = self.lifespan - dt
    if self.lifespan <= 0 then
        self.destroyed = true
    end
end

function LightningBolt:draw()
    local alpha = self.lifespan / self.maxLifespan
    
    -- 1. Outer Bloom (Blue)
    love.graphics.setColor(0.4, 0.7, 1, alpha)
    love.graphics.setLineWidth(15)
    for _, s in ipairs(self.segments) do
        love.graphics.line(s.x1, s.y1, s.x2, s.y2)
    end
    
    -- 2. Inner Glow (Brighter Blue)
    love.graphics.setColor(0.7, 0.9, 1, alpha)
    love.graphics.setLineWidth(6)
    for _, s in ipairs(self.segments) do
        love.graphics.line(s.x1, s.y1, s.x2, s.y2)
    end
    
    -- 3. Pure White Core
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.setLineWidth(2)
    for _, s in ipairs(self.segments) do
        love.graphics.line(s.x1, s.y1, s.x2, s.y2)
    end
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return LightningBolt
