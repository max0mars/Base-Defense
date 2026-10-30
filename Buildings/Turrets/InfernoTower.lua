-- InfernoTower.lua - Fire beam that locks onto one enemy and ramps up its
-- damage the longer it stays on it. Deals fire damage but applies no burn.
--
-- Like CryoBeam, damage lands in ticks: `fireRate` ticks per second, `damage`
-- per tick at the start, growing to `damage` x RAMP_MAX after RAMP_TIME
-- seconds on the same target. Switching targets resets the ramp.

local Turret = require("Buildings.Turrets.Turret")

local InfernoTower = setmetatable({}, { __index = Turret })
InfernoTower.__index = InfernoTower

InfernoTower.RAMP_TIME = 5 -- seconds on one target to reach full power
InfernoTower.RAMP_MAX = 5 -- damage multiplier at full power
InfernoTower.RETARGET_DELAY = 0.5 -- re-locking onto a new target takes a moment

function InfernoTower:new(config)
    local t = Turret:new(config)
    setmetatable(t, { __index = self })
    t.cooldown = 0
    t.lockTime = 0
    return t
end

--- 0..1 progress of the ramp on the current target.
function InfernoTower:getRamp()
    return math.min(1, self.lockTime / InfernoTower.RAMP_TIME)
end

function InfernoTower:getRampMultiplier()
    return 1 + (InfernoTower.RAMP_MAX - 1) * self:getRamp()
end

function InfernoTower:update(dt)
    if self.effectManager then
        self.effectManager:update(dt)
    end

    if self.game.inputMode == "aiming" and self.game.inputHandler.selectedBuilding == self then
        self.rotation = self.firingArc.direction
        self.targetRotation = self.firingArc.direction
        self.target = nil
        return
    end

    local previous = self.target
    self:getTargetArc()
    if not self.target then
        self.cooldown = 0
        self.lockTime = 0
        return
    end
    if self.target ~= previous then
        self.lockTime = 0
        if self.hasLocked then self.retargetTimer = InfernoTower.RETARGET_DELAY end
    end
    self.hasLocked = true

    self:lookAt(self.target.x, self.target.y, dt)

    if (self.retargetTimer or 0) > 0 then
        self.retargetTimer = self.retargetTimer - dt
        if self.retargetTimer > 0 then return end
        self.cooldown = 0
    end

    self.lockTime = self.lockTime + dt
    self.cooldown = self.cooldown - dt
    local fireRate = self:getStat("fireRate")
    while self.cooldown <= 0 and fireRate > 0 and self.target and not self.target.destroyed and not self.target.untargetable do
        self:tick(self.target)
        self.cooldown = self.cooldown + 1 / fireRate
    end
end

function InfernoTower:tick(target)
    local damage = self:getStat("damage") * self:getRampMultiplier()
    target:takeDamage(damage, self.damageType, target.x, target.y, { "beam" }, self)
end

function InfernoTower:draw(drawx, drawy)
    Turret.draw(self, drawx, drawy)
    if drawx or drawy or self.isPreview then return end

    local target = self.target
    if not target or target.destroyed or (self.retargetTimer or 0) > 0 then return end

    -- Thickens and goes from deep orange to white-hot as it ramps
    local ramp = self:getRamp()
    local fx, fy = self:getFirePoint()
    local flicker = 0.85 + 0.15 * math.sin(love.timer.getTime() * 35)
    love.graphics.push("all")
    love.graphics.setColor(1, 0.35 + 0.25 * ramp, 0.05, 0.3 * flicker)
    love.graphics.setLineWidth(4 + 6 * ramp)
    love.graphics.line(fx, fy, target.x, target.y)
    love.graphics.setColor(1, 0.6 + 0.4 * ramp, 0.2 + 0.7 * ramp, 0.95 * flicker)
    love.graphics.setLineWidth(1.5 + 1.5 * ramp)
    love.graphics.line(fx, fy, target.x, target.y)
    love.graphics.pop()
end

return InfernoTower
