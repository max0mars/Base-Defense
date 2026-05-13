local bullet = require("Bullets.Bullet")

local LobberBullet = setmetatable({}, bullet)
LobberBullet.__index = LobberBullet

LobberBullet.GRAVITY = 1500
LobberBullet.Z_COLLIDE_RANGE = 20
LobberBullet.MAX_HEIGHT = 150

function LobberBullet:getTOF()
    local vz0 = math.sqrt(2 * self.GRAVITY * self.MAX_HEIGHT)
    return (2 * vz0) / self.GRAVITY
end

function LobberBullet:new(config)
    local required = {"bulletSpeed", "damage"}
    for _, key in ipairs(required) do
        if config[key] == nil then
            error("Developer Error: LobberBullet is missing required stat: " .. key)
        end
    end

    local b = bullet.new(self, config)
    setmetatable(b, self)
    
    b.z = 0
    b.v_z = 0
    
    -- Calculate vertical and horizontal components for a fixed peak height
    if config.targetX and config.targetY then
        local dx = config.targetX - b.x
        local dy = config.targetY - b.y
        local dist = math.sqrt(dx*dx + dy*dy)
        
        b.v_z = math.sqrt(2 * self.GRAVITY * self.MAX_HEIGHT)
        
        local T = (2 * b.v_z) / self.GRAVITY
        
        if T > 0 then
            local targetSpeed = dist / T
            local currentBase = b.bulletSpeed or 1
            local modifiedSpeed = b:getStat("bulletSpeed")
            local multiplier = modifiedSpeed / currentBase
            
            b.bulletSpeed = targetSpeed / multiplier
            
            if b.effectManager then
                b.effectManager:recalculateStats()
            end
        end
    end
    
    return b
end

function LobberBullet:update(dt)
    if self.destroyed then return end
    
    bullet.update(self, dt)
    if self.destroyed then return end

    self.z = self.z + (self.v_z * dt)
    self.v_z = self.v_z - (self.GRAVITY * dt)
    
    if self.z <= 0 and self.v_z < 0 then
        self.z = 0
        self:onGroundImpact()
    end
end

function LobberBullet:onGroundImpact()
    self:onHit(nil)
    self:died()
end

function LobberBullet:onCollision(obj)
    if self.destroyed then return end
    
    if obj:isType('enemy') and not self.hitCache[obj:getID()] then
        local targetZ = obj.z or 0
        if math.abs(self.z - targetZ) < self.Z_COLLIDE_RANGE then
            self.hitCache[obj:getID()] = true
            self:onHit(obj)
        end
    end
end

function LobberBullet:draw()
    local shadowWidth = 12
    local shadowHeight = 6
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", self.x, self.y, shadowWidth/2, shadowHeight/2)
    
    love.graphics.setColor(self.color or {1, 1, 1, 1})
    local drawX = self.x
    local drawY = self.y - self.z
    
    if self.shape == "rectangle" then
        love.graphics.rectangle("fill", drawX - self.w / 2, drawY - self.h / 2, self.w, self.h)
    elseif self.shape == "circle" then
        love.graphics.circle("fill", drawX, drawY, self.size or (self.w/2))
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return LobberBullet
