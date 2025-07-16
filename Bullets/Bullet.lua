local object = require("Scripts.object")

Bullet = setmetatable({}, object)
Bullet.__index = Bullet

function Bullet:new(x, y, angle, game)
    local b = {
        x = x,
        y = y,
        angle = angle or 0,
        speed = 400,
        damage = 10,
        radius = 2,
        color = {1, 1, 0}, -- Yellow color for bullets
        destroyed = false,
        game = game,
        pierce = 1,
        hitCache = {},
        hitEffects = {},
        lifespan = 5, -- Bullet lifespan in seconds
    }
    setmetatable(b, self)
    return b
end

function Bullet:update(dt)
    if self.destroyed then return end
    self.lifespan = self.lifespan - dt
    if self.lifespan <= 0 then
        self.destroyed = true
        return
    end
    self.x = self.x + math.cos(self.angle) * self.speed * dt
    self.y = self.y + math.sin(self.angle) * self.speed * dt
end



function Bullet:onHit(enemy)
    self.pierce = self.pierce - 1
    if self.pierce <= 0 then
        self.destroyed = true
    end
    enemy:takeDamage(self.damage)
    for _, effect in ipairs(self.hitEffects) do
        effect(self, enemy) 
    end
end

function Bullet:draw()
    if self.destroyed then return end
    love.graphics.setColor(self.color[1], self.color[2], self.color[3]) -- Yellow color for bullets
    love.graphics.circle("fill", self.x, self.y, self.radius)
end

return Bullet