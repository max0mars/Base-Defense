local Turret = require("Buildings.Turrets.Turret")
local Splitter = setmetatable({}, Turret)
Splitter.__index = Splitter

default = {
    damage = 5,
    fireRate = 2, -- seconds between shots
    spread = 0.1,
    splitamount = 5,
    splitDamage = 25
}

function Splitter:new(config)
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end

    local instance = Turret:new(config)
    setmetatable(instance, Splitter)

    instance:addHitEffect(function(self)
        for i = 1, self.splitamount do
            local angle = self.angle + (i * self.spread) - (self.spread * self.splitamount/2)
            local splitBulletConfig = {
                x = self.x,
                y = self.y,
                angle = angle,
                hitCache = self.hitCache,
                damage = self.splitDamage,
                game = self.game,
            }
            self.game:addObject(self.bulletType:new(splitBulletConfig))
        end
    end)
    return instance
end

function Splitter:fire(args)
    args.spread = 0.1
    args.splitamount = 5
    args.splitDamage = 5
    Turret.fire(self, args)
end

return Splitter