local StatusEffect = require("Game.StatusEffects.StatusEffect")
local Poison = setmetatable({}, StatusEffect)
Poison.__index = Poison

local default = {
    name = "Poison",
    duration = 5, -- Duration in seconds
    damagePerSecond = 10, -- Damage dealt per second
    maxStacks = 3, -- Maximum number of stacks for this effect
    onUpdate = function(target, dt)
        local damage = Poison.damagePerSecond * dt
        target:takeDamage(damage, "poison")
        print(target.name .. " takes " .. damage .. " poison damage.")
    end,
}