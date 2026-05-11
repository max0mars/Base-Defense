local Turret = require("Buildings.Turrets.Turret")
local MainTurret = setmetatable({}, { __index = Turret })
MainTurret.__index = MainTurret

function MainTurret:new(config)
    local t = Turret:new(config)
    setmetatable(t, { __index = self })
    
    t.isMainTurret = true
    t.autofire = config.autofire or false
    t.upgrades = {} -- Persistent weapon upgrades
    t.electricFieldCooldown = 0
    
    if t.slot then
        local cx, cy = t:getCenterPosition()
        t.x, t.y = cx, cy
    end
    
    return t
end

function MainTurret:getStat(statName, defaultVal)
    local val = Turret.getStat(self, statName, defaultVal)
    
    -- Special logic for Electric Field range capping
    if statName == "range" and self.upgrades["electric_field"] then
        if val > 600 then val = 400 end
    end
    
    return val
end

function MainTurret:applyUpgrade(reward)
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
            duration_burn = 3,
            dps_burn = 10,
            maxStacks = 5
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

function MainTurret:getCenterPosition()
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

function MainTurret:update(dt)
    self.cooldown = self.cooldown - dt
    
    if self.upgrades["electric_field"] then
        self:updateElectricField(dt)
    elseif self.autofire and self.game:isState("wave") then
        local mx, my = love.mouse.getPosition()
        self:PlayerClick(mx, my)
    end
end

function MainTurret:updateElectricField(dt)
    if self.cooldown <= 0 and self.game:isState("wave") then
        local currentFireRate = self:getStat("fireRate")
        
        if currentFireRate > 0 then
            local zapRange = self:getStat("range")
            local zapDamage = self:getStat("damage") -- Use standard damage
            local cx, cy = self:getCenterPosition()
            
            -- Find up to 3 targets in range
            local targets = {}
            for _, obj in ipairs(self.game.objects) do
                if obj:isType("enemy") and not obj.destroyed then
                    local dx, dy = obj.x - cx, obj.y - cy
                    if dx*dx + dy*dy <= zapRange*zapRange then
                        table.insert(targets, obj)
                        if #targets >= 3 then break end
                    end
                end
            end
            
            if #targets > 0 then
                for _, target in ipairs(targets) do
                    target:takeDamage(zapDamage, "electric", target.x, target.y)
                    
                    -- Apply specialized hit effects (e.g. Burn procs)
                    self:applyHitEffects(target)
                    
                    -- Visual Zap: Lightning Strike
                    if self.game.spawnLightningBolt then
                        self.game:spawnLightningBolt(target.x, target.y)
                    end
                    if self.game.spawnParticleExplosion then
                        self.game:spawnParticleExplosion({0.4, 0.7, 1, 1}, 5, target.x, target.y)
                    end
                end
                self.cooldown = 1 / currentFireRate -- Use standard cooldown
            end
        end
    end
end

function MainTurret:PlayerClick(tX, tY)
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

function MainTurret:applyHitEffects(target)
    -- Apply standard hit effects from the turret's hitEffects table
    if self.hitEffects then
        for _, effectTemplate in ipairs(self.hitEffects) do
            if target.effectManager and target.effectManager.applyEffect then
                target.effectManager:applyEffect(effectTemplate, self)
            end
        end
    end
end

function MainTurret:fire(args)
     args = args or {}
     -- Ensure correct angle for hitscan/projectiles if not provided
     if not args.angle then
         local fX, fY = self:getFirePoint()
         args.angle = math.atan2(args.targetY - fY, args.targetX - fX)
     end
     args.displayLifespan = args.displayLifespan or self:getStat("displayLifespan")
     args.color = args.color or self:getStat("bulletColor")
     
     Turret.fire(self, args)
end

function MainTurret:getTargetArc() end
function MainTurret:isInFiringArc(enemy) return true end

function MainTurret:drawFiringArc(alpha)
    local cx, cy = self:getCenterPosition()
    local range = self:getStat("range")
    
    love.graphics.setColor(1, 1, 1, alpha or 0.2)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", cx, cy, range)
    love.graphics.setColor(1, 1, 1, (alpha or 0.2) * 0.3)
    love.graphics.circle("fill", cx, cy, range)
end

return MainTurret
