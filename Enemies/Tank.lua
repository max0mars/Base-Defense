local Enemy = require("Enemies.Enemy")
local Tank = setmetatable({}, {__index = Enemy})
Tank.__index = Tank

local Stats = {
    name = "Tank",
    reward = 55,
    armour = 0,
    hitbox = true,
    effectManager = true,
}

function Tank:new(config)
    config = config or {}
    for key, value in pairs(Stats) do
        config[key] = config[key] or value
    end
    
    local obj = Enemy:new(config)
    setmetatable(obj, { __index = self })
    
    if not obj.affinities then
        obj.affinities = {
            normal = 1,
            poison = 1,
            trueDamage = 1,
            fire = 1,
            explosive = 1,
            energy = 1,
            heal = 1.5
        }
    else
        obj.affinities.heal = obj.affinities.heal or 1.5
    end
    
    return obj
end

return Tank
