-- Glow.lua - Neon bloom post-process for the whole frame.
--
-- love.draw wraps the frame in Glow.begin() / Glow.finish(): everything drawn in
-- between goes to an offscreen canvas, its bright pixels are blurred at two
-- sizes (a tight halo and a wide soft one) and added back on top, so shapes,
-- projectiles, enemies and UI outlines glow like neon tubes without each draw
-- faking it.
--
-- Brightness is the strongest colour channel, not luminance, so saturated blues
-- and reds glow as much as white. Dim fills (panels, grids, empty HP) stay under
-- the threshold and don't glow.
--
-- Text stays crisp: print/printf also write into a mask that keeps text out of
-- the glow. Draw inside Glow.emissive(fn) to let text glow (titles).

local Glow = {
    enabled = true,
    THRESHOLD = 0.55, -- brightness where glow starts
    KNEE = 0.45, -- glow fades in over this much brightness above the threshold
    TIGHT_INTENSITY = 0.55, -- close halo hugging each shape
    WIDE_INTENSITY = 1.0, -- soft wide bloom
    WIDE_PASSES = 2, -- extra blur passes on the wide halo
}

local BRIGHT_SHADER = [[
    uniform float threshold;
    uniform float knee;
    uniform Image textMask;
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
        vec4 c = Texel(tex, uv);
        float b = max(c.r, max(c.g, c.b));
        float text = Texel(textMask, uv).a;
        return vec4(c.rgb * smoothstep(threshold, threshold + knee, b) * (1.0 - text), 1.0);
    }
]]

-- 9-tap gaussian folded into 5 samples using linear filtering
local BLUR_SHADER = [[
    uniform vec2 direction;
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
        vec2 o1 = direction * 1.3846153846;
        vec2 o2 = direction * 3.2307692308;
        vec3 sum = Texel(tex, uv).rgb * 0.2270270270;
        sum += (Texel(tex, uv + o1).rgb + Texel(tex, uv - o1).rgb) * 0.3162162162;
        sum += (Texel(tex, uv + o2).rgb + Texel(tex, uv - o2).rgb) * 0.0702702703;
        return vec4(sum, 1.0) * color;
    }
]]

-- Adds a halo back at any strength (colours above 1 may be clamped)
local SCALE_SHADER = [[
    uniform float intensity;
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
        return vec4(Texel(tex, uv).rgb * intensity, 1.0);
    }
]]

local state -- canvases and shaders, built on first use
local active -- the canvas drawing was redirected from, while capturing
local emissiveDepth = 0 -- > 0 inside Glow.emissive: text glows

local function supported()
    local g = love and love.graphics
    return g and g.newShader and g.newCanvas and g.getDimensions and g.getCanvas
end

local function newCanvas(w, h, format)
    local ok, canvas = pcall(love.graphics.newCanvas, math.max(1, math.floor(w)), math.max(1, math.floor(h)),
        format and { format = format } or nil)
    if ok then return canvas end
    return love.graphics.newCanvas(math.max(1, math.floor(w)), math.max(1, math.floor(h)))
end

--- Builds (or rebuilds after a resize) the canvases and shaders. False if unavailable.
local function prepare()
    if not supported() then return false end
    local w, h = love.graphics.getDimensions()
    if state and state.w == w and state.h == h then return true end

    local ok, err = pcall(function()
        local formats = love.graphics.getCanvasFormats and love.graphics.getCanvasFormats() or {}
        local hdr = formats.rgba16f and "rgba16f" or nil
        local s = state or {
            bright = love.graphics.newShader(BRIGHT_SHADER),
            blur = love.graphics.newShader(BLUR_SHADER),
            scale = love.graphics.newShader(SCALE_SHADER),
        }
        s.w, s.h = w, h
        s.scene = newCanvas(w, h)
        s.mask = newCanvas(w, h)
        s.halfA, s.halfB = newCanvas(w / 2, h / 2, hdr), newCanvas(w / 2, h / 2, hdr)
        s.wideA, s.wideB = newCanvas(w / 8, h / 8, hdr), newCanvas(w / 8, h / 8, hdr)
        state = s
    end)
    if not ok then
        print("Glow disabled: " .. tostring(err))
        Glow.enabled = false
        return false
    end
    return true
end

