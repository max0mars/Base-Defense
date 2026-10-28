-- Reanimator.lua - Tier 3 green support. Every REVIVE_COOLDOWN seconds it raises
-- up to MAX_REVIVES enemies that died nearby (see game:recordCorpse) as zombies
-- (Enemies/Zombie.lua): the strongest corpses first, then the closest.
--
-- Casting: once its cooldown is up and a corpse is in range it stops and
-- channels (shaking harder as it slowly lifts off the ground), then slams down,
-- and the slam raises the dead. Stunning or freezing it while it channels
-- interrupts the cast and restarts the cooldown. It spawns with a full cooldown.

local Enemy = require("Enemies.Enemy")
local Zombie = require("Enemies.Zombie")
local Chill = require("Game.Effects.StatusEffects.Chill")

local Reanimator = setmetatable({}, { __index = Enemy })
Reanimator.__index = Reanimator

Reanimator.REVIVE_COOLDOWN = 10
Reanimator.MAX_REVIVES = 5
Reanimator.REVIVE_RADIUS = 130
Reanimator.CHANNEL_TIME = 1.5 -- seconds of shaking and rising before the slam
Reanimator.SLAM_TIME = 0.12 -- seconds of the drop back down
Reanimator.LIFT_HEIGHT = 7 -- px it rises while channelling
Reanimator.SHAKE = 1.8 -- px of side-to-side shake at the end of the channel
Reanimator.WIDTH_RATIO = 0.62 -- the diamond's width relative to its height

local Stats = {
    name = "Reanimator",
    reward = 80,
    hitbox = true,
    effectManager = true,
}

function Reanimator:new(config)
    config = config or {}
    for key, value in pairs(Stats) do
        config[key] = config[key] or value
    end

    local obj = Enemy:new(config)
    setmetatable(obj, { __index = self })

    obj.reviveCooldown = config.reviveCooldown or Reanimator.REVIVE_COOLDOWN
    obj.maxRevives = config.maxRevives or Reanimator.MAX_REVIVES
    obj.reviveRadius = config.reviveRadius or Reanimator.REVIVE_RADIUS
    obj.reviveTimer = 0 -- spawns with its full cooldown to wait out
    obj.phase = nil -- nil, "channel" or "slam"
    obj.phaseTime = 0

    return obj
end

function Reanimator:isDisrupted()
    return self:getStat("stunned", 0) > 0 or Chill.isFrozen(self)
end

function Reanimator:update(dt)
    if self.destroyed then return end
    Enemy.update(self, dt)
    if self.isDead then return end

    if self:isDisrupted() then
        if self.phase then self:interrupt() end
        return
    end

    if self.phase then
        if self:advanceCast(dt) then
            self.reviveTimer = 0
            self:reviveNearby()
        end
        return
    end

    self.reviveTimer = math.min(self.reviveCooldown, self.reviveTimer + dt)
    if self.reviveTimer >= self.reviveCooldown and #self:findCorpses() > 0 then
        self:startChannel()
    end
end

function Reanimator:startChannel()
    self.phase, self.phaseTime = "channel", 0
end

--- Stunned or frozen mid-cast: the cast fizzles and the cooldown starts over.
function Reanimator:interrupt()
    self.phase, self.phaseTime = nil, 0
    self.reviveTimer = 0
    if self.game.spawnExpandingCircle then
        self.game:spawnExpandingCircle(self.x, self.y, self.w * 0.8, self.w * 0.2, { 0.5, 0.55, 0.45 }, 0.3)
    end
end

--- Advances the channel, then the slam. Returns true on the frame the slam lands.
function Reanimator:advanceCast(dt)
    self.phaseTime = self.phaseTime + dt
    if self.phase == "channel" and self.phaseTime >= Reanimator.CHANNEL_TIME then
        self.phase, self.phaseTime = "slam", 0
    elseif self.phase == "slam" and self.phaseTime >= Reanimator.SLAM_TIME then
        self.phase, self.phaseTime = nil, 0
        self:startPulse()
        if self.game.spawnExpandingCircle then
            self.game:spawnExpandingCircle(self.x, self.y, self.w * 0.5, self.reviveRadius, Zombie.COLOR, 0.6)
        end
        return true
    end
    return false
