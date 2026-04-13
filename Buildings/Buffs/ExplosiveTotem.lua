local Buff = require("Buildings.Buffs.Buff")
local ExplosionEffect = require("Game.Effects.IndependantEffects.explosion")

local ExplosiveTotem = setmetatable({}, Buff)
ExplosiveTotem.__index = ExplosiveTotem

local default = {
    name = "Explosive Totem",
    types = { passive = true, totem = true, explosive = true },
    affectedSlots = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}, -- Affects adjacent turrets in a cross pattern
    color = {1, 0.4, 0, 1}, -- Vibrant neon orange
    
    -- Configuration used to initialize the Explosion independent effect
    explosionConfig = {
        name = "Explosive Ammo",
        explosionDamage = 0, -- Base values are 0 because they flow from modifiers
        radius = 0
    }
}

function ExplosiveTotem:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    
    -- This effect is granted to nearby turrets
    config.effect = {
        name = "Explosive Ammo Coating",
        grantedHitEffect = ExplosionEffect:new(config.explosionConfig),
        duration = math.huge,
        statModifiers = {
            -- Sets the explosion parameters for turrets that don't have them,
            -- or upgrades them for turrets that do.
            radius = {max = 65},
            --explosionDamage = {max = 25, hidden = true},
            explosion_from_damage = {max = 0.5, hidden = true}
        }
    }
    
    local obj = Buff:new(config)
    setmetatable(obj, self)
    return obj
end

return ExplosiveTotem
