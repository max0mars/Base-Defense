-- FireZoneVisual.lua - Draws a FireZoneEffect, and goes away when it does.
--
-- Styles:
--   "coals"  scattered glowing coals with flames licking up (Embers, Meteor crater)
--   "blaze"  a ring of tall flames over a hot glow (Blazing Flames)
--   "cinder" one small pulsing coal (Cinder Mortar)

local FireZoneVisual = {}
FireZoneVisual.__index = FireZoneVisual

local HOT = { 1, 0.75, 0.25 }
local EMBER = { 1, 0.4, 0.08 }

function FireZoneVisual:new(zone, style)
    local obj = setmetatable({}, self)
    obj.zone = zone
    obj.style = style or "coals"
    obj.time = math.random() * 10
    obj.destroyed = false

    -- Coal positions spread evenly over the disc (sqrt keeps the centre from crowding)
    obj.coals = {}
    local count = obj.style == "cinder" and 0 or math.floor(6 + zone.radius / 5)
    for i = 1, count do
        local a = math.random() * math.pi * 2
        local d = math.sqrt(math.random()) * zone.radius * 0.9
        table.insert(obj.coals, {
            x = math.cos(a) * d, y = math.sin(a) * d,
            size = 1.5 + math.random() * 2,
            phase = math.random() * math.pi * 2,
        })
    end
    return obj
end

function FireZoneVisual:update(dt)
    self.time = self.time + dt
    if self.zone.spent or self.zone.duration <= 0 then
        self.destroyed = true
    end
end

local function flameLick(x, y, h, w, alpha)
    love.graphics.polygon("fill", x - w, y, x, y - h, x + w, y)
    love.graphics.setColor(HOT[1], HOT[2], HOT[3], alpha)
    love.graphics.polygon("fill", x - w * 0.45, y, x, y - h * 0.55, x + w * 0.45, y)
end

function FireZoneVisual:draw()
    local z = self.zone
    local alpha = z:getAlpha()
    if alpha <= 0 then return end
    local t = self.time

    love.graphics.push("all")
    if self.style == "cinder" then
        local pulse = 0.75 + 0.25 * math.sin(t * 6)
        love.graphics.setColor(EMBER[1], EMBER[2], EMBER[3], 0.35 * alpha)
        love.graphics.circle("fill", z.x, z.y, z.radius * 1.6)
        love.graphics.setColor(1, 0.55 * pulse + 0.2, 0.15, alpha)
        love.graphics.circle("fill", z.x, z.y, z.radius * 0.7)
        love.graphics.setColor(1, 0.95, 0.7, alpha * pulse)
        love.graphics.circle("fill", z.x, z.y, z.radius * 0.3)
        love.graphics.pop()
        return
    end

    -- Hot ground glow
    local glow = self.style == "blaze" and 0.22 or 0.12
    love.graphics.setColor(EMBER[1], EMBER[2], EMBER[3], glow * alpha)
    love.graphics.circle("fill", z.x, z.y, z.radius)
    love.graphics.setColor(EMBER[1], EMBER[2], EMBER[3], 0.45 * alpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", z.x, z.y, z.radius)

    -- Coals, each with a flickering flame
    for _, c in ipairs(self.coals) do
        local flicker = 0.6 + 0.4 * math.sin(t * 7 + c.phase)
        local x, y = z.x + c.x, z.y + c.y
        love.graphics.setColor(1, 0.45 + 0.3 * flicker, 0.1, alpha)
        love.graphics.circle("fill", x, y, c.size)
        love.graphics.setColor(EMBER[1], EMBER[2], EMBER[3], 0.7 * alpha * flicker)
        flameLick(x, y, c.size * (2 + 2 * flicker), c.size, 0.8 * alpha * flicker)
    end

    -- Blaze: tall flames dancing around the edge
    if self.style == "blaze" then
        local n = math.floor(z.radius / 5)
        for i = 1, n do
            local a = (i / n) * math.pi * 2 + t * 0.6
            local x = z.x + math.cos(a) * z.radius * 0.95
            local y = z.y + math.sin(a) * z.radius * 0.95
            local h = 8 + 6 * (0.5 + 0.5 * math.sin(t * 9 + i * 1.7))
            love.graphics.setColor(1, 0.5, 0.1, 0.8 * alpha)
            flameLick(x, y, h, 3, 0.9 * alpha)
        end
    end
    love.graphics.pop()
end

return FireZoneVisual
