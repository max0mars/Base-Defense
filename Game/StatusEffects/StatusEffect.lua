local StatusEffect = {}
StatusEffect.__index = StatusEffect

default = {
    name = "Status Effect", -- Name of the status effect
    duration = 5, -- Duration in seconds
    onApply = nil, -- Function to call when the effect is applied
    onUpdate = nil, -- Function to call every update while the effect is active
    onExpire = nil, -- Function to call when the effect expires
    maxStacks = math.huge, -- Maximum number of stacks for this effect
    source = nil, -- The source of the effect (e.g., the entity that applied it)
}

function StatusEffect:new(config)
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    local instance = setmetatable({}, StatusEffect)
    for k, v in pairs(config) do 
        instance[k] = v
    end
    return instance
end

return StatusEffect