-- Draws `src` into `dst` (cleared to black) at dst's size, optionally through a shader.
local function pass(src, dst, shader)
    love.graphics.setCanvas(dst)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setShader(shader)
    love.graphics.draw(src, 0, 0, 0, dst:getWidth() / src:getWidth(), dst:getHeight() / src:getHeight())
end

-- Blurs a (canvas, spare) pair in place: horizontal into spare, vertical back.
local function blur(canvas, spare)
    local shader = state.blur
    shader:send("direction", { 1 / canvas:getPixelWidth(), 0 })
    pass(canvas, spare, shader)
    shader:send("direction", { 0, 1 / canvas:getPixelHeight() })
    pass(spare, canvas, shader)
end

-- -----------------------------------------------------------------------------
-- Text mask: text is drawn a second time into the mask, which the bright pass
-- subtracts, so UI text never blooms into a fuzzy blob.
-- -----------------------------------------------------------------------------

local function maskText(raw, ...)
    raw(...)
    if not active or emissiveDepth > 0 then return end
    local g = love.graphics
    if g.getCanvas() ~= state.scene then return end -- drawing into some other canvas
    local stencilMode = g.getStencilTest()
    if stencilMode and stencilMode ~= "always" then return end -- the mask has no stencil

    local sx, sy, sw, sh = g.getScissor()
    local r, gr, b, a = g.getColor()
    g.setCanvas(state.mask)
    if sx then g.setScissor(sx, sy, sw, sh) end
    g.setColor(1, 1, 1, a)
    raw(...)
    g.setColor(r, gr, b, a)
    g.setCanvas({ state.scene, stencil = true })
    if sx then g.setScissor(sx, sy, sw, sh) else g.setScissor() end
end

if love and love.graphics and love.graphics.print and not Glow.textWrapped then
    local rawPrint, rawPrintf = love.graphics.print, love.graphics.printf
    love.graphics.print = function(...) maskText(rawPrint, ...) end
    love.graphics.printf = function(...) maskText(rawPrintf, ...) end
    Glow.textWrapped = true
end

--- Runs fn with text glowing like everything else (e.g. a neon title).
function Glow.emissive(fn, ...)
    emissiveDepth = emissiveDepth + 1
    local ok, err = pcall(fn, ...)
    emissiveDepth = emissiveDepth - 1
    if not ok then error(err, 0) end
end

-- -----------------------------------------------------------------------------
-- Frame capture
-- -----------------------------------------------------------------------------

--- Starts capturing drawing. Pair with Glow.finish(). False when glow is off.
function Glow.begin()
    if active or not Glow.enabled or not prepare() then return false end
    active = { canvas = love.graphics.getCanvas() }
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.setScissor()
    love.graphics.setCanvas(state.mask)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setCanvas({ state.scene, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    if sx then love.graphics.setScissor(sx, sy, sw, sh) end
    return true
end

--- Stops capturing and draws what was captured plus its glow.
function Glow.finish()
    if not active then return end
    local previous = active.canvas
    active = nil

    -- Back on the original canvas before push("all"), which restores the canvas
    -- it saw on pop
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.setCanvas(previous)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha", "alphamultiply")

    -- Bright pass at half size, tight blur; then shrink further for the wide halo
    state.bright:send("threshold", Glow.THRESHOLD)
    state.bright:send("knee", Glow.KNEE)
    state.bright:send("textMask", state.mask)
    pass(state.scene, state.halfA, state.bright)
    blur(state.halfA, state.halfB)
    pass(state.halfA, state.wideA)
    for _ = 1, Glow.WIDE_PASSES do blur(state.wideA, state.wideB) end

    -- Composite: the frame as drawn, then both halos added on top
    love.graphics.setCanvas(previous)
    love.graphics.setShader()
    if sx then love.graphics.setScissor(sx, sy, sw, sh) end
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.draw(state.scene)
    love.graphics.setBlendMode("add", "alphamultiply")
    love.graphics.setShader(state.scale)
    for _, halo in ipairs({ { state.halfA, Glow.TIGHT_INTENSITY }, { state.wideA, Glow.WIDE_INTENSITY } }) do
        local canvas = halo[1]
        state.scale:send("intensity", halo[2])
        love.graphics.draw(canvas, 0, 0, 0, state.w / canvas:getWidth(), state.h / canvas:getHeight())
    end
    love.graphics.pop()
end

return Glow
