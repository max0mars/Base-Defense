local LobberBullet = require("Bullets.LobberBullet")

local MortarBullet = setmetatable({}, LobberBullet)
MortarBullet.__index = MortarBullet

function MortarBullet:new(config)
    local b = LobberBullet.new(self, config)
    return b
end

return MortarBullet
