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

-- Sprite: a hexagonal emitter throwing flickering sparks at its four neighbours
function UnstableLaser:drawShape(cx, cy, s)
    local pts = {}
    for i = 0, 5 do
        local a = i * math.pi / 3 + math.pi / 6
        table.insert(pts, cx + math.cos(a) * s * 0.5)
        table.insert(pts, cy + math.sin(a) * s * 0.5)
    end
    love.graphics.polygon("line", pts)
end

function UnstableLaser:drawDetail(cx, cy, s)
    local t = love.timer.getTime()
    for i = 0, 3 do
        local a = i * math.pi / 2
        local dx, dy = math.cos(a), math.sin(a)
        local px, py = -dy, dx
        local j1 = math.sin(t * 23 + i * 1.7) * s * 0.18
        local j2 = math.sin(t * 31 + i * 2.3) * s * 0.18
        love.graphics.line(
            cx + dx * s * 0.5, cy + dy * s * 0.5,
            cx + dx * s * 0.68 + px * j1, cy + dy * s * 0.68 + py * j1,
            cx + dx * s * 0.84 + px * j2, cy + dy * s * 0.84 + py * j2,
            cx + dx * s, cy + dy * s)
    end
    love.graphics.setColor(1, 0.9, 0.6, 0.6 + 0.4 * math.abs(math.sin(t * 17)))
    love.graphics.circle("fill", cx, cy, s * 0.22)
end

return UnstableLaser
