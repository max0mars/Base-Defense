local StatusEffect = {}
StatusEffect.__index = StatusEffect

default = {
    name = nil,
    duration = nil, -- Duration in seconds
    onApply = nil, -- Function to call when the effect is applied
    onUpdate = nil, -- Function to call every update while the effect is active
    onExpire = nil, -- Function to call when the effect expires
    maxStacks = 1, -- Maximum number of stacks for this effect
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

function StatusEffect:apply(target)
    if self.onApply then
        self.onApply(target)
    end
end

function 