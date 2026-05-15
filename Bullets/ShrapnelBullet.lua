local Bullet = require("Bullets.Bullet")

local ShrapnelBullet = setmetatable({}, { __index = Bullet })
ShrapnelBullet.__index = ShrapnelBullet

function ShrapnelBullet:new(config)
    config.name = config.name or "Shrapnel"
    config.bulletSpeed = config.bulletSpeed or 800
    config.damage = config.damage or 25
    config.pierce = config.pierce or 1
    config.lifespan = config.lifespan or 0.5
    config.w = config.w or 4
    config.h = config.h or 6
    config.shape = config.shape or "ray" 
    config.color = config.color or {1, 0.8, 0.2, 1} 
    
    local b = Bullet:new(config)
    setmetatable(b, { __index = self })
    return b
end

return ShrapnelBullet
