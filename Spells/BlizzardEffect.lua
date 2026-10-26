-- BlizzardEffect.lua - Area left behind by the Blizzard spell (lives on the
-- global enemyEffectManager, like AcidCloudEffect). Enemies inside take ice
-- damage over time and gain chill at `chillPerSecond`, but the blizzard never
-- pushes an enemy above `chillCap` stacks, so on its own it can't freeze.

local Chill = require("Game.Effects.StatusEffects.Chill")

local BlizzardEffect = {}
BlizzardEffect.__index = BlizzardEffect

local TICK = 0.2

function BlizzardEffect:new(config)
    local instance = setmetatable({}, BlizzardEffect)
    instance.name = config.name or "blizzard"
    instance.duration = config.duration or 5.0
    instance.x = config.x or 0
    instance.y = config.y or 0
    instance.radius = config.radius or 50
    instance.dps = config.dps or 10
    instance.chillPerSecond = config.chillPerSecond or 2
    instance.chillCap = config.chillCap or 2
    instance.game = config.game
    instance.tickTimer = 0
    return instance
end

function BlizzardEffect:onUpdate(dt, owner)
    if not self.game then return end

    self.tickTimer = self.tickTimer + dt
    if self.tickTimer < TICK then return end
    local elapsed = self.tickTimer
    self.tickTimer = 0

    local r2 = self.radius * self.radius
    for _, obj in ipairs(self.game.objects) do
        if obj:isType("enemy") and not obj.destroyed then
            local dx = obj.x - self.x
            local dy = obj.y - self.y
            if dx * dx + dy * dy <= r2 then
                obj:takeDamage(self.dps * elapsed, "ice", nil, nil, { "aoe", "dot" })
                if not obj.destroyed then
                    Chill.apply(obj, self.chillPerSecond * elapsed, { cap = self.chillCap })
                end
            end
        end
    end
end

return BlizzardEffect
