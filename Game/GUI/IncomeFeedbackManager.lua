-- Game/GUI/IncomeFeedbackManager.lua
-- Manages the sequential, queued playout of wave-end income feedback

local IncomeFeedbackManager = {}
IncomeFeedbackManager.__index = IncomeFeedbackManager

function IncomeFeedbackManager:new(game)
    local obj = setmetatable({
        game = game,
        queue = {},
        timer = 0
    }, self)
    return obj
end

-- Queues a feedback step with a specific delay and action callback
function IncomeFeedbackManager:queueFeedback(delay, action)
    table.insert(self.queue, {
        delay = delay,
        action = action
    })
end

-- Updates the sequence timer and executes items sequentially
function IncomeFeedbackManager:update(dt)
    if #self.queue == 0 then return end
    
    self.timer = self.timer + dt
    local currentItem = self.queue[1]
    
    if self.timer >= currentItem.delay then
        -- Execute the step action (grants tokens, plays audio, spawns text)
        currentItem.action()
        -- Remove the finished item
        table.remove(self.queue, 1)
        -- Reset timer for the next item
        self.timer = 0
    end
end

-- Triggers the end-of-wave sequential income feedback
function IncomeFeedbackManager:triggerSequence()
    self.queue = {}
    self.timer = 0
    
    local game = self.game
    
    -- Queue simple feedback for Energy Refill
    self:queueFeedback(0.6, function()
        if AUDIO then AUDIO:playSFX("money_01") end
        local cx = (VIRTUAL_WIDTH or 800) / 2
        local cy = (VIRTUAL_HEIGHT or 600) / 2
        game:spawnFloatingText("Energy Refilled", cx, cy - 20, {0.2, 0.9, 1.0, 1})
    end)
end

return IncomeFeedbackManager
