local Buff = require("Buildings.Passives.Buff")
local Burn = require("Game.Effects.StatusEffects.Burn")

local UnstableLaser = setmetatable({}, Buff)
UnstableLaser.__index = UnstableLaser

local default = {
    name = "Unstable Laser",
    size = 20,
    color = {1, 0.4, 0.1, 1}, -- Orange glow for burn effect
    types = { building = true, passive = true },
    shapePattern = {{0,0}},
    affectedSlots = {{-1, 0}, {0, 1}, {0, -1}, {1, 0}},
    isGlobal = false,
    effect = {
        name = "Unstable Energy",
        targetTypes = { energy = true }, -- Only affects energy turrets
        duration = math.huge,
        grantedHitEffect = Burn.onHit({ name = "burn", amount = 3, chance = 0.25 })
    }
}

function UnstableLaser:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    
    local b = Buff:new(config)
    setmetatable(b, self)
    
    return b
end

function UnstableLaser:getTooltipStrings()
    local strings = {}
    table.insert(strings, "ACTIVE: Grants adjacent Energy Turrets")
    table.insert(strings, "a 25% chance to apply 3 burn.")
    return strings
end

return UnstableLaser
