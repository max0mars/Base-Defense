-- Vanguard.lua - Tier 3 red. A slow, tough walker behind a frontal shield that
-- cuts damage coming at its front by FRONT_REDUCTION.
--
-- "Front" is the way it's walking (smoothed, so it turns with the path). A hit
-- counts as frontal when it comes from within SHIELD_ARC of that direction:
-- for a bullet, judged by the way the bullet was travelling; for anything else
-- with a position (beams, the main laser), by where the source is. Area damage,
-- damage over time and true damage go around the shield. Stunning or freezing
-- it drops the shield; once it recovers, the shield stays down another
-- RECOVER_DELAY, then takes RAISE_TIME to come back up (blocking only once it's
-- fully up), leaving a window for more hits.

local Enemy = require("Enemies.Enemy")
local Chill = require("Game.Effects.StatusEffects.Chill")

local Vanguard = setmetatable({}, { __index = Enemy })
Vanguard.__index = Vanguard

Vanguard.FRONT_REDUCTION = 0.75 -- share of frontal damage the shield stops
Vanguard.SHIELD_ARC = math.rad(150) -- total width of the protected front
Vanguard.SHIELD_COLOR = { 1, 0.45, 0.3 }
Vanguard.BLOCK_FLASH_TIME = 0.15 -- seconds the shield flares after blocking
Vanguard.RECOVER_DELAY = 1.0 -- seconds the shield stays down after a stun/freeze ends
Vanguard.RAISE_TIME = 0.4 -- seconds the shield then takes to come back up
Vanguard.TURN_RATE = 6 -- how quickly its facing follows its movement

-- Damage that goes around the shield
local BYPASS_TAGS = { aoe = true, dot = true }

local Stats = {
    name = "Vanguard",
    reward = 80,
    hitbox = true,
    effectManager = true,
}

function Vanguard:new(config)
    config = config or {}
    for key, value in pairs(Stats) do
        config[key] = config[key] or value
    end

    local obj = Enemy:new(config)
    setmetatable(obj, { __index = self })

    obj.facingX, obj.facingY = -1, 0 -- toward the base
    obj.lastX, obj.lastY = obj.x, obj.y
    obj.blockFlash = nil
    obj.shieldState = "up" -- "up", "down" (recovering) or "raising"
    obj.shieldTimer = 0

    return obj
end

function Vanguard:isDisrupted()
    return self:getStat("stunned", 0) > 0 or Chill.isFrozen(self)
end

function Vanguard:isShielded()
    return self.shieldState == "up" and not self:isDisrupted()
end

--- Unit vector from the Vanguard toward where an attack came from, or nil if unknown.
function Vanguard:getIncomingDirection(source, hitX, hitY)
    local dx, dy
    if source and source.angle and source.isType and source:isType("bullet") then
        dx, dy = -math.cos(source.angle), -math.sin(source.angle)
    else
        local sx = (source and source.x) or hitX
        local sy = (source and source.y) or hitY
        if not sx or not sy then return nil end
        dx, dy = sx - self.x, sy - self.y
    end
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1e-6 then return nil end
    return dx / len, dy / len
end

--- True if this hit is stopped by the shield.
function Vanguard:blocks(damageType, damageTags, source, hitX, hitY)
    if not self:isShielded() or damageType == "trueDamage" then return false end
    for _, tag in ipairs(damageTags or {}) do
        if BYPASS_TAGS[tag] then return false end
    end
    local ix, iy = self:getIncomingDirection(source, hitX, hitY)
    if not ix then return false end
    return ix * self.facingX + iy * self.facingY >= math.cos(Vanguard.SHIELD_ARC / 2)
end

function Vanguard:takeDamage(amount, damageType, hitX, hitY, damageTags, source)
    if type(amount) == "number" and amount > 0 and self:blocks(damageType, damageTags, source, hitX, hitY) then
        amount = amount * (1 - Vanguard.FRONT_REDUCTION)
        self.blockFlash = 0
    end
    return Enemy.takeDamage(self, amount, damageType, hitX, hitY, damageTags, source)
end

--- Turns its facing toward the way it's moving, and runs the shield's animations.
function Vanguard:updateShield(dt)
    local mx, my = self.x - self.lastX, self.y - self.lastY
    self.lastX, self.lastY = self.x, self.y
    local moved = math.sqrt(mx * mx + my * my)
    if moved > 1e-3 then
        local k = math.min(1, Vanguard.TURN_RATE * dt)
        local fx = self.facingX + (mx / moved - self.facingX) * k
        local fy = self.facingY + (my / moved - self.facingY) * k
        local len = math.sqrt(fx * fx + fy * fy)
        if len > 1e-6 then self.facingX, self.facingY = fx / len, fy / len end
    end

    if self:isDisrupted() then
        if self.shieldState ~= "down" and self.game.spawnParticleExplosion then
            -- Drops: the shield breaks apart in front of it
            local r = self.w * 0.85
            self.game:spawnParticleExplosion(Vanguard.SHIELD_COLOR, 6,
                self.x + self.facingX * r, self.y + self.facingY * r, 0.4, 10)
        end
        self.shieldState, self.shieldTimer = "down", 0
    elseif self.shieldState == "down" then
        self.shieldTimer = self.shieldTimer + dt
        if self.shieldTimer >= Vanguard.RECOVER_DELAY then self.shieldState, self.shieldTimer = "raising", 0 end
    elseif self.shieldState == "raising" then
        self.shieldTimer = self.shieldTimer + dt
        if self.shieldTimer >= Vanguard.RAISE_TIME then self.shieldState, self.shieldTimer = "up", 0 end
    end
    if self.blockFlash then
        self.blockFlash = self.blockFlash + dt
        if self.blockFlash >= Vanguard.BLOCK_FLASH_TIME then self.blockFlash = nil end
    end
end

function Vanguard:update(dt)
    if self.destroyed then return end
    Enemy.update(self, dt)
    if self.isDead then return end
    self:updateShield(dt)
end

--- The shield: a curved neon band across its front. Flares when it blocks a
--- hit, gone while it's down, and grows back out (dimmer, not yet blocking)
--- while it's raised.
function Vanguard:drawShield(y)
    Enemy.drawShield(self, y)
    if self:isDisrupted() or self.shieldState == "down" then return end

    local raise = self.shieldState == "raising" and (self.shieldTimer / Vanguard.RAISE_TIME) or 1
    local half = Vanguard.SHIELD_ARC / 2 * raise
    local angle = math.atan2(self.facingY, self.facingX)
    local radius = self.w * 0.85
    local flash = self.blockFlash and (1 - self.blockFlash / Vanguard.BLOCK_FLASH_TIME) or 0
    local r, g, b = Vanguard.SHIELD_COLOR[1], Vanguard.SHIELD_COLOR[2], Vanguard.SHIELD_COLOR[3]

    love.graphics.setColor(r, g, b, 0.1 + 0.15 * flash)
    love.graphics.arc("fill", "open", self.x, y, radius, angle - half, angle + half, 16)
    love.graphics.setColor(r, g, b, self.shieldState == "up" and 1 or 0.45)
    love.graphics.setLineWidth(2.5 + 1.5 * flash)
    love.graphics.arc("line", "open", self.x, y, radius, angle - half, angle + half, 16)
    love.graphics.setColor(r + (1 - r) * (0.6 + 0.4 * flash), g + (1 - g) * (0.6 + 0.4 * flash), b + (1 - b) * (0.6 + 0.4 * flash), 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.arc("line", "open", self.x, y, radius, angle - half, angle + half, 16)
    love.graphics.setColor(1, 1, 1, 1)
end

return Vanguard
