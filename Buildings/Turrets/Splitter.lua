local Turret = require("Buildings.Turrets.Turret")
local Splitter = setmetatable({}, Turret)
Splitter.__index = Splitter

default = {
    damage = 10,
    fireRate = 2, -- seconds between shots
    spread = 0.1,
    splitamount = 5,
    splitDamage = 25,
    color = {0, 0, 1},
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
                hitCache = {},
                damage = self.splitDamage,
                game = self.game,
            }
            for k, v in pairs(self.hitCache) do
                splitBulletConfig.hitCache[k] = v
            end
            self.game:addObject(self:new(splitBulletConfig))
        end
    end)
    return instance
end

function Splitter:fire(args)
    args.spread = self.spread
    args.splitamount = self.splitamount
    args.splitDamage = self.splitDamage
    Turret.fire(self, args)
end

return Splitter