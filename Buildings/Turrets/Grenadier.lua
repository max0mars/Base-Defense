local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")
local GrenadeBullet = require("Bullets.GrenadeBullet")
local ExplosionEffect = require("Game.Effects.IndependantEffects.explosion")

local Grenadier = setmetatable({}, { __index = Turret })
Grenadier.__index = Grenadier

-- Source of Truth: All stats in a single flat table
Grenadier.template = {
    name = "Grenadier",
    size = 15,
    rotation = 0,
    turnSpeed = math.huge,
    fireRate = 0.3,
    range = 500,
    barrel = 15,
    color = {0.3, 0.8, 0.3, 1},
    baseShape = "circle",
    barrelShape = "thick",
    types = { turret = true, grenadier = true },
    sfx = "gunshot_04",
    shapePattern = {{0,0}},
    firingArc = {
        direction = 0,
        minRange = 200,
        angle = math.pi/6
    },
    
    fuseTime = 1,
    
    -- Bullet properties (now flat)
    bulletName = "Grenade",
    bulletSpeed = 400,
    damageType = "explosive",
    damage = 15, 
    canDirectHit = false,
    pierce = 1,
    lifespan = 3,
    bulletW = 6,
    bulletH = 6,
    bulletShape = "rectangle",
    hitEffects = {
        ExplosionEffect:new({explosionDamage = 0, radius = 0}) -- 0 values here because they will flow from the bullet/turret
    }
}

function Grenadier:new(config)
    local baseConfig = Utils.deepCopy(Grenadier.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    baseConfig.bulletType = GrenadeBullet
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    
    -- Add inherent stats via a hidden buff
    t.effectManager:applyEffect({
        name = "Inherent Explosion",
        statModifiers = {
            radius = {max = 30, hidden = true},
            explosion_from_damage = {max = 1, hidden = true}
        }
    })
    
    return t
end

return Grenadier
