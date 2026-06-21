local Enemy = require("Enemies.Enemy")
local TurretDebuffer = setmetatable({}, {__index = Enemy})
TurretDebuffer.__index = TurretDebuffer

local default = {
    name = "Turret Debuffer",
    reward = 35,
    numTargets = 1,
    debuffStacks = 999,
    debuffDuration = nil, -- Permanent until drone is destroyed if nil
    debuffFrequency = 3.0,
    stickyTargets = true, -- Keep same target(s) or switch
    debuffStat = "fireRate",
    debuffAmount = -0.01,
}

function TurretDebuffer:new(config)
    config = config or {}
    
    -- Retrieve base stats from EnemyIndex to support customization
    local isTesting = config.game and config.game.testingMode
    local index = isTesting and require("Game.Spawning.TestingEnemyIndex") or require("Game.Spawning.EnemyIndex")
    local name = config.name or "Drone"
    local base = nil
    for _, entry in ipairs(index) do
        if entry.id == name or entry.type == name then
            base = entry
            break
        end
    end
    
    for key, value in pairs(default) do
        config[key] = config[key] or (base and base[key]) or value
    end
    
    local instance = Enemy:new(config)
    setmetatable(instance, self)
    
    instance.debuffTimer = 0 -- Apply immediately on spawn
    instance.activeTargets = {}
    return instance
end

function TurretDebuffer:update(dt)
    if self.destroyed then return end
    Enemy.update(self, dt)
    
    if self:getStat("stunned", 0) > 0 then return end
    
    self.debuffTimer = self.debuffTimer - dt
    if self.debuffTimer <= 0 then
        self.debuffTimer = self:getStat("debuffFrequency") or 3.0
        self:applyDebuffs()
    end
end

function TurretDebuffer:applyDebuffs()
    if not self.game or not self.game.objects then return end
    
    local numTargets = self:getStat("numTargets") or 1
    local sticky = self:getStat("stickyTargets")
    local debuffStat = self:getStat("debuffStat") or "fireRate"
    local debuffAmount = self:getStat("debuffAmount") or -0.01
    local maxStacks = self:getStat("debuffStacks") or 999
    local durationVal = self:getStat("debuffDuration")
    local duration = (durationVal and durationVal > 0) and durationVal or nil
    
    local targetList = {}
    
    -- Clean up active targets if they are destroyed or invalid
    if sticky then
        for i = #self.activeTargets, 1, -1 do
            local tgt = self.activeTargets[i]
            if tgt.destroyed or not self:isValidTarget(tgt) then
                table.remove(self.activeTargets, i)
            end
        end
    else
        self.activeTargets = {}
    end
    
    -- Gather all valid candidates
    local candidates = {}
    for _, obj in ipairs(self.game.objects) do
        if self:isValidTarget(obj) then
            local alreadyTargeted = false
            for _, t in ipairs(self.activeTargets) do
                if t == obj then alreadyTargeted = true; break end
            end
            
            if not alreadyTargeted then
                local dx = obj.x - self.x
                local dy = obj.y - self.y
                local distSq = dx * dx + dy * dy
                
                -- Check if another active drone is already targeting this turret
                local targetedByOther = false
                for _, other in ipairs(self.game.objects) do
                    if other ~= self and other.activeTargets then
                        for _, activeTgt in ipairs(other.activeTargets) do
                            if activeTgt == obj then
                                targetedByOther = true
                                break
                            end
                        end
                    end
                    if targetedByOther then break end
                end
                
                table.insert(candidates, { obj = obj, distSq = distSq, targetedByOther = targetedByOther })
            end
        end
    end
    
    -- Sort candidates: prefer those not targeted by other drones, then closest first
    table.sort(candidates, function(a, b)
        if a.targetedByOther ~= b.targetedByOther then
            return not a.targetedByOther
        end
        return a.distSq < b.distSq
    end)
    
    -- Combine target list
    for _, t in ipairs(self.activeTargets) do
        table.insert(targetList, t)
    end
    
    local needed = numTargets - #targetList
    for i = 1, math.min(needed, #candidates) do
        local newTgt = candidates[i].obj
        table.insert(targetList, newTgt)
        if sticky then
            table.insert(self.activeTargets, newTgt)
        end
    end
    
    -- Apply debuff effect using EffectManager
    local effectName = "drone_debuff_" .. self.id
    for _, target in ipairs(targetList) do
        local debuffTemplate = {
            name = effectName,
            displayName = "Drone Slowdown",
            duration = duration,
            maxStacks = maxStacks,
            statModifiers = {
                [debuffStat] = { mult = debuffAmount }
            }
        }
        -- Spawn cyan particle effects at the drone
        if self.game and self.game.spawnParticleExplosion then
            self.game:spawnParticleExplosion(self.color or {0, 1, 1, 1}, 18, self.x, self.y, 0.6, 12)
        end
        
        local gameRef = self.game
        if gameRef and gameRef.spawnDebuffProjectile then
            local droneColor = self.color or {0, 1, 1, 1}
            gameRef:spawnDebuffProjectile(self.x, self.y, target, function()
                if not target.destroyed and not self.destroyed then
                    target.effectManager:applyEffect(debuffTemplate, self)
                    if gameRef.spawnDebuffArrows then
                        local tx, ty = target.x, target.y
                        if target.getCenterPosition then
                            tx, ty = target:getCenterPosition()
                        end
                        gameRef:spawnDebuffArrows(tx, ty)
                    end
                end
            end, droneColor)
        end
    end
end

function TurretDebuffer:isValidTarget(obj)
    return obj.effectManager and not obj.destroyed and (obj.types and (obj.types.turret or obj.types.building))
end

function TurretDebuffer:died()
    self:clearDebuffs()
    Enemy.died(self)
end

function TurretDebuffer:destroy()
    self:clearDebuffs()
    Enemy.destroy(self)
end

function TurretDebuffer:clearDebuffs()
    if self.game and self.game.objects then
        local effectName = "drone_debuff_" .. self.id
        for _, obj in ipairs(self.game.objects) do
            if obj.effectManager then
                for i = #obj.effectManager.activeEffects, 1, -1 do
                    local effect = obj.effectManager.activeEffects[i]
                    if effect.name == effectName then
                        obj.effectManager:removeEffect(effect)
                    end
                end
            end
        end
    end
end

return TurretDebuffer
