local Turret = require("Buildings.Turrets.Turret")
local BounceEffect = require("Game.Effects.IndependantEffects.bounce")

local ChainLaser = setmetatable({}, { __index = Turret })
ChainLaser.__index = ChainLaser

local template = {
    name = "Chain Laser",
    rotation = 0,
    turnSpeed = 5,
    fireRate = 1.2,
    damage = 40,
    bulletSpeed = 600,
    range = 500,
    barrel = 15,
    lifespan = 5,
    firingArc = {
        direction = 0,
        minRange = 0,
        angle = math.pi / 6 -- Aimable 30-degree cone
    },
    shapePattern = {
        {0, 0}
    },
    color = {0.4, 0.7, 1, 1}, -- Electric blue
    bulletW = 6,
    bulletH = 6,
    bulletName = "Lazer Bolt",
    damageType = "energy",
    bouncesLeft = 10,
    cost = 500, -- Legendary price
    types = { turret = true, legendary = true, energy = true, laser = true }
}

function ChainLaser:new(config)
    -- Deep copy the template to avoid shared table references
    local baseConfig = {}
    for k, v in pairs(template) do
        if type(v) == "table" then
            baseConfig[k] = {}
            for k2, v2 in pairs(v) do baseConfig[k][k2] = v2 end
        else
            baseConfig[k] = v
        end
    end

    if config then
        for k, v in pairs(config) do
            if type(v) == "table" and baseConfig[k] then
                for k2, v2 in pairs(v) do baseConfig[k][k2] = v2 end
            else
                baseConfig[k] = v
            end
        end
    end
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    
    -- Add the bounce effect to the turret's hit effects
    t.hitEffects = { BounceEffect:new({ name = "Chain Bounce" }) }
    
    return t
end

function ChainLaser:fire(args)
    args = args or {}
    -- Ensure the bullet knows how many times it can bounce
    args.bouncesLeft = self:getStat("bouncesLeft")
    Turret.fire(self, args)
end

return ChainLaser
