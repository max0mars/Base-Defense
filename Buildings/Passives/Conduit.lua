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
        self.game:addMana(self.manaPerWave)
        
        -- Spawn floating text to show the mana gain
        if self.game.spawnFloatingText then
            self.game:spawnFloatingText("+" .. self.manaPerWave .. " Mana", self.x, self.y - 20, {0.2, 0.6, 1, 1})
        end
    end
end

-- Sprite: a mana crystal on a pedestal with a mote orbiting it
function Conduit:drawShape(cx, cy, s)
    love.graphics.polygon("line", cx, cy - s, cx + s * 0.4, cy - s * 0.3, cx, cy + s * 0.5, cx - s * 0.4, cy - s * 0.3)
    love.graphics.polygon("line", cx - s * 0.75, cy + s, cx - s * 0.45, cy + s * 0.6, cx + s * 0.45, cy + s * 0.6, cx + s * 0.75, cy + s)
end

function Conduit:drawDetail(cx, cy, s)
    local r, g, b = unpack(self.color)
    local oy = cy - s * 0.2
    local a = love.timer.getTime() * 2.5
    -- Crystal facet
    love.graphics.line(cx, cy - s, cx, cy + s * 0.5)
    love.graphics.setColor(r, g, b, 0.35)
    love.graphics.ellipse("line", cx, oy, s * 0.85, s * 0.3)
    love.graphics.setColor(0.8, 0.95, 1, 1)
    love.graphics.circle("fill", cx + math.cos(a) * s * 0.85, oy + math.sin(a) * s * 0.3, 1.6)
end

return Conduit
