local building = require("Buildings.Building")
local bullet = require("Bullets.Bullet")

Turret = setmetatable({}, building)
Turret.__index = Turret

local default = {
    type = 'turret',
    tag = 'turret',
    rotation = 0,
    turnSpeed = math.huge,
    fireRate = 0.2,
    damage = 10,
    bulletSpeed = 400,
    range = math.huge,
    barrel = 0,
    arcAngle = math.pi/4, -- 45 degrees
    firingArc = {
        direction = 0,    -- Firing arc facing direction in radians
        minRange = 0,     -- Minimum firing range
        maxRange = 600,   -- Maximum firing range  
        angle = math.pi/4   -- Firing arc angle (in radians, math.pi = 180 degrees)
    },
    color = {1, 1, 1, 1}
}

function Turret:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    
    -- Ensure firingArc has no missing values
    if config.firingArc then
        if not config.firingArc.direction then
            error("firingArc.direction is required when providing custom firingArc")
        end
        if not config.firingArc.minRange then
            error("firingArc.minRange is required when providing custom firingArc")
        end
        if not config.firingArc.maxRange then
            error("firingArc.maxRange is required when providing custom firingArc")
        end
        if not config.firingArc.angle then
            error("firingArc.angle is required when providing custom firingArc")
        end
    end
    
    local t = setmetatable(building:new(config), { __index = self }) -- Create a new object with the base properties
    t.rotation = config.rotation
    t.targetRotation = t.rotation -- Target rotation for smooth aiming
    t.turnSpeed = config.turnSpeed
    t.fireRate = config.fireRate
    t.bulletType = config.bulletType or bullet
    t.cooldown = 0 -- Cooldown timer for firing
    t.hitEffects = {} -- Table to store hit effects
    t.damage = config.damage
    t.target = nil  -- Target to auto aim at
    t.bulletSpeed = config.bulletSpeed
    t.range = config.range
    t.barrel = config.barrel
    t.firingArc = {
        direction = config.firingArc.direction,
        minRange = config.firingArc.minRange,
        maxRange = config.firingArc.maxRange,
        angle = config.firingArc.angle
    }
    t.showArc = false -- Flag to show firing arc
    t.selected = false -- Flag to show if turret is selected
    --t.x, t.y = 0, 0
    return t
end

function Turret:addHitEffect(effectFunc)
    table.insert(self.hitEffects, effectFunc)
end

function Turret:fire(args)
    local offset = 0--love.math.random() * self.spread * 2 - self.spread
    local x, y = self:getFirePoint()
    config = {
        x = x,
        y = y,
        angle = self.rotation + offset, -- Add spread to the angle
        speed = self.bulletSpeed, -- Speed of the bullet
        damage = self.damage, -- Damage dealt by the bullet
        hitEffects = self.hitEffects, -- Effects to apply on hit
        game = self.game, -- Reference to the game object
        targetX = args.targetX,
        targetY = args.targetY,
    }
    for k, v in pairs(args or {}) do
        config[k] = v
    end
    -- for k, v in pairs(self) do
    --     config[k] = config[k] or v
    -- end
    local b = self.bulletType:new(config)
    -- Add upgrades to bullet
    -- b.hitEffects = {}
    -- for _, effect in ipairs(self.hitEffects) do
    --     table.insert(b.hitEffects, effect)
    -- end
    self.game:addObject(b) -- Add the bullet to the game's object list
end

function Turret:update(dt)
    self.cooldown = self.cooldown - dt
    self:getTargetArc()
    if self.target then
        local x, y = self:getTargetLeadPosition()
        self:lookAt(x, y, dt) -- Aim at the target's lead position
        if self.cooldown <= 0 then
            self:fire({targetX = x, targetY = y})
            self.cooldown = self.fireRate
        end
    end
end

function Turret:draw()
    -- Draw firing arc if showArc flag is set
    if self.showArc then
        self:drawFiringArc(0.4)
    end
    
    love.graphics.setColor(self.color)
    -- love.graphics.rectangle("fill", x * 25, y * 25, 25, 25)
    -- Draw turret mount
    --love.graphics.setColor(0, 0, 1)
    love.graphics.circle("fill", self.x, self.y, 8)

    -- Draw barrel
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(3) -- Set barrel thickness
    love.graphics.line(
        self.x, self.y,
        self.x + math.cos(self.rotation) * self.barrel,
        self.y + math.sin(self.rotation) * self.barrel
    )
    love.graphics.setLineWidth(1) -- Reset line width to default
    --love.graphics.printf("Rotation: " .. self.rotation, self.x - 40, self.y - 40, 200, "center")
