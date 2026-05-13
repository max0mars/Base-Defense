local MusicManager = require("Audio.MusicManager")
local SFXManager = require("Audio.SFXManager")

local AudioManager = {}
AudioManager.__index = AudioManager

function AudioManager:new()
    local instance = setmetatable({}, AudioManager)
    
    -- Sub-managers
    instance.music = MusicManager:new()
    instance.sfx = SFXManager:new()
    
    return instance
end

-- =============================================================================
-- Music APIs
-- =============================================================================

function AudioManager:playMusic(trackName)
    self.music:play(trackName)
end

function AudioManager:isPlayingMusic()
    return self.music.currentSource and self.music.currentSource:isPlaying()
end

function AudioManager:stopMusic()
    self.music:stop()
end

function AudioManager:pauseMusic()
    self.music:pause()
end

function AudioManager:resumeMusic()
    self.music:resume()
end

function AudioManager:nextMusicTrack()
    self.music:nextTrack()
end

function AudioManager:setMusicVolume(volume)
    self.music:setVolume(volume)
end

function AudioManager:getMusicVolume()
    return self.music.volume
end

function AudioManager:toggleMusicMute()
    return self.music:toggleMute()
end

-- =============================================================================
-- SFX APIs
-- =============================================================================

function AudioManager:playSFX(name)
    self.sfx:play(name)
end

function AudioManager:setSFXVolume(volume)
    self.sfx:setVolume(volume)
end

function AudioManager:getSFXVolume()
    return self.sfx.volume
end

function AudioManager:toggleSFXMute()
    return self.sfx:toggleMute()
end

-- =============================================================================
-- Core Loop Update
-- =============================================================================

function AudioManager:update(dt)
    self.music:update(dt)
    self.sfx:update(dt)
end

return AudioManager
