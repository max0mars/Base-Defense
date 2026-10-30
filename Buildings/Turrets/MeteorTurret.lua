-- MeteorTurret.lua - Calls meteors down onto its target instead of shooting.
--
-- It aims like any turret (nearest enemy in its arc, leading it by the fall
-- time). The meteor lands FALL_TIME later, dealing `damage` as fire damage in
-- `radius` (no burn), and leaves a burning crater that applies burn to enemies
-- standing in it.

local Turret = require("Buildings.Turrets.Turret")
local FireZoneEffect = require("Spells.FireZoneEffect")

local MeteorTurret = setmetatable({}, { __index = Turret })
MeteorTurret.__index = MeteorTurret

MeteorTurret.FALL_TIME = 0.8

-- Crater left behind
MeteorTurret.CRATER_DURATION = 4
MeteorTurret.CRATER_STACKS = 2       -- burn per tick to each enemy inside
MeteorTurret.CRATER_TICK = 0.5
MeteorTurret.CRATER_RADIUS_SCALE = 0.85 -- of the impact radius

-- -----------------------------------------------------------------------------
-- Falling meteor (lives in game.animations, like FireballVisual)
-- -----------------------------------------------------------------------------
local MeteorStrike = {}
MeteorStrike.__index = MeteorStrike

function MeteorStrike:new(turret, x, y)
    return setmetatable({
        turret = turret,
        game = turret.game,
        x = x, y = y,
        damage = turret:getStat("damage"),
        radius = turret:getStat("radius"),
        time = 0,
        destroyed = false,
    }, MeteorStrike)
end

function MeteorStrike:update(dt)
    self.time = self.time + dt
    if self.time >= MeteorTurret.FALL_TIME and not self.destroyed then
        self.destroyed = true
        self:impact()
    end
end

function MeteorStrike:impact()
    local game, r = self.game, self.radius
    if AUDIO then AUDIO:playSFX("explosion_02") end
    if game.spawnParticleExplosion then
        game:spawnParticleExplosion({ 1, 0.45, 0.05, 1 }, 18, self.x, self.y, 0.6, 28)
        game:spawnParticleExplosion({ 1, 0.85, 0.4, 1 }, 10, self.x, self.y, 0.4, 14)
    end
    if game.spawnExpandingCircle then
        game:spawnExpandingCircle(self.x, self.y, r * 0.2, r * 1.1, { 1, 0.5, 0.1 }, 0.35)
    end

    local r2 = r * r
    for _, obj in ipairs(game.objects) do
        if obj:isType("enemy") and not obj.destroyed then
            local dx, dy = obj.x - self.x, obj.y - self.y
            if dx * dx + dy * dy <= r2 then
                obj:takeDamage(self.damage, "fire", nil, nil, { "aoe" }, self.turret)
            end
        end
    end

    FireZoneEffect.spawn(game, {
        name = "meteor_crater",
        x = self.x, y = self.y,
        radius = r * MeteorTurret.CRATER_RADIUS_SCALE,
        duration = MeteorTurret.CRATER_DURATION,
        tickInterval = MeteorTurret.CRATER_TICK,
        stacksPerTick = MeteorTurret.CRATER_STACKS,
        source = self.turret,
    }, "coals")
end

function MeteorStrike:draw()
    local p = math.min(1, self.time / MeteorTurret.FALL_TIME)
    -- Comes in from the upper right, accelerating
    local fall = p * p
    local startDx, startDy = 160, -420
    local mx = self.x + startDx * (1 - fall)
    local my = self.y + startDy * (1 - fall)
    local dirX, dirY = startDx / 450, startDy / 450

    love.graphics.push("all")
    -- Target marker: a shrinking ring and a growing shadow
    love.graphics.setColor(1, 0.4, 0.1, 0.25 + 0.35 * p)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", self.x, self.y, self.radius * (1.4 - 0.4 * p))
    love.graphics.setColor(0, 0, 0, 0.3 * p)
    love.graphics.circle("fill", self.x, self.y, 10 * p)

    -- Tail
    for i = 6, 1, -1 do
        local k = i / 6
        love.graphics.setColor(1, 0.35 + 0.3 * (1 - k), 0.05, 0.5 * (1 - k))
        love.graphics.circle("fill", mx + dirX * 30 * k, my + dirY * 30 * k, 9 * (1 - k * 0.6))
    end
    -- Rock with a molten core
    love.graphics.setColor(1, 0.55, 0.15, 1)
    love.graphics.circle("fill", mx, my, 9)
    love.graphics.setColor(1, 0.95, 0.7, 1)
    love.graphics.circle("fill", mx, my, 4.5)
    love.graphics.pop()
