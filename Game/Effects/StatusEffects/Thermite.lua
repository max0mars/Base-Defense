-- Thermite.lua - Charges stuck to an enemy by the Thermite Launcher.
--
-- Each charge applies STACKS_PER_PULSE burn every PULSE_INTERVAL seconds,
-- PULSES times. Charges stack: every hit attaches another one.
--
-- Usage from a turret: hitEffects = { Thermite.onHit() }

local Burn = require("Game.Effects.StatusEffects.Burn")

local Thermite = {
    STACKS_PER_PULSE = 3,
    PULSE_INTERVAL   = 1,
    PULSES           = 5,
    NAME             = "hidden_thermite",
}

-- -----------------------------------------------------------------------------
-- Charge state: one per thermite stuck to the enemy
-- -----------------------------------------------------------------------------
local ThermiteState = {}
ThermiteState.__index = ThermiteState

function ThermiteState:new(source, offsetX, offsetY)
    return setmetatable({
        name = Thermite.NAME,
        displayName = "Thermite",
        isDebuff = true,
        maxStacks = math.huge,
        source = source, -- the bullet / turret credited for its burn
        timer = 0,
        pulsesLeft = Thermite.PULSES,
        duration = math.huge, -- set to 0 after the last pulse so the manager removes it
        offsetX = offsetX, -- where it's stuck, relative to the enemy's centre
        offsetY = offsetY,
    }, ThermiteState)
end

function ThermiteState:onUpdate(dt, target)
    self.timer = self.timer + dt
    while self.timer >= Thermite.PULSE_INTERVAL and self.pulsesLeft > 0 and not target.destroyed do
        self.timer = self.timer - Thermite.PULSE_INTERVAL
        self.pulsesLeft = self.pulsesLeft - 1
        Burn.apply(target, Thermite.STACKS_PER_PULSE, { source = self.source })
    end
    if self.pulsesLeft <= 0 then
        self.duration = 0
    end
end

-- -----------------------------------------------------------------------------
-- Queries / applying
-- -----------------------------------------------------------------------------

--- Number of thermite charges stuck to a target.
function Thermite.count(target)
    local em = target and target.effectManager
    return em and em.effectCounts[Thermite.NAME] or 0
end

--- Sticks a new charge to the target.
function Thermite.attach(target, source)
    local em = target and target.effectManager
    if not em or target.destroyed then return end
    local half = (target.w or target.size or 20) / 2
    local ox = (math.random() * 2 - 1) * half * 0.6
    local oy = (math.random() * 2 - 1) * half * 0.6
    em:applyEffect(ThermiteState:new(source, ox, oy))
end

-- -----------------------------------------------------------------------------
-- Hit effect
-- -----------------------------------------------------------------------------
local ThermiteOnHit = {}
ThermiteOnHit.__index = ThermiteOnHit

function Thermite.onHit(config)
    config = config or {}
    return setmetatable({ name = config.name or "thermite", isIndependent = true }, ThermiteOnHit)
end

function ThermiteOnHit:trigger(target, source)
    if not target or not target.isType or not target:isType("enemy") then return end
    Thermite.attach(target, source)
end

function ThermiteOnHit:onApply(target, source)
    self:trigger(target, source)
end

-- -----------------------------------------------------------------------------
-- Visuals: a white-hot spark per charge, flaring as it pulses
-- -----------------------------------------------------------------------------
function Thermite.draw(enemy)
    local em = enemy.effectManager
    if not em or Thermite.count(enemy) == 0 then return end
    local now = love.timer.getTime()

    love.graphics.push("all")
    for _, effect in ipairs(em.activeEffects) do
        if effect.name == Thermite.NAME then
            local x, y = enemy.x + effect.offsetX, enemy.y + effect.offsetY
            -- Swells just after each pulse, then settles
            local flare = 1 - math.min(1, effect.timer / Thermite.PULSE_INTERVAL)
            local flicker = 0.85 + 0.15 * math.sin(now * 40 + effect.offsetX)
            love.graphics.setColor(1, 0.55, 0.15, 0.45 * flicker)
            love.graphics.circle("fill", x, y, 3 + 2 * flare)
            love.graphics.setColor(1, 0.97, 0.85, flicker)
            love.graphics.circle("fill", x, y, 1.6)
        end
    end
    love.graphics.pop()
end

return Thermite
