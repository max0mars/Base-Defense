-- Neon.lua - Shared neon-tube drawing for menus, HUD and cards.
--
-- A neon "tube" is a saturated coloured line with a thinner, near-white core
-- line on top; the frame-wide glow pass (Graphics/Glow.lua) adds the halo.
-- Panels are a near-black fill with a faint tint of their tube colour, so only
-- their outlines glow.

local Glow = require("Graphics.Glow")

local Neon = {}

Neon.BG = { 0.015, 0.02, 0.035 } -- panel base
Neon.CYAN = { 0.0, 0.85, 1.0 }
Neon.MAGENTA = { 1.0, 0.25, 0.85 }
Neon.GREEN = { 0.2, 1.0, 0.45 }
Neon.AMBER = { 1.0, 0.7, 0.15 }
Neon.RED = { 1.0, 0.3, 0.35 }
Neon.DIM = { 0.32, 0.34, 0.4 } -- disabled: stays under the glow threshold

--- The colour pushed toward white by k (0..1): the hot core of a tube.
function Neon.hot(c, k)
    k = k or 0.6
    return { c[1] + (1 - c[1]) * k, c[2] + (1 - c[2]) * k, c[3] + (1 - c[3]) * k }
end

-- Draws `shape(mode)` as a tube: coloured line, then the hot core over it.
-- Greys get little or no white core, so they read as grey rather than lit up.
local function tube(shape, color, width, alpha)
    width, alpha = width or 2, alpha or 1
    love.graphics.setLineWidth(width)
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    shape()
    local hi = math.max(color[1], color[2], color[3])
    local lo = math.min(color[1], color[2], color[3])
    local saturation = hi > 0 and (hi - lo) / hi or 0
    local core = Neon.hot(color, 0.65 * saturation)
    love.graphics.setLineWidth(math.max(1, width * 0.4))
    love.graphics.setColor(core[1], core[2], core[3], alpha * 0.9)
    shape()
end

--- Neon rectangle.
-- opts: radius (6), width (2), alpha (1), bg (base fill alpha, nil = none),
--       tint (fill alpha of the tube colour, nil = none)
function Neon.rect(x, y, w, h, color, opts)
    opts = opts or {}
    local radius = opts.radius or 6
    love.graphics.push("all")
    if opts.bg then
        love.graphics.setColor(Neon.BG[1], Neon.BG[2], Neon.BG[3], opts.bg)
        love.graphics.rectangle("fill", x, y, w, h, radius, radius)
    end
    if opts.tint then
        love.graphics.setColor(color[1], color[2], color[3], opts.tint)
        love.graphics.rectangle("fill", x, y, w, h, radius, radius)
    end
    tube(function() love.graphics.rectangle("line", x, y, w, h, radius, radius) end, color, opts.width, opts.alpha)
    love.graphics.pop()
end

--- Dark panel with a neon frame.
function Neon.panel(x, y, w, h, color, opts)
    opts = opts or {}
    Neon.rect(x, y, w, h, color, { radius = opts.radius or 10, width = opts.width or 2, alpha = opts.alpha,
        bg = opts.bg or 0.94, tint = opts.tint or 0.05 })
end

function Neon.line(x1, y1, x2, y2, color, width, alpha)
    love.graphics.push("all")
    tube(function() love.graphics.line(x1, y1, x2, y2) end, color, width, alpha)
    love.graphics.pop()
end

function Neon.circle(x, y, r, color, width, alpha)
    love.graphics.push("all")
    tube(function() love.graphics.circle("line", x, y, r) end, color, width, alpha)
    love.graphics.pop()
end

function Neon.polygon(points, color, width, alpha)
    love.graphics.push("all")
    tube(function() love.graphics.polygon("line", points) end, color, width, alpha)
    love.graphics.pop()
end

--- Button with a centred label. btn: x, y, w, h, label, and borderColor (or color).
-- state: hovered, disabled, active (selected), font
function Neon.button(btn, state)
    state = state or {}
    local color = btn.borderColor or btn.color or Neon.CYAN
    if state.disabled then
        Neon.rect(btn.x, btn.y, btn.w, btn.h, Neon.DIM, { bg = 0.9, width = 1, alpha = 0.8 })
    elseif state.hovered or state.active then
        Neon.rect(btn.x, btn.y, btn.w, btn.h, color, { bg = 0.9, tint = 0.22, width = 2.5 })
    else
        Neon.rect(btn.x, btn.y, btn.w, btn.h, color, { bg = 0.9, tint = 0.08, width = 1.5, alpha = 0.85 })
    end
    if btn.label then
        love.graphics.push("all")
        if state.font then love.graphics.setFont(state.font) end
        local font = love.graphics.getFont()
        if state.disabled then
            love.graphics.setColor(0.45, 0.47, 0.52, 1)
        elseif state.hovered or state.active then
            love.graphics.setColor(1, 1, 1, 1)
        else
            local c = Neon.hot(color, 0.75)
            love.graphics.setColor(c[1], c[2], c[3], 1)
        end
        love.graphics.printf(btn.label, btn.x, math.floor(btn.y + btn.h / 2 - font:getHeight() / 2), btn.w, "center")
        love.graphics.pop()
    end
end

--- Glowing title text (it opts in to the glow that other text is kept out of).
function Neon.title(text, x, y, w, align, color, scale)
    scale = scale or 1
    love.graphics.push("all")
    love.graphics.translate(x, y)
    love.graphics.scale(scale, scale)
    Glow.emissive(function()
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.printf(text, 0, 0, w / scale, align or "center")
    end)
    love.graphics.pop()
end

return Neon
