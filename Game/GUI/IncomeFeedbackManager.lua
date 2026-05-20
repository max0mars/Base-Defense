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
    -- Reset any active sequence
    self.queue = {}
    self.timer = 0
    
    local game = self.game
    local initialTokens = game.tokens
    
    -- 1. Calculate Base Wave Income
    local baseIncome = 3
    
    -- 2. Calculate Interest Income (10% of tokens before wave payouts)
    local interestAmount = math.floor(initialTokens * 0.1)
    
    -- 3. Calculate and collect Bank yields
    local bankPayouts = {}
    local totalBankYield = 0
    
    for _, obj in ipairs(game.objects) do
        if obj.name == "Bank" and not obj.destroyed then
            if obj.checkPayout then
                local payout = obj:checkPayout()
                if payout > 0 then
                    table.insert(bankPayouts, { bank = obj, amount = payout })
                    totalBankYield = totalBankYield + payout
                end
            end
        end
    end
    
    -- Step 1: Base Wave Income
    self:queueFeedback(0.6, function()
        game:addTokens(baseIncome)
        if AUDIO then AUDIO:playSFX("money_01") end
        
        local cx = (VIRTUAL_WIDTH or 800) / 2
        local cy = (VIRTUAL_HEIGHT or 600) / 2
        game:spawnFloatingText("+" .. baseIncome .. " Wave Income", cx, cy - 20, {1, 0.84, 0, 1})
    end)
    
    -- Step 2: Interest Income (only queued if > 0)
    if interestAmount > 0 then
        self:queueFeedback(0.6, function()
            game:addTokens(interestAmount)
            if AUDIO then AUDIO:playSFX("money_01") end
            
            local cx = (VIRTUAL_WIDTH or 800) / 2
            local cy = (VIRTUAL_HEIGHT or 600) / 2
            game:spawnFloatingText("+" .. interestAmount .. " Interest", cx, cy - 20, {0.4, 0.9, 0.4, 1})
        end)
    end
    
    -- Step 3: Bank Buildings Feedback (only queued if > 0)
    if totalBankYield > 0 then
        self:queueFeedback(0.6, function()
            game:addTokens(totalBankYield)
            if AUDIO then AUDIO:playSFX("money_01") end
            
            for _, payout in ipairs(bankPayouts) do
                -- Default to base position if the bank was somehow destroyed during sequence delay
                local cx, cy = game.base.x, game.base.y
                if game.base.getCenterPosition then
                    cx, cy = game.base:getCenterPosition()
                end
                
                if not payout.bank.destroyed then
                    cx, cy = payout.bank:getCenterPosition()
                end
                game:spawnFloatingText("+" .. payout.amount .. " token", cx, cy - 20, {1, 0.84, 0, 1})
            end
        end)
    end
end

return IncomeFeedbackManager
