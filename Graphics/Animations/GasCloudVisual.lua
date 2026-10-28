-- GasCloudVisual.lua - A drifting cloud of gas built from many small, soft
-- wisps. Each wisp is a blurred sprite that fades in, swells, drifts and fades
-- out on its own clock; new ones keep appearing while the cloud lasts, so the
-- gas churns instead of reading as a few solid shapes. The cloud rolls out
-- from the centre, then thins away at the end.
-- Used by Stun Gas (a short burst) and Acid Cloud (a lingering cloud).
--
-- options (all optional):
--   color    {r, g, b}       cloud colour
--   growTime number          seconds to roll out to full size
--   wisps    boolean         fine vapour rises off the cloud while it lingers

local GasCloudVisual = {}
GasCloudVisual.__index = GasCloudVisual

local FADE_TIME = 0.6
local TEXTURE_SIZE = 64

-- One soft, round puff with a smooth falloff to fully transparent edges,
-- shared by every cloud (made on first draw).
local puffTexture
local function getPuffTexture()
    if puffTexture == nil then
        puffTexture = false
        if love.image and love.image.newImageData and love.graphics.newImage then
            local data = love.image.newImageData(TEXTURE_SIZE, TEXTURE_SIZE)
            local c = (TEXTURE_SIZE - 1) / 2
            data:mapPixel(function(x, y)
                local d = math.sqrt((x - c) ^ 2 + (y - c) ^ 2) / c
                local a = math.max(0, 1 - d)
                return 1, 1, 1, a * a * (3 - 2 * a) -- smoothstep: no visible edge
            end)
            puffTexture = love.graphics.newImage(data)
        end
    end
    return puffTexture or nil
end

local function rand(a, b) return a + math.random() * (b - a) end

-- A random point in the cloud, biased toward the middle so the edge stays thin
local function pointInCloud(radius)
    local angle = math.random() * math.pi * 2
    local dist = math.sqrt(math.random()) * radius * 0.85
    return math.cos(angle) * dist, math.sin(angle) * dist
end

function GasCloudVisual:new(x, y, radius, duration, options)
    options = options or {}
    local obj = setmetatable({}, self)
    obj.x = x
    obj.y = y
    obj.radius = radius or 60
    obj.maxLifetime = duration or 5.0
    obj.lifetime = obj.maxLifetime
    obj.destroyed = false
    obj.age = 0
    obj.color = options.color or {0.1, 0.7, 0.2}
    obj.growTime = options.growTime or 0.4
    obj.vapour = options.wisps and {} or nil
    obj.vapourTimer = 0

    -- Enough wisps to fill the area densely; each covers a small part of it
    obj.wispCount = math.max(50, math.min(160, math.floor(obj.radius * obj.radius / 35)))
    obj.wisps = {}
    for _ = 1, obj.wispCount do
        local w = obj:newWisp()
        w.age = rand(0, w.life * 0.6) -- staggered, so they don't all pulse together
        table.insert(obj.wisps, w)
    end
    return obj
end

function GasCloudVisual:newWisp()
    local ox, oy = pointInCloud(self.radius)
    local life = math.min(rand(1.0, 2.2), self.maxLifetime)
    return {
        ox = ox, oy = oy,                         -- offset from the cloud's centre
        vx = rand(-6, 6), vy = rand(-6, 6),       -- slow drift
        size = self.radius * rand(0.3, 0.5),      -- diameter
        growth = rand(1.15, 1.5),                 -- swells this much over its life
        alpha = rand(0.06, 0.12),
        shade = rand(-0.06, 0.08),                -- slight tone variation
        rot = rand(0, math.pi * 2), spin = rand(-0.4, 0.4),
        age = 0, life = life,
    }
end

function GasCloudVisual:update(dt)
    self.age = self.age + dt
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self.destroyed = true
        return
    end

    local r2 = (self.radius * 0.95) ^ 2
    for i, w in ipairs(self.wisps) do
        w.age = w.age + dt
        w.ox = w.ox + w.vx * dt
        w.oy = w.oy + w.vy * dt
        w.rot = w.rot + w.spin * dt
        -- Drifted out of the area: ease back toward the middle
        if w.ox * w.ox + w.oy * w.oy > r2 then
            w.vx = w.vx - w.ox * dt * 0.8
            w.vy = w.vy - w.oy * dt * 0.8
        end
        -- Burnt out: a fresh wisp takes its place while the cloud isn't fading
        if w.age >= w.life and self.lifetime > FADE_TIME then
            self.wisps[i] = self:newWisp()
        end
    end

    if self.vapour then
        self.vapourTimer = self.vapourTimer - dt
        if self.vapourTimer <= 0 and self.lifetime > FADE_TIME then
            self.vapourTimer = 0.06
            local ox, oy = pointInCloud(self.radius * 0.9)
            table.insert(self.vapour, {
                x = self.x + ox, y = self.y + oy,
                drift = rand(-6, 6),
                life = 1.4, maxLife = 1.4,
                size = rand(12, 20),
            })
        end
        for i = #self.vapour, 1, -1 do
            local v = self.vapour[i]
            v.life = v.life - dt
            v.y = v.y - 12 * dt
            v.x = v.x + v.drift * dt
            if v.life <= 0 then table.remove(self.vapour, i) end
        end
    end
end

-- Draws one soft puff of diameter `size` (falls back to faint stacked circles
-- if the texture can't be made)
local function drawPuff(tex, x, y, size, rot)
    if tex then
        local s = size / TEXTURE_SIZE
        love.graphics.draw(tex, x, y, rot, s, s, TEXTURE_SIZE / 2, TEXTURE_SIZE / 2)
    else
        love.graphics.circle("fill", x, y, size * 0.25)
    end
end

function GasCloudVisual:draw()
    local tex = getPuffTexture()
    local r, g, b = self.color[1], self.color[2], self.color[3]

    -- Roll out from the centre (ease-out), then thin away and spread a little
    local grow = math.min(1, self.age / self.growTime)
    grow = 1 - (1 - grow) * (1 - grow)
    local cloudAlpha = math.min(1, self.lifetime / FADE_TIME)
    local spread = (0.25 + 0.75 * grow) * (1 + (1 - cloudAlpha) * 0.2)

    love.graphics.push("all")

    -- Faint haze under the wisps, so the gas has a body without a hard edge
    love.graphics.setColor(r, g, b, 0.14 * cloudAlpha * grow)
    drawPuff(tex, self.x, self.y, self.radius * 2.3 * spread, 0)

    for _, w in ipairs(self.wisps) do
        local t = math.min(1, w.age / w.life)
        local fade = math.sin(t * math.pi) -- in, then out
        local a = w.alpha * fade * cloudAlpha
        if a > 0.003 then
            local size = w.size * (1 + (w.growth - 1) * t)
            love.graphics.setColor(
                math.min(1, math.max(0, r + w.shade)),
                math.min(1, math.max(0, g + w.shade)),
                math.min(1, math.max(0, b + w.shade)), a)
            drawPuff(tex, self.x + w.ox * spread, self.y + w.oy * spread, size, w.rot)
        end
    end

    if self.vapour then
        for _, v in ipairs(self.vapour) do
            local t = v.life / v.maxLife
            love.graphics.setColor(r, g, b, math.sin(t * math.pi) * 0.12 * cloudAlpha)
            drawPuff(tex, v.x, v.y, v.size * (2 - t), 0)
        end
    end

    love.graphics.pop()
end

return GasCloudVisual
