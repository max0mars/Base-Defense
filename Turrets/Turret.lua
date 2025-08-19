local object = require("Classes.object")
local bullet = require("Bullets.Bullet")

Turret = setmetatable({}, object)
Turret.__index = Turret

function Turret:new(config)
    local t = setmetatable(object:new(config), { __index = self }) -- Create a new object with the base properties
    t.rotation = config.rotation or 0 -- Initial rotation of the turret
    t.targetRotation = t.rotation -- Target rotation for smooth aiming
    t.turnSpeed = config.turnSpeed or math.huge -- Speed of turret rotation
    t.mode = config.mode or "auto"  -- "auto" for auto-aim, "manual" for manual aiming
    t.fireRate = config.fireRate or 0.2 -- Rate of fire in seconds
    t.bulletType = config.bulletType or bullet
    t.cooldown = 0 -- Cooldown timer for firing
    t.hitEffects = {} -- Table to store hit effects
    t.damage = config.damage or 10 -- Damage dealt by the turret
    t.target = nil  -- Target to auto aim at
    t.spread = config.spread or 0 -- Spread for bullets
    t.bulletSpeed = config.bulletSpeed or 400
    t.range = config.range or math.huge
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
        speed = self.bulletSpeed, -- Speed of the bullet
        damage = self.damage, -- Damage dealt by the bullet
        pierce = 1, -- Number of enemies the bullet can pierce
        hitEffects = self.hitEffects, -- Effects to apply on hit
        lifespan = 5, -- Lifespan of the bullet
        game = self.game, -- Reference to the game object
        color = {1, 1, 1, 1}, -- Default color for the bullet
        size = 3, -- Size of the bullet
        shape = "circle", -- Shape of the bullet
        tag = "bullet", -- Tag for collision detection
        hitbox = {
            shape = "circle", -- Hitbox shape for the bullet
        }
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
            local x,y = self:getTargetLeadPosition()
            self:lookAt(x, y, dt) -- Aim at the target's lead position
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
    -- love.graphics.setColor(1, 1, 1)
    -- love.graphics.setLineWidth(3) -- Set barrel thickness
    -- love.graphics.line(
    --     self.x, self.y,
    --     self.x + math.cos(self.rotation) * 20,
    --     self.y + math.sin(self.rotation) * 20
    -- )
    -- love.graphics.setLineWidth(1) -- Reset line width to default
    --love.graphics.printf("Rotation: " .. self.rotation, self.x - 40, self.y - 40, 200, "center")
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