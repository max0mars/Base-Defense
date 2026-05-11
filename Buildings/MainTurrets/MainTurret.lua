local Turret = require("Buildings.Turrets.Turret")
local MainTurret = setmetatable({}, { __index = Turret })
MainTurret.__index = MainTurret

function MainTurret:new(config)
    local t = Turret:new(config)
    setmetatable(t, { __index = self })
    
    t.isMainTurret = true
    t.autofire = config.autofire or false
    
    if t.slot then
        local cx, cy = t:getCenterPosition()
        t.x, t.y = cx, cy
    end
    
    return t
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
    
    if self.autofire and self.game:isState("wave") then
        local mx, my = love.mouse.getPosition()
        self:PlayerClick(mx, my)
    end
end

function MainTurret:PlayerClick(tX, tY)
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

function MainTurret:fire(args)
     -- Ensure correct angle for hitscan/projectiles
     local fX, fY = self:getFirePoint()
     local angle = math.atan2(args.targetY - fY, args.targetX - fX)
     args.angle = angle
     args.displayLifespan = self:getStat("displayLifespan")
     args.color = self:getStat("bulletColor")
     Turret.fire(self, args)
end

function MainTurret:getTargetArc() end
function MainTurret:isInFiringArc(enemy) return true end
function MainTurret:drawFiringArc(alpha) end

return MainTurret
