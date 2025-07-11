Bullet = {}
Bullet.__index = Bullet

function Bullet:new(x, y, angle, game)
    local b = {
        x = x,
        y = y,
        angle = angle or 0,
        speed = 400,
        damage = 10,
        radius = 4,
        dead = false,
        game = game,
        pierce = 1,
        hitCache = {},
        hitEffects = {}
    }
    setmetatable(b, self)
    return b
end

function Bullet:update(dt)
    self.x = self.x + math.cos(self.angle) * self.speed * dt
    self.y = self.y + math.sin(self.angle) * self.speed * dt

    -- Check collisions
    for _, enemy in ipairs(game.enemies) do
        if self:collidesWith(enemy) and not self.dead then
            self:onHit(enemy)
        end
    end
end

function Bullet:collidesWith(enemy)
    local dx = self.x - enemy.x
    local dy = self.y - enemy.y
    local dist = math.sqrt(dx * dx + dy * dy)
    return dist < (self.radius + enemy.radius)
end

function Bullet:onHit(enemy)
    self.pierce = self.pierce - 1
    if self.pierce <= 0 then
        self.dead = true
    end
    enemy:takeDamage(self.damage)
    for _, effect in ipairs(self.hitEffects) do
        effect(self, enemy) 
    end
end

function Bullet:draw()
    love.graphics.circle("fill", self.x, self.y, self.radius)
end