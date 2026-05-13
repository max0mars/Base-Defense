local SFXManager = {}
SFXManager.__index = SFXManager

function SFXManager:new()
    local instance = setmetatable({}, SFXManager)
    instance.sounds = {}
    instance.activeSounds = {}
    instance.playedThisFrame = {}
    instance.volume = 0.03
    instance.isMuted = false
    
    -- Pre-register default sound effects
    instance:registerSound("laser_01", "Audio/SFX/laser_01.mp3")
    instance:registerSound("gunshot_01", "Audio/SFX/gunshot_01.mp3")
    instance:registerSound("explosion_01", "Audio/SFX/explosion_01.mp3")
    instance:registerSound("gunshot_02", "Audio/SFX/gunshot_02.mp3")
    instance:registerSound("gunshot_03", "Audio/SFX/gunshot_03.mp3")
    instance:registerSound("laser_02", "Audio/SFX/laser_02.mp3")
    instance:registerSound("money_01", "Audio/SFX/money_01.mp3")
    instance:registerSound("gunshot_04", "Audio/SFX/gunshot_04.mp3")
    instance:registerSound("explosion_02", "Audio/SFX/explosion_02.mp3")
    instance:registerSound("missile_01", "Audio/SFX/missile_01.mp3")
    instance:registerSound("lightning_01", "Audio/SFX/lightning_01.mp3")
    
    return instance
end

function SFXManager:registerSound(name, filepath)
    local success, source = pcall(love.audio.newSource, filepath, "static")
    if success and source then
        self.sounds[name] = source
    else
        print("SFXManager: Failed to load static audio source -> " .. filepath)
    end
end

function SFXManager:play(name)
    if self.isMuted then return end
    
    -- Prevent sound stacking/constructive interference and source exhaustion in a single frame
    if self.playedThisFrame[name] then return end
    self.playedThisFrame[name] = true
    
    local baseSource = self.sounds[name]
    if baseSource then
        local sfxVol = name == "missile_01" and math.min(1, self.volume * 40) or self.volume
        local success, clone = pcall(baseSource.clone, baseSource)
        if success and clone then
            clone:setVolume(sfxVol)
            clone:play()
            table.insert(self.activeSounds, clone)
        else
            -- Fallback to playing the base source directly
            baseSource:setVolume(sfxVol)
            baseSource:play()
        end
    else
        print("SFXManager: Sound effect not found -> " .. tostring(name))
    end
end

function SFXManager:setVolume(volume)
    self.volume = math.max(0, math.min(1, volume))
end

function SFXManager:toggleMute()
    self.isMuted = not self.isMuted
    return self.isMuted
end

function SFXManager:update(dt)
    self.playedThisFrame = {}
    for i = #self.activeSounds, 1, -1 do
        local source = self.activeSounds[i]
        if not source:isPlaying() then
            table.remove(self.activeSounds, i)
        end
    end
end

return SFXManager
