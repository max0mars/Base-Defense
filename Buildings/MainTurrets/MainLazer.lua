local Turret = require("Buildings.Turrets.Turret")
local MainLazer = setmetatable({}, { __index = Turret })
MainLazer.__index = MainLazer

function MainLazer:new(config)
    local t = Turret:new(config)
    setmetatable(t, { __index = self })
    
    t.isMainLazer = true
    t.autofire = config.autofire or false
    t.upgrades = {} -- Persistent weapon upgrades
    t.electricFieldCooldown = 0
    t.zapBurstCount = 0 -- Tracks shots in current burst
    t.zapDelayTimer = 0.3 -- Warm-up delay before first burst shot
    
    if t.slot then
        local cx, cy = t:getCenterPosition()
        t.x, t.y = cx, cy
    end
    
    return t
end

function MainLazer:getStat(statName, defaultVal)
    local val = Turret.getStat(self, statName, defaultVal)
    
    return val
end

function MainLazer:applyUpgrade(reward)
    if not reward or not reward.id then return end
    
    -- Track persistent flag for custom logic
    self.upgrades[reward.id] = true
    
    if reward.id == "low_power_operating" then
        -- Use built-in Effect System for stat changes
        if self.effectManager then
            self.effectManager:applyEffect({
                name = "Low Power Operating",
                statModifiers = {
                    damage = { mult = -0.2 },
                    fireRate = { mult = 0.5 }
                }
            })
        end
    elseif reward.id == "unstable_laser" then
        -- Use built-in hitEffects system with proper naming for tooltips
        local BurnEffect = require("Game.Effects.StatusEffects.Burn")
        local burn = BurnEffect:new({
            name = "burn",
            duration_burn = 3.2,
            dps_burn = 10,
            maxStacks = 5,
            chance = 0.25
        })
        self:addHitEffect(burn)
        
        -- Apply an effect so it shows up in the tooltip
        if self.effectManager then
            self.effectManager:applyEffect({
                name = "+Burn Chance"
            })
        end
    elseif reward.id == "electric_field" then
        -- Apply a named effect for the tooltip
        if self.effectManager then
            self.effectManager:applyEffect({
                name = "Electric Field"
            })
        end
    end
    
    -- Print confirmation
    print("Main Turret Upgrade Applied: " .. reward.name)
end

function MainLazer:getCenterPosition()
    if not self.slot then
        return self.x, self.y
    end

    local anchorSlot = self.slot
    local anchorX = ((anchorSlot - 1) % self.buildGrid.width) * self.buildGrid.cellSize + self.buildGrid.x
    local anchorY = (math.ceil(anchorSlot / self.buildGrid.width) - 1) * self.buildGrid.cellSize + self.buildGrid.y
    
    -- Main turrets are usually 2x2, so the center is 1 cell size offset
    local centerX = anchorX + self.buildGrid.cellSize
    local centerY = anchorY + self.buildGrid.cellSize
    
    return centerX, centerY
end

function MainLazer:update(dt)
    self.cooldown = self.cooldown - dt
    
    if self.upgrades["electric_field"] then
        self:updateElectricField(dt)
    elseif self.autofire and self.game:isState("wave") then
        local mx, my = love.mouse.getPosition()
        self:PlayerClick(mx, my)
    end
end

