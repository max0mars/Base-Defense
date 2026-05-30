-- SettingsPanel.lua: reusable centered settings panel (display mode + resolution
-- + audio), framed in a dark-glass panel. Used by the main menu (BACK button)
-- and the in-game pause menu (RESUME / EXIT). Display/audio interactions are
-- handled internally; bottom-button clicks are returned to the caller as an
-- action string so each scene can route them (e.g. "back", "resume", "exit").

local AudioSlidersUI = require("Game.GUI.AudioSlidersUI")

local SettingsPanel = {}
SettingsPanel.__index = SettingsPanel

-- Actions handled internally (not returned to the caller).
local INTERNAL = { fullscreen_mode = true, windowed = true, resolution = true }

-- opts.title       : panel title (default "SETTINGS")
-- opts.bottomButtons: array of { label, action, color, hoverColor, borderColor }
function SettingsPanel:new(opts)
    opts = opts or {}
    local obj = setmetatable({}, SettingsPanel)

    local pw, ph = 440, 512
    local p = { x = math.floor((VIRTUAL_WIDTH - pw) / 2), y = math.floor((VIRTUAL_HEIGHT - ph) / 2), w = pw, h = ph }
    obj.panel = p
    obj.title = opts.title or "SETTINGS"

    local mid = p.x + p.w / 2
    local bw, bx = 200, p.x + p.w / 2 - 100
    local setCol, setHov, setBord = {0.15, 0.15, 0.18, 1}, {0.28, 0.28, 0.32, 1}, {0.5, 0.5, 0.55, 1}

    obj.buttons = {}

    -- Window mode (Fullscreen above Windowed).
    table.insert(obj.buttons, { x = bx, y = p.y + 80, w = bw, h = 30, label = "FULLSCREEN",
        action = "fullscreen_mode", color = setCol, hoverColor = setHov, borderColor = setBord })
    table.insert(obj.buttons, { x = bx, y = p.y + 116, w = bw, h = 30, label = "WINDOWED",
        action = "windowed", color = setCol, hoverColor = setHov, borderColor = setBord })

    -- Stacked resolutions.
    local resOptions = {
        { width = 1280, height = 720, label = "1280 x 720" },
        { width = 1600, height = 900, label = "1600 x 900" },
        { width = 1920, height = 1080, label = "1920 x 1080" },
    }
    for i, res in ipairs(resOptions) do
        table.insert(obj.buttons, { x = bx, y = p.y + 174 + (i - 1) * 38, w = bw, h = 30,
            label = res.label, action = "resolution", data = res,
            color = setCol, hoverColor = setHov, borderColor = setBord })
    end

    -- Bottom action buttons (1 centered, or 2 side by side).
    local bottom = opts.bottomButtons or {}
    local by, bh = p.y + 444, 38
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

    obj.sliders = AudioSlidersUI:new({ x = mid - 120, y = p.y + 344, w = 240 })
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
    end

    local bgCol, borderCol = btn.color, btn.borderColor
    if isTooBig then
        bgCol, borderCol = {0.4, 0.15, 0.15, 1}, {0.8, 0.3, 0.3, 1}
    elseif isActive then
        bgCol, borderCol = {0.1, 0.35, 0.2, 1}, {0.3, 1.0, 0.55, 1}
    elseif isHovered then
        bgCol = btn.hoverColor
    end

    love.graphics.setColor(bgCol)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 6, 6)
    love.graphics.setColor(borderCol)
    love.graphics.setLineWidth((isHovered or isActive) and 2 or 1)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 6, 6)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1)
    local label = btn.label
    if isTooBig then label = label .. " (!)" end
    if btn.type == "main" then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.printf(label, btn.x + 1, btn.y + btn.h / 2 - 6, btn.w, "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(label, btn.x, btn.y + btn.h / 2 - 7, btn.w, "center")
    else
        love.graphics.printf(label, btn.x, btn.y + btn.h / 2 - 6, btn.w, "center")
    end
end

function SettingsPanel:divider(y)
    local p = self.panel
    love.graphics.setColor(0.3, 0.4, 0.5, 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.line(p.x + 26, y, p.x + p.w - 26, y)
end

function SettingsPanel:draw()
    local p = self.panel
    local mx, my = love.mouse.getPosition()

    -- Panel body + border.
    love.graphics.setColor(0.04, 0.06, 0.09, 0.96)
    love.graphics.rectangle("fill", p.x, p.y, p.w, p.h, 10, 10)
    love.graphics.setColor(0.2, 0.55, 0.8, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", p.x, p.y, p.w, p.h, 10, 10)
    love.graphics.setLineWidth(1)

    -- Title.
    love.graphics.push()
    love.graphics.translate(p.x + p.w / 2, p.y + 20)
    love.graphics.scale(1.6, 1.6)
    love.graphics.setColor(0.3, 0.7, 1, 1)
    love.graphics.printf(self.title, -140, 0, 280, "center")
    love.graphics.pop()

    self:divider(p.y + 50)
    love.graphics.setColor(0.5, 0.6, 0.7, 0.9)
    love.graphics.printf("DISPLAY", p.x, p.y + 60, p.w, "center")
    love.graphics.setColor(0.45, 0.5, 0.58, 0.8)
    love.graphics.printf("Resolution", p.x, p.y + 154, p.w, "center")

    self:divider(p.y + 300)
    love.graphics.setColor(0.5, 0.6, 0.7, 0.9)
    love.graphics.printf("AUDIO", p.x, p.y + 312, p.w, "center")

    self:divider(p.y + 428)

    for _, btn in ipairs(self.buttons) do drawButton(btn, mx, my) end
    if self.sliders then self.sliders:draw() end
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
                scalify:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, btn.data.width, btn.data.height, {resizable = true, highdpi = true})
            else
                return btn.action -- bottom button: let the caller handle it
            end
            return nil
        end
    end
    return nil
end

function SettingsPanel:mousereleased(x, y, button)
    if self.sliders then self.sliders:mousereleased(x, y, button) end
end

return SettingsPanel
