local Stun = {}
Stun.__index = Stun

function Stun:new(config)
    if not config then
        error("Developer Error: Stun effect called with nil config.")
    end

    local instance = setmetatable({}, Stun)
    for k, v in pairs(config) do 
        instance[k] = v
    end

    instance.name = config.name or "stun"
    instance.duration = config.duration or 2.0
    instance.hidden = config.hidden or false
    instance.isIndependent = false
    instance.isDebuff = true
    
    instance.statModifiers = {
        stunned = { add = 1 }
    }
    
    return instance
end

function Stun:onApply(target, source)
    -- Optional hook if needed
end

function Stun:onUpdate(dt, target)
    -- Passive stat modifiers handle the stunned adjustment automatically
end

return Stun
