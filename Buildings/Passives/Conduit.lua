local Buff = require("Buildings.Passives.Buff")

local Conduit = setmetatable({}, Buff)
Conduit.__index = Conduit

local default = {
    name = "Conduit",
    size = 20,
    color = {0.2, 0.6, 1, 1}, -- Blue-ish
    types = { building = true, economy = true, passive = true },
    shapePattern = {{0,0}},
    -- Explicitly no buff effect so the base Buff class never applies damage buffs
    effect = false,
    
    manaPerWave = 10
}

function Conduit:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    
    -- Pass effect=nil to Buff:new so it never applies any stat modifier
    config.effect = nil
    
    local b = Buff:new(config)
    setmetatable(b, self)
    
    return b
end

function Conduit:applyBuffs()
    -- Conduit does not apply stat buffs to neighbors — economy building only
end

function Conduit:getTooltipStrings()
    local strings = {}
    table.insert(strings, "+" .. tostring(self.manaPerWave) .. " Mana per wave")
    return strings
end

function Conduit:onWaveComplete()
    if not self.destroyed and self.game then
        self.game.mana = (self.game.mana or 0) + self.manaPerWave
        
        -- Spawn floating text to show the mana gain
        if self.game.spawnFloatingText then
            self.game:spawnFloatingText("+" .. self.manaPerWave .. " Mana", self.x, self.y - 20, {0.2, 0.6, 1, 1})
        end
    end
end

return Conduit