end

function Turret:drawFiringArc(alpha)
    alpha = alpha or 0.3
    love.graphics.setColor(1, 1, 0, alpha) -- Yellow with transparency
    
    -- Calculate arc bounds using firing arc direction
    local startAngle = self.firingArc.direction - self.firingArc.angle / 2
    local endAngle = self.firingArc.direction + self.firingArc.angle / 2
    
    -- Draw the firing arc as a sector
    if self.firingArc.minRange > 0 then
        -- Draw arc with inner and outer radius
        self:drawArcSector(self.x, self.y, self.firingArc.minRange, self.firingArc.maxRange, startAngle, endAngle)
    else
        -- Draw simple arc from center
        self:drawArcSector(self.x, self.y, 0, self.firingArc.maxRange, startAngle, endAngle)
    end
    
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

function Turret:drawArcSector(x, y, innerRadius, outerRadius, startAngle, endAngle)
    local segments = 20
    local angleStep = (endAngle - startAngle) / segments
    
    -- Draw the arc as a series of triangles
    for i = 0, segments - 1 do
        local angle1 = startAngle + i * angleStep
        local angle2 = startAngle + (i + 1) * angleStep
        
        -- Create quad vertices
        local x1_inner = x + math.cos(angle1) * innerRadius
        local y1_inner = y + math.sin(angle1) * innerRadius
        local x1_outer = x + math.cos(angle1) * outerRadius
        local y1_outer = y + math.sin(angle1) * outerRadius
        
        local x2_inner = x + math.cos(angle2) * innerRadius
        local y2_inner = y + math.sin(angle2) * innerRadius
        local x2_outer = x + math.cos(angle2) * outerRadius
        local y2_outer = y + math.sin(angle2) * outerRadius
        
        -- Draw two triangles to form a quad
        love.graphics.polygon("fill", 
            x1_inner, y1_inner,
            x1_outer, y1_outer, 
            x2_outer, y2_outer,
            x2_inner, y2_inner
        )
    end
end

function Turret:getTarget()
    if self.target and self.target.destroyed then
        self.target = nil -- Reset target if it is destroyed
    elseif self.target then
        return self.target -- Return the current target if it is still valid
    end-- If we already have a target, no need to search again
    local dist = self.range^2 -- Use squared distance to avoid sqrt for performance
    for _, obj in ipairs(self.game.objects) do
        if obj.tag == "enemy" and not obj.destroyed then
            local newdist = (obj.x - self.x)^2 + (obj.y - self.y)^2 -- Calculate squared distance to avoid sqrt for performance
            if newdist < dist then
                dist = newdist -- Calculate distance to the enemy
                self.target = obj
            end
        end
    end
end

function Turret:getTargetArc()
    if self.target and self.target.destroyed then
        self.target = nil -- Reset target if it is destroyed
    elseif self.target and self:isInFiringArc(self.target) then
        return self.target -- Return current target if still valid and in arc
    end
    
    self.target = nil -- Clear target if it's out of arc
    local closestDist = math.huge
    local closestEnemy = nil
    
    for _, obj in ipairs(self.game.objects) do
        if obj.tag == "enemy" and not obj.destroyed then
            if self:isInFiringArc(obj) then
                local dist = (obj.x - self.x)^2 + (obj.y - self.y)^2
                if dist < closestDist then
                    closestDist = dist
                    closestEnemy = obj
                end
            end
        end
    end
    
    self.target = closestEnemy
    return self.target
end

function Turret:isInFiringArc(target)
    if not target then return false end
    
    local dx = target.x - self.x
    local dy = target.y - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Check if target is within range
    if distance < self.firingArc.minRange or distance > self.firingArc.maxRange then
        return false
    end
    
    -- Calculate angle to target
    local angleToTarget = math.atan2(dy, dx)
    
    -- Normalize angle to [0, 2π]
    if angleToTarget < 0 then
        angleToTarget = angleToTarget + 2 * math.pi
    end
    
    -- Normalize direction to [0, 2π]
    local normalizedDirection = self.firingArc.direction
    if normalizedDirection < 0 then
        normalizedDirection = normalizedDirection + 2 * math.pi
    end
    
    -- Calculate angular difference
    local angleDiff = math.abs(angleToTarget - normalizedDirection)
    if angleDiff > math.pi then
        angleDiff = 2 * math.pi - angleDiff
    end
    
    -- Check if target is within firing arc angle
    return angleDiff <= self.firingArc.angle / 2
