local game_scene = {
    
}
game_scene.__index = game_scene
local scene = require("Scenes.scene") -- Import the base scene class
setmetatable(game_scene, { __index = scene })

local game = require("Game.Core.GameManager") -- Import the game module
local SettingsPanel = require("Game.GUI.SettingsPanel")
local Cursor = require("Game.GUI.Cursor")
local DamageStats = require("Game.Core.DamageStats")
local DevMode = require("Game.Dev.DevMode")

function game_scene:load()
    local isTesting = game.testingMode
    game:load(nil, isTesting)
    game.time_mul = 1 -- game starts at normal speed
    paused = 0
    self.gameover = false
    if AUDIO and not AUDIO:isPlayingMusic() then AUDIO:playMusic() end

    -- In-game pause menu: the shared settings panel with Resume / Exit.
    self.settings = SettingsPanel:new({
        title = "PAUSED",
        bottomButtons = {
            { label = "RESUME", action = "resume",
              color = {0.1, 0.45, 0.25, 1}, hoverColor = {0.18, 0.7, 0.4, 1}, borderColor = {0.3, 0.9, 0.5, 1} },
            { label = "EXIT", action = "exit",
              color = {0.4, 0.18, 0.2, 1}, hoverColor = {0.6, 0.28, 0.3, 1}, borderColor = {0.95, 0.45, 0.45, 1} },
        },
    })
end

function game_scene:mousepressed(x, y, button)
    if self.showingSummary then
        self.showingSummary = false
        self.scene_manager.switch("preparation", true)
        return
    end

    if paused == 1 then
        local action = self.settings:mousepressed(x, y, button)
        if action == "resume" then
            paused = 0
        elseif action == "exit" then
            paused = 0
            self.scene_manager.switch("menu")
        end
        return
    end
    game.inputHandler:mousepressed(x, y, button) -- Route through InputHandler
end

function game_scene:mousereleased(x, y, button)
    if self.showingSummary then return end
    if paused == 1 then
        self.settings:mousereleased(x, y, button)
        return
    end
    if game.inputHandler.mousereleased then
        game.inputHandler:mousereleased(x, y, button)
    end
end

function game_scene:update(dt)
    if paused == 1 then
        self.settings:update(dt)
    end
    if game:isState("gameover") and not self.gameover then
        self.gameover = true
        self.scene_manager.switch("gameover")
    end

    if game.battleComplete then
        if not (game.rewardSystem and game.rewardSystem.isActive) then
            game.battleComplete = false
            self.showingSummary = true
            self.summaryDamage = game.damageTakenThisBattle or 0
            self.summaryIncome = game.battleReward or 0
            self.summaryPerfectBonus = (self.summaryDamage == 0) and 25 or 0
            
            local currentCash = _G.PersistentState and _G.PersistentState.cash or 0
            local cashBeforeBattle = currentCash - self.summaryIncome
            if cashBeforeBattle < 0 then cashBeforeBattle = 0 end
            self.summaryInterest = math.floor(cashBeforeBattle * 0.10 + 0.5)
            
            if _G.PersistentState then
                _G.PersistentState.cash = currentCash + self.summaryInterest + self.summaryPerfectBonus
                self.summaryTotalCash = _G.PersistentState.cash
            else
                self.summaryTotalCash = 0
            end

            -- Top 3 turrets by damage dealt this battle (first is the MVP)
            self.summaryTopTurrets = {}
            if game.damageStats then
                for i, entry in ipairs(game.damageStats:getRanking()) do
                    if i > 3 then break end
                    table.insert(self.summaryTopTurrets, entry)
                end
            end

            self.summaryOtherRewards = {}
            if game.awardedBattleRewards then
                for _, r in ipairs(game.awardedBattleRewards) do
                    if r.type ~= "gold" and r.name then
                        local desc = r.name
                        if r.amount and r.amount > 1 then
                            desc = desc .. " (x" .. r.amount .. ")"
                        end
                        table.insert(self.summaryOtherRewards, desc)
                    end
                end
            end
            return
        end
    end
    
    if self.showingSummary then return end

    local effectiveDt = dt * game.time_mul
    
    -- Freeze game if paused or a modal menu is active
    if paused == 1 or
       (game.gui.codex and game.gui.codex.isActive) or
       (game.rewardSystem and game.rewardSystem.isActive) or
       (game.gui.mutation and game.gui.mutation.isActive) or
       (game.gui.confirmation and game.gui.confirmation.active) or
       (game.gui.enemySpawner and game.gui.enemySpawner.isActive) or
       (game.gui.itemPicker and game.gui.itemPicker.isActive) or
       (game.gui.devSpawner and game.gui.devSpawner.isActive) then
        effectiveDt = 0
    end
    
    if game.rewardSystem and game.rewardSystem.isActive then
        game.rewardSystem:update(dt)
    end
    
    game:update(effectiveDt)
