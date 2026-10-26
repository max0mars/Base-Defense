-- DamageStats.lua - Per-battle damage and kill tracking for turrets (incl. the main turret).
--
-- Damage is credited to the turret behind a hit by following `.source` links
-- (bullet -> turret, split/bounce bullet -> bullet -> turret). Burn/poison ticks
-- and explosions carry the bullet that caused them, so they credit the same turret.
-- Only effective damage counts: HP or shield actually removed, never overkill.

local DamageStats = {}
DamageStats.__index = DamageStats

function DamageStats.new()
    return setmetatable({
        entries = {}, -- turret -> { name, damage, kills }
        order = {},   -- turrets in first-hit order (stable ranking ties)
        total = 0,
    }, DamageStats)
end

--- The turret responsible for a damage source, or nil (e.g. spells).
function DamageStats.resolveTurret(source)
    local obj, hops = source, 0
    while obj and hops < 10 do
        if type(obj.isType) == "function" and obj:isType("turret") then
            return obj
        end
        obj = obj.source
        hops = hops + 1
    end
    return nil
end

--- Credits effective damage (and a kill) to the turret behind `source`.
function DamageStats:record(source, amount, killed)
    local turret = DamageStats.resolveTurret(source)
    if not turret or not amount or amount <= 0 then return end

    local entry = self.entries[turret]
    if not entry then
        entry = { turret = turret, name = turret.name or "Turret", damage = 0, kills = 0 }
        self.entries[turret] = entry
        table.insert(self.order, turret)
    end
    entry.damage = entry.damage + amount
    if killed then entry.kills = entry.kills + 1 end
    self.total = self.total + amount
end

--- { damage, kills, share } for a turret (zeros if it hasn't dealt damage yet).
function DamageStats:get(turret)
    local entry = self.entries[turret]
    local damage = entry and entry.damage or 0
    return {
        damage = damage,
        kills = entry and entry.kills or 0,
        share = self.total > 0 and damage / self.total or 0,
    }
end

--- Entries sorted by damage, highest first: { name, damage, kills, share, turret }.
function DamageStats:getRanking()
    local ranking = {}
    for i, turret in ipairs(self.order) do
        local e = self.entries[turret]
        table.insert(ranking, {
            turret = turret, name = e.name, damage = e.damage, kills = e.kills,
            share = self.total > 0 and e.damage / self.total or 0, firstHit = i,
        })
    end
    table.sort(ranking, function(a, b)
        if a.damage ~= b.damage then return a.damage > b.damage end
        return a.firstHit < b.firstHit
    end)
    return ranking
end

--- The top-damage turret's ranking entry, or nil if no turret dealt damage.
function DamageStats:getMVP()
    return self:getRanking()[1]
end

--- 1234567 -> "1,234,567" (rounded to whole numbers).
function DamageStats.formatNumber(n)
    local s = tostring(math.floor((n or 0) + 0.5))
    local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (formatted:gsub("^,", ""))
end

return DamageStats
