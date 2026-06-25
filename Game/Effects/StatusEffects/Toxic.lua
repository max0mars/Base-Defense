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
    instance.duration = config.duration or 16
    instance.dps = config.dps or 6
    instance.speedMult = config.speedMult or -0.15
    instance.bloomDamage = config.bloomDamage or 3
    instance.recursion = config.recursion or 1 -- Default to 1 to prevent infinite loops
    instance.globalStacks = 1
    
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

function Toxic:onOverwrite(oldEffect)
    if oldEffect.recursion and self.recursion then
        self.recursion = math.max(self.recursion, oldEffect.recursion)
    end
end

function Toxic:onDeath(target)
    if self.recursion <= 0 then return end

    -- Spawn a burst of shards instead of an explosion
    local ToxicShard = require("Bullets.ToxicShard")
    local numShards = 4
    local baseAngle = love.math.random() * math.pi * 2
    local angleStep = (math.pi * 2) / numShards
    
    for i = 1, numShards do
        local minAngle = baseAngle + (i - 1) * angleStep
        local angle = minAngle + (love.math.random() * angleStep)
        local shard = ToxicShard:new({
            game = target.game,
            source = target,
            x = target.x,
            y = target.y,
            angle = angle,
            damage = self.bloomDamage,
            hitCache = {[target:getID()] = true}, -- Skip the enemy that just died
            recursion = self.recursion - 1
        })
        target.game:addObject(shard)
    end
end

return Toxic
