local building = require("Buildings.Building")
local bullet = require("Bullets.Bullet")

Turret = setmetatable({}, { __index = building })
Turret.__index = Turret

function Turret:new(config)
    if not config then
        error("Developer Error: Turret:new called with nil config.")
    end

    local required = {"name", "fireRate", "damage", "bulletSpeed", "range", "firingArc"}
    for _, key in ipairs(required) do
        if config[key] == nil then
            error("Developer Error: Turret [" .. (config.name or "Unknown") .. "] is missing the '" .. key .. "' field in config.")
        end
    end
    
    config.shapePattern = config.shapePattern or {{0, 0}}
    config.rotation = config.rotation or 0
    config.color = config.color or {1, 1, 1, 1}
    config.barrel = config.barrel or 10

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
    
    t.bulletId = config.bulletId
    if t.bulletId then
        local BulletIndex = require("Bullets.BulletIndex")
        t.bulletDef = BulletIndex[t.bulletId]
        if not t.bulletDef then
            error("Unknown bulletId: " .. tostring(t.bulletId))
        end
        t.bulletType = t.bulletDef.class or bullet
    else
        t.bulletType = config.bulletType or bullet
    end
    t.cooldown = 0 -- Cooldown timer for firing
    t.hitEffects = config.hitEffects or {} -- Table to store hit effects
    t.target = nil  -- Target to auto aim at
    
    t.pelletCount = config.pelletCount or 1
    t.ammoMax = config.ammoMax
    if t.ammoMax then
        t.ammoCount = t.ammoMax
        t.reloadTime = config.reloadTime or 2
        t.isReloading = false
        t.reloadTimer = 0
    end
    
    -- Re-structure firingArc for internal use
    t.firingArc = {
        direction = config.firingArc.direction,
        minRange = config.firingArc.minRange,
        maxRange = config.range,
        angle = config.firingArc.angle
    }
    
    t.color = config.color
    t.baseShape = config.baseShape or "octagon"
    t.barrelShape = config.barrelShape or "single"
    t.bulletName = config.bulletName or "Bullet"
    t.lifespan = config.lifespan or 1
    t.displayLifespan = config.displayLifespan or 0.1
    t.pierce = config.pierce or 1
    t.bulletW = config.bulletW
    t.bulletH = config.bulletH
    t.bulletShape = config.bulletShape
    t.damageType = config.damageType or "normal"
    -- Effect Stats (Initialized from config, defaulting to 0)
    t.dps_poison = config.dps_poison or 0
    t.duration_poison = config.duration_poison or 0
    t.poison_from_damage = config.poison_from_damage or 0
    t.maxStacks = config.maxStacks or 0
    t.splitamount = config.splitamount or 0
    t.spread = config.spread or 0
    t.splitDamage = config.splitDamage or 0
    t.splitDamage_from_damage = config.splitDamage_from_damage or 0
    t.radius = config.radius or 0
    t.explosionDamage = config.explosionDamage or 0
    t.explosion_from_damage = config.explosion_from_damage or 0
    t.recursion = config.recursion or 0
    t.recursionSpread = config.recursionSpread or math.rad(5)
    
    t.canDirectHit = config.canDirectHit
    if t.canDirectHit == nil then t.canDirectHit = true end
    
    return t
end

function Turret:addHitEffect(effect)
    table.insert(self.hitEffects, effect)
end

