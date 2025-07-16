local living_object = require("Scripts.living_object")
local Enemy = setmetatable({}, living_object)
Enemy.__index = Enemy

function Enemy:new(config)
    local obj = setmetatable(living_object:new(config), { __index = self })
    obj.speed = config.speed or 10
    obj.damage = config.damage or 10
    obj.xp = config.xp or 10
    return obj
end

function Enemy:update(dt)
    self.x = self.x - (self.speed * dt)
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

return Enemy