local M = { scenes = {}, current = nil }


function M.switch(name)
    assert(M.scenes[name])
    M.current = M.scenes[name]
    if M.current.load then M.current:load() end
end

function M:load()
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
 
function M:keypressed(key)
    if M.current.keypressed then
        M.current:keypressed(key)
    end
end

return M