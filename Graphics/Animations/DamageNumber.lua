-- DamageNumber.lua
-- Floating text for damage feedback

local DamageNumber = {}
DamageNumber.__index = DamageNumber

local typeColors = {
    normal = {1, 1, 1, 1},
    poison = {0.3, 1, 0.3, 1},
    energy = {0.3, 0.6, 1, 1},
    crit = {1, 0.8, 0.2, 1},
}

function DamageNumber:new(amount, x, y, damageType)
    local obj = setmetatable({}, self)
    
    obj.amount = math.floor(amount + 0.5)
    obj.x = x + love.math.random(-15, 15)
    obj.y = y + love.math.random(-15, 15)
    obj.velY = -60
    obj.velX = love.math.random(-20, 20)
    obj.color = typeColors[damageType or "normal"] or typeColors.normal
    obj.lifetime = 0.8
    obj.maxLifetime = 0.8
    obj.destroyed = false
    
    return obj
end

function DamageNumber:update(dt)
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self.destroyed = true
        return
    end
    
    -- Drift up and slow down
    self.x = self.x + self.velX * dt
    self.y = self.y + self.velY * dt
    self.velY = self.velY * 0.95
    self.velX = self.velX * 0.95
end

function DamageNumber:draw()
    local alpha = math.min(1, self.lifetime / (self.maxLifetime * 0.5))
    local r, g, b = self.color[1], self.color[2], self.color[3]
    
    love.graphics.setColor(0, 0, 0, alpha) -- shadow/outline
    love.graphics.print(self.amount, self.x + 1, self.y + 1)
    
    love.graphics.setColor(r, g, b, alpha)
    love.graphics.print(self.amount, self.x, self.y)
    
    love.graphics.setColor(1, 1, 1, 1)
end

return DamageNumber
