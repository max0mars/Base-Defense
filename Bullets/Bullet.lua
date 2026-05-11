local object = require("Classes.object")
--local collision = require("Physics.collisionSystem")

Bullet = setmetatable({}, object)
Bullet.__index = Bullet

function Bullet:new(config)
    if not config then
        error("Developer Error: Bullet:new called with nil config.")
    end

    local required = {"name", "bulletSpeed", "damage", "pierce", "lifespan", "w", "h", "shape"}
    for _, key in ipairs(required) do
        if config[key] == nil then
            error("Developer Error: Bullet [" .. (config.name or "Unknown") .. "] is missing the '" .. key .. "' field in config.")
        end
    end

    if(config.source == nil) then error("Bullet has no source??? Where did it come from then??? (set config.source when creating bullet)") end
    local b = setmetatable(object:new(config), { __index = self }) -- Create a new object with the base properties
    b.angle = config.angle or 0 -- Angle of the bullet
    b.hitCache = config.hitCache or {} -- Cache for hit enemies to avoid multiple hits
    b.tags = config.tags or {} -- Initialize tags table
    b.source = config.source -- Track bullet source for stat calculation
    b.damageType = config.damageType or "normal"
    b.hitEffects = config.hitEffects or {}
    b.displayLifespan = config.displayLifespan or 0.1


    -- Effect Stats
    b.poison_from_damage = config.poison_from_damage or 0
    b.dps_poison = config.dps_poison or 0
    b.duration_poison = config.duration_poison or 0
    b.maxStacks = config.maxStacks or 0
    b.splitamount = config.splitamount or 0
    b.spread = config.spread or 0
    b.splitDamage = config.splitDamage or 0
    b.splitDamage_from_damage = config.splitDamage_from_damage or 0
    b.radius = config.radius or 0
    b.explosionDamage = config.explosionDamage or 0
    b.explosion_from_damage = config.explosion_from_damage or 0
    b.canDirectHit = config.canDirectHit
    if b.canDirectHit == nil then b.canDirectHit = true end
    
    b.color = config.color or {1, 1, 0.8, 1}
    b.trail = {}
    b.maxTrail = 5
    
    return b
end

function Bullet:update(dt)
    if self.destroyed then return end
    if self.x > self.game.ground.x + self.game.ground.w or self.x < self.game.ground.x or self.y < self.game.ground.y or self.y > self.game.ground.y + self.game.ground.h then
        self:died() -- bullet hit wall
        return
    end
    self.lifespan = self.lifespan - dt
    if self.lifespan <= 0 then
        self:died()
        return
    end
    -- Store previous position
    local oldX, oldY = self.x, self.y
    
    -- Calculate new position
    self.x = self.x + math.cos(self.angle) * self:getStat("bulletSpeed") * dt
    self.y = self.y + math.sin(self.angle) * self:getStat("bulletSpeed") * dt
    
    -- Update Trail
    table.insert(self.trail, 1, {x = self.x, y = self.y})
    if #self.trail > self.maxTrail then
        table.remove(self.trail)
    end
end

function Bullet:draw()
    local r, g, b, a = unpack(self.color or {1, 1, 1, 1})
    
    -- 1. Draw Fading Trail
    if #self.trail > 1 then
        for i = 1, #self.trail - 1 do
            local p1 = self.trail[i]
            local p2 = self.trail[i+1]
            local alpha = (1 - (i / #self.trail)) * 0.5
            
            -- Glow Layer
            love.graphics.setColor(r, g, b, alpha * 0.4)
            love.graphics.setLineWidth(4)
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
            
            -- Core Layer
            love.graphics.setColor(r, g, b, alpha)
            love.graphics.setLineWidth(1.5)
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
        end
    end
    
    -- 2. Draw Bullet Head
    -- Outer Glow
    love.graphics.setColor(r, g, b, 0.3)
    love.graphics.circle("fill", self.x, self.y, self.w * 0.8)
    
    -- Main Shape
    love.graphics.setColor(r, g, b, 1)
    if self.shape == "pill" or self.shape == "ray" then
        local angle = self.angle
        local length = self.w
        local x1 = self.x - math.cos(angle) * length/2
        local y1 = self.y - math.sin(angle) * length/2
        local x2 = self.x + math.cos(angle) * length/2
        local y2 = self.y + math.sin(angle) * length/2
        love.graphics.setLineWidth(3)
        love.graphics.line(x1, y1, x2, y2)
    else
        love.graphics.circle("fill", self.x, self.y, self.w / 2)
    end
    
    -- Bright Core
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", self.x, self.y, self.w / 4)
    
    -- Reset state
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Bullet:onCollision(obj)
    if self.destroyed then return end
    if obj:isType('enemy') and not self.hitCache[obj:getID()] then
        self.hitCache[obj:getID()] = true -- Mark this enemy as hit
        self:onHit(obj) -- Call the hit function
    end
end

function Bullet:onHit(target)
    -- Visual Feedback
    self.game:spawnParticleExplosion(self.color, 8, self.x, self.y)

    -- Immediately mark target as hit in the cache (regardless of damage)
    if target then 
        self.hitCache[target:getID()] = true
    end

    -- 1. Trigger Independent Effects (The Payload)
    -- These trigger regardless of canDirectHit
    if self.hitEffects then
        for _, effectTemplate in ipairs(self.hitEffects) do
            if effectTemplate.isIndependent then
                if effectTemplate.trigger then
                    effectTemplate:trigger(target, self)
                end
            end
        end
    end
    
    -- 2. Conditional Direct Impact (Contact Damage & Status Effects)
    if self:getStat("canDirectHit") then
        if target then 
            target:takeDamage(self:getStat("damage"), self.damageType)
        end

        -- Apply non-independent status effects (Poison, Fire, etc.)
        if self.hitEffects then
            for _, effectTemplate in ipairs(self.hitEffects) do
                if not effectTemplate.isIndependent and target and target.effectManager then
                    target.effectManager:applyEffect(effectTemplate, self)
                end
            end
        end
    end

    self.pierce = self.pierce - 1
    if self.pierce <= 0 then
        self:died()
    end
end

return Bullet