end

function game_scene:draw()
    game:draw()
    if paused == 1 then
        love.graphics.setColor(0, 0, 0, 0.6) -- Dim overlay behind the pause menu
        love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
        self.settings:draw()
        -- Real OS hand/arrow cursor over the pause menu (matches the main menu).
        Cursor.applyOS()
    end
    if self.showingSummary then
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
        
        -- Centered rounded container box
        local boxW = 460
        local hasOther = (self.summaryOtherRewards and #self.summaryOtherRewards > 0)
        local top = self.summaryTopTurrets or {}
        -- MVP block: name + damage line, then one line per runner-up, then a divider
        local mvpH = (#top > 0) and (58 + (#top - 1) * 20) or 0
        local boxH = (hasOther and 340 or 300) + mvpH
        local boxX = math.floor((VIRTUAL_WIDTH - boxW) / 2)
        local boxY = math.floor((VIRTUAL_HEIGHT - boxH) / 2) - 10
        
        -- Box background (dark tech-glass)
        love.graphics.setColor(0.06, 0.08, 0.12, 0.96)
        love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 12, 12)
        
        -- Box glowing cyan/teal border
        love.graphics.setColor(0.2, 0.6, 0.85, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 12, 12)
        love.graphics.setLineWidth(1)
        
        -- Header title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("BATTLE COMPLETE", boxX, boxY + 22, boxW, "center")
        
        -- Thin divider below header
        love.graphics.setColor(0.3, 0.5, 0.7, 0.4)
        love.graphics.line(boxX + 24, boxY + 48, boxX + boxW - 24, boxY + 48)

        -- MVP turret (most damage dealt) and runners-up
        if #top > 0 then
            local fmt = DamageStats.formatNumber
            local mvp = top[1]
            love.graphics.setColor(1, 0.82, 0.25, 1)
            love.graphics.printf("MVP: " .. mvp.name, boxX, boxY + 60, boxW, "center")
            love.graphics.setColor(1, 0.9, 0.6, 1)
            love.graphics.printf(string.format("%s dmg (%d%%)", fmt(mvp.damage), math.floor(mvp.share * 100 + 0.5)),
                boxX, boxY + 80, boxW, "center")
            love.graphics.setColor(0.75, 0.78, 0.85, 1)
            for i = 2, #top do
                love.graphics.printf(string.format("%d. %s - %s dmg", i, top[i].name, fmt(top[i].damage)),
                    boxX, boxY + 80 + (i - 1) * 20, boxW, "center")
            end
            love.graphics.setColor(0.3, 0.5, 0.7, 0.4)
            local dividerY = boxY + 48 + mvpH
            love.graphics.line(boxX + 24, dividerY, boxX + boxW - 24, dividerY)
        end
        local oy = boxY + mvpH -- Everything below shifts down by the MVP block

        -- Battle statistics
        love.graphics.setColor(0.85, 0.85, 0.9, 1)
        love.graphics.printf("Damage Taken: " .. self.summaryDamage, boxX, oy + 65, boxW, "center")

        love.graphics.setColor(0.2, 0.9, 0.35, 1)
        love.graphics.printf("Cash: +$" .. self.summaryIncome, boxX, oy + 95, boxW, "center")
        love.graphics.printf("Perfect Bonus: +$" .. self.summaryPerfectBonus, boxX, oy + 125, boxW, "center")
        love.graphics.printf("Interest: +$" .. self.summaryInterest, boxX, oy + 155, boxW, "center")

        -- Thin divider above Total Cash
        love.graphics.setColor(0.3, 0.5, 0.7, 0.4)
        love.graphics.line(boxX + 24, oy + 185, boxX + boxW - 24, oy + 185)

        love.graphics.setColor(0.3, 1.0, 0.5, 1)
        love.graphics.printf("Total Cash: $" .. self.summaryTotalCash, boxX, oy + 198, boxW, "center")

        local nextY = oy + 232
        if hasOther then
            love.graphics.setColor(1, 0.85, 0.3, 1)
            local otherText = "Other Rewards: " .. table.concat(self.summaryOtherRewards, ", ")
            love.graphics.printf(otherText, boxX + 15, nextY, boxW - 30, "center")
            nextY = nextY + 36
        end
        
        love.graphics.setColor(0.55, 0.6, 0.68, 1)
        love.graphics.printf("Click anywhere to continue", boxX, nextY + 12, boxW, "center")
        
        -- Restore standard OS cursor over the summary screen
        Cursor.applyOS()
    end
    
    -- Key list steps aside while a menu (e.g. a dev panel) is open over the battle
    DevMode.draw(true, game.gui:overlayActive())

    -- love.graphics.print("Tokens: " .. game.tokens, 10, 10)
    -- --love.graphics.print("Time Multiplier: " .. string.format("%.1f", time_mul) .. "x", 10, 30)
    -- love.graphics.print("Wave: " .. game.wave, 10, 30)
    -- --love.graphics.print("Game State: " .. game.state, 10, 70)
    -- --love.graphics.print("Wave State: " .. game.WaveSpawner.waveState, 200, 10)
    -- --love.graphics.print("Selected Turret: " .. (game.inputHandler.selectedTurret and game.inputHandler.selectedTurret.id or "None"), 200, 30)
    -- --love.graphics.print("Spawn Rate: " .. game.WaveSpawner.spawnRate, 200, 50)
    -- love.graphics.print("Debug: " .. tostring(game.debugMode or false), 10, 50)
end

function game_scene:keypressed(key)
    -- Developer mode F keys (not on the post-battle summary: the battle is already over)
    if not self.showingSummary and not game.battleComplete and DevMode.keypressed(key, game) then
        return
    end

    -- Testing debug command: Shift + Z instantly wins the battle
    if (key == "z" or key == "Z") and (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) then
        paused = 0
        game:winBattle()
        return
    end

    -- Codex (if open) captures Esc to close itself first.
    if game.gui.codex and game.gui.codex.isActive then
        game.gui.codex:keypressed(key)
        return
    end

    -- Esc / P toggle the pause menu (the shared settings panel).
    if key == "escape" or key == "p" then
        paused = paused == 1 and 0 or 1
        return
    end

    if paused == 1 then return end -- ignore gameplay keys while paused

    if key == "+" or key == "=" then
        game.time_mul = math.min(game.time_mul + 0.5, 2) -- Increase time multiplier up to 2x
    elseif key == "-" then
        game.time_mul = math.max(game.time_mul - 0.5, 0.5) -- Decrease time multiplier down to 0.5x
    else
        if game.inputHandler and game.inputHandler.keypressed then
            game.inputHandler:keypressed(key) -- Route through InputHandler
        end
    end
end

return game_scene