end

function Turret:getFirePoint()
    return self.x + math.cos(self.rotation) * self.barrel, self.y + math.sin(self.rotation) * self.barrel
end

function Turret:lookAt(x, y, dt)

    local dx = x - self.x
    local dy = y - self.y
    local target_angle = math.atan(dy / dx)
    if dx < 0 then -- for quadrants 3,4
        target_angle = math.pi + target_angle
    else
        if dy < 0 then -- ensures angle is always positive (0 - 2pi)
            target_angle = 2 * math.pi + target_angle
        end
    end


    self.targetRotation = target_angle
    if self.turnSpeed > 10 then
        self.rotation = self.targetRotation
        return
    end
    local angle = target_angle - self.rotation
    local sign = 1
    if angle < 0 then -- convert the angle to a positive
        sign = -1
        angle = angle * -1
    end

    if angle > math.pi then -- if the angle is > pi than it is faster to rotate the other way
        sign = sign * -1
    end

    if math.abs(angle) < self.turnSpeed * dt then -- angle is too small
        self.rotation = target_angle -- Snap to target rotation
        return 0
    end

    self.rotation = self.rotation + sign * self.turnSpeed * dt -- Rotate towards the target angle
    if self.rotation > math.pi*2 then
        self.rotation = self.rotation - math.pi*2 -- Wrap around to keep rotation in range
    elseif self.rotation < 0 then
        self.rotation = self.rotation + math.pi*2 -- Wrap around to keep rotation in range
    end
end



function Turret:getTargetLeadPosition()

    local x = self.x
    local y = self.y
    local targetx = self.target.x
    local targety = self.target.y
    local pSpeed = self.bulletSpeed
    local targetvx = self.target:getVelocity() -- Assuming the target has a method to get its velocity
    local targetvy = 0 -- Assuming enemies move horizontally

    local dx = targetx - x
    local dy = targety - y

    local a = targetvx^2 + targetvy^2 - pSpeed^2
    local b = 2 * (dx * targetvx + dy * targetvy)
    local c = dx^2 + dy^2

    local disc = b^2 - 4 * a * c
    if disc < 0 or math.abs(a) < 0.0001 then
        return targetx, targety -- No lead angle, just aim directly at the target
    end

    local sqrt_disc = math.sqrt(disc)
    local t1 = (-b + sqrt_disc) / (2 * a)
    local t2 = (-b - sqrt_disc) / (2 * a)

    local t = math.min(t1, t2)
    if t < 0 then
        t = math.max(t1, t2) -- Use the positive time if available
    end
    if t < 0 then
        return targetx, targety -- If no valid time, aim directly at the target
    end

    local lead_x = targetx + targetvx * t
    local lead_y = targety + targetvy * t

    return lead_x, lead_y -- Return the position to aim at
end

function Turret:lookAtTarget(dt)
    local dx = self.target.x - self.x
    local dy = self.target.y - self.y
    
    local target_angle = math.atan(dy / dx)
    if dx < 0 then -- for quadrants 3,4
        target_angle = math.pi + target_angle
    else
        if dy < 0 then -- ensures angle is always positive (0 - 2pi)
            target_angle = 2 * math.pi + target_angle
        end
    end


    self.targetRotation = target_angle

    if self.turnSpeed > 10 then
        self.rotation = self.targetRotation
        return
    end

    local angle = self.targetRotation - self.rotation
    local sign = 1
    if angle < 0 then -- convert the angle to a positive
        sign = -1
        angle = angle * -1
    end

    if angle > math.pi then -- if the angle is > pi than it is faster to rotate the other way
        sign = sign * -1
    end

    if math.abs(angle) < self.turnSpeed * dt then -- angle is too small
        self.rotation = self.targetRotation -- Snap to target rotation
        return 0
    end

    self.rotation = self.rotation + sign * self.turnSpeed * dt -- Rotate towards the target angle
    if self.rotation > math.pi*2 then
        self.rotation = self.rotation - math.pi*2 -- Wrap around to keep rotation in range
    elseif self.rotation < 0 then
        self.rotation = self.rotation + math.pi*2 -- Wrap around to keep rotation in range
    end
end

return Turret