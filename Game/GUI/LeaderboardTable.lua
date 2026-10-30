-- =============================================================================
-- LEADERBOARD TABLE (LeaderboardTable.lua)
-- Rows of leaderboard runs, as drawn by the leaderboard screen and by the game
-- over screen's YOUR RANK tab, so both look the same.
-- =============================================================================

local Leaderboard = require("Game.Online.Leaderboard")
local Neon = require("Game.GUI.Neon")
local DamageStats = require("Game.Core.DamageStats")

local LeaderboardTable = {}

LeaderboardTable.WIDTH = 1000
-- Columns: x offset in the table, width, header, alignment. The space after
-- the last one (x 910 onward) is free for a per-row button.
LeaderboardTable.COLUMNS = {
    { key = "rank", x = 0, w = 50, title = "#", align = "center" },
    { key = "name", x = 60, w = 200, title = "NAME", align = "left" },
    { key = "level", x = 270, w = 80, title = "LEVEL", align = "center" },
    { key = "turret", x = 360, w = 170, title = "MAIN TURRET", align = "left" },
    { key = "damage", x = 540, w = 130, title = "DAMAGE DEALT", align = "center" },
    { key = "kills", x = 680, w = 100, title = "KILLS", align = "center" },
    { key = "date", x = 790, w = 110, title = "DATE", align = "center" },
}

function LeaderboardTable.formatDate(ms)
    ms = tonumber(ms)
    return ms and os.date("%d %b %Y", math.floor(ms / 1000)) or ""
end

--- Column titles at y, with a line under them at lineY.
function LeaderboardTable.drawHeader(x, y, lineY)
    love.graphics.setColor(0, 0.85, 1.0, 0.8)
    for _, col in ipairs(LeaderboardTable.COLUMNS) do
        love.graphics.printf(col.title, x + col.x, y, col.w, col.align)
    end
    Neon.line(x, lineY, x + LeaderboardTable.WIDTH, lineY, Neon.CYAN, 1, 0.5)
end

--- One run. highlight: "mine" (one of the player's runs, a faint tint) or
--- "this" (the run just played: tinted and outlined), or nil.
function LeaderboardTable.drawRow(entry, x, y, h, highlight)
    local w = LeaderboardTable.WIDTH
    if highlight then
        love.graphics.setColor(1, 0.25, 0.85, highlight == "this" and 0.18 or 0.1)
        love.graphics.rectangle("fill", x, y + 2, w, h - 4, 4)
    end
    if highlight == "this" then
        Neon.rect(x, y + 2, w, h - 4, Neon.MAGENTA, { width = 1.5 })
    else
        love.graphics.setColor(0, 0.85, 1.0, 0.12)
        love.graphics.rectangle("line", x, y + 2, w, h - 4, 4)
    end

    local values = {
        rank = tostring(entry.rank),
        name = tostring(entry.name),
        level = tostring(entry.level),
        turret = Leaderboard.mainTurretName(entry.mainTurret),
        damage = DamageStats.formatNumber(tonumber(entry.damageDealt) or 0),
        kills = DamageStats.formatNumber(tonumber(entry.kills) or 0),
        date = LeaderboardTable.formatDate(entry.createdAt),
    }
    local ty = y + h / 2 - love.graphics.getFont():getHeight() / 2
    for _, col in ipairs(LeaderboardTable.COLUMNS) do
        if col.key == "rank" and (tonumber(entry.rank) or 99) <= 3 then
            love.graphics.setColor(Neon.hot(Neon.AMBER, 0.3))
        elseif col.key == "level" then
            love.graphics.setColor(Neon.hot(Neon.GREEN, 0.3))
        else
            love.graphics.setColor(0.88, 0.9, 0.95, 1)
        end
        love.graphics.printf(values[col.key], x + col.x, ty, col.w, col.align)
    end
end

return LeaderboardTable
