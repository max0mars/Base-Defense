local HitscanBullet = require("Bullets.HitscanBullet")
local collision = require("Physics.collisionSystem_brute")
local DeathAnimation = require("Graphics.Animations.DeathAnimation")

local Lazer = setmetatable({}, HitscanBullet)
Lazer.__index = Lazer

function Lazer:new(config)
    config.damageType = "energy"
    config.color = {0, 0, 1}
    local obj = setmetatable(HitscanBullet:new(config), { __index = self })
    return obj
end


function Lazer:onHit(target)
    target:takeDamage(self.damage, "energy")
    if target.effectManager then
        for _, effectTemplate in ipairs(self.hitEffects) do
            target.effectManager:applyEffect(effectTemplate)
        end
        target.effectManager:triggerEvent("onHit", self)
    end
end

return Lazer
