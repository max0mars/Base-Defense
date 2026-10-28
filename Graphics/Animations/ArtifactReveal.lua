-- Graphics/Animations/ArtifactReveal.lua
-- Reveal for an artifact won in battle, shown before the battle summary. Like
-- drawing a card but bigger: the card slides up face down from below the
-- screen, zooms in and shakes harder and harder as it reaches the middle, then
-- slams down face up with a flash, a burst of sparks and a screen shake.

local CardReveal = require("Graphics.Animations.CardReveal")
local ArtifactViewerUI = require("Game.GUI.ArtifactViewerUI")

local ArtifactReveal = {}
ArtifactReveal.__index = ArtifactReveal

local CARD_W, CARD_H = 240, 336

-- Phase lengths (seconds)
local RISE = 0.9     -- slide up from below the screen
local CHARGE = 0.7   -- hang at the top, zooming and shaking harder
local SLAM = 0.24    -- flip: lift up edge-on, then come down face up
local SETTLE = 0.35  -- the face bounces back to full size after the impact
local CONTINUE_DELAY = 0.5 -- after landing, before a click moves on

-- Build-up: zoom and shake ramp in over the end of the rise and the charge
local BUILD_START = RISE * 0.5
local MAX_ZOOM = 0.3
local MAX_SHAKE = 12       -- pixels
local MAX_WOBBLE = 0.08    -- radians
local SLAM_LIFT = 0.15     -- extra zoom at the top of the flip
local LAND_SQUASH = 0.12   -- the face lands this much smaller, then bounces back
local SCREEN_SHAKE_TIME = 0.4
local SCREEN_SHAKE = 10
local SPARKS = 40

local LANDED = RISE + CHARGE + SLAM

local function easeOutCubic(p) return 1 - (1 - p) ^ 3 end
local function clamp01(p) return math.max(0, math.min(1, p)) end

--- `def` is the artifact definition; the card rises to the screen centre.
function ArtifactReveal.new(def)
    local obj = setmetatable({}, ArtifactReveal)
    obj.def = def
    obj.t = 0
    obj.sparks = {}
    obj.impacted = false
    obj.done = false
    return obj
end

function ArtifactReveal:update(dt)
    self.t = self.t + dt
    if not self.impacted and self.t >= RISE + CHARGE + SLAM / 2 then
        self.impacted = true
        self:impact()
    end
    for i = #self.sparks, 1, -1 do
        local s = self.sparks[i]
        s.life = s.life - dt
        s.x, s.y = s.x + s.vx * dt, s.y + s.vy * dt
        s.vx, s.vy = s.vx * (1 - 3 * dt), s.vy * (1 - 3 * dt)
        if s.life <= 0 then table.remove(self.sparks, i) end
    end
end

-- The card lands face up: sound, sparks and screen shake
function ArtifactReveal:impact()
    if AUDIO then
        AUDIO:playSFX("explosion_01") -- the slam
        AUDIO:playSFX("rare")
    end
    local color = self.def.color or { 1, 1, 1, 1 }
    for _ = 1, SPARKS do
        local angle = math.random() * math.pi * 2
        local speed = 250 + math.random() * 450
        table.insert(self.sparks, {
            x = 0, y = 0,
            vx = math.cos(angle) * speed, vy = math.sin(angle) * speed,
            life = 0.4 + math.random() * 0.5, color = color,
        })
    end
end

function ArtifactReveal:isLanded()
    return self.t >= LANDED
end

--- A click moves on once the card has landed and sat for a moment.
function ArtifactReveal:click()
    if self.t >= LANDED + CONTINUE_DELAY then self.done = true end
end

--- Screen shake offset after the impact, for everything drawn under the reveal.
function ArtifactReveal:screenShake()
    local since = self.t - (RISE + CHARGE + SLAM / 2)
    if since < 0 or since > SCREEN_SHAKE_TIME then return 0, 0 end
    local strength = SCREEN_SHAKE * (1 - since / SCREEN_SHAKE_TIME)
    return (math.random() * 2 - 1) * strength, (math.random() * 2 - 1) * strength
end

