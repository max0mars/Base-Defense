-- CinderBullet.lua - Hot cinder lobbed by the Cinder Mortar.
--
-- Fired several at a time like shotgun pellets: each lands somewhere within
-- SCATTER of the aim point and becomes a cinder on the ground. The first enemy
-- to walk over a cinder takes the bullet's damage as fire damage plus
-- STACKS burn, and the cinder goes out. Unclaimed cinders fade after LIFETIME.

local LobberBullet = require("Bullets.LobberBullet")
local FireZoneEffect = require("Spells.FireZoneEffect")

local CinderBullet = setmetatable({}, LobberBullet)
CinderBullet.__index = CinderBullet

CinderBullet.SCATTER = 45
CinderBullet.STACKS = 3
CinderBullet.LIFETIME = 6
CinderBullet.CINDER_RADIUS = 5

function CinderBullet:new(config)
    -- Scatter the landing point over a disc so the pellets spread out
    if config.targetX and config.targetY then
        local a = math.random() * math.pi * 2
        local d = math.sqrt(math.random()) * CinderBullet.SCATTER
        config.targetX = config.targetX + math.cos(a) * d
        config.targetY = config.targetY + math.sin(a) * d
    end
    config.explodeOnGroundOnly = true
    local b = LobberBullet.new(self, config)
    setmetatable(b, self)
    return b
end

function CinderBullet:onGroundImpact()
    FireZoneEffect.spawn(self.game, {
        name = "cinder",
        x = self.x, y = self.y,
        radius = CinderBullet.CINDER_RADIUS,
        duration = CinderBullet.LIFETIME,
        singleUse = true,
        touchDamage = self:getStat("damage"),
        stacksPerTick = CinderBullet.STACKS,
        source = self,
    }, "cinder")
    self:died()
end

function CinderBullet:draw()
    local x, y = self.x, self.y - self.z
    love.graphics.push("all")
    love.graphics.setColor(1, 0.4, 0.05, 0.4)
    love.graphics.circle("fill", x, y, 4)
    love.graphics.setColor(1, 0.75, 0.3, 1)
    love.graphics.circle("fill", x, y, 2)
    love.graphics.pop()
end

return CinderBullet
