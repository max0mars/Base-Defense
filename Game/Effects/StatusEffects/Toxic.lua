local Toxic = {
    timePerTick = 0.5
}
Toxic.__index = Toxic

function Toxic:new(config)
    config = config or {}
    local instance = setmetatable({}, Toxic)
    
    -- Configurable variables
    instance.name = "toxic"
    instance.displayName = "Toxic"
    instance.duration = config.duration or 8
    instance.dps = config.dps or 6
    instance.speedMult = config.speedMult or -0.15
    instance.bloomDamage = config.bloomDamage or 15
    instance.globalStacks = true
    
    -- Internal state
    instance.time = 0
    
    -- Built-in stat modifiers for speed reduction
    instance.statModifiers = {
        speed = { mult = instance.speedMult }
    }
    
    return instance
end

function Toxic:onUpdate(dt, target)
    self.time = self.time + dt
    if self.time >= self.timePerTick then
        target:takeDamage(self.dps * self.timePerTick, "toxic")
        self.time = self.time - self.timePerTick
    end
end

function Toxic:onDeath(target)
    -- Spawn a burst of shards instead of an explosion
    local ToxicShard = require("Bullets.ToxicShard")
    local numShards = 8
    
    for i = 1, numShards do
        local angle = love.math.random() * math.pi * 2
        local shard = ToxicShard:new({
            game = target.game,
            source = target,
            x = target.x,
            y = target.y,
            angle = angle,
            hitCache = {[target:getID()] = true} -- Skip the enemy that just died
        })
        target.game:addObject(shard)
    end
end

return Toxic
