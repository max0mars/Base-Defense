-- Phantom.lua - Tier 3 yellow. A fast arrow that blinks away when hit.
--
-- Blink: first it vanishes, wiped away from left to right over VANISH_TIME
-- (still visible and hittable meanwhile). Then it's gone: invisible and
-- untargetable (Enemy:isType) for BLINK_TIME, after which it reappears in one
-- of the other lanes, picked at random however far away it is, at a random
-- height within that lane. It's the only enemy that crosses lane borders. It
-- holds still throughout. Its BLINK_COOLDOWN only starts once it reappears.
-- (Without lanes, e.g. the codex demo, it blinks MIN_BLINK to MAX_BLINK of the
-- field's height up or down instead: see pickBlinkY.)
--
-- Damage over time doesn't make it blink (only actual hits do), and it can't
-- start a blink while stunned or frozen.

local Enemy = require("Enemies.Enemy")
local Chill = require("Game.Effects.StatusEffects.Chill")

local Phantom = setmetatable({}, { __index = Enemy })
Phantom.__index = Phantom

Phantom.BLINK_COOLDOWN = 1.5
Phantom.VANISH_TIME = 0.3 -- seconds of the left-to-right wipe (still hittable)
Phantom.BLINK_TIME = 0.5 -- seconds invisible and untargetable
Phantom.MIN_BLINK = 0.15 -- of the battlefield's height
Phantom.MAX_BLINK = 0.35
Phantom.APPEAR_TIME = 0.15 -- seconds it takes to pop back to full size

local Stats = {
    name = "Phantom",
    reward = 70,
    hitbox = true,
    effectManager = true,
    shape = "arrow",
}

function Phantom:new(config)
    config = config or {}
    for key, value in pairs(Stats) do
        config[key] = config[key] or value
    end

    local obj = Enemy:new(config)
    setmetatable(obj, { __index = self })

    obj.blinkCooldown = 0 -- ready from the start
    obj.vanishTime = nil -- seconds into the wipe (nil when not vanishing)
    obj.blinkY = nil -- where it reappears
    obj.blinkTime = nil -- seconds into the blink (nil when not gone)
    obj.appearTime = nil

    return obj
end

local function isDot(damageTags)
    for _, tag in ipairs(damageTags or {}) do
        if tag == "dot" then return true end
    end
    return false
end

function Phantom:takeDamage(amount, damageType, hitX, hitY, damageTags, source)
    -- Out of reach while gone (damage over time keeps ticking)
    if self.untargetable and not isDot(damageTags) then return 0 end
    local dealt = Enemy.takeDamage(self, amount, damageType, hitX, hitY, damageTags, source)
    if dealt > 0 and not self.isDead and not isDot(damageTags) then
        self:tryBlink()
    end
    return dealt
end

function Phantom:isBlinking()
    return self.vanishTime ~= nil or self.blinkTime ~= nil
end

function Phantom:canBlink()
    return not self:isBlinking() and self.blinkCooldown <= 0
        and self:getStat("stunned", 0) <= 0 and not Chill.isFrozen(self)
end

--- Rows it may blink between (off the outermost rows, like spawns) and the field's height.
function Phantom:getBlinkBounds()
    local grid = self.game.battlefieldGrid
    if not grid then return nil end
    local fieldH = grid.height * grid.cellSize
    return grid.y + grid.cellSize, grid.y + fieldH - grid.cellSize, fieldH
end

--- Where it reappears on a laned battlefield: one of the lanes other than
--- `fromLane` at random, and a random y inside it with room for a body
--- `halfSize` tall either side. Returns the lane and the y.
function Phantom.pickBlinkLane(grid, fromLane, halfSize)
    local choices = {}
    for lane = 1, #grid.LANES do
        if lane ~= fromLane then table.insert(choices, lane) end
    end
    if #choices == 0 then return nil end
    local lane = choices[math.random(#choices)]
    local top, bottom = grid:getLaneBounds(lane)
    halfSize = math.min(halfSize or 0, (bottom - top) / 2)
    return lane, top + halfSize + math.random() * (bottom - top - 2 * halfSize)
end

--- Without lanes: a y between min and max blink distance from `y`, up or down
--- at random, staying within [top, bottom]. nil if neither direction has room.
function Phantom.pickBlinkY(y, top, bottom, fieldH)
    local minDist, maxDist = fieldH * Phantom.MIN_BLINK, fieldH * Phantom.MAX_BLINK
    local dirs = {}
    if y - minDist >= top then table.insert(dirs, -1) end
    if y + minDist <= bottom then table.insert(dirs, 1) end
    if #dirs == 0 then return nil end
    local dir = dirs[math.random(#dirs)]
    local room = dir < 0 and (y - top) or (bottom - y)
    return y + dir * (minDist + math.random() * (math.min(maxDist, room) - minDist))
end

function Phantom:tryBlink()
    if not self:canBlink() then return false end
    local grid = self.game.battlefieldGrid
    if grid and grid.LANES and grid.getLaneBounds then
        local fromLane = self.lane or grid:getLaneAt(self.y)
        local lane, toY = Phantom.pickBlinkLane(grid, fromLane, (self.h or 0) / 2)
        if not lane then return false end
        self:startVanish(toY, lane)
        return true
    end
    local top, bottom, fieldH = self:getBlinkBounds()
    if not top then return false end
    local toY = Phantom.pickBlinkY(self.y, top, bottom, fieldH)
    if not toY then return false end
    self:startVanish(toY)
    return true
end

--- Starts the wipe; once it's done it's gone, and reappears at `toY` (in `lane`).
function Phantom:startVanish(toY, lane)
    self.vanishTime = 0
    self.blinkY = toY
    self.blinkLane = lane
end

--- Gone now (invisible and untargetable), moved to where it will reappear.
function Phantom:startBlink(toY, lane)
    if self.game.spawnExpandingCircle then
        self.game:spawnExpandingCircle(self.x + self.w * 0.5, self.y, self.w * 0.6, 2, self.color, 0.2)
    end
    self.vanishTime = nil
    self.untargetable = true
    self.blinkTime = 0
    self.y = toY
    -- Blinking is the one way across a lane border: it now belongs to the lane it landed in
    local grid = self.game.battlefieldGrid
    if grid and grid.getLaneAt then
        self.lane = lane or grid:getLaneAt(toY)
        self.y = grid:clampToLane(self.lane, toY, (self.h or 0) / 2)
    end
    self.blinkLane = nil
    self.trail = {}
    if self.game.battlefieldGrid and self.recalculatePath then self:recalculatePath() end
end

function Phantom:appear()
    self.untargetable = false
    self.blinkTime = nil
    self.blinkCooldown = Phantom.BLINK_COOLDOWN
    self.appearTime = 0
    self.trail = {}
    if self.game.spawnExpandingCircle then
        self.game:spawnExpandingCircle(self.x, self.y, 2, self.w, self.color, 0.25)
    end
end

--- Advances the wipe, the blink and the cooldown (which only runs while it's visible).
function Phantom:updateBlink(dt)
    if self.vanishTime then
        self.vanishTime = self.vanishTime + dt
        if self.vanishTime >= Phantom.VANISH_TIME then self:startBlink(self.blinkY, self.blinkLane) end
    elseif self.blinkTime then
        self.blinkTime = self.blinkTime + dt
        if self.blinkTime >= Phantom.BLINK_TIME then self:appear() end
    else
        self.blinkCooldown = math.max(0, self.blinkCooldown - dt)
    end
    if self.appearTime then
        self.appearTime = self.appearTime + dt
        if self.appearTime >= Phantom.APPEAR_TIME then self.appearTime = nil end
    end
end

function Phantom:update(dt)
    if self.destroyed then return end
    Enemy.update(self, dt)
    if self.isDead then return end
    self:updateBlink(dt)
end

--- Holds still from the start of the wipe until it reappears.
function Phantom:isHalted()
    return Enemy.isHalted(self) or self:isBlinking()
end

function Phantom:getFxScale()
    local scale = Enemy.getFxScale(self)
    if self.appearTime then
        local p = self.appearTime / Phantom.APPEAR_TIME
        scale = scale * (0.3 + 0.7 * (1 - (1 - p) * (1 - p)))
    end
    return scale
end

--- Invisible while gone. While vanishing, only the part right of the wipe is
--- drawn, with a bright line at the wipe's edge. Enemy drawing sets and clears
--- its own scissors (the HP fill), so SetGameScissor is swapped for one that
--- stays inside the wipe while it draws.
function Phantom:drawAnimated()
    if self.blinkTime then return end
    if not self.vanishTime then return Enemy.drawAnimated(self) end

    local p = math.min(1, self.vanishTime / Phantom.VANISH_TIME)
    local reach = self.w * 0.8 -- the arrow's tip and tail are within this of its centre
    local edgeX = self.x - reach + 2 * reach * p
    local cx, cy, cw, ch = edgeX, self.y - reach * 2, self.x + reach * 2 - edgeX, reach * 4

    local realScissor = SetGameScissor
    SetGameScissor = function(x, y, w, h)
        if not x then return realScissor(cx, cy, cw, ch) end
        local x1, y1 = math.max(x, cx), math.max(y, cy)
        local x2, y2 = math.min(x + w, cx + cw), math.min(y + h, cy + ch)
        realScissor(x1, y1, math.max(0, x2 - x1), math.max(0, y2 - y1))
    end
    realScissor(cx, cy, cw, ch)
    local ok, err = pcall(Enemy.drawAnimated, self)
    SetGameScissor = realScissor
    realScissor()
    if not ok then error(err, 0) end

    -- The wipe's edge
    local r, g, b = self.color[1], self.color[2], self.color[3]
    love.graphics.setColor(r, g, b, 0.9 * (1 - p * 0.5))
    love.graphics.setLineWidth(1.5)
    love.graphics.line(edgeX, self.y - reach * 0.55, edgeX, self.y + reach * 0.55)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

return Phantom
