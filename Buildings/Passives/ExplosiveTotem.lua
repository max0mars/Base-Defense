local Buff = require("Buildings.Passives.Buff")
local ExplosionEffect = require("Game.Effects.IndependantEffects.explosion")

local ExplosiveTotem = setmetatable({}, Buff)
ExplosiveTotem.__index = ExplosiveTotem

local default = {
    name = "Explosive Totem",
    types = { passive = true, explosive = true },
    affectedSlots = {{1, 0}, {2, 0}}, -- Affects adjacent turrets in a cross pattern
    color = {1, 0.4, 0, 1}, -- Vibrant neon orange
    
    -- Configuration used to initialize the Explosion independent effect
    explosionConfig = {
        name = "Explosive Ammo",
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
            radius = {max = 35, hidden = true},
            --explosionDamage = {max = 25, hidden = true},
            explosion_from_damage = {max = 0.5, hidden = true}
        }
    }
    
    local obj = Buff:new(config)
    setmetatable(obj, self)
    return obj
end

-- Sprite: a bomb with a sparking fuse
function ExplosiveTotem:drawShape(cx, cy, s)
    local bx, by, br = cx - s * 0.15, cy + s * 0.25, s * 0.7
    love.graphics.circle("line", bx, by, br)
    -- Fuse cap
    love.graphics.polygon("line",
        bx + br * 0.45, by - br * 0.95, bx + br * 0.95, by - br * 0.45,
        bx + br * 1.15, by - br * 0.65, bx + br * 0.65, by - br * 1.15)
end

function ExplosiveTotem:drawDetail(cx, cy, s)
    local bx, by, br = cx - s * 0.15, cy + s * 0.25, s * 0.7
    local fx, fy = bx + br * 0.9, by - br * 0.9
    local tx, ty = cx + s * 0.85, cy - s * 0.85
    love.graphics.line(fx, fy, fx + s * 0.05, ty + s * 0.15, tx, ty)
    -- Highlight
    love.graphics.arc("line", "open", bx, by, br * 0.6, math.pi * 1.05, math.pi * 1.45)
    -- Spark
    local k = s * (0.2 + 0.1 * math.abs(math.sin(love.timer.getTime() * 19)))
    love.graphics.setColor(1, 0.85, 0.3, 1)
    love.graphics.line(tx - k, ty, tx + k, ty)
    love.graphics.line(tx, ty - k, tx, ty + k)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", tx, ty, 1)
end

return ExplosiveTotem