end

-- -----------------------------------------------------------------------------
-- Turret
-- -----------------------------------------------------------------------------

function MeteorTurret:new(config)
    local t = Turret:new(config)
    setmetatable(t, { __index = self })
    -- Lead targets by the fall time (Turret:getTargetLeadPosition asks this)
    t.bulletType = { getTOF = function() return MeteorTurret.FALL_TIME end }
    return t
end

-- Sprite: a satellite dish that turns toward its target. Turret:draw calls
-- this in the turret's rotated frame (origin at the centre, facing +x) for the
-- glow and core passes alike.
local DISH_CX, DISH_R = 10, 10 -- dish is an arc of this circle, opening toward +x
local DISH_HALF = math.rad(55)
local FEED_X = 12 -- receiver at the dish's focus (the turret's `barrel` length)

function MeteorTurret:drawCustomBarrel()
    local rimX = DISH_CX - math.cos(DISH_HALF) * DISH_R
    local rimY = math.sin(DISH_HALF) * DISH_R
    love.graphics.arc("line", "open", DISH_CX, 0, DISH_R, math.pi - DISH_HALF, math.pi + DISH_HALF)
    -- Feed struts from the rim to the receiver
    love.graphics.line(rimX, rimY, FEED_X, 0)
    love.graphics.line(rimX, -rimY, FEED_X, 0)
    love.graphics.circle("line", FEED_X, 0, 1.5)
    -- Mount
    love.graphics.line(0, 0, DISH_CX - DISH_R, 0)
end

-- Calling a meteor: WAVES radio waves pulse out of the receiver toward the
-- target, one after another, each growing to WAVE_REACH and fading over WAVE_LIFE
MeteorTurret.TRANSMIT = {
    WAVES = 3,
    WAVE_LIFE = 0.4,
    WAVE_GAP = 0.15, -- seconds between waves
    WAVE_REACH = 28,
    WAVE_HALF_ANGLE = math.rad(35),
}

function MeteorTurret:update(dt)
    Turret.update(self, dt)
    if self.transmitTime then
        local T = MeteorTurret.TRANSMIT
        self.transmitTime = self.transmitTime + dt
        if self.transmitTime >= (T.WAVES - 1) * T.WAVE_GAP + T.WAVE_LIFE then
            self.transmitTime = nil
        end
    end
end

function MeteorTurret:draw(drawx, drawy)
    Turret.draw(self, drawx, drawy)
    if drawx or drawy or self.isPreview or not self.transmitTime then return end

    local T = MeteorTurret.TRANSMIT
    local fx, fy = self:getFirePoint()
    local r, g, b = unpack(self.color or { 1, 1, 1, 1 })
    love.graphics.push("all")
    love.graphics.setLineStyle("smooth")
    for i = 0, T.WAVES - 1 do
        local age = self.transmitTime - i * T.WAVE_GAP
        if age >= 0 and age <= T.WAVE_LIFE then
            local p = age / T.WAVE_LIFE
            local radius = 3 + p * T.WAVE_REACH
            local a1, a2 = self.rotation - T.WAVE_HALF_ANGLE, self.rotation + T.WAVE_HALF_ANGLE
            -- Soft outer pass, then a bright core that fades as the wave spreads
            love.graphics.setColor(r, g, b, 0.35 * (1 - p))
            love.graphics.setLineWidth(4)
            love.graphics.arc("line", "open", fx, fy, radius, a1, a2)
            love.graphics.setColor(r + (1 - r) * 0.6, g + (1 - g) * 0.6, b + (1 - b) * 0.6, 1 - p)
            love.graphics.setLineWidth(1.5)
            love.graphics.arc("line", "open", fx, fy, radius, a1, a2)
        end
    end
    love.graphics.pop()
end

function MeteorTurret:fire(args)
    local x = args and args.targetX or (self.target and self.target.x)
    local y = args and args.targetY or (self.target and self.target.y)
    if not (x and y) then return end
    self.lastAimX, self.lastAimY = x, y
    self.transmitTime = 0
    if AUDIO then AUDIO:playSFX(self.sfx or "missile_01") end
    table.insert(self.game.animations, MeteorStrike:new(self, x, y))
end

MeteorTurret.MeteorStrike = MeteorStrike

return MeteorTurret
