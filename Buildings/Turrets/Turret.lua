local building = require("Buildings.Building")
local bullet = require("Bullets.Bullet")

Turret = setmetatable({}, { __index = building })
Turret.__index = Turret

function Turret:new(config)
    if not config then
        error("Developer Error: Turret:new called with nil config.")
    end

    local required = {"name", "rotation", "turnSpeed", "fireRate", "damage", "bulletSpeed", "range", "barrel", "firingArc", "shapePattern", "color"}
    for _, key in ipairs(required) do
        if config[key] == nil then
            error("Developer Error: Turret [" .. (config.name or "Unknown") .. "] is missing the '" .. key .. "' field in config.")
        end
    end

    -- Nested validation for firingArc
    local arcRequired = {"direction", "minRange", "angle"}
    for _, key in ipairs(arcRequired) do
        if config.firingArc[key] == nil then
            error("Developer Error: Turret [" .. (config.name or "Unknown") .. "] is missing 'firingArc." .. key .. "' in config.")
        end
    end
    
    config.effectManager = true
    
    local t = setmetatable(building:new(config), { __index = self }) 
    
    t.targetRotation = t.rotation -- Target rotation for smooth aiming
    t.bulletType = config.bulletType or bullet
    t.cooldown = 0 -- Cooldown timer for firing
    --t.hitEffects = config.hitEffects or {} -- Table to store hit effects
    t.target = nil  -- Target to auto aim at
    
    -- Re-structure firingArc for internal use
    t.firingArc = {
        direction = config.firingArc.direction,
        minRange = config.firingArc.minRange,
        maxRange = config.range,
        angle = config.firingArc.angle
    }
    
    t.showArc = false -- Flag to show firing arc
    t.selected = false -- Flag to show if turret is selected
    
    return t
end

function Turret:addHitEffect(effect)
    table.insert(self.hitEffects, effect)
end

function Turret:fire(args)
    local offset = 0 --love.math.random() * self.spread * 2 - self.spread
    local x, y
    -- Use provided position or default to fire point
    if args and args.fireX and args.fireY then
        x, y = args.fireX, args.fireY
    else
        x, y = self:getFirePoint()
    end

    local config = {
        name = self:getStat("bulletName"),
        x = x,
        y = y,
        angle = self.rotation + offset, -- Add spread to the angle
        bulletSpeed = self:getStat("bulletSpeed"), -- Speed of the bullet
        damage = self:getStat("damage"), -- Damage dealt by the bullet
        pierce = self:getStat("pierce"),
        lifespan = self:getStat("lifespan"),
        damageType = self:getStat("damageType"),
        w = self.bulletW,
        h = self.bulletH,
        shape = self.bulletShape,
        hitbox = true,
        hitEffects = self.hitEffects or {}, -- Effects to apply on hit
        game = self.game, -- Reference to the game object
        source = self,
        tags = {"bullet"},
        types = { bullet = true },
        targetX = args and args.targetX or nil,
        targetY = args and args.targetY or nil,
    }
    -- If args has extra keys, override config
    if args then
        for k, v in pairs(args) do
            config[k] = v
        end
    end

    --self.bulletType:new(config)
    self.game:addObject(self.bulletType:new(config))
end

function Turret:update(dt)
    -- Do not acquire targets or shoot while the player is setting the firing arc
    if self.game.inputMode == "aiming" and self.game.inputHandler.selectedBuilding == self then
        if self.firingArc then
            self.rotation = self.firingArc.direction
            self.targetRotation = self.firingArc.direction
        end
        return
    end

    self.cooldown = self.cooldown - dt
    self:getTargetArc()
    if self.target then
        local x, y = self.target.x, self.target.y
        self:lookAt(x, y, dt) -- Aim at the target's lead position
        if self.cooldown <= 0 then
            local currentFireRate = self:getStat("fireRate")
            if currentFireRate > 0 then
                x, y = self:getTargetLeadPosition()
                self:lookAt(x, y, dt)
                self:fire({targetX = x, targetY = y})
                self.cooldown = 1 / currentFireRate
            end
        end
    end
end

