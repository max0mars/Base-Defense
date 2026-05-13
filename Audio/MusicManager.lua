local MusicManager = {}
MusicManager.__index = MusicManager

function MusicManager:new()
    local instance = setmetatable({}, MusicManager)
    instance.tracks = {}
    instance.currentTrackName = nil
    instance.currentSource = nil
    instance.volume = 0.07
    instance.isMuted = false
    
    -- Register default available tracks
    instance:registerTrack("City Chase", "Audio/Music/City Chase (Club Mix).mp3")
    instance:registerTrack("Clutterfunk", "Audio/Music/Clutterfunk, Pt. 2.mp3")
    instance:registerTrack("Electroman", "Audio/Music/Electroman Adventures V2.mp3")
    instance:registerTrack("Moonbeam", "Audio/Music/Moonbeam.mp3")
    instance:registerTrack("Dawn of Time", "Audio/Music/The Dawn of Time.mp3")
    instance:registerTrack("Meltdown", "Audio/Music/Meltdown.mp3")
    
    instance.playlist = {"City Chase", "Moonbeam", "Meltdown", "Dawn of Time", "Clutterfunk", "Electroman"}
    instance.playlistIndex = 1
    
    return instance
end

function MusicManager:registerTrack(name, filepath)
    self.tracks[name] = filepath
end

function MusicManager:play(trackName)
    -- If no track specified, play the current playlist track
    if not trackName then
        trackName = self.playlist[self.playlistIndex]
    else
        -- Find index in playlist if possible
        for i, name in ipairs(self.playlist) do
            if name == trackName then
                self.playlistIndex = i
                break
            end
        end
    end

    if not trackName or not self.tracks[trackName] then
        print("MusicManager: Track not found -> " .. tostring(trackName))
        return
    end

    -- Stop current track if playing
    self:stop()

    local filepath = self.tracks[trackName]
    local success, source = pcall(love.audio.newSource, filepath, "stream")
    
    if success and source then
        self.currentSource = source
        self.currentTrackName = trackName
        self.currentSource:setVolume(self.isMuted and 0 or self.volume)
        self.currentSource:play()
        print("MusicManager: Playing track -> " .. trackName)
    else
        print("MusicManager: Failed to load streaming audio source -> " .. filepath)
    end
end

function MusicManager:stop()
    if self.currentSource then
        self.currentSource:stop()
        self.currentSource = nil
        self.currentTrackName = nil
    end
end

function MusicManager:pause()
    if self.currentSource and self.currentSource:isPlaying() then
        self.currentSource:pause()
    end
end

function MusicManager:resume()
    if self.currentSource and not self.currentSource:isPlaying() then
        self.currentSource:play()
    end
end

function MusicManager:nextTrack()
    if #self.playlist == 0 then return end
    self.playlistIndex = self.playlistIndex + 1
    if self.playlistIndex > #self.playlist then
        self.playlistIndex = 1
    end
    self:play(self.playlist[self.playlistIndex])
end

function MusicManager:setVolume(volume)
    self.volume = math.max(0, math.min(1, volume))
    if self.currentSource then
        self.currentSource:setVolume(self.isMuted and 0 or self.volume)
    end
end

function MusicManager:toggleMute()
    self.isMuted = not self.isMuted
    if self.currentSource then
        self.currentSource:setVolume(self.isMuted and 0 or self.volume)
    end
    return self.isMuted
end

function MusicManager:update(dt)
    -- Check if current track finished playing, then automatically transition to next track
    if self.currentSource then
        if not self.currentSource:isPlaying() then
            self:nextTrack()
        end
    end
end

return MusicManager
