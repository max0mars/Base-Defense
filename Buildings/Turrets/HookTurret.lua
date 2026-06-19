local Turret = require("Buildings.Turrets.Turret")
local StunEffect = require("Game.Effects.StatusEffects.Stun")
local Utils = require("Classes.Utils")

local HookTurret = setmetatable({}, { __index = Turret })
HookTurret.__index = HookTurret

HookTurret.template = {
    name = "The Hook",
    rotation = 0,

    fireRate = 0.2,
    range = 300,
    barrel = 15,
    firingArc = { direction = 0, minRange = 0, angle = math.pi/4 },
    shapePattern = {{0,0}},
    color = {0.7, 0.4, 0.4, 1},
    types = { turret = true, stun = true},
    
    -- Bullet Properties
    bulletName = "Heavy Hook",
    bulletSpeed = 250,
    damageType = "normal",
    damage = 25,
    pierce = 1,
    lifespan = 2,
    bulletW = 8, 
    bulletH = 8, 
    
    -- Values for effect initialization
    duration_stun = 3,
}

function HookTurret:new(config)
    local baseConfig = Utils.deepCopy(HookTurret.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    -- Initialize hit effects from the config values
    local stunEffectConfig = {
        name = "stun",
        duration = baseConfig.duration_stun
    }
    baseConfig.hitEffects = {StunEffect:new(stunEffectConfig)}
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    
    return t
end

function HookTurret:drawCustomBase(cx, cy)
    love.graphics.rectangle("line", cx - 10, cy - 10, 20, 20)
end

function HookTurret:drawCustomBarrel()
    love.graphics.rectangle("fill", 0, -3, self.barrel, 6)
    love.graphics.rectangle("line", 0, -3, self.barrel, 6)
end

return HookTurret
