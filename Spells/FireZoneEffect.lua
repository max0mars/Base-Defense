-- FireZoneEffect.lua - Burning ground (lives on the global enemyEffectManager,
-- like BlizzardEffect). Used by the Meteor's crater, Cinder Mortar cinders and
-- the Embers / Blazing Flames spells.
--
-- Every `tickInterval` seconds, each enemy inside gets `stacksPerTick` burn
-- (one burn application, so Fuel Tank adds to each tick). Optional:
--   burnDamageMult / burnDecayMult  enemies inside burn harder / faster while
--                                   they stay in (Blazing Flames)
--   singleUse    the first enemy to touch it takes `touchDamage` fire damage
--                plus the stacks, and the zone is used up (a cinder)
--   source       the turret credited for the burn and damage (nil for spells)

local Burn = require("Game.Effects.StatusEffects.Burn")

local FireZoneEffect = {}
FireZoneEffect.__index = FireZoneEffect

-- Zone multipliers are refreshed every frame while inside; they linger this long
local ZONE_LINGER = 0.15

function FireZoneEffect:new(config)
    local instance = setmetatable({}, FireZoneEffect)
    instance.name = config.name or "fire_zone"
    instance.duration = config.duration or 5
    instance.maxDuration = instance.duration
    instance.x = config.x or 0
    instance.y = config.y or 0
    instance.radius = config.radius or 50
    instance.tickInterval = config.tickInterval or 0.5
    instance.stacksPerTick = config.stacksPerTick or 0
    -- Not named burnDamageMult / burnDecayMult: the zone sits on the global
    -- enemy manager, where Burn would apply those to every enemy
    instance.zoneDamageMult = config.burnDamageMult
    instance.zoneDecayMult = config.burnDecayMult
    instance.singleUse = config.singleUse or false
    instance.touchDamage = config.touchDamage or 0
    instance.source = config.source
    instance.game = config.game
    -- First tick lands as soon as the zone is down
    instance.tickTimer = instance.tickInterval
    return instance
end

function FireZoneEffect:contains(obj)
    local dx = obj.x - self.x
    local dy = obj.y - self.y
    local reach = self.radius + (self.singleUse and (obj.w or obj.size or 0) / 2 or 0)
    return dx * dx + dy * dy <= reach * reach
end

function FireZoneEffect:enemiesInside()
    local inside = {}
    for _, obj in ipairs(self.game.objects) do
        if obj:isType("enemy") and not obj.destroyed and self:contains(obj) then
            table.insert(inside, obj)
        end
    end
    return inside
end

function FireZoneEffect:onUpdate(dt, owner)
    if not self.game or self.spent then return end

    if self.singleUse then
        local enemy = self:enemiesInside()[1]
        if enemy then
            enemy:takeDamage(self.touchDamage, "fire", nil, nil, { "aoe" }, self.source)
            if not enemy.destroyed then
                Burn.apply(enemy, self.stacksPerTick, { source = self.source })
            end
            self.spent = true
            self.duration = 0
        end
        return
    end

    local inside = (self.zoneDamageMult or self.zoneDecayMult) and self:enemiesInside()
    if inside then
        for _, enemy in ipairs(inside) do
            self:markInside(enemy)
        end
    end

    self.tickTimer = self.tickTimer + dt
    if self.tickTimer < self.tickInterval then return end
    self.tickTimer = self.tickTimer - self.tickInterval
    if self.stacksPerTick <= 0 then return end
    for _, enemy in ipairs(inside or self:enemiesInside()) do
        if not enemy.destroyed then
            Burn.apply(enemy, self.stacksPerTick, { source = self.source })
        end
    end
end

-- Puts (or refreshes) this zone's burn multipliers on an enemy inside it.
-- One marker per zone name, so overlapping casts don't multiply together.
function FireZoneEffect:markInside(enemy)
    local em = enemy.effectManager
    if not em then return end
    local key = "hidden_" .. self.name .. "_zone"
    local marker = em:getEffect(key)
    if marker then
        marker.duration = ZONE_LINGER
        return
    end
    em:applyEffect({
        name = key,
        duration = ZONE_LINGER,
        isDebuff = true,
        burnDamageMult = self.zoneDamageMult,
        burnDecayMult = self.zoneDecayMult,
    })
end

--- Puts a zone down (with its visual, see FireZoneVisual for styles).
-- @return the zone, or nil if the game has no enemy effect manager
function FireZoneEffect.spawn(game, config, style)
    if not (game and game.enemyEffectManager) then return nil end
    config.game = game
    local em = game.enemyEffectManager
    em:applyEffect(FireZoneEffect:new(config))
    -- applyEffect stores a copy; the visual has to follow that one
    local zone = em.activeEffects[#em.activeEffects]
    if game.animations then
        local FireZoneVisual = require("Graphics.Animations.FireZoneVisual")
        table.insert(game.animations, FireZoneVisual:new(zone, style))
    end
    return zone
end

--- 0..1, fading out over the last half second (for visuals).
function FireZoneEffect:getAlpha()
    if self.spent then return 0 end
    return math.max(0, math.min(1, self.duration / 0.5))
end

return FireZoneEffect
