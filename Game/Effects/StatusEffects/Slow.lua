local Slow = {}
Slow.__index = Slow

function Slow:new(config)
    if not config then
        error("Developer Error: Slow effect called with nil config.")
    end

    local instance = setmetatable({}, Slow)
    for k, v in pairs(config) do 
        instance[k] = v
    end

    instance.name = config.name or "slow"
    instance.duration = config.duration or 0.2
    instance.amount = config.amount or 0.5
    instance.hidden = config.hidden or false
    
    instance.statModifiers = {
        speed = { mult = -instance.amount }
    }
    
    return instance
end

function Slow:onApply(target, source)
    -- Optional hook if needed
end

function Slow:onUpdate(dt, target)
    -- Passive stat modifiers handle the speed adjustment automatically
end

return Slow
