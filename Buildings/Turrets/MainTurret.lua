local Turret = require("Buildings.Turrets.Turret")

local MainTurret = setmetatable({}, Turret)
MainTurret.__index = MainTurret

local default = {
    --type = 'turret',
    tag = 'mainTurret',
    rotation = 0,
    turnSpeed = math.huge,
    fireRate = 1,
    damage = 85,      -- More damage than regular turret
    bulletSpeed = 800, -- Faster bullets
    range = math.huge,
    barrel = 0,
    color = {1, 0.5, 0, 1} -- Orange color to distinguish from regular turrets
}

function MainTurret:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    -- MainTurret doesn't use firing arcs, so remove firingArc from config
    config.firingArc = nil
    
    local t = setmetatable(Turret.new(self, config), { __index = self })
    return t
end

function MainTurret:update(dt)
    -- Simple player-controlled logic - no targeting, no firing arc checks
    self.cooldown = self.cooldown - dt
    
    -- Always aim at mouse position
    local mx, my = love.mouse.getPosition()
    self:lookAt(mx, my, dt)
end

function MainTurret:PlayerClick(targetX, targetY)
    -- Fire directly at specified coordinates if not on cooldown
    if self.cooldown <= 0 then
        self:fire({targetX = targetX, targetY = targetY})
        self.cooldown = self.fireRate
        return true -- Successfully fired
    end
    return false -- Still on cooldown
end

function MainTurret:drawReloadBar()
    -- Only show reload bar if reloading
    if self.cooldown > 0 then
        local barWidth = 35  -- Slightly wider than Mortar
        local barHeight = 5   -- Slightly taller than Mortar
        local barX = self.x - barWidth/2
        local barY = self.y - 25  -- Position above the main turret
        
        local reloadProgress = 1 - (self.cooldown / self.fireRate)
        
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
    -- Draw without firing arc since MainTurret doesn't use them
    love.graphics.setColor(self.color)
    
    -- Draw turret mount (slightly larger than regular turret)
    love.graphics.circle("fill", self.x, self.y, 10)

    -- Draw barrel
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(4) -- Thicker barrel than regular turret
    love.graphics.line(
        self.x, self.y,
        self.x + math.cos(self.rotation) * 20,
        self.y + math.sin(self.rotation) * 20
    )
    love.graphics.setLineWidth(1) -- Reset line width
    
    -- Draw reload bar
    self:drawReloadBar()
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
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