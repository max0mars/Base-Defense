Turret = {}
Turret.__index = Turret

function Turret:new(config, game)
    local t = {
        -- Position relative to world
        x = config.x or 50,
        y = config.y or 300,

        -- Local rotation for aiming
        rotation = 0,
        targetRotation = 0, -- Target rotation for smooth aiming
        turnSpeed = config.turnSpeed or .3, -- Speed of turret rotation
        mode = config.mode or "auto",  -- "auto" for auto-aim, "manual" for manual aiming
        -- Firing properties
        fireRate = config.fireRate or .05,
        bulletType = require('Bullets.Bullet'),
        cooldown = 0,

        -- Upgrades: e.g. hit effects, damage bonus
        hitEffects = {},
        damage = config.damage or 2,
        target = nil,  -- Target to auto aim at
        game = game,
        spread = config.spread or math.rad(3), -- Spread for bullets
        testval = 0, -- For debugging purposes
    }
    setmetatable(t, self)
    return t
end


function Turret:addHitEffect(effectFunc)
    table.insert(self.hitEffects, effectFunc)
end

function Turret:fire()
    local offset = love.math.random() * self.spread * 2 - self.spread
    local x, y = self:getFirePoint()
    local b = self.bulletType:new(x, y, self.rotation + offset, self.game)
    b.damage = self.damage

    -- Add upgrades to bullet
    b.hitEffects = {}
    for _, effect in ipairs(self.hitEffects) do
        table.insert(b.hitEffects, effect)
    end

    table.insert(self.game.bullets, b)
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
        -- Manual aiming mode, do nothing or implement manual controls
        -- For example, you could use mouse position to aim
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
    love.graphics.printf("Turret Rotation: ".. self.rotation, 50, 20, 100, "center")
    love.graphics.printf("Target Rotation: ".. self.targetRotation, 50, 40, 100, "center")

end

function Turret:getTarget()
    if self.target and self.target.destroyed then
        self.target = nil -- Reset target if it is destroyed
    elseif self.target then
        return 
    end-- If we already have a target, no need to search again
    local dist = math.huge -- Start with a very large distance
    for _, enemy in ipairs(self.game.enemies) do
        if enemy.x and enemy.y then
            local newdist = (enemy.x - self.x)^2 + (enemy.y - self.y)^2 -- Calculate squared distance to avoid sqrt for performance
            if(newdist < dist) then
                dist = newdist -- Calculate distance to the enemy
                self.target = enemy
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

function vectorfromangle(rads, mag) -- creates a vector when given an angle and a length/magnitude
    if (mag == nil) then mag = 1 end
    return {math.sin(rads) * mag, math.cos(rads) * mag}
end

return Turret