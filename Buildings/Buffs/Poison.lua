local Buff = require("Buildings.Buffs.buff")
Poison = setmetatable({}, Buff)
Poison.__index = Poison

default = {
    type = "passive",
    tag = "onHit",
    buffType = "onHit",
    statChanges = {}, -- No stat changes, only on hit effect
    onHitEffect = {tag = "poison", func = self.applyPoison}, -- Apply poison effect on hit
}



function Poison:applyPoison(enemy)
    enemy:addEffect(self.id, {
        tag = "poison",
        duration = 5, -- Poison lasts for 5 seconds
        damagePerSecond = 10, -- Poison deals 10 damage per second
        onUpdate = function(enemy, dt)
            duration = duration - dt
            if duration <= 0 then


        end
    })
end