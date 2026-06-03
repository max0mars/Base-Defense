local Turret = require("Buildings.Turrets.Turret")
local Layout = require("Game.GUI.Layout")

local StandardMainTurret = setmetatable({}, { __index = Turret })
StandardMainTurret.__index = StandardMainTurret

function StandardMainTurret:new(config)
    local t = Turret:new(config)
    setmetatable(t, { __index = self })
    t.isMainTurret = true
    t.autofire = config.autofire or false
    t.upgrades = {} -- Persistent weapon upgrades
    
    if t.slot then
        local cx, cy = t:getCenterPosition()
        t.x, t.y = cx, cy
    end
    
    return t
end

function StandardMainTurret:getStat(statName, defaultVal)
    return Turret.getStat(self, statName, defaultVal)
end

function StandardMainTurret:applyUpgrade(reward)
    if not reward or not reward.id then return end
    self.upgrades[reward.id] = true
    if self.effectManager and reward.name then
        self.effectManager:applyEffect({ name = reward.name })
    end
    print("Main Turret Upgrade Applied: " .. reward.name)
end

function StandardMainTurret:getCenterPosition()
    if not self.slot then return self.x, self.y end
    local anchorSlot = self.slot
    local anchorX = ((anchorSlot - 1) % self.buildGrid.width) * self.buildGrid.cellSize + self.buildGrid.x
    local anchorY = (math.ceil(anchorSlot / self.buildGrid.width) - 1) * self.buildGrid.cellSize + self.buildGrid.y
    return anchorX + self.buildGrid.cellSize, anchorY + self.buildGrid.cellSize
end

function StandardMainTurret:update(dt)
    self.cooldown = self.cooldown - dt
    if self.autofire and self.game:isState("wave") then
        local mx, my = Layout.mouseToField()
        self:PlayerClick(mx, my)
    end
end

function StandardMainTurret:PlayerClick(tX, tY)
    local base = self.game.base
    if base then
        local bx1 = base.x - base.w / 2
        local bx2 = base.x + base.w / 2
        local by1 = base.y - base.h / 2
        local by2 = base.y + base.h / 2
        if tX >= bx1 and tX <= bx2 and tY >= by1 and tY <= by2 then
            return false
        end
    end

    if self.cooldown <= 0 then
        local currentFireRate = self:getStat("fireRate")
        if currentFireRate > 0 then
            local fX, fY = self:getFirePoint()
            local angle = math.atan2(tY - fY, tX - fX)
            local range = (self:getStat("range") or 2000) * 2
            local extendedTx = fX + math.cos(angle) * range
            local extendedTy = fY + math.sin(angle) * range
            
            self:fire({
                targetX = extendedTx, 
                targetY = extendedTy,
                fireX = fX,
                fireY = fY,
                angle = angle
            })
            self.cooldown = 1 / currentFireRate
            return true
        end
    end
    return false
end

function StandardMainTurret:getFirePoint()
    local cx, cy = self:getCenterPosition()
    return cx, cy
end

function StandardMainTurret:fire(args)
     args = args or {}
     if not args.angle then
         local fX, fY = self:getFirePoint()
         args.angle = math.atan2(args.targetY - fY, args.targetX - fX)
     end
     args.displayLifespan = args.displayLifespan or self:getStat("displayLifespan")
     args.color = args.color or self:getStat("bulletColor")
     Turret.fire(self, args)
end

function StandardMainTurret:applyHitEffects(target)
    if not target or not target.effectManager then return end
    local uniqueEffects = {}
    local seen = {}
    
    if self.hitEffects then
        for _, effect in ipairs(self.hitEffects) do
            if effect.name and not seen[effect.name] then
                table.insert(uniqueEffects, effect)
                seen[effect.name] = true
            end
        end
    end
    
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
    
    for _, effect in ipairs(uniqueEffects) do
        if effect.isIndependent then
            if effect.trigger then effect:trigger(target, self) end
        else
            target.effectManager:applyEffect(effect, self)
        end
    end
end

-- Abstract methods to override
function StandardMainTurret.getStartingDeck() return nil end
function StandardMainTurret.getUniqueCards() return {} end

return StandardMainTurret
