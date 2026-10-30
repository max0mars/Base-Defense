-- SettingsPanel.lua: reusable centered settings panel (display mode + resolution
-- + neon glow + audio), framed in a neon panel. Every change is saved to disk. Used by the main menu (BACK button)
-- and the in-game pause menu (RESUME / EXIT). Display/audio interactions are
-- handled internally; bottom-button clicks are returned to the caller as an
-- action string so each scene can route them (e.g. "back", "resume", "exit").

local AudioSlidersUI = require("Game.GUI.AudioSlidersUI")
local Cursor = require("Game.GUI.Cursor")
local Neon = require("Game.GUI.Neon")
local Glow = require("Graphics.Glow")
local Settings = require("Game.Core.Settings")

local SettingsPanel = {}
SettingsPanel.__index = SettingsPanel

-- Actions handled internally (not returned to the caller).
local INTERNAL = { fullscreen_mode = true, windowed = true, resolution = true, glow = true }

-- opts.title       : panel title (default "SETTINGS")
-- opts.bottomButtons: array of { label, action, color, hoverColor, borderColor }
function SettingsPanel:new(opts)
    opts = opts or {}
    local obj = setmetatable({}, SettingsPanel)

    local pw, ph = 440, 552
    local p = { x = math.floor((VIRTUAL_WIDTH - pw) / 2), y = math.floor((VIRTUAL_HEIGHT - ph) / 2), w = pw, h = ph }
    obj.panel = p
    obj.title = opts.title or "SETTINGS"

    local mid = p.x + p.w / 2
    local bw, bx = 200, p.x + p.w / 2 - 100
    local setCol, setHov, setBord = {0.15, 0.15, 0.18, 1}, {0.28, 0.28, 0.32, 1}, {0.5, 0.5, 0.55, 1}

    obj.buttons = {}

    local colW = 190
    local col1X = p.x + 24
    local col2X = p.x + 226

    -- Window mode (Fullscreen and Windowed side-by-side).
    table.insert(obj.buttons, { x = col1X, y = p.y + 76, w = colW, h = 28, label = "FULLSCREEN",
        action = "fullscreen_mode", color = setCol, hoverColor = setHov, borderColor = setBord })
    table.insert(obj.buttons, { x = col2X, y = p.y + 76, w = colW, h = 28, label = "WINDOWED",
        action = "windowed", color = setCol, hoverColor = setHov, borderColor = setBord })

    -- Resolution options (2 columns).
    local resOptions = {
        { width = 1280, height = 720,  label = "1280 x 720" },
        { width = 1366, height = 768,  label = "1366 x 768" },
        { width = 1600, height = 900,  label = "1600 x 900" },
        { width = 1920, height = 1080, label = "1920 x 1080" },
        { width = 2560, height = 1440, label = "2560 x 1440" },
        { width = 2880, height = 1620, label = "2880 x 1620" },
        { width = 3200, height = 1800, label = "3200 x 1800" },
        { width = 3840, height = 2160, label = "3840 x 2160" },
    }
    for i, res in ipairs(resOptions) do
        local col = ((i - 1) % 2 == 0) and col1X or col2X
        local row = math.floor((i - 1) / 2)
        table.insert(obj.buttons, { x = col, y = p.y + 142 + row * 30, w = colW, h = 26,
            label = res.label, action = "resolution", data = res,
            color = setCol, hoverColor = setHov, borderColor = setBord })
    end

    -- Neon glow on / off (full width under the resolutions).
    table.insert(obj.buttons, { x = col1X, y = p.y + 272, w = col2X + colW - col1X, h = 28, label = "NEON GLOW",
        action = "glow", color = setCol, hoverColor = setHov, borderColor = Neon.MAGENTA })

    -- Bottom action buttons (1 centered, or 2 side by side).
    local bottom = opts.bottomButtons or {}
    local by, bh = p.y + 484, 38
    if #bottom == 1 then
        local b = bottom[1]
        table.insert(obj.buttons, { x = bx, y = by, w = bw, h = bh, label = b.label, action = b.action, type = "main",
            color = b.color, hoverColor = b.hoverColor, borderColor = b.borderColor })
    elseif #bottom >= 2 then
        local pad, gap = 26, 16
        local w2 = math.floor((p.w - pad * 2 - gap) / 2)
        for i = 1, 2 do
            local b = bottom[i]
            table.insert(obj.buttons, { x = p.x + pad + (i - 1) * (w2 + gap), y = by, w = w2, h = bh,
                label = b.label, action = b.action, type = "main",
                color = b.color, hoverColor = b.hoverColor, borderColor = b.borderColor })
        end
    end

    obj.sliders = AudioSlidersUI:new({ x = mid - 120, y = p.y + 362, w = 240 })
    return obj
