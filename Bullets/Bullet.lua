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

    if target then 
        target:takeDamage(self:getStat("damage"), self.damageType)
    end
    
    self.pierce = self.pierce - 1

    if self.hitEffects then
        for _, effectTemplate in ipairs(self.hitEffects) do
            if effectTemplate.isIndependent then
                if effectTemplate.trigger then
                    effectTemplate:trigger(target, self)
                elseif effectTemplate.onApply and target and target.effectManager then
                    target.effectManager:applyEffect(effectTemplate, self)
                end
            elseif target and target.effectManager then
                target.effectManager:applyEffect(effectTemplate, self)
            end
        end
    end
    
    if self.pierce <= 0 then
        self:died()
    end
end

return Bullet