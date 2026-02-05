local object = require("Classes.object")
--local collision = require("Physics.collisionSystem")

Bullet = setmetatable({}, object)
Bullet.__index = Bullet

local stats = {
    speed = 400, -- Speed of the bullet
    damage = 10, -- Damage dealt by the bullet
    pierce = 1, -- Number of enemies the bullet can pierce
    hitEffects = {}, -- Effects to apply on hit
    lifespan = 5, -- Lifespan of the bullet in seconds
    tag = "bullet", -- Tag for collision detection
    hitbox = true, -- Bullets have hitboxes
    shape = "rectangle",
    w = 4,
    h = 4,
}

function Bullet:new(config)
    for key, value in pairs(stats) do
        config[key] = config[key] or value -- Use default values if not provided
    end
    config.tag = "bullet" -- Set the tag for collision detection
    local b = setmetatable(object:new(config), { __index = self }) -- Create a new object with the base properties
    b.angle = config.angle or 0 -- Angle of the bullet
    b.hitCache = config.hitCache or {} -- Cache for hit enemies to avoid multiple hits
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
        if type(effect) == "function" then
            error("Bullet hitEffect should be a table with func field, not a direct function.")
            effect(self, enemy)
        elseif type(effect) == "table" and effect.func then
            effect.func(self, enemy)
        end
    end
    if self.pierce <= 0 then
        self:died()
    end
end

return Bullet