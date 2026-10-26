local Buff = require("Buildings.Passives.Buff")

local IceMarket = setmetatable({}, Buff)
IceMarket.__index = IceMarket

-- Economy building: pays cash every time a frozen enemy dies, anywhere on the
-- field. Each placed Ice Market pays separately (see game:onFrozenEnemyDied).
local default = {
    name = "Ice Market",
    types = { passive = true, economy = true },
    affectedSlots = {},
    color = {0.55, 0.95, 0.85, 1}, -- Icy mint
    cashPerFrozenKill = 5,
}

function IceMarket:new(config)
    config = config or {}
    for key, value in pairs(default) do
        if config[key] == nil then
            config[key] = value
        end
    end

    local obj = Buff:new(config)
    setmetatable(obj, self)
    obj.cashPerFrozenKill = config.cashPerFrozenKill
    return obj
end

function IceMarket:applyBuffs()
    -- Economy only: no stat buffs for neighbours
end

return IceMarket
