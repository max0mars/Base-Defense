local Turret = require("Buildings.Turrets.Turret")
local Utils = require("Classes.Utils")

local Bank = setmetatable({}, { __index = Turret })
Bank.__index = Bank

Bank.template = {
    name = "Bank",
    size = 20,
    rotation = 0,
    turnSpeed = 0, -- Static
    fireRate = 0, -- Doesn't fire
    range = 0,
    barrel = 0,
    damage = 0,
    bulletSpeed = 0,
    color = {1, 0.84, 0, 1}, -- Neon Gold
    types = { building = true, economy = true },
    shapePattern = {{0,0}},
    firingArc = {
        direction = 0,
        minRange = 0,
        angle = 0
    },
    
    -- Economy specific
    wavesSinceLastToken = 0,
    tokensPerCycle = 1,
    cycleWaves = 3
}

function Bank:new(config)
    local baseConfig = Utils.deepCopy(Bank.template)
    
    if config then
        for k, v in pairs(config) do
            baseConfig[k] = v
        end
    end
    
    local t = Turret:new(baseConfig)
    setmetatable(t, { __index = self })
    
    t.wavesSinceLastToken = 0
    
    return t
end

function Bank:onWaveComplete()
    self.wavesSinceLastToken = self.wavesSinceLastToken + 1
    
    if self.wavesSinceLastToken >= self.cycleWaves then
        self.game:addTokens(self.tokensPerCycle)
        self.wavesSinceLastToken = 0
        
        -- Payout visual cue
        if self.game.spawnFloatingText then
            local cx, cy = self:getCenterPosition()
            self.game:spawnFloatingText("+1 Token", cx, cy - 20, {1, 0.84, 0, 1})
        end
    end
end

-- Override draw to make it look like a mint/vault
function Bank:draw(drawx, drawy)
    local cx, cy = drawx or self.x, drawy or self.y
    if not drawx and not drawy then
        cx, cy = self:getCenterPosition()
    end
    
    local r, g, b = unpack(self.color)
    local pulse = (math.sin(love.timer.getTime() * 4) + 1) / 2
    
    -- Outer frame
    love.graphics.setColor(r, g, b, 0.2 + pulse * 0.2)
    love.graphics.rectangle("line", cx - 12, cy - 12, 24, 24, 4, 4)
    
    -- Inner "Coin" core
    love.graphics.setColor(r, g, b, 1)
    love.graphics.circle("line", cx, cy, 6 + pulse * 2)
    love.graphics.circle("fill", cx, cy, 3)
    
    love.graphics.setColor(1, 1, 1, 1)
end

return Bank
