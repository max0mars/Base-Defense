local M = { scenes = {}, current = nil }

-- Scenes are laid out on a 1280x720 canvas unless they set `virtualHeight`
M.DEFAULT_VIRTUAL_HEIGHT = 720

--- Resizes the virtual canvas to the scene's height (the window is left alone;
--- scalify just letterboxes the new size).
local function applyVirtualHeight(scene)
    local h = scene.virtualHeight or M.DEFAULT_VIRTUAL_HEIGHT
    if VIRTUAL_HEIGHT == h then return end
    VIRTUAL_HEIGHT = h
    if scalify and scalify._WHEIGHT then
        scalify._WHEIGHT = h
        scalify:initValues()
        -- A render canvas is made at the old size: rebuild it so nothing is clipped
        if scalify._canvas then scalify:setupCanvas({ "default" }) end
    end
end

function M.switch(name, ...)
    assert(M.scenes[name])
    M.current = M.scenes[name]
    applyVirtualHeight(M.current)
    if M.current.load then M.current:load(...) end
end

function M:load()
    applyVirtualHeight(M.current)
    if M.current.load then
        M.current:load()
    end
end

function M:update(dt)
    if M.current.update then
        M.current:update(dt)
    end
end

function M:draw()
    if M.current.draw then
        M.current:draw()
    end
end

function M:mousepressed(x, y, button)
    if M.current.mousepressed then
        M.current:mousepressed(x, y, button)
    end
end

function M:mousereleased(x, y, button)
    if M.current.mousereleased then
        M.current:mousereleased(x, y, button)
    end
end
 
function M:keypressed(key)
    if M.current.keypressed then
        M.current:keypressed(key)
    end
end

return M
