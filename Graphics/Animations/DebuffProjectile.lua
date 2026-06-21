-- DebuffProjectile.lua
-- A fake projectile that travels to a target and executes a callback upon hitting.

local DebuffProjectile = {}
DebuffProjectile.__index = DebuffProjectile

function DebuffProjectile:new(x, y, target, onHitCallback, color)
    local obj = setmetatable({}, self)
    obj.x = x
    obj.y = y
    obj.target = target
    obj.onHitCallback = onHitCallback
    obj.color = color or {0, 1, 1, 1}
    obj.speed = 300
    obj.destroyed = false
    obj.isUI = false
    return obj
end

function DebuffProjectile:update(dt)
    if self.destroyed then return end
    
    if not self.target or self.target.destroyed then
        self.destroyed = true
        return
    end
    
    local targetX, targetY = self.target.x, self.target.y
    if self.target.getCenterPosition then
        targetX, targetY = self.target:getCenterPosition()
    end
    
    local dx = targetX - self.x
    local dy = targetY - self.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist < self.speed * dt then
        -- Reached the target
        self.x = targetX
        self.y = targetY
        if self.onHitCallback then
            self.onHitCallback()
        end
        self.destroyed = true
    else
        self.x = self.x + (dx/dist) * self.speed * dt
        self.y = self.y + (dy/dist) * self.speed * dt
    end
end

function DebuffProjectile:draw()
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.x, self.y, 4)
    love.graphics.setColor(1, 1, 1, 1)
end

return DebuffProjectile
