-- GlacialMonolith.lua - Deals no damage. While an enemy is in its firing arc it
-- sends out a slowly expanding ring, confined to the arc, that applies chill to
-- every enemy the ring's front passes over (once per wave).
--
-- `fireRate` is waves per second and `waveSpeed` is how fast a ring expands
-- (world px/s); rings stop at the turret's current range.

local Turret = require("Buildings.Turrets.Turret")
local Chill = require("Game.Effects.StatusEffects.Chill")

local GlacialMonolith = setmetatable({}, { __index = Turret })
GlacialMonolith.__index = GlacialMonolith

function GlacialMonolith:new(config)
    local t = Turret:new(config)
    setmetatable(t, { __index = self })
    t.waves = {}
    t.cooldown = 0
    t.waveSpeed = config.waveSpeed or 120
    t.chillPerWave = config.chillPerWave or 1
    return t
end

local function angleDiff(a, b)
    local d = (a - b) % (2 * math.pi)
    if d > math.pi then d = 2 * math.pi - d end
    return d
end

function GlacialMonolith:update(dt)
    if self.effectManager then
        self.effectManager:update(dt)
    end

    -- The monolith never turns: it always faces its arc.
    self.rotation = self.firingArc.direction
    self.targetRotation = self.firingArc.direction

    self:updateWaves(dt)

    if self.game.inputMode == "aiming" and self.game.inputHandler.selectedBuilding == self then
        return
    end

    self.cooldown = self.cooldown - dt
    if self.cooldown <= 0 then
        if self:getTargetArc() then
            table.insert(self.waves, { radius = 0, hit = {} })
            local fireRate = self:getStat("fireRate")
            self.cooldown = fireRate > 0 and (1 / fireRate) or math.huge
        else
            self.cooldown = 0 -- pulse as soon as something enters the arc
        end
    end
end

function GlacialMonolith:updateWaves(dt)
    if #self.waves == 0 then return end
    local cx, cy = self:getCenterPosition()
    local range = self:getStat("range")
    local dir, half = self.firingArc.direction, self.firingArc.angle / 2

    for i = #self.waves, 1, -1 do
        local wave = self.waves[i]
        local prevRadius = wave.radius
        wave.radius = math.min(range, wave.radius + self.waveSpeed * dt)

        -- Chill enemies whose body overlaps the band the front swept this frame.
        for _, obj in ipairs(self.game.objects) do
            if obj:isType("enemy") and not obj.destroyed and not wave.hit[obj] then
                local dx, dy = obj.x - cx, obj.y - cy
                local dist = math.sqrt(dx * dx + dy * dy)
                local r = (obj.size or obj.w or 0) / 2
                if dist - r <= wave.radius and dist + r >= prevRadius
                   and angleDiff(math.atan2(dy, dx), dir) <= half then
                    wave.hit[obj] = true
                    Chill.apply(obj, self.chillPerWave)
                end
            end
        end

        if wave.radius >= range then
            table.remove(self.waves, i)
        end
    end
end

function GlacialMonolith:draw(drawx, drawy)
    Turret.draw(self, drawx, drawy)
    if drawx or drawy or self.isPreview or #self.waves == 0 then return end

    local cx, cy = self:getCenterPosition()
    local range = self:getStat("range")
    local a1 = self.firingArc.direction - self.firingArc.angle / 2
    local a2 = self.firingArc.direction + self.firingArc.angle / 2
    love.graphics.push("all")
    for _, wave in ipairs(self.waves) do
        local fade = 1 - wave.radius / range
        love.graphics.setColor(0.55, 0.85, 1, 0.25 * fade)
        love.graphics.setLineWidth(8)
        love.graphics.arc("line", "open", cx, cy, wave.radius, a1, a2)
        love.graphics.setColor(0.85, 0.97, 1, 0.9 * fade)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", cx, cy, wave.radius, a1, a2)
    end
    love.graphics.pop()
end

return GlacialMonolith
