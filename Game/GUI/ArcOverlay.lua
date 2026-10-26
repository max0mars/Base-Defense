-- ArcOverlay.lua - Draws visible turret firing arcs coloured by how many overlap.
--
-- Each arc increments the stencil buffer, so every pixel holds the number of arcs
-- covering it. The field is then filled once per overlap level with that level's
-- colour, so 1..8+ overlapping arcs each read as a distinct colour instead of
-- translucent grey stacking into the same near-opaque shade.

local ArcOverlay = {}

-- Overlap level -> colour. The last entry is used for that many arcs or more.
ArcOverlay.LEVELS = {
    { 0.55, 0.60, 0.70, 0.28 }, -- 1: slate (close to the old single-arc grey)
    { 0.25, 0.50, 1.00, 0.32 }, -- 2: blue
    { 0.15, 0.85, 0.95, 0.34 }, -- 3: cyan
    { 0.30, 0.90, 0.35, 0.36 }, -- 4: green
    { 1.00, 0.92, 0.25, 0.44 }, -- 5: yellow
    { 1.00, 0.55, 0.15, 0.46 }, -- 6: orange
    { 0.95, 0.20, 0.25, 0.48 }, -- 7: red
    { 0.90, 0.30, 0.95, 0.52 }, -- 8+: magenta
}

--- True when a game object should have its arc drawn by the overlay.
function ArcOverlay.wants(obj)
    return obj.showArc and not obj.destroyed and obj.firingArc and obj.drawFiringArcShape ~= nil
        and not obj.ownArcDisplay
end

--- Draws the overlay for the given arcs, filling within the rectangle (x, y, w, h).
-- @param arcs table: objects with drawFiringArcShape()
function ArcOverlay.draw(arcs, x, y, w, h)
    if #arcs == 0 then return end
    love.graphics.push("all")

    love.graphics.stencil(function()
        for _, obj in ipairs(arcs) do
            obj:drawFiringArcShape()
        end
    end, "increment", 1)

    local maxLevel = #ArcOverlay.LEVELS
    for level, color in ipairs(ArcOverlay.LEVELS) do
        love.graphics.setStencilTest(level == maxLevel and "gequal" or "equal", level)
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", x, y, w, h)
    end

    love.graphics.setStencilTest()
    love.graphics.pop()
end

return ArcOverlay
