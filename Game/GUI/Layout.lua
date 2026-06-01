-- Layout.lua: single source of truth for the 16:9 screen layout.
--
-- The virtual canvas is 1280x720. The battlefield keeps its original world
-- coordinate system (grid anchored at world x=0, y=100, sized 800x400) but is
-- drawn into a viewport that is SCALED UP to fill the space, so the play area
-- reads large without changing any game logic.
--
--   +--------------------------------------------------+
--   |                THIN TOP BAR (controls)           |
--   +--------+-----------------------------------------+
--   | LEFT   |                                         |
--   | COLUMN |             BATTLEFIELD                 |
--   | stats  |          (fills remaining space)        |
--   | horde  |                                         |
--   | prev   |                                         |
--   +--------+-----------------------------------------+
--   |                  BOTTOM TRAY                     |
--   +--------------------------------------------------+
--
-- World rendering is wrapped in pushWorld()/popWorld() which translates AND
-- scales the world onto the field. Code comparing the mouse to WORLD
-- coordinates (placement, turret aiming, enemy hover) must convert via
-- mouseToField(); HUD code keeps using raw (full-canvas) mouse coordinates.

local Layout = {}

-- Canvas (virtual) size.
Layout.W = 1280
Layout.H = 720

-- The battlefield's existing world coordinate bounds (unchanged game logic).
Layout.WORLD_X = 0
Layout.WORLD_Y = 100
Layout.FIELD_W = 800
Layout.FIELD_H = 400

-- HUD region sizes. A single full-height left command column holds ALL the HUD
-- (stats + controls + horde + preview); there is no top bar. The battlefield
-- fills the rest, with a stored-towers tray under it.
local TOPBAR_H     = 0
local TRAY_H       = 150
local LEFTCOL_W    = 300
local RIGHT_MARGIN = 0   -- battlefield runs flush to the right screen edge

-- Battlefield fills the space right of the left column; scaled to fit.
local AVAIL_W = Layout.W - LEFTCOL_W - RIGHT_MARGIN
local AVAIL_H = Layout.H - TOPBAR_H - TRAY_H
Layout.scale  = math.min(AVAIL_W / Layout.FIELD_W, AVAIL_H / Layout.FIELD_H)

local SCALED_W = Layout.FIELD_W * Layout.scale
local SCALED_H = Layout.FIELD_H * Layout.scale
local FIELD_X  = LEFTCOL_W + math.floor((AVAIL_W - SCALED_W) / 2)
-- Pin the field's bottom flush to the tray top (no gap above the stored towers);
-- the leftover vertical space sits in the top strip where the controls live.
local FIELD_Y  = (Layout.H - TRAY_H) - SCALED_H

-- Regions (screen/virtual coords). field.w/h are the SCALED on-screen sizes.
-- The left column spans the full height of the left strip; the stored-towers
-- tray sits only under the battlefield (to the right of the left column).
Layout.topBar     = { x = 0,         y = 0,                 w = Layout.W,             h = TOPBAR_H }
Layout.leftColumn = { x = 0,         y = TOPBAR_H,          w = LEFTCOL_W,            h = Layout.H - TOPBAR_H }
Layout.tray       = { x = LEFTCOL_W, y = Layout.H - TRAY_H, w = Layout.W - LEFTCOL_W, h = TRAY_H }
Layout.field      = { x = FIELD_X,   y = FIELD_Y,           w = SCALED_W,             h = SCALED_H }

-- The tray's right slice is reserved for the roll/purchase buttons; stored-tower
-- cards lay out in the area to the left of it.
Layout.trayActionsW = 200
Layout.trayCards = { x = Layout.tray.x, y = Layout.tray.y, w = Layout.tray.w - Layout.trayActionsW, h = Layout.tray.h }

local S = Layout.scale

--- Convert a (full-canvas) mouse position to world/field coordinates.
function Layout.mouseToField(mx, my)
    if not mx then mx, my = love.mouse.getPosition() end
    local wx = (mx - FIELD_X) / S
    local wy = (my - FIELD_Y) / S + Layout.WORLD_Y
    return wx, wy
end

--- Convert a world point to its on-screen (full-canvas) position.
function Layout.worldToScreen(wx, wy)
    return FIELD_X + wx * S, FIELD_Y + (wy - Layout.WORLD_Y) * S
end

--- True if a full-canvas mouse position sits over the battlefield viewport.
function Layout.inFieldScreen(mx, my)
    if not mx then mx, my = love.mouse.getPosition() end
    return mx >= Layout.field.x and mx < Layout.field.x + Layout.field.w
       and my >= Layout.field.y and my < Layout.field.y + Layout.field.h
end

--- True if a full-canvas point lies in the given region rect.
function Layout.inRegion(region, x, y)
    return x >= region.x and x < region.x + region.w
       and y >= region.y and y < region.y + region.h
end

-- True while world-space rendering is active (between pushWorld/popWorld). Used
-- by SetGameScissor so world-coordinate scissors (e.g. enemy HP fills) convert
-- correctly through the scaled, offset field viewport.
Layout.worldActive = false

--- Begin drawing in world space (call popWorld() when done). Translates and
--- scales so world (0,100) maps to the field's top-left and the play area is
--- rendered Layout.scale times larger.
function Layout.pushWorld()
    love.graphics.push()
    love.graphics.translate(FIELD_X, FIELD_Y - S * Layout.WORLD_Y)
    love.graphics.scale(S, S)
    Layout.worldActive = true
end

function Layout.popWorld()
    love.graphics.pop()
    Layout.worldActive = false
end

return Layout
