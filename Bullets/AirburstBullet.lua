local Bullet = require("Bullets.Bullet")

local AirburstBullet = setmetatable({}, { __index = Bullet })
AirburstBullet.__index = AirburstBullet

-- The shell bursts once it has flown this fraction of the turret's base range
AirburstBullet.BURST_RANGE_FRACTION = 0.6
AirburstBullet.SHRAPNEL_SPEED = 800
AirburstBullet.SHRAPNEL_LIFESPAN = 0.5
AirburstBullet.SHRAPNEL_CONE = 60 -- degrees, edge to edge

function AirburstBullet:new(config)
    local b = Bullet:new(config)
    setmetatable(b, { __index = self })

    b.startX, b.startY = b.x, b.y
    -- Base range excludes in-battle range buffs, so the burst point stays put
    local baseRange = (config.source and config.source.range) or (b.bulletSpeed * b.lifespan)
    b.burstDistance = baseRange * self.BURST_RANGE_FRACTION

    return b
end

function AirburstBullet:update(dt)
    if self.destroyed then return end

    -- Burst instead of silently expiring if lifespan would run out first
    if self.lifespan - dt <= 0 then
        self:airburst()
        return
    end

    -- Handle movement and collision
    Bullet.update(self, dt)

    -- If it hit an enemy or a wall, it doesn't airburst
    if self.destroyed then return end

    local dx, dy = self.x - self.startX, self.y - self.startY
    if dx * dx + dy * dy >= self.burstDistance * self.burstDistance then
        self:airburst()
    end
end

function AirburstBullet:airburst()
    -- Shrapnel damage follows the shell's (already buffed) damage, like split shards
    local finalDamage
    local mult = self:getStat("splitDamage_from_damage")
    if mult > 0 then
        finalDamage = self:getStat("damage") * mult
    else
        local damageMult = 1
        if self.source and self.source.effectManager then
            damageMult = self.source.effectManager:getStatMult("damage")
        end
        finalDamage = self:getStat("splitDamage") * damageMult
    end
    if finalDamage <= 0 then
        finalDamage = self:getStat("damage")
    end

    -- Shrapnel must still reach the turret's current (possibly buffed) range
    local dx, dy = self.x - self.startX, self.y - self.startY
    local travelled = math.sqrt(dx * dx + dy * dy)
    local currentRange = self.source and self.source:getStat("range") or 0
    local remaining = math.max(0, currentRange - travelled)
    local shrapnelLifespan = math.max(self.SHRAPNEL_LIFESPAN, remaining * 1.1 / self.SHRAPNEL_SPEED)

    -- `splitamount` small, fast Shrapnel bullets spread evenly over a forward-facing cone
    local count = math.max(1, math.floor(self:getStat("splitamount")))
    for i = 1, count do
        local offsetRad = 0
        if count > 1 then
            offsetRad = math.rad(-self.SHRAPNEL_CONE / 2 + (i - 1) * self.SHRAPNEL_CONE / (count - 1))
        end
        local config = {
            game = self.game,
            source = self.source,
            x = self.x,
            y = self.y,
            angle = self.angle + offsetRad,
            bulletSpeed = self.SHRAPNEL_SPEED,
            damage = finalDamage,
            pierce = 1,
            lifespan = shrapnelLifespan,
            w = 4,
            h = 6,
            shape = "ray",
            color = {1, 0.8, 0.2, 1},
            hitbox = {shape = "rectangle"},
            tags = {"bullet"},
            types = { bullet = true },
            effectManager = true, -- Allow shrapnel to receive buffs directly
            -- Propagate all buffs and effects
            hitEffects = self.hitEffects,
            damageType = self.damageType,
            poison_from_damage = self.poison_from_damage,
            dps_poison = self.dps_poison,
            duration_poison = self.duration_poison,
            maxStacks = self.maxStacks,
            explosionDamage = self.explosionDamage,
            explosion_from_damage = self.explosion_from_damage,
            radius = self.radius,
            recursion = self.recursion,
            recursionSpread = self.recursionSpread
        }
        local BulletIndex = require("Bullets.BulletIndex")
        local shrapnelDef = BulletIndex.shrapnel
        for k, v in pairs(shrapnelDef) do
            if k ~= "class" then config[k] = v end
        end
        self.game:addObject(shrapnelDef.class:new(config))
    end
    
    -- Visual pop effect
    if self.game.spawnParticleExplosion then
        self.game:spawnParticleExplosion({1, 1, 1, 1}, 15, self.x, self.y)
    end
    
    -- Destroy the original bullet without triggering recursion
    self.skipRecursion = true
    self:died()
end

return AirburstBullet
