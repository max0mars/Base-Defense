local AudioSlidersUI = {}
AudioSlidersUI.__index = AudioSlidersUI

function AudioSlidersUI:new(options)
    options = options or {}
    local obj = setmetatable({
        x = options.x or 300,
        y = options.y or 450,
        w = options.w or 200,
        dragging = nil
    }, self)
    return obj
end

function AudioSlidersUI:setPosition(x, y)
    self.x = x
    self.y = y
end

function AudioSlidersUI:update(dt)
    if not AUDIO then return end
    
    local mx, my = love.mouse.getPosition()
    
    if not love.mouse.isDown(1) then
        self.dragging = nil
    end
    
    if self.dragging then
        local pct = (mx - self.x) / self.w
        pct = math.max(0, math.min(1, pct))
        
        if self.dragging == "music" then
            AUDIO:setMusicVolume(pct)
        elseif self.dragging == "sfx" then
            AUDIO:setSFXVolume(pct)
        end
    end
end

function AudioSlidersUI:draw()
    if not AUDIO then return end
    
    local musicVol = AUDIO:getMusicVolume()
    local sfxVol = AUDIO:getSFXVolume()
    
    local trackH = 16
    local cornerRadius = 4
    
    -- Save graphics state
    love.graphics.push("all")
    
    -- Draw Music Slider
    local musicY = self.y
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(string.format("Music Volume: %d%%", math.floor(musicVol * 100)), self.x, musicY - 18, self.w, "center")
    
    -- Background track
    love.graphics.setColor(0.15, 0.15, 0.15, 1)
    love.graphics.rectangle("fill", self.x, musicY, self.w, trackH, cornerRadius)
    
    -- Filled track
    if musicVol > 0 then
        love.graphics.setColor(0.2, 0.7, 0.4, 1) -- Accent green
        love.graphics.rectangle("fill", self.x, musicY, self.w * musicVol, trackH, cornerRadius)
    end
    
    -- Border
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", self.x, musicY, self.w, trackH, cornerRadius)
    
    -- Knob/Handle
    local knobWidth = 8
    local knobX = self.x + self.w * musicVol - knobWidth / 2
    knobX = math.max(self.x, math.min(self.x + self.w - knobWidth, knobX))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", knobX, musicY - 2, knobWidth, trackH + 4, 2)
    
    -- Draw SFX Slider
    local sfxY = self.y + 50
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(string.format("SFX Volume: %d%%", math.floor(sfxVol * 100)), self.x, sfxY - 18, self.w, "center")
    
    -- Background track
    love.graphics.setColor(0.15, 0.15, 0.15, 1)
    love.graphics.rectangle("fill", self.x, sfxY, self.w, trackH, cornerRadius)
    
    -- Filled track
    if sfxVol > 0 then
        love.graphics.setColor(0.2, 0.6, 0.8, 1) -- Accent blue
        love.graphics.rectangle("fill", self.x, sfxY, self.w * sfxVol, trackH, cornerRadius)
    end
    
    -- Border
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.rectangle("line", self.x, sfxY, self.w, trackH, cornerRadius)
    
    -- Knob/Handle
    local sfxKnobX = self.x + self.w * sfxVol - knobWidth / 2
    sfxKnobX = math.max(self.x, math.min(self.x + self.w - knobWidth, sfxKnobX))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", sfxKnobX, sfxY - 2, knobWidth, trackH + 4, 2)
    
    love.graphics.pop()
end

function AudioSlidersUI:mousepressed(x, y, button)
    if not AUDIO or button ~= 1 then return false end
    
    local trackH = 16
    
    -- Check Music Slider
    local musicY = self.y
    if x >= self.x - 5 and x <= self.x + self.w + 5 and y >= musicY - 5 and y <= musicY + trackH + 5 then
        self.dragging = "music"
        local pct = math.max(0, math.min(1, (x - self.x) / self.w))
        AUDIO:setMusicVolume(pct)
        return true
    end
    
    -- Check SFX Slider
    local sfxY = self.y + 50
    if x >= self.x - 5 and x <= self.x + self.w + 5 and y >= sfxY - 5 and y <= sfxY + trackH + 5 then
        self.dragging = "sfx"
        local pct = math.max(0, math.min(1, (x - self.x) / self.w))
        AUDIO:setSFXVolume(pct)
        AUDIO:playSFX("gunshot_01")
        return true
    end
    
    return false
end

function AudioSlidersUI:mousereleased(x, y, button)
    if button == 1 then
        self.dragging = nil
    end
end

return AudioSlidersUI
