local Buff = require("Buildings.Passives.Buff")

-- Economy building: pays out cash when the battle is won, if it's still standing
-- (see game:payVaults)
local Vault = setmetatable({}, Buff)
Vault.__index = Vault

local default = {
    name = "The Vault",
    size = 20,
    color = {1, 0.82, 0.3, 1}, -- Gold
    types = { building = true, economy = true, passive = true },
    shapePattern = {{0,0}},
    -- Explicitly no buff effect so the base Buff class never applies damage buffs
    effect = false,

    cashOnBattleWon = 50
}

function Vault:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end

    -- Pass effect=nil to Buff:new so it never applies any stat modifier
    config.effect = nil

    local b = Buff:new(config)
    setmetatable(b, self)
    b.cashOnBattleWon = config.cashOnBattleWon
    return b
end

function Vault:applyBuffs()
    -- Economy only: no stat buffs for neighbours
end

function Vault:getTooltipStrings()
    return { "+$" .. tostring(self.cashOnBattleWon) .. " when the battle is won" }
end

return Vault