function Turret:fire(args)
    if AUDIO then
        if self.sfx then
            AUDIO:playSFX(self.sfx)
        elseif not self.isMainLazer and not (self.types and self.types.mainLazer) then
            AUDIO:playSFX("gunshot_01")
        end
    end

    local currentSpread = self:getStat("spread") or 0
    local offset = love.math.random() * currentSpread * 2 - currentSpread
    local x, y
    -- Use provided position or default to fire point
    if args and args.fireX and args.fireY then
        x, y = args.fireX, args.fireY
    else
        x, y = self:getFirePoint()
    end

    local currentHitEffects = {}
    local seenEffects = {}

    if self.hitEffects then
        for _, e in ipairs(self.hitEffects) do 
            table.insert(currentHitEffects, e) 
            if e.name then seenEffects[e.name] = true end
        end
    end
    
    -- Dynamically collect hit effects from current status effects (buffs/totems)
    -- Use a seen map to prevent duplicate payloads (e.g. from multiple Explosive Totems)
    if self.effectManager then
        local function collectUnique(em)
            for _, effect in ipairs(em.activeEffects) do
                if effect.grantedHitEffect then
                    local ge = effect.grantedHitEffect
                    if not seenEffects[ge.name] then
                        table.insert(currentHitEffects, ge)
                        if ge.name then seenEffects[ge.name] = true end
                    end
                end
            end
            if em.parent then collectUnique(em.parent) end
        end
        collectUnique(self.effectManager)
    end

    local currentSpread = self:getStat("spread") or 0
    local pelletCount = self:getStat("pelletCount") or 1

    local oldAudio = AUDIO
    if pelletCount > 1 then AUDIO = nil end

    for i = 1, pelletCount do
        local offset = 0
        if pelletCount > 1 then
            offset = (math.random() - 0.5) * currentSpread
        else
            offset = love.math.random() * currentSpread * 2 - currentSpread
        end
        
        -- Vary speed slightly for shotgun blasts
        local speedFactor = 1.0
        if pelletCount > 1 then speedFactor = 0.9 + math.random() * 0.2 end
        
        local configCopy = {
            name = self:getStat("bulletName"),
            x = x,
            y = y,
            angle = (args and args.angle or self.rotation) + offset,
            bulletSpeed = self:getStat("bulletSpeed") * speedFactor,
            damage = self:getStat("damage"),
            pierce = self:getStat("pierce"),
            lifespan = self:getStat("lifespan"),
            displayLifespan = self:getStat("displayLifespan"),
            damageType = self:getStat("damageType"),
            w = self.bulletW,
            h = self.bulletH,
            shape = self.bulletShape,
            hitbox = true,
            hitEffects = currentHitEffects,
            poison_from_damage = self:getStat("poison_from_damage"),
            dps_poison = self:getStat("dps_poison"),
            duration_poison = self:getStat("duration_poison"),
            maxStacks = self:getStat("maxStacks"),
            splitamount = self:getStat("splitamount"),
            spread = self:getStat("spread"),
            splitDamage = self:getStat("splitDamage"),
            splitDamage_from_damage = self:getStat("splitDamage_from_damage"),
            radius = self:getStat("radius"),
            explosionDamage = self:getStat("explosionDamage"),
            explosion_from_damage = self:getStat("explosion_from_damage"),
            bouncesLeft = self:getStat("bouncesLeft"),
            recursion = self:getStat("recursion"),
            recursionSpread = self:getStat("recursionSpread"),
            canDirectHit = self:getStat("canDirectHit"),
            game = self.game,
            source = self,
            color = self.color,
            types = { bullet = true },
            targetX = args and args.targetX or nil,
            targetY = args and args.targetY or nil,
        }
        if self.bulletDef then
            for k, v in pairs(self.bulletDef) do
                if k ~= "class" and configCopy[k] == nil then
                    configCopy[k] = v
                end
            end
        end
        if args then
            for k, v in pairs(args) do
                if k ~= "angle" then configCopy[k] = v end
            end
        end
        self.game:addObject(self.bulletType:new(configCopy))
    end
    
    AUDIO = oldAudio
    
    if self.ammoMax then
        self.ammoCount = self.ammoCount - 1
        if self.ammoCount <= 0 then
            self.isReloading = true
            self.reloadTimer = self.reloadTime
            self.burstsRemaining = 0 -- Cancel active bursts if out of ammo
        end
    end
end

function Turret:update(dt)
    if self.effectManager then
        self.effectManager:update(dt)
    end

    if self.game.inputMode == "aiming" and self.game.inputHandler.selectedBuilding == self then
        if self.firingArc then
            self.rotation = self.firingArc.direction
            self.targetRotation = self.firingArc.direction
        end
        return
    end

    if self.isReloading then
        self.reloadTimer = self.reloadTimer - dt
        if self.reloadTimer <= 0 then
            self.isReloading = false
            self.ammoCount = self.ammoMax
        end
        return
    end

    if (self.burstsRemaining or 0) > 0 then
        self.burstTimer = self.burstTimer - dt
        if self.burstTimer <= 0 then
            if self.target and not self.target.destroyed then
                local tx, ty = self:getTargetLeadPosition()
                self:lookAt(tx, ty, dt)
                self:fire({targetX = tx, targetY = ty, isBurst = true})
            else
                self:fire({isBurst = true})
            end
            
            self.burstsRemaining = self.burstsRemaining - 1
            if self.burstsRemaining > 0 then
                self.burstTimer = self:getStat("burstDelay") or 0.1
            end
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
                
                local angleDiff = math.abs((self.targetRotation or self.rotation) - self.rotation)
                if angleDiff > math.pi then
                    angleDiff = 2 * math.pi - angleDiff
                end
                
                if angleDiff <= 0.15 then
                    self:fire({targetX = x, targetY = y})
                    
                    local burstCount = self:getStat("burstCount") or 1
                    if burstCount > 1 then
                        self.burstsRemaining = burstCount - 1
                        self.burstTimer = self:getStat("burstDelay") or 0.1
                    end
                    
                    self.cooldown = 1 / currentFireRate
                end
            end
        end
    end
