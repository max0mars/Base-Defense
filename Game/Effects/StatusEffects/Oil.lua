-- Oil.lua - Fire synergy setup status (Oil Gun).
--
-- Oil slows the enemy. The next time burn is applied to it, the oil ignites:
-- it adds BONUS_STACKS extra burn and is used up (see Burn.apply). Oiling an
-- enemy that is already burning ignites right away instead.
--
-- Usage from a turret: hitEffects = { Oil.onHit() }

local Burn = require("Game.Effects.StatusEffects.Burn")

local Oil = {
    BONUS_STACKS = 5,
    SLOW         = 0.3, -- speed x0.7, compounding with other slows
    DURATION     = 4,
    NAME         = Burn.OIL_NAME,
}

local OIL_COLOR = { 0.25, 0.18, 0.08 }
local SHEEN_COLOR = { 0.9, 0.75, 0.35 }

-- -----------------------------------------------------------------------------
-- Oil state
-- -----------------------------------------------------------------------------
local OilState = {}
OilState.__index = OilState

function OilState:new(oiledBy)
    return setmetatable({
        name = Oil.NAME,
        displayName = "Oiled",
        isDebuff = true,
        duration = Oil.DURATION,
        bonusStacks = Oil.BONUS_STACKS,
        oiledBy = oiledBy, -- the bullet / turret credited for the bonus stacks
        statModifiers = { speed = { compoundMult = 1 - Oil.SLOW } },
    }, OilState)
end

-- Called by Burn.apply after it uses the oil up.
function OilState:onIgnite(target)
    Oil.spawnIgnite(target)
end

-- -----------------------------------------------------------------------------
-- Queries / applying
-- -----------------------------------------------------------------------------

function Oil.isOiled(target)
    local em = target and target.effectManager
    return em ~= nil and em:getEffect(Oil.NAME) ~= nil
end

function Oil.spawnIgnite(target)
    local game = target.game
    if game and game.spawnParticleExplosion then
        game:spawnParticleExplosion({ 1, 0.55, 0.1, 1 }, 14, target.x, target.y, 0.35, 10)
    end
end

--- Oils a target, or ignites it straight away if it's already burning.
-- @param opts table|nil: source = the turret (or its bullet) applying it
function Oil.apply(target, opts)
    local em = target and target.effectManager
    if not em or target.destroyed then return end
    local source = opts and opts.source

    if Burn.isBurning(target) then
        Burn.addRaw(target, Oil.BONUS_STACKS, Burn.creditKeyFor(source))
        Oil.spawnIgnite(target)
        return
    end

    local existing = em:getEffect(Oil.NAME)
    if existing then
        existing.duration = Oil.DURATION
        existing.oiledBy = source
        return
    end
    em:applyEffect(OilState:new(source))
end

-- -----------------------------------------------------------------------------
-- Hit effect
-- -----------------------------------------------------------------------------
local OilOnHit = {}
OilOnHit.__index = OilOnHit

function Oil.onHit(config)
    config = config or {}
    return setmetatable({ name = config.name or "oil", isIndependent = true }, OilOnHit)
end

function OilOnHit:trigger(target, source)
    if not target or not target.isType or not target:isType("enemy") then return end
    Oil.apply(target, { source = source })
end

function OilOnHit:onApply(target, source)
    self:trigger(target, source)
end

-- -----------------------------------------------------------------------------
-- Visuals: a dark slick over the body with a glossy highlight and a drip
-- -----------------------------------------------------------------------------
local function drawBody(enemy, mode)
    if enemy.drawCustomShape and enemy.shape ~= "arrow" then
        enemy:drawCustomShape(mode, enemy.x, enemy.y)
    else
        local r = (enemy.getStat and enemy:getStat("size") or enemy.size or 10) * 0.8
        love.graphics.circle(mode, enemy.x, enemy.y, r)
    end
end

function Oil.draw(enemy)
    local em = enemy.effectManager
    local oil = em and em:getEffect(Oil.NAME)
    if not oil then return end
    local fade = math.min(1, oil.duration / 0.5)
    local half = (enemy.h or enemy.size or 20) / 2

    love.graphics.push("all")
    love.graphics.setColor(OIL_COLOR[1], OIL_COLOR[2], OIL_COLOR[3], 0.55 * fade)
    drawBody(enemy, "fill")
    love.graphics.setColor(SHEEN_COLOR[1], SHEEN_COLOR[2], SHEEN_COLOR[3], 0.6 * fade)
    love.graphics.setLineWidth(1.5)
    love.graphics.arc("line", "open", enemy.x, enemy.y, half * 0.6, math.pi * 1.1, math.pi * 1.45)
    -- A drip that slowly falls from the bottom edge and repeats
    local t = (love.timer.getTime() * 0.8 + enemy.x * 0.01) % 1
    love.graphics.setColor(OIL_COLOR[1] + 0.15, OIL_COLOR[2] + 0.1, OIL_COLOR[3], 0.8 * fade * (1 - t))
    love.graphics.circle("fill", enemy.x + half * 0.3, enemy.y + half + 1 + t * 5, 1.5)
    love.graphics.pop()
end

return Oil
