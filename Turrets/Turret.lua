local object = require("Scripts.object")

Turret = setmetatable({}, object)
Turret.__index = Turret

function Turret:new(config)
    local t = setmetatable(object:new(config), { __index = self }) -- Create a new object with the base properties
    t.rotation = config.rotation or 0 -- Initial rotation of the turret
    t.targetRotation = t.rotation -- Target rotation for smooth aiming
    t.turnSpeed = config.turnSpeed or 0.3 -- Speed of turret rotation
    t.mode = config.mode or "auto"  -- "auto" for auto-aim, "manual" for manual aiming
    t.fireRate = config.fireRate or 0.05 -- Rate of fire in seconds
    t.bulletType = config.bulletType or require('Bullets.Bullet')
    t.cooldown = 0 -- Cooldown timer for firing
    t.hitEffects = {} -- Table to store hit effects
    t.damage = config.damage or 2 -- Damage dealt by the turret
    t.target = nil  -- Target to auto aim at
    t.spread = config.spread or 0 -- Spread for bullets
    return t
end


function Turret:addHitEffect(effectFunc)
    table.insert(self.hitEffects, effectFunc)
end

function Turret:fire()
    local offset = love.math.random() * self.spread * 2 - self.spread
    local x, y = self:getFirePoint()
    config = {
        x = x,
        y = y,
        angle = self.rotation + offset, -- Add spread to the angle
        speed = 400, -- Speed of the bullet
        damage = self.damage, -- Damage dealt by the bullet
        pierce = 1, -- Number of enemies the bullet can pierce
        hitEffects = self.hitEffects, -- Effects to apply on hit
        lifespan = 5, -- Lifespan of the bullet
        game = self.game -- Reference to the game object
    }
    local b = self.bulletType:new(config)
    b.damage = self.damage

    -- Add upgrades to bullet
    b.hitEffects = {}
    for _, effect in ipairs(self.hitEffects) do
        table.insert(b.hitEffects, effect)
    end
    self.game:addObject(b) -- Add the bullet to the game's object list
end

function Turret:update(dt)
    self.cooldown = self.cooldown - dt

    if self.mode == "auto" then
        self:getTarget()
        if self.target then
            self:lookAtTarget(dt)
            if self.cooldown <= 0 then
                self:fire()
                self.cooldown = self.fireRate
            end
        end
    else
        -- Manual aiming mode
        local mx, my = love.mouse.getPosition()
        self:lookAt(mx, my, dt)
        if love.mouse.isDown(1) and self.cooldown <= 0 then
            self:fire()
            self.cooldown = self.fireRate
        end
    end
end

function Turret:draw()

    -- Draw turret mount
    love.graphics.setColor(0, 0, 1)
    love.graphics.circle("fill", self.x, self.y, 8)

    -- Draw barrel
    love.graphics.setColor(1, 1, 1)
    love.graphics.line(
        self.x, self.y,
        self.x + math.cos(self.rotation) * 20,
        self.y + math.sin(self.rotation) * 20
    )
end

function Turret:getTarget()
    if self.target and self.target.destroyed then
        self.target = nil -- Reset target if it is destroyed
    elseif self.target then
        return self.target -- Return the current target if it is still valid
    end-- If we already have a target, no need to search again
    local dist = math.huge -- Start with a very large distance
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

function Turret:getFirePoint()
    return self.x + math.cos(self.rotation) * 20, self.y + math.sin(self.rotation) * 20
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

    local angle = target_angle - self.rotation
    print(angle)
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

    local angle = self.targetRotation - self.rotation
    print(angle)
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