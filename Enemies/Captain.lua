local Enemy = require("Enemies.Enemy")
local Captain = setmetatable({}, {__index = Enemy})
Captain.__index = Captain

local Stats = {
    name = "Captain",
    reward = 40,
    armour = 0,
    hitbox = true,
    effectManager = true,
}

function Captain:new(config)
    config = config or {}
    for key, value in pairs(Stats) do
        config[key] = config[key] or value
    end
    
    local obj = Enemy:new(config)
    setmetatable(obj, { __index = self })
    
    obj.range = config.range or 120
    obj.targets = config.targets or 1
    obj.clearCooldown = config.clearCooldown or 3.0
    obj.clearTimer = 0
    
    return obj
end

function Captain:update(dt)
    if self.destroyed then return end
    
    -- Call parent update (Enemy.lua handles navigation, base collision, etc.)
    Enemy.update(self, dt)
    
    if self:getStat("stunned", 0) > 0 then return end
    
    self.clearTimer = self.clearTimer + dt
    if self.clearTimer >= self.clearCooldown then
        self.clearTimer = self.clearTimer - self.clearCooldown
        self:clearNearbyDebuffs()
    end
end

function Captain:clearNearbyDebuffs()
    local radiusSq = self.range * self.range
    local candidates = {}
    
    for _, obj in ipairs(self.game.objects) do
        if obj.isType and obj:isType("enemy") and not obj.destroyed then
            local dx = obj.x - self.x
            local dy = obj.y - self.y
            if dx*dx + dy*dy <= radiusSq then
                if obj.effectManager and obj.effectManager:hasDebuff() then
                    table.insert(candidates, obj)
                end
            end
        end
    end
    
    if #candidates > 0 then
        -- Select up to `self.targets` random enemies
        local clearedCount = 0
        local toClear = math.min(self.targets, #candidates)
        
        for i = 1, toClear do
            local idx = math.random(1, #candidates)
            local chosen = table.remove(candidates, idx)
            
            if chosen.effectManager:clearDebuffs() then
                clearedCount = clearedCount + 1
                -- Spawn a nice visual effect on cleared enemy
                if self.game.spawnExpandingCircle then
                    self.game:spawnExpandingCircle(chosen.x, chosen.y, 0, chosen.w * 1.5, {0.2, 0.6, 1.0}, 0.5)
                end
            end
        end
        
        -- Visual effect on Captain showing they activated their ability
        if clearedCount > 0 and self.game.spawnExpandingCircle then
            self.game:spawnExpandingCircle(self.x, self.y, 0, self.range, {0.1, 0.4, 0.9}, 0.6)
        end
    end
end

return Captain
