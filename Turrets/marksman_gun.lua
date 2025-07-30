local Turret = require("Turrets.Turret")
local marksman_gun = setmetatable({}, {__index = Turret})

local baseConfig = {
    name = "Marksman Gun",
    description = "A long-range turret that excels at picking off enemies from a distance.",
    range = 300,
    damage = 50,
    fireRate = 1.5,
    turnSpeed = math.huge,
    ammoType = "standard",
    mode = 'auto',
    hitEffects = {},
    bulletSpeed = 600,
}

function marksman_gun:new(config)
    local obj = Turret:new(config)
    setmetatable(obj, { __index = self })
    obj.range = config.range or 300
    return obj
end

return marksman_gun