local StatusEffect = {}
StatusEffect.__index = StatusEffect

function StatusEffect:new(config)
    if not config then
        error("Developer Error: StatusEffect:new called with nil config.")
    end

    local required = {"name", "duration", "maxStacks"}
    for _, key in ipairs(required) do
        if config[key] == nil then
            error("Developer Error: StatusEffect [" .. (config.name or "Unknown") .. "] is missing the '" .. key .. "' field in config.")
        end
    end

    local instance = setmetatable({}, StatusEffect)
    for k, v in pairs(config) do 
        instance[k] = v
    end
    return instance
end

return StatusEffect