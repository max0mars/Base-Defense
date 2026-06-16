local AcidCloudEffect = {}
AcidCloudEffect.__index = AcidCloudEffect

function AcidCloudEffect:new(config)
    local instance = setmetatable({}, AcidCloudEffect)
    instance.name = config.name or "acid_cloud"
    instance.duration = config.duration or 5.0
    instance.x = config.x or 0
    instance.y = config.y or 0
    instance.radius = config.radius or 80
    instance.dps = config.dps or 25
    instance.game = config.game
    instance.tickTimer = 0
    return instance
end

function AcidCloudEffect:onApply(target, source)
    -- Optional apply logic
end

function AcidCloudEffect:onUpdate(dt, owner)
    if not self.game then return end
    
    self.tickTimer = self.tickTimer + dt
    if self.tickTimer >= 0.2 then
        local dmg = self.dps * self.tickTimer
        self.tickTimer = 0
        
        local r2 = self.radius * self.radius
        for _, obj in ipairs(self.game.objects) do
            if obj:isType("enemy") and not obj.destroyed then
                local dx = obj.x - self.x
                local dy = obj.y - self.y
                if dx*dx + dy*dy <= r2 then
                    obj:takeDamage(dmg, "poison")
                end
            end
        end
    end
end

return AcidCloudEffect
