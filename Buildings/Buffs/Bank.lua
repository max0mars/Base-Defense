local Buff = require("Buildings.Buffs.Buff")

local Bank = setmetatable({}, Buff)
Bank.__index = Bank

local default = {
    name = "Bank",
    size = 20,
    color = {1, 0.84, 0, 1}, -- Neon Gold
    types = { building = true, economy = true, passive = true },
    shapePattern = {{0,0}, {0,1}, {1,0}, {1,1}},
    affectedSlots = {}, -- Bank doesn't affect other slots
    effect = nil, -- No buff effect
    
    -- Economy specific
    tokensPerCycle = 3,
    cycleWaves = 3
}

function Bank:new(config)
    config = config or {}
    for key, value in pairs(default) do
        config[key] = config[key] or value
    end
    
    local b = Buff:new(config)
    setmetatable(b, self)
    
    b.wavesSinceLastToken = 0
    return b
end

local lastWaveNumber = -1
local currentStaggerIndex = 0

function Bank:onWaveComplete()
    self.wavesSinceLastToken = self.wavesSinceLastToken + 1
    
    if self.wavesSinceLastToken >= self.cycleWaves then
        self.wavesSinceLastToken = 0
        
        if self.game.wave ~= lastWaveNumber then
            lastWaveNumber = self.game.wave
            currentStaggerIndex = 0
        end
        
        -- Stagger multiple banks by 0.25 seconds each
        self.payoutDelay = currentStaggerIndex * 0.25
        currentStaggerIndex = currentStaggerIndex + 1
    end
end

function Bank:update(dt)
    -- Skip Turret.update since we inherit from Buff/Building
    if self.payoutDelay then
        self.payoutDelay = self.payoutDelay - dt
        if self.payoutDelay <= 0 then
            self.payoutDelay = nil
            
            if AUDIO then AUDIO:playSFX("money_01") end
            self.game:addTokens(self.tokensPerCycle)
            
            -- Payout visual cue
            if self.game.spawnFloatingText then
                local cx, cy = self:getCenterPosition()
                self.game:spawnFloatingText("+" .. tostring(self.tokensPerCycle) .. " Tokens", cx, cy - 20, {1, 0.84, 0, 1})
            end
        end
    end
end

-- We inherit Buff:draw() so it looks like other support/buff buildings (Neon Gold Diamond)

return Bank
