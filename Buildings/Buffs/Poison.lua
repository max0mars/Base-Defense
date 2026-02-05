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



function Poison:applyPoison(enemy){
    
}