-- =============================================================================
-- HTTP (Http.lua)
-- Asynchronous HTTP requests from the main thread. The requests are made one
-- at a time, in order, by Game/Online/HttpThread.lua; call Http.update every
-- frame to get the callbacks.
-- =============================================================================

local Http = {}

local thread
local nextId = 0
local callbacks = {}

local function start()
    if thread then return true end
    if not (love.thread and love.thread.newThread) then return false end
    thread = love.thread.newThread("Game/Online/HttpThread.lua")
    thread:start()
    return true
end

--- Queues a request. `callback(status, body, err)` is called from Http.update:
--- status is the HTTP status code, or 0 with `err` set when there was no response.
function Http.request(method, url, body, callback)
    if not start() then
        if callback then callback(0, nil, "threads unavailable") end
        return
    end
    nextId = nextId + 1
    callbacks[nextId] = callback or false
    love.thread.getChannel("http_requests"):push({ id = nextId, method = method, url = url, body = body })
end

--- Delivers finished requests to their callbacks.
function Http.update()
    if not thread then return end
    local err = thread:getError()
    if err then
        print("[Http] Thread crashed: " .. err)
        -- Fail whatever was waiting, then start a fresh thread on the next request
        thread = nil
        for id, cb in pairs(callbacks) do
            if cb then cb(0, nil, "http thread crashed") end
            callbacks[id] = nil
        end
        love.thread.getChannel("http_requests"):clear()
        return
    end
    local responses = love.thread.getChannel("http_responses")
    local res = responses:pop()
    while res do
        local cb = callbacks[res.id]
        callbacks[res.id] = nil
        if cb then cb(res.status, res.body, res.error) end
        res = responses:pop()
    end
end

--- True while any request is waiting for its response.
function Http.isBusy()
    return next(callbacks) ~= nil
end

return Http