-- Card position, zoom, shake, flip and wobble for the current moment
function ArtifactReveal:pose()
    local t = self.t
    local cx, cy = VIRTUAL_WIDTH / 2, VIRTUAL_HEIGHT / 2
    local startY = VIRTUAL_HEIGHT + CARD_H / 2 + 10
    local y = startY + (cy - startY) * easeOutCubic(clamp01(t / RISE))

    local build = clamp01((t - BUILD_START) / (RISE + CHARGE - BUILD_START))
    local scale = 1 + MAX_ZOOM * build
    local shake = MAX_SHAKE * build * build
    local wobble = MAX_WOBBLE * build * build
    local flipX, faceUp = 1, false

    local slam = (t - RISE - CHARGE) / SLAM
    if slam >= 0 then
        slam = clamp01(slam)
        if slam < 0.5 then
            -- Lift up and turn edge-on, still shaking
            flipX = 1 - slam * 2
            scale = 1 + MAX_ZOOM + SLAM_LIFT * slam * 2
        else
            -- Come down hard, face up: zoom snaps from lifted to below full size
            faceUp = true
            flipX = slam * 2 - 1
            local down = (slam - 0.5) * 2
            scale = (1 + MAX_ZOOM + SLAM_LIFT) + ((1 - LAND_SQUASH) - (1 + MAX_ZOOM + SLAM_LIFT)) * down * down
            shake, wobble = 0, 0
        end
    end
    if t >= LANDED then
        -- Bounce back up to full size
        local settle = clamp01((t - LANDED) / SETTLE)
        scale = (1 - LAND_SQUASH) + LAND_SQUASH * easeOutCubic(settle)
        faceUp, flipX, shake, wobble = true, 1, 0, 0
    end

    local jx = (math.random() * 2 - 1) * shake
    local jy = (math.random() * 2 - 1) * shake
    local rot = (math.random() * 2 - 1) * wobble
    return cx + jx, y + jy, scale, flipX, rot, faceUp
end

local function fonts(self)
    if not self.titleFont then
        self.titleFont = love.graphics.newFont(22)
        self.smallFont = love.graphics.newFont(13)
    end
    return self.titleFont, self.smallFont
end

-- The artifact's face, centred on the origin
function ArtifactReveal:drawFace()
    local def = self.def
    local ring = def.color or { 1, 1, 1, 1 }
    local titleFont, smallFont = fonts(self)
    local w, h = CARD_W, CARD_H
    local oldFont = love.graphics.getFont()

    love.graphics.setColor(0.07, 0.07, 0.1, 1)
    love.graphics.rectangle("fill", -w / 2, -h / 2, w, h, 12)
    love.graphics.setColor(ring)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", -w / 2, -h / 2, w, h, 12)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.7, 0.7, 0.8, 1)
    love.graphics.printf("NEW ARTIFACT", -w / 2, -h / 2 + 16, w, "center")

    ArtifactViewerUI.drawIcon(def, 0, -h / 2 + 105, 50)

    -- A long name wraps onto a second line; the description starts below it
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 1, 1, 1)
    local titleY = -h / 2 + 170
    love.graphics.printf(def.name or "", -w / 2 + 12, titleY, w - 24, "center")
    local _, titleLines = titleFont:getWrap(def.name or "", w - 24)
    local titleH = math.max(1, #titleLines) * titleFont:getHeight()
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.85, 0.85, 0.9, 1)
    love.graphics.printf(def.description or "", -w / 2 + 18, titleY + titleH + 12, w - 36, "center")
    love.graphics.setFont(oldFont)
end

function ArtifactReveal:draw()
    local x, y, scale, flipX, rot, faceUp = self:pose()
    local ring = self.def.color or { 1, 1, 1, 1 }

    -- Glow behind the card, building with the shake
    local build = clamp01((self.t - BUILD_START) / (RISE + CHARGE - BUILD_START))
    if build > 0 and not self:isLanded() then
        love.graphics.setColor(ring[1], ring[2], ring[3], 0.25 * build)
        love.graphics.circle("fill", x, y, CARD_H * 0.6 * scale)
    end

    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rot)
    love.graphics.scale(math.max(flipX, 0.01) * scale, scale)
    if faceUp then self:drawFace() else CardReveal.drawBack(CARD_W, CARD_H) end
    love.graphics.pop()

    -- Sparks from the impact
    local cx, cy = VIRTUAL_WIDTH / 2, VIRTUAL_HEIGHT / 2
    love.graphics.setLineWidth(2)
    for _, s in ipairs(self.sparks) do
        love.graphics.setColor(s.color[1], s.color[2], s.color[3], math.min(1, s.life * 2))
        love.graphics.line(cx + s.x, cy + s.y, cx + s.x - s.vx * 0.03, cy + s.y - s.vy * 0.03)
    end
    love.graphics.setLineWidth(1)

    -- Impact flash
    local since = self.t - (RISE + CHARGE + SLAM / 2)
    if since >= 0 and since < 0.25 then
        love.graphics.setColor(1, 1, 1, 0.7 * (1 - since / 0.25))
        love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    end

    if self.t >= LANDED + CONTINUE_DELAY then
        love.graphics.setColor(0.6, 0.65, 0.75, 1)
        love.graphics.printf("Click to continue", 0, cy + CARD_H / 2 + 30, VIRTUAL_WIDTH, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return ArtifactReveal
