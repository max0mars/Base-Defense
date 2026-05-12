local Turret = require("Buildings.Turrets.Turret")
local BounceEffect = require("Game.Effects.IndependantEffects.bounce")

local ChainLaser = setmetatable({}, { __index = Turret })
ChainLaser.__index = ChainLaser

local template = {
    name = "Chain Laser",
    rotation = 0,
    turnSpeed = 5,
    fireRate = 0.65,
    damage = 30,
    bulletSpeed = 600,
    range = 500,
    barrel = 15,
    lifespan = 5,
    firingArc = {
        direction = 0,
        minRange = 0,
        angle = math.pi / 6 -- Aimable 30-degree cone
    },
    shapePattern = {
        {0, 0}
    },
    color = {0.4, 0.7, 1, 1}, -- Electric blue
    bulletW = 6,
    bulletH = 6,
    bulletName = "Lazer Bolt",
    damageType = "energy",
    bouncesLeft = 10,
    cost = 500, -- Legendary price
    types = { turret = true, legendary = true, energy = true, laser = true },
    sfx = "laser_02"
}

function ChainLaser:new(config)
    -- Deep copy the template to avoid shared table references
    local baseConfig = {}
    for k, v in pairs(template) do
        if type(v) == "table" then
            baseConfig[k] = {}
            for k2, v2 in pairs(v) do baseConfig[k][k2] = v2 end
        else
            baseConfig[k] = v
        end
    end

    if config then
        for k, v in pairs(config) do
            if type(v) == "table" and baseConfig[k] then
                for k2, v2 in pairs(v) do baseConfig[k][k2] = v2 end
            else
                baseConfig[k] = v
            end
        end
    end
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    
    -- Add the bounce effect to the turret's hit effects
    t.hitEffects = { BounceEffect:new({ name = "Chain Bounce" }) }
    
    return t
end

function ChainLaser:fire(args)
    args = args or {}
    -- Ensure the bullet knows how many times it can bounce
    args.bouncesLeft = self:getStat("bouncesLeft")
    Turret.fire(self, args)
end

function ChainLaser:draw(drawx, drawy)
    local cx, cy = drawx or self.x, drawy or self.y
    if not drawx and not drawy then
        cx, cy = self:getCenterPosition()
    end
    local r, g, b = unpack(self.color or {0.4, 0.7, 1, 1})
    local time = love.timer.getTime()
    
    -- Draw Aiming Arc (Standard Turret feature)
    if self.showArc then
        self:drawFiringArc(cx, cy, 0.4)
    end
    
    -- 1. Draw Hexagonal Power Base
    local function drawHex(radius)
        local pts = {}
        for i = 0, 5 do
            local angle = i * (math.pi * 2 / 6)
            table.insert(pts, cx + math.cos(angle) * radius)
            table.insert(pts, cy + math.sin(angle) * radius)
        end
        love.graphics.polygon("line", pts)
    end
    
    -- Base Glow
    love.graphics.setColor(r, g, b, 0.2)
    love.graphics.setLineWidth(4)
    drawHex(12)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(2)
    drawHex(10)
    
    -- Corner Power Cells
    for i = 0, 2 do
        local angle = i * (math.pi * 2 / 3) + time * 0.5
        local px = cx + math.cos(angle) * 12
        local py = cy + math.sin(angle) * 12
        local pulse = (math.sin(time * 5 + i) + 1) / 2
        love.graphics.setColor(r, g, b, 0.3 + 0.7 * pulse)
        love.graphics.circle("fill", px, py, 2)
    end
    
    -- 2. Draw Aiming Head (Floating Rails)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(self.rotation)
    
    -- Reload Progress for visuals
    local currentFireRate = self:getStat("fireRate")
    local reloadProgress = 1 - math.max(0, self.cooldown / (1 / currentFireRate))
    
    -- Floating Rails
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", 5, -6, 15, 3, 1) -- Top rail
    love.graphics.rectangle("fill", 5, 3, 15, 3, 1)  -- Bottom rail
    
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("line", 5, -6, 15, 3, 1)
    love.graphics.rectangle("line", 5, 3, 15, 3, 1)
    
    -- Energy Core (Pulsing)
    local corePulse = (math.sin(time * 15) + 1) / 2
    love.graphics.setColor(r, g, b, 0.4 + 0.6 * corePulse * reloadProgress)
    love.graphics.circle("fill", 8, 0, 4 + corePulse)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 8, 0, 2)
    
    -- Electrical Arcs between rails (if charging)
    if reloadProgress > 0.3 then
        love.graphics.setColor(r, g, b, 0.7 * reloadProgress)
        love.graphics.setLineWidth(1)
        for i = 1, 2 do
            local x = 8 + math.random() * 10
            local y1 = -3
            local y2 = 3
            love.graphics.line(x, y1, x + (math.random()-0.5)*4, (y1+y2)/2, x, y2)
        end
    end
    
    love.graphics.pop()
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return ChainLaser
