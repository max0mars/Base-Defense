local Enemy = require("Enemies.Enemy")
local Guardian = setmetatable({}, {__index = Enemy})
Guardian.__index = Guardian

local Stats = {
    speed = 22,
    damage = 20,
    reward = 50,
    armour = 0,
    size = 24,
    shape = "cross",
    color = {0.2, 0.7, 1, 1}, -- Blueish aura color
    maxHp = 250,
    hitbox = true,
    types = { enemy = true, guardian = true },
    effectManager = true,
}

function Guardian:new(config)
    config = config or {}
    for key, value in pairs(Stats) do
        config[key] = config[key] or value
    end
    
    local obj = Enemy:new(config)
    setmetatable(obj, { __index = self })
    
    obj.auraRadius = 150
    obj.grantsShield = false -- Set to true by upgrade
    obj.shieldTimer = 0
    
    return obj
end

function Guardian:update(dt)
    if self.destroyed then return end
    
    -- Call parent update (Enemy.lua handles navigation, base collision, etc.)
    Enemy.update(self, dt)
    
    -- 1. Aura Logic: Buff nearby allies using the effect system
    local radiusSq = self.auraRadius * self.auraRadius
    local auraEffectTemplate = {
        name = "GuardianAura",
        duration = 0.5, -- Refreshable short duration
        maxStacks = 1,
        statModifiers = {
            damageReductionMultiplier = { mult = -0.25 }
        }
    }

    for _, obj in ipairs(self.game.objects) do
        if obj.isType and obj:isType("enemy") and obj ~= self and not obj.destroyed then
            local dx = obj.x - self.x
            local dy = obj.y - self.y
            if dx*dx + dy*dy <= radiusSq then
                local existing = obj.effectManager:getEffect("GuardianAura")
                if existing then
                    existing.duration = 0.2 -- Refresh duration
                else
                    obj.effectManager:applyEffect(auraEffectTemplate)
                end
            end
        end
    end
    
    -- 2. Shield Upgrade Logic
    if self.grantsShield then
        self.shieldTimer = self.shieldTimer + dt
        if self.shieldTimer >= 5.0 then
            self.shieldTimer = 0
            self:grantShieldsToNearby()
        end
    end
end

function Guardian:grantShieldsToNearby()
    local candidates = {}
    for _, obj in ipairs(self.game.objects) do
        if obj.isType and obj:isType("enemy") and obj ~= self and not obj.destroyed then
                local dx = obj.x - self.x
                local dy = obj.y - self.y
                table.insert(candidates, {obj = obj, distSq = dx*dx + dy*dy})
        end
    end
    
    -- Sort by distance
    table.sort(candidates, function(a, b) return a.distSq < b.distSq end)
    
    -- Grant shields to the 5 closest
    for i = 1, math.min(5, #candidates) do
        local target = candidates[i].obj
        target.shield = (target.shield or 0) + 50
    end
end

function Guardian:drawShape(mode, x, y, w, h)
    local thickness = w * 0.35
    -- Vertical Bar
    love.graphics.rectangle(mode, x + (w - thickness)/2, y, thickness, h)
    -- Horizontal Bar
    love.graphics.rectangle(mode, x, y + (h - thickness)/2, w, thickness)
end

function Guardian:draw()
    local r, g, b, a = unpack(self.color)
    local drawX = self.x - self.w/2
    local drawY = self.y - self.h/2
    
    -- Layer 1: Empty Base (Dim)
    love.graphics.setColor(r, g, b, 0.15)
    self:drawShape("fill", drawX, drawY, self.w, self.h)
    
    -- Layer 2: HP Fill (Scissor bottom-up)
    local fillRatio = self.hp / self:getStat("maxHp")
    local scissorY = drawY + self.h * (1 - fillRatio)
    local scissorH = self.h * fillRatio
    
    love.graphics.setScissor(math.floor(drawX), math.floor(scissorY), math.floor(self.w), math.ceil(scissorH))
    love.graphics.setColor(r, g, b, 0.7)
    self:drawShape("fill", drawX, drawY, self.w, self.h)
    love.graphics.setScissor()
    
    -- Layer 3: Shield Fill (Scissor bottom-up)
    if self.maxShield > 0 and self.shield > 0 then
        local shieldRatio = self.shield / self.maxShield
        local sScissorY = drawY + self.h * (1 - shieldRatio)
        local sScissorH = self.h * shieldRatio
        
        love.graphics.setScissor(math.floor(drawX), math.floor(sScissorY), math.floor(self.w), math.ceil(sScissorH))
        love.graphics.setColor(0.6, 0.6, 0.6, 1) -- Flat Grey
        self:drawShape("fill", drawX, drawY, self.w, self.h)
        love.graphics.setScissor()
    end
    
    -- Layer 4: Neon Border & Glow
    for i = 4, 1, -1 do
        local alpha = 0.05 * (1 - i/5)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.setLineWidth(i * 3)
        self:drawShape("line", drawX, drawY, self.w, self.h)
    end
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    self:drawShape("line", drawX, drawY, self.w, self.h)
    
    -- Aura Range Visual (Faint circle)
    love.graphics.setColor(r, g, b, 0.03)
    love.graphics.circle("fill", self.x, self.y, self.auraRadius)
    love.graphics.setColor(r, g, b, 0.15)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", self.x, self.y, self.auraRadius)
end

return Guardian
