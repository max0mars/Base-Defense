local StatusEffect = require("Game.Effects.StatusEffects.StatusEffect")
local IndependantEffect = setmetatable({}, { __index = StatusEffect })
IndependantEffect.__index = IndependantEffect

local default = {
    name = "Independant Effect", -- Name of the status effect
    duration = 5, -- Duration in seconds
    onTrigger = nil, -- Function to call when the effect is triggered
}

function IndependantEffect:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    local effect = setmetatable({}, IndependantEffect)
    for key, value in pairs(config) do
        effect[key] = value
    end
    return effect
end

return IndependantEffect