end

function Turret:draw(drawx, drawy)
    local cx, cy = drawx or self.x, drawy or self.y
    if not drawx and not drawy then
        cx, cy = self:getCenterPosition()
    end

    if self.showArc then
        self:drawFiringArc(cx, cy, 0.4)
    end
    
    local r, g, b, a = unpack(self.color or {1, 1, 1, 1})

    -- 1. Draw Turret Base
    local function drawBaseShape()
        if self.drawCustomBase then
            self:drawCustomBase(cx, cy)
            return
        end
        local s = self.baseShape
        local radius = 9
        if s == "octagon" then
            local points = {}
            for i = 0, 7 do
                local angle = i * (math.pi * 2 / 8) + math.pi / 8
                table.insert(points, cx + math.cos(angle) * radius)
                table.insert(points, cy + math.sin(angle) * radius)
            end
            love.graphics.polygon("line", points)
        elseif s == "diamond" then
            love.graphics.polygon("line", cx, cy-11, cx+11, cy, cx, cy+11, cx-11, cy)
        elseif s == "square" then
            love.graphics.rectangle("line", cx-9, cy-9, 18, 18, 2, 2)
        elseif s == "circle" then
            love.graphics.circle("line", cx, cy, 10)
        elseif s == "hexagon" then
            local pts = {}
            for i = 0, 5 do
                local angle = i * (math.pi * 2 / 6)
                table.insert(pts, cx + math.cos(angle) * 10)
                table.insert(pts, cy + math.sin(angle) * 10)
            end
            love.graphics.polygon("line", pts)
        end
    end

    -- Sharper Neon Glow (2 layers, tighter widths)
    for i = 2, 1, -1 do
        love.graphics.setColor(r, g, b, 0.15 * (3 - i))
        love.graphics.setLineWidth(i * 2.5)
        drawBaseShape()
    end
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(1.5)
    drawBaseShape()

    -- 2. Draw Rotating Barrel
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(self.rotation)

    local function drawBarrelShape()
        if self.drawCustomBarrel then
            self:drawCustomBarrel()
            return
        end
        local s = self.barrelShape
        if s == "single" then
            love.graphics.rectangle("line", 0, -2, self.barrel, 4, 1, 1)
        elseif s == "double" then
            love.graphics.rectangle("line", 0, -5, self.barrel, 3, 1, 1)
            love.graphics.rectangle("line", 0, 2, self.barrel, 3, 1, 1)
        elseif s == "thick" then
            love.graphics.rectangle("line", 0, -4, self.barrel, 8, 2, 2)
        elseif s == "long" then
            love.graphics.rectangle("line", 0, -1.5, self.barrel, 3, 0.5, 0.5)
        elseif s == "flared" then
            love.graphics.polygon("line", 0, -3, self.barrel, -6.5, self.barrel, 6.5, 0, 3)
        elseif s == "funnel" then
            love.graphics.polygon("line", 2, -3, self.barrel, -6, self.barrel, 6, 2, 3)
        end
    end

    -- Barrel Neon Glow
    for i = 2, 1, -1 do
        love.graphics.setColor(r, g, b, 0.15 * (3 - i))
        love.graphics.setLineWidth(i * 2.5)
        drawBarrelShape()
    end
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    drawBarrelShape()

    -- 3. Energy core / breach glow (Sharper)
    love.graphics.setColor(r, g, b, 0.4)
    love.graphics.circle("fill", 0, 0, 3)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 0, 0, 1.5)

    love.graphics.pop()
    
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
    self.rotation = self.targetRotation
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
        self.effectManager:recalculateStats()
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
    self.rotation = self.targetRotation
end

return Turret
