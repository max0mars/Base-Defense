local Turret = require("Buildings.Turrets.Turret")
local Split = require("Game.Effects.IndependantEffects.split")
local Splitter = setmetatable({}, Turret)
Splitter.__index = Splitter

--[[
Splitter Turret:
- Same functionality as regular turret but with on hit effect:
- Fires a projectile that splits into multiple smaller projectiles upon hitting an enemy.
--]]

default = {
    damage = 10,
    fireRate = 0.5, -- Hz (was 2s delay)
    spread = 0.1,
    splitamount = 5,
    splitDamage = 25,
    types = { turret = true },
    color = {0, 0, 1},
    firingArc = {
        direction = 0,    -- Firing arc facing direction in radians
        minRange = 0,     -- Minimum firing range
        angle = math.pi/10   -- Firing arc angle size in radians
    },
}

function Splitter:new(config)
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end


    local instance = Turret:new(config)
    setmetatable(instance, Splitter)

    instance:addHitEffect(Split:new{})
    return instance
end

function Splitter:fire(args)
    args.spread = self.spread
    args.splitamount = self.splitamount
    args.splitDamage = self.splitDamage
    Turret.fire(self, args)
end

return Splitter