end

function SettingsPanel:update(dt)
    if self.sliders then self.sliders:update(dt) end
end

local function drawButton(btn, mx, my)
    local isHovered = mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h
    local isTooBig, isActive = false, false
    local cw, ch, flags = love.window.getMode()
    if btn.action == "resolution" then
        local dw, dh = love.window.getDesktopDimensions()
        isTooBig = btn.data.width > dw or btn.data.height > dh
        isActive = (not flags.fullscreen) and cw == btn.data.width and ch == btn.data.height
    elseif btn.action == "windowed" then
        isActive = not flags.fullscreen
    elseif btn.action == "fullscreen_mode" then
        isActive = flags.fullscreen
    elseif btn.action == "glow" then
        isActive = Glow.enabled
    end

    -- Unset options keep a dim blue frame; the active one lights up green
    local border = btn.borderColor
    if isTooBig then
        border = Neon.RED
    elseif isActive and btn.action ~= "glow" then
        border = Neon.GREEN
    elseif btn.type ~= "main" and btn.action ~= "glow" then
        border = { 0.3, 0.55, 0.85 }
    end
    local label = btn.label
    if isTooBig then label = label .. " (!)" end
    if btn.action == "glow" then label = label .. (Glow.enabled and ": ON" or ": OFF") end
    Neon.button({ x = btn.x, y = btn.y, w = btn.w, h = btn.h, label = label, borderColor = border },
        { hovered = isHovered, active = isActive })
end

function SettingsPanel:divider(y)
    local p = self.panel
    love.graphics.setColor(0.0, 0.6, 0.85, 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.line(p.x + 26, y, p.x + p.w - 26, y)
end

function SettingsPanel:draw()
    local p = self.panel
    local mx, my = love.mouse.getPosition()

    -- Panel body + border.
    Neon.panel(p.x, p.y, p.w, p.h, Neon.CYAN)

    -- Title.
    Neon.title(self.title, p.x + p.w / 2 - 224, p.y + 20, 448, "center", Neon.hot(Neon.CYAN, 0.3), 1.6)

    self:divider(p.y + 50)
    love.graphics.setColor(0.5, 0.6, 0.7, 0.9)
    love.graphics.printf("DISPLAY", p.x, p.y + 58, p.w, "center")
    self:divider(p.y + 114)
    love.graphics.setColor(0.45, 0.5, 0.58, 0.8)
    love.graphics.printf("Resolution", p.x, p.y + 122, p.w, "center")

    self:divider(p.y + 316)
    love.graphics.setColor(0.5, 0.6, 0.7, 0.9)
    love.graphics.printf("AUDIO", p.x, p.y + 328, p.w, "center")

    self:divider(p.y + 462)

    for _, btn in ipairs(self.buttons) do
        drawButton(btn, mx, my)
        Cursor.hover(btn.x, btn.y, btn.w, btn.h)
    end
    if self.sliders then
        self.sliders:draw()
        Cursor.hover(self.sliders.x, self.sliders.y - 4, self.sliders.w, 24)
        Cursor.hover(self.sliders.x, self.sliders.y + 46, self.sliders.w, 24)
    end
end

-- Returns the clicked bottom-button action string (for the caller to route), or
-- nil. Display/audio clicks are handled here and also return nil.
function SettingsPanel:mousepressed(x, y, button)
    if self.sliders and self.sliders:mousepressed(x, y, button) then return nil end
    if button ~= 1 then return nil end

    for _, btn in ipairs(self.buttons) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            if btn.action == "fullscreen_mode" then
                if not love.window.getFullscreen() then scalify:switchFullscreen() end
            elseif btn.action == "windowed" then
                if love.window.getFullscreen() then scalify:switchFullscreen() end
            elseif btn.action == "resolution" then
                -- Same settings as at startup (main.lua): scalify defaults to a fixed-size
                -- render canvas, which would clip scenes taller than the current one
                scalify:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, btn.data.width, btn.data.height, {resizable = true, highdpi = true, canvas = false})
            elseif btn.action == "glow" then
                Glow.enabled = not Glow.enabled
            else
                return btn.action -- bottom button: let the caller handle it
            end
            Settings.capture(AUDIO)
            return nil
        end
    end
    return nil
end

function SettingsPanel:mousereleased(x, y, button)
    if not self.sliders then return end
    local wasDragging = self.sliders.dragging
    self.sliders:mousereleased(x, y, button)
    if wasDragging then Settings.capture(AUDIO) end -- a volume drag just ended
end

return SettingsPanel
