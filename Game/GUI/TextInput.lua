-- =============================================================================
-- TEXT INPUT (TextInput.lua)
-- A one-line text box. The scene forwards love.textinput and key presses to it
-- while it's focused; Enter calls onSubmit(text).
-- =============================================================================

local Neon = require("Game.GUI.Neon")

local TextInput = {}
TextInput.__index = TextInput

--- opts: x, y, w, h, text, maxLength, placeholder, onSubmit
function TextInput:new(opts)
    return setmetatable({
        x = opts.x, y = opts.y, w = opts.w, h = opts.h or 36,
        text = opts.text or "",
        maxLength = opts.maxLength or 16,
        placeholder = opts.placeholder or "",
        onSubmit = opts.onSubmit,
        focused = false,
        blink = 0,
    }, self)
end

function TextInput:focus()
    self.focused = true
    self.blink = 0
    love.keyboard.setTextInput(true)
    if love.keyboard.setKeyRepeat then love.keyboard.setKeyRepeat(true) end
end

function TextInput:unfocus()
    self.focused = false
    love.keyboard.setTextInput(false)
    if love.keyboard.setKeyRepeat then love.keyboard.setKeyRepeat(false) end
end

function TextInput:contains(x, y)
    return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

function TextInput:update(dt)
    self.blink = (self.blink + dt) % 1
end

-- Printable ASCII only, so the name fits the game's font and the leaderboard's rules
function TextInput:textinput(t)
    if not self.focused then return false end
    t = t:gsub("[^\32-\126]", "")
    self.text = (self.text .. t):sub(1, self.maxLength)
    self.blink = 0
    return true
end

--- Returns true if the key was used.
function TextInput:keypressed(key)
    if not self.focused then return false end
    if key == "backspace" then
        self.text = self.text:sub(1, -2)
        self.blink = 0
    elseif key == "return" or key == "kpenter" then
        if self.onSubmit then self.onSubmit(self.text) end
    elseif key == "escape" then
        self:unfocus()
    end
    return true
end

--- Clicking the box focuses it; clicking elsewhere unfocuses it. Returns true if it was clicked.
function TextInput:mousepressed(x, y, button)
    if button ~= 1 then return false end
    if self:contains(x, y) then
        self:focus()
        return true
    end
    if self.focused then self:unfocus() end
    return false
end

function TextInput:draw()
    Neon.rect(self.x, self.y, self.w, self.h, self.focused and Neon.CYAN or Neon.DIM,
        { bg = 0.9, tint = self.focused and 0.1 or 0, width = self.focused and 2 or 1.5 })
    local font = love.graphics.getFont()
    local ty = math.floor(self.y + self.h / 2 - font:getHeight() / 2)
    if self.text == "" and not self.focused then
        love.graphics.setColor(0.5, 0.52, 0.58, 1)
        love.graphics.print(self.placeholder, self.x + 10, ty)
    else
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(self.text, self.x + 10, ty)
        if self.focused and self.blink < 0.5 then
            local cx = self.x + 11 + font:getWidth(self.text)
            love.graphics.rectangle("fill", cx, ty, 2, font:getHeight())
        end
    end
end

return TextInput
