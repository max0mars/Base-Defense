local Toxic = {
    timePerTick = 1
}
Toxic.__index = Toxic

function Toxic:new(config)
    config = config or {}
    local instance = setmetatable({}, Toxic)
    
    -- Configurable variables
    instance.name = "toxic"
    instance.displayName = "Toxic"
    instance.duration = config.duration or 10
    instance.tickDamage = config.tickDamage or 2
    instance.speedMult = config.speedMult or -0.15
    instance.bloomDamage = config.bloomDamage or 0
    instance.globalStacks = 1
    instance.isDebuff = true
    
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
        target:takeDamage(self.tickDamage, "poison", nil, nil, { "dot", "toxic" }, self.damageSource)
        self.time = self.time - self.timePerTick
    end
end

-- Bursts into shards that infect nearby enemies. Shards deal no damage, so the
-- spread can chain indefinitely.
function Toxic:onDeath(target)
    local BulletIndex = require("Bullets.BulletIndex")
    local shardDef = BulletIndex.toxicShard
    local numShards = 4
    local baseAngle = love.math.random() * math.pi * 2
    local angleStep = (math.pi * 2) / numShards
    
    for i = 1, numShards do
        local minAngle = baseAngle + (i - 1) * angleStep
        local angle = minAngle + (love.math.random() * angleStep)
        
        local config = {
            game = target.game,
            source = target,
            x = target.x,
            y = target.y,
            angle = angle,
            damage = self.bloomDamage,
            hitCache = {[target:getID()] = true}, -- Skip the enemy that just died
            name = "Toxic Shard",
            bulletSpeed = 350,
            pierce = 1,
            lifespan = 0.25,
            damageType = "poison",
            damageTags = { "projectile", "toxic" }
        }
        for k, v in pairs(shardDef) do
            if k ~= "class" then config[k] = v end
        end
        
        local shard = shardDef.class:new(config)
        target.game:addObject(shard)
    end
end

return Toxic
