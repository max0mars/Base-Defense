local object = require("Classes.object")
local collision = require("Physics.collisionSystem")

Bullet = setmetatable({}, object)
Bullet.__index = Bullet

function Bullet:new(config)
    local b = setmetatable(object:new(config), { __index = self }) -- Create a new object with the base properties
    b.angle = config.angle or 0 -- Angle of the bullet
    b.speed = config.speed or 400 -- Speed of the bullet
    b.damage = config.damage or 10 -- Damage dealt by the bullet
    b.pierce = config.pierce or 1 -- Number of enemies the bullet can pierce
    b.hitCache = {} -- Cache for hit enemies to avoid multiple hits
    b.hitEffects = config.hitEffects or {} -- Effects to apply on hit
    b.lifespan = config.lifespan or 5 -- Lifespan of the
    return b
end

function Bullet:update(dt)
    if self.destroyed then return end
    if self.x > self.game.ground.x + self.game.ground.w or self.x < self.game.ground.x or self.y < self.game.ground.y or self.y > self.game.ground.y + self.game.ground.h then
        self:died() -- bullet hit wall
        return
    end
    self.lifespan = self.lifespan - dt
    if self.lifespan <= 0 then
        self:died()
        return
    end
    -- Store previous position
    local oldX, oldY = self.x, self.y
    
    -- Calculate new position
    self.x = self.x + math.cos(self.angle) * self.speed * dt
    self.y = self.y + math.sin(self.angle) * self.speed * dt
end

function Bullet:onCollision(obj)
    if obj.tag == 'enemy' and not self.hitCache[obj:getID()] then
        self.hitCache[obj:getID()] = true -- Mark this enemy as hit
        self:onHit(obj) -- Call the hit function
    end
end

function Bullet:onHit(enemy)
    self.pierce = self.pierce - 1
    enemy:takeDamage(self.damage)
    for _, effect in ipairs(self.hitEffects) do
        effect(self, enemy) 
    end
    if self.pierce <= 0 then
        self:died()
    end
end

return Bullet