end

--- Holds still while casting.
function Reanimator:isHalted()
    return Enemy.isHalted(self) or self.phase ~= nil
end

--- How far it's lifted off its usual height (0 when not casting).
function Reanimator:getLift()
    if self.phase == "channel" then
        local p = math.min(1, self.phaseTime / Reanimator.CHANNEL_TIME)
        return Reanimator.LIFT_HEIGHT * p * p * (3 - 2 * p)
    elseif self.phase == "slam" then
        local p = math.min(1, self.phaseTime / Reanimator.SLAM_TIME)
        return Reanimator.LIFT_HEIGHT * (1 - p * p)
    end
    return 0
end

function Reanimator:getHoverOffset()
    return Enemy.getHoverOffset(self) - self:getLift()
end

--- Shakes side to side while channelling, harder as the channel builds.
function Reanimator:drawAnimated()
    local shake = 0
    if self.phase == "channel" then
        local p = math.min(1, self.phaseTime / Reanimator.CHANNEL_TIME)
        shake = math.sin(self.phaseTime * 55) * Reanimator.SHAKE * (0.3 + 0.7 * p)
    end
    local baseX = self.x
    self.x = baseX + shake
    Enemy.drawAnimated(self)
    self.x = baseX
end

--- A diamond, narrower than it is tall.
function Reanimator:drawCustomShape(mode, cx, cy)
    local h = self.h / 2
    local w = h * Reanimator.WIDTH_RATIO
    love.graphics.polygon(mode, cx, cy - h, cx + w, cy, cx, cy + h, cx - w, cy)
end

--- Corpses in range, strongest (highest tier) first, then closest.
function Reanimator:findCorpses()
    local found = {}
    local radiusSq = self.reviveRadius * self.reviveRadius
    for _, corpse in ipairs(self.game.corpses or {}) do
        local dx, dy = corpse.x - self.x, corpse.y - self.y
        local distSq = dx * dx + dy * dy
        if distSq <= radiusSq then
            table.insert(found, { corpse = corpse, distSq = distSq })
        end
    end
    table.sort(found, function(a, b)
        if a.corpse.tier ~= b.corpse.tier then return a.corpse.tier > b.corpse.tier end
        return a.distSq < b.distSq
    end)
    return found
end

--- Raises up to maxRevives corpses in range. Returns how many it raised.
function Reanimator:reviveNearby()
    local found = self:findCorpses()
    local raised = 0
    for i = 1, math.min(#found, self.maxRevives) do
        local corpse = found[i].corpse
        self.game:takeCorpse(corpse)
        if self:raise(corpse) then raised = raised + 1 end
    end
    return raised
end

--- Brings one corpse back as a zombie where it fell.
function Reanimator:raise(corpse)
    local EnemyRegistry = require("Game.Spawning.EnemyRegistry")
    local class
    for _, e in ipairs(EnemyRegistry.allEnemies or {}) do
        if e.id == corpse.id then class = e.class; break end
    end
    if not class then return nil end

    local config = { game = self.game, x = corpse.x, y = corpse.y, name = corpse.id }
    for k, v in pairs(corpse.overrides or {}) do config[k] = v end
    local zombie = class:new(config)
    EnemyRegistry:applyActiveMutations(zombie)
    Zombie.apply(zombie)
    zombie:startRise()

    if self.game.spawnExpandingCircle then
        self.game:spawnExpandingCircle(corpse.x, corpse.y, 2, zombie.w or 20, Zombie.COLOR, 0.4)
    end
    self.game:addObject(zombie)
    return zombie
end

return Reanimator
