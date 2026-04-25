local bullet = require("Bullets.Bullet")

local RicochetBullet = setmetatable({}, bullet)
RicochetBullet.__index = RicochetBullet

function RicochetBullet:new(config)
    config.maxBounces = config.maxBounces or 3
    config.bounces = 0

    local b = bullet:new(config)
    setmetatable(b, self)

    b.maxBounces = config.maxBounces
    b.bounces = config.bounces
    b.hasLeftBase = false

    return b
end

function RicochetBullet:update(dt)
    if self.destroyed then return end

    self.lifespan = self.lifespan - dt
    if self.lifespan <= 0 then
        self:died()
        return
    end

    self.x = self.x + math.cos(self.angle) * self:getStat("bulletSpeed") * dt
    self.y = self.y + math.sin(self.angle) * self:getStat("bulletSpeed") * dt

    -- Track when bullet has left the base area
    local g = self.game.ground
    local baseRight = self.game.base.x + self.game.base.w / 2
    if not self.hasLeftBase and self.x > baseRight then
        self.hasLeftBase = true
    end

    -- Die at right edge (end of battlefield) always, and left edge only after leaving base
    if self.x >= g.x + g.w then
        self:died()
        return
    end
    if self.hasLeftBase and self.x <= baseRight then
        self:died()
        return
    end

    -- Bounce off top and bottom boundaries only
    local bounced = false
    if self.y < g.y then
        self.angle = -self.angle
        self.y = g.y
        bounced = true
    elseif self.y > g.y + g.h then
        self.angle = -self.angle
        self.y = g.y + g.h
        bounced = true
    end

    if bounced then
        self.bounces = self.bounces + 1
        if self.bounces > self.maxBounces then
            self:died()
        end
    end
end

function RicochetBullet:onHit(target)
    -- Visual feedback
    self.game:spawnParticleExplosion(self.color, 8, self.x, self.y)

    if target then
        self.hitCache[target:getID()] = true
    end

    -- Trigger independent effects
    if self.hitEffects then
        for _, effectTemplate in ipairs(self.hitEffects) do
            if effectTemplate.isIndependent then
                if effectTemplate.trigger then
                    effectTemplate:trigger(target, self)
                end
            end
        end
    end

    -- Direct damage and status effects
    if self:getStat("canDirectHit") then
        if target then
            target:takeDamage(self:getStat("damage"), self.damageType)
        end

        if self.hitEffects then
            for _, effectTemplate in ipairs(self.hitEffects) do
                if not effectTemplate.isIndependent and target and target.effectManager then
                    target.effectManager:applyEffect(effectTemplate, self)
                end
            end
        end
    end

    self.pierce = self.pierce - 1
    if self.pierce <= 0 then
        -- Instead of dying, try to bounce toward nearest enemy
        local nearest = self:findNearestEnemy()
        if nearest and self.bounces < self.maxBounces then
            self.bounces = self.bounces + 1
            self.angle = math.atan2(nearest.y - self.y, nearest.x - self.x)
            -- Reset pierce for the next leg
            self.pierce = 1
        else
            self:died()
        end
    end
end

function RicochetBullet:findNearestEnemy()
    local closestDist = math.huge
    local closest = nil

    for _, obj in ipairs(self.game.objects) do
        if obj:isType("enemy") and not obj.destroyed and not self.hitCache[obj:getID()] then
            local dx = obj.x - self.x
            local dy = obj.y - self.y
            local dist = dx * dx + dy * dy
            if dist < closestDist then
                closestDist = dist
                closest = obj
            end
        end
    end

    return closest
end

function RicochetBullet:draw()
    love.graphics.setColor(self.color or {1, 1, 1, 1})
    if self.shape == "rectangle" then
        love.graphics.rectangle("fill", self.x - self.w / 2, self.y - self.h / 2, self.w, self.h)
    elseif self.shape == "circle" then
        love.graphics.circle("fill", self.x, self.y, self.size or (self.w / 2))
    end
end

return RicochetBullet
