local Buff = require("Buildings.Passives.Buff")
local Chill = require("Game.Effects.StatusEffects.Chill")

local FrostTrap = setmetatable({}, Buff)
FrostTrap.__index = FrostTrap

-- Placeable on the battlefield; as a passive it never blocks or reroutes
-- enemies. While an enemy is in range it pulses, chilling everything in range.
local default = {
    name = "Frost Trap",
    types = { passive = true, slow = true, control = true },
    color = {0.4, 0.6, 0.9, 1}, -- Cool bluish tone
    shapePattern = {{0, 0}},
    affectedSlots = {},
    range = 200,
    pulseInterval = 1.2,
    chillPerPulse = 1,
}

function FrostTrap:new(config)
    config = config or {}
    for key, value in pairs(default) do
        if config[key] == nil then
            config[key] = value
        end
    end

    local obj = Buff:new(config)
    setmetatable(obj, self)
    obj.range = config.range
    obj.pulseInterval = config.pulseInterval
    obj.chillPerPulse = config.chillPerPulse
    obj.pulseCooldown = 0

    return obj
end

function FrostTrap:applyBuffs()
    -- Frost Trap chills enemies instead of buffing neighbours
end

function FrostTrap:update(dt)
    if self.isPreview then return end
    if not self.game or not self.game.objects or not self.slot then return end

    self.pulseCooldown = math.max(0, self.pulseCooldown - dt)
    if self.pulseCooldown > 0 then return end

    local cx, cy = self:getCenterPosition()
    local rSq = self.range * self.range
    local pulsed = false

    for _, obj in ipairs(self.game.objects) do
        if obj:isType("enemy") and not obj.destroyed then
            local distSq = (obj.x - cx)^2 + (obj.y - cy)^2
            if distSq <= rSq then
                Chill.apply(obj, self.chillPerPulse)
                pulsed = true
            end
        end
    end

    -- Only pulse (and start the cooldown) when something was in range.
    if pulsed then
        self.pulseCooldown = self.pulseInterval
        if self.game.spawnExpandingCircle then
            self.game:spawnExpandingCircle(cx, cy, 8, self.range, {0.6, 0.85, 1, 0.5}, 0.4)
        end
    end
end

function FrostTrap:draw(x, y)
    Buff.draw(self, x, y)

    -- Draw radius arc only when showArc or isPreview is true
    if self.showArc or self.isPreview then
        local cx, cy
        if x and y then
            cx, cy = x, y
        else
            cx, cy = self:getCenterPosition()
        end
        love.graphics.setColor(0.6, 0.8, 1, 0.2)
        love.graphics.circle("fill", cx, cy, self.range)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return FrostTrap
