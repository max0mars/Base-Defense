local object = require("Classes.object")
local collision = require("Physics.collisionSystem_brute")
local DeathAnimation = require("Graphics.Animations.DeathAnimation")

local HitscanBullet = setmetatable({}, object)
HitscanBullet.__index = HitscanBullet

function HitscanBullet:new(config)
    if not config then
        error("Developer Error: HitscanBullet:new called with nil config.")
    end

    local required = {"name", "damage", "maxLifespan", "color"} -- removed "range"
    for _, key in ipairs(required) do
        if config[key] == nil then
            error("Developer Error: HitscanBullet [" .. (config.name or "Unknown") .. "] is missing the '" .. key .. "' field in config.")
        end
    end

    local obj = setmetatable(object:new(config), { __index = self })
    
    obj.source = config.source
    obj.lifespan = obj.maxLifespan
    obj.tags = config.tags or {"bullet"}
    obj.damageType = config.damageType or "normal"
    obj.hitEffects = config.hitEffects or {}
    
    -- Hitscan endpoint logic
    local x2 = config.targetX --or obj.x + math.cos(obj.angle) * obj:getStat("range")
    local y2 = config.targetY --or obj.y + math.sin(obj.angle) * obj:getStat("range")
    
    local ray = {
        x1 = obj.x, y1 = obj.y,
        x2 = x2, y2 = y2,
        getHitbox = function(s) return s end,
        isType = function() return false end -- Rays aren't themselves types usually
    }
    
    local closestT = 1
    local closestEnemy = nil
    
    for _, other in ipairs(obj.game.objects) do
        if other:isType("enemy") and not other.destroyed then
            local hit, t = collision:rayRect(ray, other)
            if hit and t < closestT then
                closestT = t
                closestEnemy = other
            end
        end
    end
    
    obj.endpoint = {
        x = obj.x + (x2 - obj.x) * closestT,
        y = obj.y + (y2 - obj.y) * closestT
    }
    
    if closestEnemy then
        obj:onHit(closestEnemy)
    end
    
    table.insert(obj.game.animations, DeathAnimation:new(obj.color, 8, obj.endpoint.x, obj.endpoint.y))

    return obj
end



function HitscanBullet:onHit(target)
    target:takeDamage(self:getStat("damage"), self.damageType)
    if target.effectManager then
        for _, effectTemplate in ipairs(self.hitEffects) do
            target.effectManager:applyEffect(effectTemplate, self)
        end
        target.effectManager:triggerEvent("onHit", self)
    end
end

function HitscanBullet:update(dt)
    self.lifespan = self.lifespan - dt
    if self.lifespan <= 0 then
        self.destroyed = true
    end
end

function HitscanBullet:draw()
    local alpha = self.lifespan / self.maxLifespan
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], alpha)
    love.graphics.setLineWidth(2)
    love.graphics.line(self.x, self.y, self.endpoint.x, self.endpoint.y)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end
return HitscanBullet
