local Bullet = require("Bullets.Bullet")
local ShrapnelBullet = require("Bullets.ShrapnelBullet")

local AirburstBullet = setmetatable({}, { __index = Bullet })
AirburstBullet.__index = AirburstBullet

function AirburstBullet:new(config)
    local b = Bullet:new(config)
    setmetatable(b, { __index = self })
    
    b.airburstTimer = 0
    b.airburstDelay = 1
    
    return b
end

function AirburstBullet:update(dt)
    if self.destroyed then return end
    
    -- Store destruction state before movement
    local alreadyDead = self.destroyed
    
    -- Handle movement and collision
    Bullet.update(self, dt)
    
    -- If it hit an enemy and was destroyed, it doesn't airburst
    if self.destroyed and not alreadyDead then return end
    
    -- Handle the airburst timer
    self.airburstTimer = self.airburstTimer + dt
    if self.airburstTimer >= self.airburstDelay then
        self:airburst()
    end
end

function AirburstBullet:airburst()
    -- Calculate damage multiplier relative to the source turret's base damage
    -- This ensures that buffs applied to the turret are propagated to the shrapnel
    local turretBaseDamage = (self.source and self.source.damage) or 10
    local damageMult = self:getStat("damage") / turretBaseDamage
    
    -- 5 high-damage Shrapnel bullets in a forward-facing cone
    local angles = {-30, -15, 0, 15, 30}
    for _, offsetDeg in ipairs(angles) do
        local offsetRad = math.rad(offsetDeg)
        local config = {
            game = self.game,
            source = self.source,
            x = self.x,
            y = self.y,
            angle = self.angle + offsetRad,
            bulletSpeed = 800,
            damage = 25 * damageMult,
            pierce = 1,
            lifespan = 0.5,
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
        self.game:addObject(ShrapnelBullet:new(config))
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
