explosions = require("Effects.explosions")
local bullet = {
    z, r,
    targetX, targetY,
    startX, startY, -- Starting position of the bullet
    speed = 300, -- Speed of the bullet
    vx, vy, vz, -- Velocity components
    peakHeight = 200, -- Peak height of the bullet arc
    timescale = 2,
    flytime = 1,
    destroyed = 0,
    explosion_radius = 100, -- Radius of the explosion effect
    explosion_duration = 0.5,
    color = {1, 0, 0}, -- Color of the bullet
}

function bullet:newInstance()
    local obj = setmetatable({}, {__index = self})
    return obj
end

function bullet:update(dt, enemies, effects)
    self.elapsedTime = self.elapsedTime + dt
    self.x, self.y, self.z = self:getProjectilePosition(self.startX, self.startY, self.targetX, self.targetY, self.elapsedTime, self.totalTime)
    if self.z < 0 then
        self:hit(enemies, effects) -- Ensure z does not go below ground level
    end
end

function bullet:hit(enemies, effects)
    table.insert(effects, explosions:new(self.x, self.y, self.explosion_radius, self.explosion_duration)) -- Create an explosion effect
    for i, target in ipairs(enemies) do
        if target.x and target.y then
            local distance = ((target.x - self.x)^2 + (target.y - self.y)^2)^0.5 -- Calculate distance to the target
            if distance < self.explosion_radius then -- Check if the target is within the bullet's radius
                target:takeDamage(self.damage * (self.explosion_radius - distance) / self.explosion_radius) -- Deal damage to the target
            end
        end
    end
    self.destroyed = 1 -- Mark the bullet as destroyed
    self.x = -1000 -- Move the bullet off-screen
end

function bullet:draw()
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.x, self.y - self.z, self.r) -- Draw the bullet as a circle
    love.graphics.setColor(0.1, 0.1, 0.1, 0.1) -- Reset color to white for text
    love.graphics.circle("fill", self.x, self.y, self.r + 4*self.z/self.peakHeight) -- Draw the target as a small circle
end

function bullet:new(x, y, targetX, targetY, damage)
    self.damage = damage or 50 -- Default damage if not provided
    local distanceFactor = ((targetX - x)^2 + (targetY - y)^2)^0.5 / 1000 -- Scale distance to a factor for the projectile
    if distanceFactor < 1 then
        distanceFactor = 1 -- Ensure a minimum distance factor to avoid division by zero
    end
    local obj = setmetatable({}, {__index = self})
    obj.targetX = targetX
    obj.targetY = targetY
    obj.x = x -- Initial x position
    obj.y = y -- Initial y position
    obj.z = 0 -- Initial z position (height)
    obj.r = self.r or 5 -- Radius of the bullet
    obj.startX = x -- Starting x position
    obj.startY = y -- Starting y position
    obj.totalTime = self.timescale * distanceFactor * self.flytime -- Total time for the projectile to reach the target
    obj.peakHeight = self.peakHeight * distanceFactor * self.flytime -- Peak height of the bullet arc
    obj.elapsedTime = 0
    obj.destroyed = 0 -- Bullet is not destroyed initially
    return obj
end

function bullet:getProjectilePosition(startX, startY, endX, endY, timeElapsed, totalTime)
    local t = timeElapsed / totalTime
    local x = startX + (endX - startX) * t
    local y = startY + (endY - startY) * t  -- Adjust for desired arc
    local z = self.peakHeight * 4 * t * (1 - t)  -- Parabolic arc
    return x, y, z
end

-- local function velocity(x, y, speed)
--     local length = (x * x + y * y) ^ 0.5
--     if length < 0 then
--         return 0, 0
--     end
--     return (x / length) * speed, (y / length) * speed
-- end

return bullet