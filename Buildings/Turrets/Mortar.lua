local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")
local MortarBullet = require("Bullets.MortarBullet")
local ExplosionEffect = require("Game.Effects.IndependantEffects.explosion")

local Mortar = setmetatable({}, { __index = Turret })
Mortar.__index = Mortar

-- Source of Truth: All stats in a single flat table
Mortar.template = {
    name = "Mortar",
    size = 15,
    rotation = 0,
    turnSpeed = math.huge,
    fireRate = 0.3,
    range = 500,
    barrel = 15,
    color = {1, 1, 1, 1},
    baseShape = "circle",
    barrelShape = "thick",
    types = { turret = true, mortar = true },
    shapePattern = {{0,0}},
    firingArc = {
        direction = 0,
        minRange = 200,
        angle = math.pi/6
    },
    
    -- Bullet properties (now flat)
    bulletName = "Mortar Shell",
    bulletSpeed = 400,
    damageType = "explosive",
    damage = 40, 
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

function Mortar:new(config)
    local baseConfig = Utils.deepCopy(Mortar.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    baseConfig.bulletType = MortarBullet
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

return Mortar
