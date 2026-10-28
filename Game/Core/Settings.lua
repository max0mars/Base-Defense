-- Settings.lua - Player settings saved to disk (settings.lua in the save folder).
--
-- Holds what the settings panel changes: neon glow, music / SFX volume and the
-- window mode. Settings.load() reads them at startup, Settings.apply*() pushes
-- them into the game, and Settings.capture() reads the live values back and
-- saves them after the player changes something.

local Glow = require("Graphics.Glow")

local Settings = {
    FILE = "settings.lua",
    values = {
        glow = true,
        musicVolume = nil, -- nil: keep the audio defaults
        sfxVolume = nil,
        fullscreen = false,
        width = nil, -- windowed size; nil: the default
        height = nil,
    },
}

local function filesystem()
    return love and love.filesystem and love.filesystem.read and love.filesystem
end

--- Reads saved settings over the defaults. Missing or broken files are ignored.
function Settings.load()
    local fs = filesystem()
    if not fs or not (fs.getInfo and fs.getInfo(Settings.FILE)) then return Settings.values end
    local text = fs.read(Settings.FILE)
    local chunk = text and load(text, "settings", "t", {})
    local ok, saved = pcall(chunk or error)
    if ok and type(saved) == "table" then
        for k, v in pairs(saved) do
            if Settings.values[k] ~= nil or type(v) ~= "table" then Settings.values[k] = v end
        end
    end
    Glow.enabled = Settings.values.glow ~= false
    return Settings.values
end

--- Writes the current values to disk.
function Settings.save()
    local fs = filesystem()
    if not fs or not fs.write then return false end
    local keys = {}
    for k in pairs(Settings.values) do table.insert(keys, k) end
    table.sort(keys)
    local lines = { "return {" }
    for _, k in ipairs(keys) do
        local v = Settings.values[k]
        if type(v) == "number" or type(v) == "boolean" then
            table.insert(lines, string.format("    %s = %s,", k, tostring(v)))
        elseif type(v) == "string" then
            table.insert(lines, string.format("    %s = %q,", k, v))
        end
    end
    table.insert(lines, "}")
    return fs.write(Settings.FILE, table.concat(lines, "\n") .. "\n")
end

function Settings.get(key) return Settings.values[key] end

--- Sets one value and saves.
function Settings.set(key, value)
    Settings.values[key] = value
    if key == "glow" then Glow.enabled = value ~= false end
    Settings.save()
end

--- Saved window size (or the given defaults) for the initial setupScreen.
function Settings.windowSize(defaultW, defaultH)
    local v = Settings.values
    if v.width and v.height then return v.width, v.height end
    return defaultW, defaultH
end

--- Applies audio volumes (call once the audio manager exists).
function Settings.applyAudio(audio)
    if not audio then return end
    if Settings.values.musicVolume then audio:setMusicVolume(Settings.values.musicVolume) end
    if Settings.values.sfxVolume then audio:setSFXVolume(Settings.values.sfxVolume) end
end

--- Switches to fullscreen if that was saved (call after the window is set up).
function Settings.applyDisplay(screen)
    if Settings.values.fullscreen and screen and love.window and not love.window.getFullscreen() then
        screen:switchFullscreen()
    end
end

--- Reads the live glow / audio / window state into the settings and saves.
function Settings.capture(audio)
    local v = Settings.values
    v.glow = Glow.enabled
    if audio then
        v.musicVolume = audio:getMusicVolume()
        v.sfxVolume = audio:getSFXVolume()
    end
    if love.window and love.window.getMode then
        local w, h, flags = love.window.getMode()
        v.fullscreen = flags.fullscreen and true or false
        if not flags.fullscreen then v.width, v.height = w, h end
    end
    return Settings.save()
end

return Settings
