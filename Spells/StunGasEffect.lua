-- StunGasEffect.lua - The cloud left by the Stun Gas spell (lives on the global
-- enemyEffectManager, like AcidCloudEffect). Every enemy inside the cloud is
-- stunned once: those caught when it's cast, and any that walk in while it lingers.

local Stun = require("Game.Effects.StatusEffects.Stun")

local StunGasEffect = {}
StunGasEffect.__index = StunGasEffect

function StunGasEffect:new(config)
    local instance = setmetatable({}, StunGasEffect)
    instance.name = config.name or "stun_gas"
    instance.duration = config.duration or 1.5
    instance.x = config.x or 0
    instance.y = config.y or 0
    instance.radius = config.radius or 40
    instance.stunDuration = config.stunDuration or 2.0
    instance.game = config.game
    instance.stunned = {} -- enemy -> true once this cloud has stunned it
    return instance
end

--- Stuns every enemy inside the cloud that it hasn't stunned yet.
function StunGasEffect:stunEnemiesInside()
    if not self.game then return end
    local r2 = self.radius * self.radius
    for _, obj in ipairs(self.game.objects) do
        if obj:isType("enemy") and not obj.destroyed and not self.stunned[obj] then
            local dx = obj.x - self.x
            local dy = obj.y - self.y
            if dx * dx + dy * dy <= r2 and obj.effectManager then
                self.stunned[obj] = true
                obj.effectManager:applyEffect(Stun:new({ duration = self.stunDuration }))
            end
        end
    end
end

function StunGasEffect:onUpdate(dt, owner)
    self:stunEnemiesInside()
end

return StunGasEffect
