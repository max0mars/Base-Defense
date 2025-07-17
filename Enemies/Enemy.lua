local living_object = require("Scripts.living_object")
local Enemy = setmetatable({}, {__index = living_object})
Enemy.__index = Enemy

function Enemy:new(config)
    config.tag = "enemy" -- Set the tag for collision detection
    local obj = living_object:new(config)
    setmetatable(obj, { __index = self })
    obj.speed = config.speed or 10
    obj.damage = config.damage or 10
    obj.xp = config.xp or 10
    obj.target = obj.game.base.x + obj.game.base.w / 2 + (obj.size or obj.w/2)
    return obj
end

function Enemy:update(dt)
    if self.destroyed then return end
    self.x = self.x - (self.speed * dt)
    if self.x < self.target then
        self.game.base:takeDamage(self.damage) -- Damage the base if the enemy reaches it
        self:died() -- Destroy the enemy if it reaches the base
    end
end

function Enemy:getVelocity()
    return -self.speed, 0 -- Enemies move left by default
end

function Enemy:onCollision(obj)
    if obj.tag == 'base' then
        obj:takeDamage(self.damage)
        self:died() -- Destroy enemy on collision with base
    end
end

function Enemy:died()
    self.game:addXP(self.xp) -- Give XP to the game when the enemy dies
    self:destroy() -- Call the destroy method from the base living_object
end

function Enemy:getTargetPos()
    self.target = self.game.base.x + self.game.base.w / 2 + (self.size or self.w/2)
end

function Enemy:checkBaseCollision()
    if self.x <= self.target then
        return true
    end
    return false
end

return Enemy