-- CryoBeam.lua - Continuous beam that locks onto one enemy until it dies,
-- leaves the firing arc, or freezes (it also skips thawing enemies).
--
-- The beam deals damage and applies its hit effects (chill) in ticks:
-- `fireRate` ticks per second, `damage` per tick. Keeping it tick-based means
-- damage / fire-rate buffs work like on any other turret and damage numbers
-- stay readable.

local Turret = require("Buildings.Turrets.Turret")
local Chill = require("Game.Effects.StatusEffects.Chill")

local CryoBeam = setmetatable({}, { __index = Turret })
CryoBeam.__index = CryoBeam

function CryoBeam:new(config)
    local t = Turret:new(config)
    setmetatable(t, { __index = self })
    t.cooldown = 0
    return t
end

function CryoBeam:update(dt)
    if self.effectManager then
        self.effectManager:update(dt)
    end

    if self.game.inputMode == "aiming" and self.game.inputHandler.selectedBuilding == self then
        self.rotation = self.firingArc.direction
        self.targetRotation = self.firingArc.direction
        self.target = nil
        return
    end

    self:acquireTarget()
    if not self.target then
        self.cooldown = 0 -- tick immediately on the next lock
        return
    end

    self:lookAt(self.target.x, self.target.y, dt)

    self.cooldown = self.cooldown - dt
    local fireRate = self:getStat("fireRate")
    while self.cooldown <= 0 and fireRate > 0 and self.target and not self.target.destroyed do
        self:tick(self.target)
        self.cooldown = self.cooldown + 1 / fireRate
    end
end

--- Keeps the current target until it dies, leaves range/arc, or becomes
--- immune to chill (frozen or thawing); then picks the nearest chillable enemy
--- in arc. Falls back to the nearest immune one so the beam still deals
--- damage when nothing else is in reach.
function CryoBeam:acquireTarget()
    local current = self.target
    if current and not current.destroyed and self:isInFiringArc(current) and not Chill.isImmune(current) then
        return current
    end

    local best, bestDist, immuneBest, immuneDist = nil, math.huge, nil, math.huge
    for _, obj in ipairs(self.game.objects) do
        if obj:isType("enemy") and not obj.destroyed and self:isInFiringArc(obj) then
            local d = (obj.x - self.x)^2 + (obj.y - self.y)^2
            if Chill.isImmune(obj) then
                if d < immuneDist then immuneBest, immuneDist = obj, d end
            elseif d < bestDist then
                best, bestDist = obj, d
            end
        end
    end
    self.target = best or immuneBest
    return self.target
end

--- One beam tick: damage plus this turret's own hit effects.
function CryoBeam:tick(target)
    local damage = self:getStat("damage") * Chill.getDamageMultiplier(target, self:getDamageVsChill())
    target:takeDamage(damage, self.damageType, target.x, target.y, { "beam" }, self)
    if target.destroyed then return end
    for _, effect in ipairs(self.hitEffects or {}) do
        if effect.isIndependent then
            if effect.trigger then effect:trigger(target, self) end
        elseif target.effectManager then
            target.effectManager:applyEffect(effect, self)
        end
    end
end

function CryoBeam:draw(drawx, drawy)
    Turret.draw(self, drawx, drawy)
    if drawx or drawy or self.isPreview then return end

    local target = self.target
    if not target or target.destroyed then return end

    local fx, fy = self:getFirePoint()
    local flicker = 0.85 + 0.15 * math.sin(love.timer.getTime() * 30)
    love.graphics.push("all")
    love.graphics.setColor(0.55, 0.85, 1, 0.25 * flicker)
    love.graphics.setLineWidth(7)
    love.graphics.line(fx, fy, target.x, target.y)
    love.graphics.setColor(0.85, 0.97, 1, 0.9 * flicker)
    love.graphics.setLineWidth(2)
    love.graphics.line(fx, fy, target.x, target.y)
    love.graphics.pop()
end

return CryoBeam
