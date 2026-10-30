-- Oil.lua - Fire synergy setup status (Oil Gun).
--
-- Oil slows the enemy. The next time burn is applied to it or it takes fire
-- damage, the oil ignites: it adds BONUS_STACKS burn and is used up (see
-- Burn.igniteOil). Oiling an enemy that is already burning ignites right away
-- instead.
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

--- Called by Enemy:takeDamage for fire damage: ignites the target's oil.
function Oil.onFireDamage(target)
    Burn.igniteOil(target)
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

--- @param config table|nil: radius (oils every enemy that close to the hit,
---   not just the one hit; default 0), name (default "oil")
function Oil.onHit(config)
    config = config or {}
    return setmetatable({ name = config.name or "oil", isIndependent = true, radius = config.radius or 0 }, OilOnHit)
end

--- Oils every enemy within `radius` of (x, y), measured to the edge of its body.
function Oil.splash(game, x, y, radius, source)
    for _, obj in ipairs(game.objects) do
        if obj.isType and obj:isType("enemy") and not obj.destroyed then
            local halfW, halfH = (obj.w or 0) / 2, (obj.h or 0) / 2
            local dx = x - math.max(obj.x - halfW, math.min(x, obj.x + halfW))
            local dy = y - math.max(obj.y - halfH, math.min(y, obj.y + halfH))
            if dx * dx + dy * dy <= radius * radius then
                Oil.apply(obj, { source = source })
            end
        end
    end
    if game.spawnExpandingCircle then
        game:spawnExpandingCircle(x, y, radius * 0.3, radius, { OIL_COLOR[1] + 0.2, OIL_COLOR[2] + 0.15, OIL_COLOR[3] + 0.05, 0.8 }, 0.35)
    end
end

function OilOnHit:trigger(target, source)
    if not target or not target.isType or not target:isType("enemy") then return end
    if self.radius > 0 and target.game then
        Oil.splash(target.game, target.x, target.y, self.radius, source)
    else
        Oil.apply(target, { source = source })
    end
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
