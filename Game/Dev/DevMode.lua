-- =============================================================================
-- DEVELOPER MODE (DevMode.lua)
-- A normal run with debug tools bound to the F keys. Started with F1 on the
-- title screen. State lives in _G.PersistentState.devMode, so it lasts for the
-- whole run (toggles carry over between battles) and ends with it.
-- =============================================================================

local ArtifactManager = require("Game.Artifacts.ArtifactManager")

local DevMode = {}

DevMode.TOKENS = 99    -- Token floor while unlimited tokens is on
DevMode.MANA = 999     -- Mana floor while unlimited tokens is on
DevMode.CASH = 500     -- Cash granted per press
DevMode.DRAW = 3       -- Cards drawn per press
DevMode.MESSAGE_TIME = 2

-- Help overlay starts open so the bindings are discoverable
DevMode.showHelp = true

-- Bindings, in display order. `scope`: where the key works ("battle", "prep" or "both").
-- `flag`: a persistent toggle shown as ON/OFF.
DevMode.BINDINGS = {
    { key = "f1",  label = "Show / hide this list",          scope = "both" },
    { key = "f2",  label = "Unlimited tokens & mana",        scope = "battle", flag = "infiniteTokens" },
    { key = "f3",  label = "Invincible base",                scope = "battle", flag = "invincible" },
    { key = "f4",  label = "Add any card to hand",           scope = "battle" },
    { key = "f5",  label = "Win battle instantly",           scope = "battle" },
    { key = "f6",  label = "Draw " .. DevMode.DRAW .. " cards", scope = "battle" },
    { key = "f7",  label = "Grant random artifact",          scope = "both" },
    { key = "f8",  label = "+$" .. DevMode.CASH .. " cash",  scope = "both" },
    { key = "f9",  label = "Merchant level +1",              scope = "both" },
    { key = "f10", label = "Kill all enemies (and dev queue)", scope = "battle" },
    { key = "f11", label = "Spawn specific enemies",         scope = "battle" },
}

-- -----------------------------------------------------------------------------
-- State
-- -----------------------------------------------------------------------------

function DevMode.isActive()
    return _G.PersistentState ~= nil and _G.PersistentState.devMode ~= nil
end

--- Marks the current run as a developer run.
function DevMode.enable()
    _G.PersistentState.devMode = {}
    DevMode.showHelp = true
end

function DevMode.isOn(flag)
    return DevMode.isActive() and _G.PersistentState.devMode[flag] == true
end

function DevMode.toggle(flag)
    local dev = _G.PersistentState.devMode
    dev[flag] = not dev[flag]
    return dev[flag]
end

function DevMode.notify(text)
    DevMode.message = text
    DevMode.messageUntil = love.timer.getTime() + DevMode.MESSAGE_TIME
end

--- Whether a binding with `scope` works in the current context.
local function usableHere(scope, inBattle)
    return scope == "both" or (scope == "battle" and inBattle) or (scope == "prep" and not inBattle)
end

-- -----------------------------------------------------------------------------
-- Actions
-- -----------------------------------------------------------------------------

local actions = {}

actions.f1 = function()
    DevMode.showHelp = not DevMode.showHelp
end

actions.f2 = function()
    DevMode.notify("Unlimited tokens & mana: " .. (DevMode.toggle("infiniteTokens") and "ON" or "OFF"))
end

actions.f3 = function()
    DevMode.notify("Invincible base: " .. (DevMode.toggle("invincible") and "ON" or "OFF"))
end

actions.f4 = function(game)
    local picker = game.gui and game.gui.itemPicker
    if picker then picker.isActive = not picker.isActive end
end

actions.f5 = function(game)
    paused = 0
    game:winBattle()
end

actions.f6 = function(game)
    local drawn = game:drawCard(DevMode.DRAW)
    DevMode.notify("Drew " .. drawn .. " card(s)")
end

actions.f7 = function(game)
    local def = ArtifactManager.grantRandom()
    if not def then
        DevMode.notify("Every artifact is already owned")
        return
    end
    -- Mid-battle: apply it right away instead of waiting for the next battle
    if game and game.artifacts then
        game.artifacts:addInstance(def.id)
        game.artifacts:refresh()
    end
    DevMode.notify("Artifact: " .. def.name)
end

