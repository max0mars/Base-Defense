local bullet = require("Bullets.Bullet")

local LobberBullet = setmetatable({}, bullet)
LobberBullet.__index = LobberBullet

-- Constants
local GRAVITY = 1500
local Z_COLLIDE_RANGE = 20
local MAX_HEIGHT = 150

function LobberBullet:getTOF()
    local vz0 = math.sqrt(2 * GRAVITY * MAX_HEIGHT)
    return (2 * vz0) / GRAVITY
end

function LobberBullet:new(config)
    -- Safety checks (getStat protocol)
    local required = {"bulletSpeed", "damage"}
    for _, key in ipairs(required) do
        if config[key] == nil then
            error("Developer Error: LobberBullet is missing required stat: " .. key)
        end
    end

    local b = bullet:new(config)
    setmetatable(b, self)
    
    b.z = 0
    b.v_z = 0
    
    -- Calculate vertical and horizontal components for a fixed peak height
    if config.targetX and config.targetY then
        local dx = config.targetX - b.x
        local dy = config.targetY - b.y
        local dist = math.sqrt(dx*dx + dy*dy)
        
        -- Fixed Peak Height (z = MAX_HEIGHT)
        -- Physics: v_z0 = sqrt(2 * gravity * H)
        b.v_z = math.sqrt(2 * GRAVITY * MAX_HEIGHT)
        
        -- Total flight time T = 2 * v_z0 / gravity
        local T = (2 * b.v_z) / GRAVITY
        
        -- Adjust horizontal speed so it covers 'dist' in exactly time 'T'
        if T > 0 then
            local targetSpeed = dist / T
            
            -- Account for potential stat modifiers so the final getStat value equals targetSpeed
            local currentBase = b.bulletSpeed or 1
            local modifiedSpeed = b:getStat("bulletSpeed")
            local multiplier = modifiedSpeed / currentBase
            
            b.bulletSpeed = targetSpeed / multiplier
            
            -- CRITICAL: Clear the EffectManager cache so that getStat returns the new adjusted speed
            if b.effectManager then
                b.effectManager:incrementVersion()
            end
        end
    end
    
    return b
end

function LobberBullet:update(dt)
    if self.destroyed then return end
    
    -- Horizontal Movement (using Bullet code)
    bullet.update(self, dt)
    if self.destroyed then return end

    -- Vertical Physics
    self.z = self.z + (self.v_z * dt)
    self.v_z = self.v_z - (GRAVITY * dt)
    
    -- Ground Impact Logic
    if self.z <= 0 and self.v_z < 0 then
        self.z = 0
        self:onHit(nil)
        self:died()
    end
end

function LobberBullet:onCollision(obj)
    if self.destroyed then return end
    
    -- Only check for enemy collisions
    if obj:isType('enemy') and not self.hitCache[obj:getID()] then
        -- Vertical collision check (treat objects without .z as z=0)
        local targetZ = obj.z or 0
        if math.abs(self.z - targetZ) < Z_COLLIDE_RANGE then
            self.hitCache[obj:getID()] = true
            self:onHit(obj)
        end
    end
end

function LobberBullet:draw()
    -- Visual Indicator: Shadow at base coordinates
    local shadowWidth = 12
    local shadowHeight = 6
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", self.x, self.y, shadowWidth/2, shadowHeight/2)
    
    -- Render Bullet at (x, y - z)
    love.graphics.setColor(self.color or {1, 1, 1, 1})
    local drawX = self.x
    local drawY = self.y - self.z
    
    if self.shape == "rectangle" then
        love.graphics.rectangle("fill", drawX - self.w / 2, drawY - self.h / 2, self.w, self.h)
    elseif self.shape == "circle" then
        love.graphics.circle("fill", drawX, drawY, self.size or (self.w/2))
    end
end

return LobberBullet
