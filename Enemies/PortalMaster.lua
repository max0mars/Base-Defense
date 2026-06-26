local Enemy = require("Enemies.Enemy")
local PortalMaster = setmetatable({}, {__index = Enemy})
PortalMaster.__index = PortalMaster

local Stats = {
    name = "Portal Master",
    reward = 40,
    armour = 0,
    hitbox = true,
    effectManager = true,
}

function PortalMaster:new(config)
    config = config or {}
    for key, value in pairs(Stats) do
        config[key] = config[key] or value
    end
    
    local obj = Enemy:new(config)
    setmetatable(obj, { __index = self })
    
    obj.range = config.range or 120
    obj.targets = config.targets or 1
    obj.teleportDistance = config.teleportDistance or 80
    obj.teleportCooldown = config.teleportCooldown or 3.0
    obj.teleportTimer = 0
    
    return obj
end

function PortalMaster:update(dt)
    if self.destroyed then return end
    
    -- Call parent update
    Enemy.update(self, dt)
    
    if self:getStat("stunned", 0) > 0 then return end
    
    self.teleportTimer = self.teleportTimer + dt
    if self.teleportTimer >= self.teleportCooldown then
        self.teleportTimer = self.teleportTimer - self.teleportCooldown
        self:teleportAllies()
    end
end

function PortalMaster:teleportAllies()
    local radiusSq = self.range * self.range
    local candidates = {}
    
    for _, obj in ipairs(self.game.objects) do
        if obj.isType and obj:isType("enemy") and obj ~= self and not obj.destroyed then
            local dx = obj.x - self.x
            local dy = obj.y - self.y
            if dx*dx + dy*dy <= radiusSq then
                table.insert(candidates, obj)
            end
        end
    end
    
    if #candidates > 0 then
        local teleportedCount = 0
        local toTeleport = math.min(self.targets, #candidates)
        
        for i = 1, toTeleport do
            local idx = math.random(1, #candidates)
            local chosen = table.remove(candidates, idx)
            
            local speed = chosen:getStat("speed")
            if speed and speed > 0 then
                local oldX, oldY = chosen.x, chosen.y
                local newX, newY = chosen:getFuturePosition(self.teleportDistance / speed)
                
                chosen.x, chosen.y = newX, newY
                
                if chosen.recalculatePath then
                    chosen:recalculatePath()
                end
                
                teleportedCount = teleportedCount + 1
                
                if self.game.spawnExpandingCircle then
                    self.game:spawnExpandingCircle(oldX, oldY, 0, chosen.w * 1.5, {0.9, 0.8, 0.1}, 0.5)
                    self.game:spawnExpandingCircle(newX, newY, chosen.w * 1.5, 0, {0.9, 0.8, 0.1}, 0.5)
                end
            end
        end
        
        if teleportedCount > 0 and self.game.spawnExpandingCircle then
            self.game:spawnExpandingCircle(self.x, self.y, 0, self.range, {0.9, 0.8, 0.2}, 0.6)
        end
    end
end

return PortalMaster
