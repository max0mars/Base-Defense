local Enemy = require("Enemies.Enemy")
local Medic = setmetatable({}, {__index = Enemy})
Medic.__index = Medic

local Stats = {
    name = "Medic",
    reward = 50,
    armour = 0,
    hitbox = true,
    effectManager = true,
}

function Medic:new(config)
    config = config or {}
    for key, value in pairs(Stats) do
        config[key] = config[key] or value
    end
    
    local obj = Enemy:new(config)
    setmetatable(obj, { __index = self })
    
    obj.range = config.range or 150
    obj.targets = config.targets or 3
    obj.regenAmount = config.regenAmount or 15 -- HP per second
    obj.attachedTargets = {}
    obj.regenTimer = 0
    
    return obj
end

function Medic:update(dt)
    if self.destroyed then return end
    
    -- Call parent update (Enemy.lua handles navigation, base collision, etc.)
    Enemy.update(self, dt)
    
    if self:getStat("stunned", 0) > 0 then return end
    
    -- 1. Filter out dead or out-of-range attached targets
    local radiusSq = self.range * self.range
    for i = #self.attachedTargets, 1, -1 do
        local t = self.attachedTargets[i]
        if t.destroyed or t.isDead then
            table.remove(self.attachedTargets, i)
        elseif t.hp and t.maxHp and t.hp >= t.maxHp then
            -- Detach from fully healed targets
            table.remove(self.attachedTargets, i)
        else
            local dx = t.x - self.x
            local dy = t.y - self.y
            if dx*dx + dy*dy > radiusSq then
                table.remove(self.attachedTargets, i)
            end
        end
    end
    
    -- 2. If below target limit, scan range and randomly attach to new candidates
    if #self.attachedTargets < self.targets then
        local candidates = {}
        for _, obj in ipairs(self.game.objects) do
            if obj.isType and obj:isType("enemy") and obj ~= self and not obj.destroyed and not obj.isDead
               and obj.hp and obj.maxHp and obj.hp < obj.maxHp then
                -- Check if already attached
                local alreadyAttached = false
                for _, attached in ipairs(self.attachedTargets) do
                    if attached == obj then
                        alreadyAttached = true
                        break
                    end
                end
                
                if not alreadyAttached then
                    local dx = obj.x - self.x
                    local dy = obj.y - self.y
                    if dx*dx + dy*dy <= radiusSq then
                        table.insert(candidates, obj)
                    end
                end
            end
        end
        
        while #self.attachedTargets < self.targets and #candidates > 0 do
            local idx = math.random(1, #candidates)
            local chosen = table.remove(candidates, idx)
            table.insert(self.attachedTargets, chosen)
        end
    end
    
    -- 3. Apply healing to attached targets every 0.5 seconds
    self.regenTimer = self.regenTimer + dt
    while self.regenTimer >= 0.5 do
        local tickTime = 0.5
        self.regenTimer = self.regenTimer - 0.5
        
        for _, t in ipairs(self.attachedTargets) do
            local amountHealed = t:heal(self.regenAmount * tickTime)
            
            -- Spawn healing damage number if accumulated heal >= 1
            if not t.accumulatedHeal then t.accumulatedHeal = 0 end
            t.accumulatedHeal = t.accumulatedHeal + amountHealed
            if t.accumulatedHeal >= 1 then
                local rounded = math.floor(t.accumulatedHeal)
                self.game:spawnDamageNumber(rounded, t.x, t.y, "heal")
                t.accumulatedHeal = t.accumulatedHeal - rounded
            end
        end
    end
end

function Medic:draw()
    -- Draw default Enemy representation
    Enemy.draw(self)
    
    -- Draw attachment beams/lines to attached targets
    if not self.destroyed and not self.isDead and self.attachedTargets then
        for _, t in ipairs(self.attachedTargets) do
            -- Draw a pulsing green healing beam
            love.graphics.setColor(0.2, 1.0, 0.4, 0.4 + 0.2 * math.sin(love.timer.getTime() * 10))
            love.graphics.setLineWidth(2)
            love.graphics.line(self.x, self.y, t.x, t.y)
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1)
    end
end

return Medic
