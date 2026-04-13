local Buff = require("Buildings.Buffs.Buff")
local PoisonEffect = require("Game.Effects.StatusEffects.Poison")

local PoisonTotem = setmetatable({}, Buff)
PoisonTotem.__index = PoisonTotem

local default = {
    name = "Poison Totem",
    types = { passive = true, totem = true, poison = true },
    affectedSlots = {{1, 0}}, -- Only affects building directly in front
    color = {0, 0.6, 0.2, 1}, -- Vibrant poison green
    
    -- Properties for the poison effect granted to cannons
    poisonConfig = {
        name = "poison",
        duration = 3,
        dps_poison = 10,
        maxStacks = math.huge
    }
}

function PoisonTotem:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    
    -- Create the effect that the Totem applies to the turret
    -- This effect now adds a stat that tells the poison effect to scale with damage
    config.effect = {
        name = "Poison Coating",
        grantedHitEffect = PoisonEffect:new(config.poisonConfig),
        duration = math.huge,
        statModifiers = {
            poison_from_damage = {max = 0.4, hidden = true} -- 20% of bullet damage becomes Poison DPS (Non-stacking)
        }
    }
    
    local obj = Buff:new(config)
    setmetatable(obj, self)
    return obj
end

return PoisonTotem
