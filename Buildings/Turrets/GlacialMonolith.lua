-- GlacialMonolith.lua - Deals no damage. While an enemy is in its firing arc it
-- sends out a slowly expanding ring that applies chill to every enemy the
-- ring's front passes over (once per wave).
--
-- `fireRate` is waves per second and `waveSpeed` is how fast a ring expands
-- (world px/s); rings stop at the turret's current range. Each ring is
-- `ringAngle` wide (defaults to the whole arc), centred on the enemy that
-- triggered it but clamped so the whole ring stays inside the firing arc.

local Turret = require("Buildings.Turrets.Turret")
local Chill = require("Game.Effects.StatusEffects.Chill")

local GlacialMonolith = setmetatable({}, { __index = Turret })
GlacialMonolith.__index = GlacialMonolith

-- Frost motes shed by each ring as it travels (visual only)
local MOTES_PER_SECOND = 45
local MOTE_LIFE_MIN, MOTE_LIFE_MAX = 0.3, 0.6
local MOTE_DRIFT_MIN, MOTE_DRIFT_MAX = 10, 35 -- outward speed, px/s

function GlacialMonolith:new(config)
    local t = Turret:new(config)
    setmetatable(t, { __index = self })
    t.waves = {}
    t.motes = {}
    t.cooldown = 0
    t.waveSpeed = config.waveSpeed or 120
    t.chillPerWave = config.chillPerWave or 1
    t.ringAngle = math.min(config.ringAngle or t.firingArc.angle, t.firingArc.angle)
    return t
end

local function angleDiff(a, b)
    local d = (a - b) % (2 * math.pi)
    if d > math.pi then d = 2 * math.pi - d end
    return d
end

-- Signed shortest angle from b to a, in (-pi, pi].
local function signedDiff(a, b)
    local d = (a - b + math.pi) % (2 * math.pi) - math.pi
    return d
end

--- Ring centre aimed at the target, clamped so the ring stays inside the arc.
function GlacialMonolith:getRingCenter(target)
    local dir = self.firingArc.direction
    local cx, cy = self:getCenterPosition()
    local offset = signedDiff(math.atan2(target.y - cy, target.x - cx), dir)
    local maxOffset = (self.firingArc.angle - self.ringAngle) / 2
    return dir + math.max(-maxOffset, math.min(maxOffset, offset))
end

function GlacialMonolith:update(dt)
    if self.effectManager then
        self.effectManager:update(dt)
    end

    -- Faces its most recent ring (kept relative to the arc, so re-aiming moves it).
    self.rotation = self.firingArc.direction + (self.aimOffset or 0)
    self.targetRotation = self.rotation

    self:updateWaves(dt)
    self:updateMotes(dt)

    if self.game.inputMode == "aiming" and self.game.inputHandler.selectedBuilding == self then
        return
    end

    self.cooldown = self.cooldown - dt
    if self.cooldown <= 0 then
        local target = self:getTargetArc()
        if target then
            local center = self:getRingCenter(target)
            self.aimOffset = center - self.firingArc.direction
            table.insert(self.waves, { radius = 0, hit = {}, center = center })
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
    local half = self.ringAngle / 2

    for i = #self.waves, 1, -1 do
        local wave = self.waves[i]
        local dir = wave.center or self.firingArc.direction
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
                    Chill.apply(obj, self.chillPerWave, { source = self })
                end
            end
        end

        self:shedMotes(wave, dt)

        if wave.radius >= range then
            table.remove(self.waves, i)
        end
    end
end

-- Scatters a few motes along the ring's front
function GlacialMonolith:shedMotes(wave, dt)
    local cx, cy = self:getCenterPosition()
    local center = wave.center or self.firingArc.direction
    wave.moteBudget = (wave.moteBudget or 0) + MOTES_PER_SECOND * dt
    while wave.moteBudget >= 1 do
        wave.moteBudget = wave.moteBudget - 1
        local angle = center + (math.random() - 0.5) * self.ringAngle
        local drift = MOTE_DRIFT_MIN + math.random() * (MOTE_DRIFT_MAX - MOTE_DRIFT_MIN)
        local life = MOTE_LIFE_MIN + math.random() * (MOTE_LIFE_MAX - MOTE_LIFE_MIN)
        table.insert(self.motes, {
            x = cx + math.cos(angle) * wave.radius, y = cy + math.sin(angle) * wave.radius,
            vx = math.cos(angle) * drift, vy = math.sin(angle) * drift,
            life = life, maxLife = life, size = 1 + math.random() * 1.5,
        })
    end
end

function GlacialMonolith:updateMotes(dt)
    for i = #self.motes, 1, -1 do
        local m = self.motes[i]
        m.life = m.life - dt
        if m.life <= 0 then
            table.remove(self.motes, i)
        else
            m.x, m.y = m.x + m.vx * dt, m.y + m.vy * dt
        end
    end
end

function GlacialMonolith:draw(drawx, drawy)
    Turret.draw(self, drawx, drawy)
    if drawx or drawy or self.isPreview then return end

    love.graphics.push("all")
    for _, m in ipairs(self.motes) do
        love.graphics.setColor(0.85, 0.97, 1, 0.8 * m.life / m.maxLife)
        love.graphics.circle("fill", m.x, m.y, m.size)
    end
    love.graphics.pop()
    if #self.waves == 0 then return end

    local cx, cy = self:getCenterPosition()
    local range = self:getStat("range")
    love.graphics.push("all")
    for _, wave in ipairs(self.waves) do
        local center = wave.center or self.firingArc.direction
        local a1, a2 = center - self.ringAngle / 2, center + self.ringAngle / 2
        local fade = 1 - wave.radius / range
        love.graphics.setColor(0.55, 0.85, 1, 0.25 * fade)
        love.graphics.setLineWidth(16)
        love.graphics.arc("line", "open", cx, cy, wave.radius, a1, a2)
        love.graphics.setColor(0.85, 0.97, 1, 0.9 * fade)
        love.graphics.setLineWidth(5)
        love.graphics.arc("line", "open", cx, cy, wave.radius, a1, a2)
    end
    love.graphics.pop()
end

return GlacialMonolith
