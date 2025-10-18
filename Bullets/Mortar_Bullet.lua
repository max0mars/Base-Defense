explosions = require("Effects.explosions")
local object = require("Classes.object")
bullet = setmetatable({}, object)
bullet.__index = bullet

local default = {
    speed = 300, -- Speed of the bullet
    peakHeight = 250, -- Peak height of the bullet arc
    timescale = 2,
    flytime = 1,
    explosion_radius = 100, -- Radius of the explosion effect
    explosion_duration = 0.5,
    color = {1, 0, 0}, -- Color of the bullet
}

function bullet:newInstance()
    local obj = setmetatable({}, {__index = self})
    return obj
end

function bullet:update(dt)
    self.elapsedTime = self.elapsedTime + dt
    self.x, self.y, self.z = self:getProjectilePosition(self.startX, self.startY, self.targetX, self.targetY, self.elapsedTime, self.totalTime)
    if self.z < 0 then
        self:hit() -- Ensure z does not go below ground level
    end
end

function bullet:hit()
    self.game:addObject(explosions:new(self.x, self.y, self.explosion_radius, self.explosion_duration))
    for i, target in ipairs(self.game.objects) do
        if target.x and target.y and target.tag == "enemy" then
            local distance = (((target.x - self.x))^2 + (target.y - self.y)^2)^0.5 -- Calculate distance to the target
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

function bullet:new(config)
    for key, value in pairs(default) do
        config[key] = config[key] or value -- Use default values if not provided
    end
    --self.damage = config.damage or 50 -- Default damage if not provided
    local distanceFactor = ((config.targetX - config.x)^2 + (config.targetY - config.y)^2)^0.5 / 1000 -- Scale distance to a factor for the projectile
    if distanceFactor < 1 then
        distanceFactor = 1 -- Ensure a minimum distance factor to avoid division by zero
    end
    local obj = setmetatable(object:new(config), { __index = self })
    obj.targetX = config.targetX
    obj.targetY = config.targetY
    obj.x = config.x -- Initial x position
    obj.y = config.y -- Initial y position
    obj.z = 0 -- Initial z position (height)
    obj.r = self.r or 5 -- Radius of the bullet
    obj.startX = config.x -- Starting x position
    obj.startY = config.y -- Starting y position
    obj.totalTime = config.timescale * distanceFactor * config.flytime -- Total time for the projectile to reach the target
    obj.peakHeight = config.peakHeight * distanceFactor * config.flytime -- Peak height of the bullet arc
    obj.elapsedTime = 0
    obj.destroyed = false -- Bullet is not destroyed initially
    obj.tag = "mortar_bullet"
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