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

-- Sprite: a market stall with a snowflake on the counter
function IceMarket:drawShape(cx, cy, s)
    -- Scalloped awning
    local pts = { cx - s, cy - s }
    for i = 0, 3 do
        local x0 = cx - s + i * s * 0.5
        table.insert(pts, x0); table.insert(pts, cy - s * 0.55)
        table.insert(pts, x0 + s * 0.25); table.insert(pts, cy - s * 0.35)
    end
    table.insert(pts, cx + s); table.insert(pts, cy - s * 0.55)
    table.insert(pts, cx + s); table.insert(pts, cy - s)
    love.graphics.polygon("line", pts)
    -- Posts and counter
    love.graphics.line(cx - s * 0.85, cy - s * 0.4, cx - s * 0.85, cy + s)
    love.graphics.line(cx + s * 0.85, cy - s * 0.4, cx + s * 0.85, cy + s)
    love.graphics.line(cx - s, cy + s, cx + s, cy + s)
end

function IceMarket:drawDetail(cx, cy, s)
    local fy, fr = cy + s * 0.3, s * 0.42
    for i = 0, 2 do
        local a = i * math.pi / 3 + math.pi / 2
        love.graphics.line(cx + math.cos(a) * fr, fy + math.sin(a) * fr, cx - math.cos(a) * fr, fy - math.sin(a) * fr)
    end
end

return IceMarket