actions.f8 = function()
    _G.PersistentState.cash = (_G.PersistentState.cash or 0) + DevMode.CASH
    DevMode.notify("+$" .. DevMode.CASH .. " cash")
end

actions.f9 = function()
    local Merchant = require("Game.Prep.Merchant")
    local ps = _G.PersistentState
    ps.shopLevel = math.min(Merchant.MAX_LEVEL, Merchant.getLevel() + 1)
    DevMode.notify("Merchant level " .. ps.shopLevel)
end

actions.f10 = function(game)
    -- Also drop anything still waiting in the dev spawner's queue
    if game.gui and game.gui.devSpawner then game.gui.devSpawner:clearQueue() end
    local killed = 0
    for _, obj in ipairs(game.objects) do
        if not obj.destroyed and obj.isType and obj:isType("enemy") then
            obj:died()
            killed = killed + 1
        end
    end
    DevMode.notify("Killed " .. killed .. " enemies")
end

actions.f11 = function(game)
    local spawner = game.gui and game.gui.devSpawner
    if spawner then spawner:toggle() end
end

--- Runs the dev action bound to `key`, if any. Returns true when the key was consumed.
-- @param game table|nil the battle's game, or nil outside a battle (preparation scene)
function DevMode.keypressed(key, game)
    if not DevMode.isActive() then return false end
    for _, b in ipairs(DevMode.BINDINGS) do
        if b.key == key then
            local inBattle = game ~= nil
            if usableHere(b.scope, inBattle) then
                actions[key](game)
            else
                DevMode.notify(key:upper() .. " only works " .. (inBattle and "between battles" or "during a battle"))
            end
            return true
        end
    end
    return false
end

--- Applies always-on toggles. Called every frame from the battle update.
function DevMode.update(game)
    if DevMode.isOn("infiniteTokens") then
        game.tokens = math.max(game.tokens, DevMode.TOKENS)
        game.mana = math.max(game.mana or 0, DevMode.MANA)
    end
end

-- -----------------------------------------------------------------------------
-- Overlay
-- -----------------------------------------------------------------------------

--- Badge, last action message and (when open) the key list.
-- @param inBattle boolean dims the bindings that don't apply here
-- @param hideHelp boolean skips the key list (e.g. while a menu is open)
function DevMode.draw(inBattle, hideHelp)
    if not DevMode.isActive() then return end
    local font = love.graphics.getFont()
    local lineH = font:getHeight() + 4

    love.graphics.push("all")
    love.graphics.setColor(1, 0.55, 0.1, 1)
    love.graphics.printf("DEV MODE  (F1: keys)", 0, 2, VIRTUAL_WIDTH, "center")

    if DevMode.message and love.timer.getTime() < (DevMode.messageUntil or 0) then
        love.graphics.setColor(1, 0.85, 0.4, 1)
        love.graphics.printf(DevMode.message, 0, 2 + lineH, VIRTUAL_WIDTH, "center")
    end

    if DevMode.showHelp and not hideHelp then
        local w = 330
        local h = 32 + #DevMode.BINDINGS * lineH
        local x, y = VIRTUAL_WIDTH - w - 12, 110
        love.graphics.setColor(0.05, 0.04, 0.02, 0.9)
        love.graphics.rectangle("fill", x, y, w, h, 6)
        love.graphics.setColor(1, 0.55, 0.1, 0.9)
        love.graphics.rectangle("line", x, y, w, h, 6)
        love.graphics.print("DEVELOPER KEYS", x + 10, y + 8)

        for i, b in ipairs(DevMode.BINDINGS) do
            local ly = y + 28 + (i - 1) * lineH
            local usable = usableHere(b.scope, inBattle)
            local alpha = usable and 1 or 0.35
            love.graphics.setColor(1, 0.7, 0.3, alpha)
            love.graphics.print(b.key:upper(), x + 10, ly)
            love.graphics.setColor(0.92, 0.92, 0.92, alpha)
            love.graphics.print(b.label, x + 50, ly)
            if b.flag then
                local on = DevMode.isOn(b.flag)
                love.graphics.setColor(on and 0.3 or 0.6, on and 1 or 0.6, on and 0.4 or 0.6, alpha)
                love.graphics.printf(on and "ON" or "OFF", x, ly, w - 10, "right")
            end
        end
    end
    love.graphics.pop()
end

return DevMode