function MainLazer:updateElectricField(dt)
    if not self.upgrades["electric_field"] then return end
    
    -- Progress the cooldown
    if self.electricFieldCooldown > 0 then
        self.electricFieldCooldown = self.electricFieldCooldown - dt
        return
    end

    if not self.game:isState("wave") then return end

    local cx, cy = self:getCenterPosition()
    local zapRange = self:getStat("range")
    local r2 = zapRange * zapRange
    
    -- 1. Find potential targets in range
    local potentialTargets = {}
    for _, obj in ipairs(self.game.objects) do
        if obj:isType("enemy") and not obj.destroyed then
            local dx, dy = obj.x - cx, obj.y - cy
            if dx*dx + dy*dy <= r2 then
                table.insert(potentialTargets, obj)
            end
        end
    end

    -- 2. Handle Firing Sequence
    if #potentialTargets > 0 then
        -- Only the first shot of a burst has the warm-up delay
        if self.zapBurstCount == 0 then
            self.zapDelayTimer = self.zapDelayTimer - dt
        else
            self.zapDelayTimer = 0 -- Instant firing for subsequent burst shots
        end
        
        if self.zapDelayTimer <= 0 then
            -- Pick ONE random target for this shot of the burst
            local target = potentialTargets[love.math.random(1, #potentialTargets)]
            
            -- Fire the Zap
            if AUDIO then AUDIO:playSFX("lightning_01") end
            
            target:takeDamage(self:getStat("damage"), "energy", target.x, target.y)
            self:applyHitEffects(target)
            
            if self.game.spawnLightningBolt then
                self.game:spawnLightningBolt(target.x, target.y)
            end
            if self.game.spawnParticleExplosion then
                self.game:spawnParticleExplosion({0.4, 0.7, 1, 1}, 5, target.x, target.y)
            end
            
            -- Increment burst and set appropriate cooldown
            self.zapBurstCount = self.zapBurstCount + 1
            
            if self.zapBurstCount < 3 then
                -- Short delay between burst shots
                self.electricFieldCooldown = 0.1 
            else
                -- Full cooldown after the burst
                self.zapBurstCount = 0
                self.electricFieldCooldown = 1 / self:getStat("fireRate")
                self.zapDelayTimer = 0.3 -- Reset warm-up for next burst
            end
        end
    else
        -- Reset state if no enemies are in range
        self.zapBurstCount = 0
        self.zapDelayTimer = 0.3
    end
end

function MainLazer:PlayerClick(tX, tY)
    if self.upgrades["electric_field"] then return false end -- Disabled for lightning field
    
    local base = self.game.base
    local bx1 = base.x - base.w / 2
    local bx2 = base.x + base.w / 2
    local by1 = base.y - base.h / 2
    local by2 = base.y + base.h / 2
    
    -- Don't fire if clicking on the base itself
    if tX >= bx1 and tX <= bx2 and tY >= by1 and tY <= by2 then
        return false
    end

    if self.cooldown <= 0 then
        local currentFireRate = self:getStat("fireRate")
        if currentFireRate > 0 then
            local fX, fY = self:getFirePoint()
            
            self:fire({
                targetX = tX, 
                targetY = tY,
                fireX = fX,
                fireY = fY
            })
            self.cooldown = 1 / currentFireRate
            return true
        end
    end
    return false
end

function MainLazer:applyHitEffects(target)
    if not target or not target.effectManager then return end
    
    -- 1. Collect all unique effect templates (Base effects + Buffs)
    local uniqueEffects = {}
    local seen = {}
    
    -- Add base hit effects
    if self.hitEffects then
        for _, effect in ipairs(self.hitEffects) do
            if effect.name and not seen[effect.name] then
                table.insert(uniqueEffects, effect)
                seen[effect.name] = true
            end
        end
    end
    
    -- Add effects granted by the EffectManager (Buffs/Totems)
    if self.effectManager then
        local function collectEffects(em)
            for _, effect in ipairs(em.activeEffects) do
                if effect.grantedHitEffect then
                    local e = effect.grantedHitEffect
                    if e.name and not seen[e.name] then
                        table.insert(uniqueEffects, e)
                        seen[e.name] = true
                    end
                end
            end
            if em.parent then collectEffects(em.parent) end
        end
        collectEffects(self.effectManager)
    end
    
    -- 2. Apply the effects
    for _, effect in ipairs(uniqueEffects) do
        if effect.isIndependent then
            -- Independent effects (Explosions, Shrapnel) are triggered directly
            if effect.trigger then
                effect:trigger(target, self)
            end
        else
            -- Status effects (Burn, Poison, Slow) are applied to the target's EffectManager
            target.effectManager:applyEffect(effect, self)
        end
    end
end

function MainLazer:fire(args)
     args = args or {}
     -- Ensure correct angle for hitscan/projectiles if not provided
     if not args.angle then
         local fX, fY = self:getFirePoint()
         args.angle = math.atan2(args.targetY - fY, args.targetX - fX)
     end
     args.displayLifespan = args.displayLifespan or self:getStat("displayLifespan")
     args.color = args.color or self:getStat("bulletColor")
     
     if AUDIO then AUDIO:playSFX("laser_01") end
     
     Turret.fire(self, args)
end

function MainLazer:getTargetArc() end
function MainLazer:isInFiringArc(enemy) return true end

function MainLazer:drawFiringArc(a1, a2, a3)
    local alpha = (type(a1) == "number" and a1 <= 1 and a1) or a3 or 0.2
    local cx, cy = self:getCenterPosition()
    local range = self:getStat("range")
    
    if self.upgrades["electric_field"] then
        love.graphics.setColor(0.4, 0.7, 1, alpha)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", cx, cy, range)
        love.graphics.setColor(0.4, 0.7, 1, alpha * 0.15)
        love.graphics.circle("fill", cx, cy, range)
    else
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", cx, cy, range)
        love.graphics.setColor(1, 1, 1, alpha * 0.3)
        love.graphics.circle("fill", cx, cy, range)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return MainLazer
