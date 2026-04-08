local Turret = require("Buildings.Turrets.Turret")
local Laser = require("Bullets.Laser")

local MainTurret = setmetatable({}, Turret)
MainTurret.__index = MainTurret

local default = {
    types = { turret = true, mainTurret = true },
    turnSpeed = math.huge,
    fireRate = 0.5, -- Hz (was 0.2s delay)
    damage = 65,      -- More damage than regular turret
    bulletSpeed = 800, -- Faster bullets
    range = math.huge,
    size = 18,
    barrel = 10,
    bulletType = Laser,
    -- Define shape as relative coordinates instead of absolute slots
    shapePattern = {
        {0, 0}, {1, 0},  -- Top row: anchor + right
        {0, 1}, {1, 1}   -- Bottom row: down + down-right
    },
    color = {0.3, 0.3, 0.3, 1}, -- Orange color to distinguish from regular turrets
    autofire = false
}

function MainTurret:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    -- MainTurret doesn't use firing arcs, so remove firingArc from config
    config.firingArc = nil
    
    local t = setmetatable(Turret.new(self, config), { __index = self })
    
    -- Sync logical position (x, y) with the center if we have a slot,
    -- otherwise Turret.new already handles base initialization.
    if t.slot then
        local cx, cy = t:getCenterPosition()
        t.x, t.y = cx, cy
    end
    
    return t
end

function MainTurret:getCenterPosition()
    -- If the building is not yet placed (e.g. during placement preview), 
    -- the slot will be nil. Use raw x, y (mouse coords) in this case.
    if not self.slot then
        return self.x, self.y
    end

    -- Calculate center position for 2x2 turret in grid
    local anchorSlot = self.slot
    local anchorX = ((anchorSlot - 1) % self.buildGrid.width) * self.buildGrid.cellSize + self.buildGrid.x
    local anchorY = (math.ceil(anchorSlot / self.buildGrid.width) - 1) * self.buildGrid.cellSize + self.buildGrid.y
    
    -- Center in the 2x2 area
    local centerX = anchorX + self.buildGrid.cellSize
    local centerY = anchorY + self.buildGrid.cellSize
    
    return centerX, centerY
end

function MainTurret:update(dt)
    -- Simple player-controlled logic - no targeting, no firing arc checks
    self.cooldown = self.cooldown - dt
    
    -- Handle autofire
    if self.autofire and self.game:isState("wave") then
        local mx, my = love.mouse.getPosition()
        self:PlayerClick(mx, my)
    end
end

function MainTurret:PlayerClick(tX, tY)
    -- Only fire during wave state
    -- Prevent firing if clicking on the base
    local base = self.game.base
    local bx1 = base.x - base.w / 2
    local bx2 = base.x + base.w / 2
    local by1 = base.y - base.h / 2
    local by2 = base.y + base.h / 2
    
    if tX >= bx1 and tX <= bx2 and tY >= by1 and tY <= by2 then
        return false -- Clicked on base
    end

    -- Fire directly at specified coordinates if not on cooldown
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
            return true -- Successfully fired
        end
    end
    return false -- Still on cooldown
end

function MainTurret:drawReloadBar()
    -- Only show reload bar if reloading
    if self.cooldown > 0 then
        local centerX, centerY = self:getCenterPosition()
        local barWidth = 40  -- Wider for 2x2 turret
        local barHeight = 6   -- Taller for 2x2 turret
        local barX = centerX - barWidth/2
        local barY = centerY - 30  -- Position higher above the larger turret
        
        local currentFireRate = self:getStat("fireRate")
        local reloadProgress = 0
        if currentFireRate > 0 then
            reloadProgress = 1 - (self.cooldown / (1 / currentFireRate))
        end
        
        -- Draw background (dark grey)
        love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
        
        -- Draw reload progress (orange to match turret color)
        love.graphics.setColor(1, 0.5, 0, 0.9)
        love.graphics.rectangle("fill", barX, barY, barWidth * reloadProgress, barHeight)
        
        -- Draw border
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
    end
end

function MainTurret:draw()
    -- Get center position for 2x2 turret
    local centerX, centerY = self:getCenterPosition()
    -- Draw without firing arc since MainTurret doesn't use them
    love.graphics.setColor(self.color)
    
    -- Draw larger turret mount to fit 2x2 area
    love.graphics.rectangle("line", centerX - self.size, centerY - self.size, self.size * 2, self.size * 2)

    -- Draw larger barrel
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(2) -- Much thicker barrel for 2x2 turret
    love.graphics.line(
        centerX- 10, centerY+5,
        centerX, --+ math.cos(self.rotation) * self.barrel,
        centerY - self.barrel --math.sin(self.rotation) * self.barrel
    )

    love.graphics.line(
        centerX+10, centerY+5,
        centerX, --+ math.cos(self.rotation) * self.barrel,
        centerY - self.barrel --math.sin(self.rotation) * self.barrel
    )

    love.graphics.line(
        centerX, centerY+5,
        centerX, --+ math.cos(self.rotation) * self.barrel,
        centerY - self.barrel --math.sin(self.rotation) * self.barrel
    )

    love.graphics.setColor(0, 0, 1)
    love.graphics.circle("fill", centerX, centerY - self.barrel, 4)
    love.graphics.setLineWidth(1) -- Reset line width
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function MainTurret:getFirePoint()
    local centerX, centerY = self:getCenterPosition()
    return centerX, centerY - self.barrel
end

-- Override methods that shouldn't be used by MainTurret
function MainTurret:getTargetArc()
    -- MainTurret doesn't use arc-based targeting
end

function MainTurret:isInFiringArc(enemy)
    -- MainTurret can fire in any direction
    return true
end

function MainTurret:drawFiringArc(alpha)
    -- MainTurret doesn't draw firing arcs
end

return MainTurret