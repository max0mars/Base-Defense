local LobberBullet = require("Bullets.LobberBullet")

local MortarBullet = setmetatable({}, LobberBullet)
MortarBullet.__index = MortarBullet

function MortarBullet:new(config)
    local b = LobberBullet.new(self, config)
    return b
end

function MortarBullet:onCollision(obj)
    -- Mortars only explode on ground impact
end

return MortarBullet