function Turret:draw(drawx, drawy)
    local cx, cy = drawx or self.x, drawy or self.y
    -- If no override provided, default to the building's logical center
    if not drawx and not drawy then
        cx, cy = self:getCenterPosition()
    end

    -- Draw firing arc if showArc flag is set
    if self.showArc then
        self:drawFiringArc(cx, cy, 0.4)
    end
    
    love.graphics.setColor(self.color)
    -- Draw turret mount
    love.graphics.circle("fill", cx, cy, 8)

    -- Draw barrel
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.line(
        cx, cy,
        cx + math.cos(self.rotation) * self.barrel,
        cy + math.sin(self.rotation) * self.barrel
    )
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Turret:drawFiringArc(drawx, drawy, alpha)
    drawx = drawx or self.x
    drawy = drawy or self.y
    alpha = alpha or 0.3
    love.graphics.setColor(0.5, 0.5, 0.5, alpha) -- Grey with transparency
    
    -- Calculate arc bounds using firing arc direction
    local startAngle = self.firingArc.direction - self.firingArc.angle / 2
    local endAngle = self.firingArc.direction + self.firingArc.angle / 2
    
    -- Draw the firing arc as a sector
    if self.firingArc.minRange > 0 then
        -- Draw arc with inner and outer radius
        self:drawArcSector(drawx, drawy, self.firingArc.minRange, self:getStat("range"), startAngle, endAngle)
    else
        -- Draw simple arc from center
        self:drawArcSector(drawx, drawy, 0, self:getStat("range"), startAngle, endAngle)
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
    local range = self:getStat("range")
    local dist = range * range -- Use squared distance to avoid sqrt for performance
    for _, obj in ipairs(self.game.objects) do
        if obj:isType("enemy") and not obj.destroyed then
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
        if obj:isType("enemy") and not obj.destroyed then
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
    if distance < self.firingArc.minRange or distance > self:getStat("range") then
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
    local cx, cy = self:getCenterPosition()
    return cx + math.cos(self.rotation) * self.barrel, cy + math.sin(self.rotation) * self.barrel
end

function Turret:lookAt(x, y, dt)
    local cx, cy = self:getCenterPosition()
    local dx = x - cx
    local dy = y - cy
    self.targetRotation = math.atan2(dy, dx)
    
    -- Normalize targetRotation to [0, 2π]
    if self.targetRotation < 0 then
        self.targetRotation = self.targetRotation + 2 * math.pi
    end

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



function Turret:getTargetLeadPosition()
    if not self.target then return self.x, self.y end
    
    local tof
    local cx, cy = self:getCenterPosition()

    -- Check if bullet type specifies a custom flight time calculation
    if self.bulletType and self.bulletType.getTOF then
        tof = self.bulletType:getTOF(self, self.target)
    else
        local bulletSpeed = self:getStat("bulletSpeed")
        if bulletSpeed <= 0 then return self.target.x, self.target.y end
        
        local dx = self.target.x - cx
        local dy = self.target.y - cy
        local initialDist = math.sqrt(dx*dx + dy*dy)
        tof = initialDist / bulletSpeed
    end
    
    -- Predict
    local leadX, leadY = self.target:getFuturePosition(tof)
    
    -- Iterative Refinement (only needed for bullets with dynamic flight times)
    if not (self.bulletType and self.bulletType.getTOF) then
        local dx2 = leadX - cx
        local dy2 = leadY - cy
        local dist2 = math.sqrt(dx2*dx2 + dy2*dy2)
        local bulletSpeed = self:getStat("bulletSpeed")
        local tof2 = dist2 / bulletSpeed
        
        leadX, leadY = self.target:getFuturePosition(tof2)
    end
    
    return leadX, leadY
end

function Turret:clearAllBuffs()
    if self.effectManager then
        for i = #self.effectManager.activeEffects, 1, -1 do
            local effect = self.effectManager.activeEffects[i]
            if effect.isBuffTotem then
                local eName = effect.name
                self.effectManager.effectCounts[eName] = (self.effectManager.effectCounts[eName] or 1) - 1
                table.remove(self.effectManager.activeEffects, i)
            end
        end
        self.effectManager:incrementVersion()
    end
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