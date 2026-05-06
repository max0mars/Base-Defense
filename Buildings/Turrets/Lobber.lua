local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")
local LobberBullet = require("Bullets.LobberBullet")
local ExplosionEffect = require("Game.Effects.IndependantEffects.explosion")

local Lobber = setmetatable({}, { __index = Turret })
Lobber.__index = Lobber

-- Source of Truth: All stats in a single flat table
Lobber.template = {
    name = "Lobber",
    size = 15,
    rotation = 0,
    turnSpeed = math.huge,
    fireRate = 0.3,
    range = 500,
    barrel = 15,
    color = {1, 1, 1, 1},
    types = { turret = true, lobber = true },
    shapePattern = {{0,0}},
    firingArc = {
        direction = 0,
        minRange = 200,
        angle = math.pi/6
    },
    
    -- Bullet properties (now flat)
    bulletName = "Lobber Shell",
    bulletSpeed = 400,
    damageType = "explosive",
    damage = 35, 
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

function Lobber:new(config)
    local baseConfig = Utils.deepCopy(Lobber.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    baseConfig.bulletType = LobberBullet
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

return Lobber
