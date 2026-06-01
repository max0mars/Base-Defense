local Layout = require("Game.GUI.Layout")

local TooltipManager = {}
TooltipManager.__index = TooltipManager

local DAMAGE_TYPE_NAMES = {
    normal         = "Normal",
    poison         = "Poison",
    armourPiercing = "Armor Piercing",
    trueDamage     = "True",
    fire           = "Fire",
    explosive      = "Explosive",
    energy         = "Energy",
    electric       = "Electric",
}

local DAMAGE_TYPE_COLORS = {
    normal         = {1, 1, 1, 1},
    poison         = {0.4, 0.85, 0.3, 1},
    armourPiercing = {0.9, 0.85, 0.6, 1},
    trueDamage     = {1, 0.4, 0.7, 1},
    fire           = {1, 0.5, 0.2, 1},
    explosive      = {1, 0.55, 0.1, 1},
    energy         = {0.4, 0.7, 1, 1},
    electric       = {0.6, 0.8, 1, 1},
}

function TooltipManager:new(game)
    local obj = setmetatable({
        game = game,
        hoveredBuilding = nil,
        hoverTooltip = nil,
        rarityProbs = nil
    }, self)
    return obj
end

function TooltipManager:update(dt)
    self.hoveredBuilding = self.game.inputHandler.hoveredBuilding
    self.hoverTooltip = self.game.base.hoverTooltip
    self.hoveredEnemy = self:findHoveredEnemy()
end

--- Finds the enemy under the cursor (if any), respecting menus, the HUD bands,
--- and giving buildings/placement priority.
function TooltipManager:findHoveredEnemy()
    local game = self.game

    -- Don't show enemy info over buildings, while placing, or behind a menu.
    if self.hoveredBuilding then return nil end
    if game.inputMode == "placing" then return nil end
    if game.rewardSystem and game.rewardSystem.isActive then return nil end
    if game.specialUpgradeManager and game.specialUpgradeManager.isActive then return nil end
    if game.gui and game.gui.mutation and game.gui.mutation.isActive then return nil end

    local rmx, rmy = love.mouse.getPosition()
    if not Layout.inFieldScreen(rmx, rmy) then return nil end -- outside the battlefield
    local mx, my = Layout.mouseToField(rmx, rmy)

    local best, bestArea
    for _, obj in ipairs(game.objects) do
        if obj:isType("enemy") and not obj.destroyed and obj.affinities then
            local hw = (obj.w or obj.size or 20) / 2
            local hh = (obj.h or obj.size or 20) / 2
            if mx >= obj.x - hw and mx <= obj.x + hw and
               my >= obj.y - hh and my <= obj.y + hh then
                -- Prefer the smallest (visually topmost) enemy under the cursor.
                local area = hw * hh
                if not best or area < bestArea then
                    best, bestArea = obj, area
                end
            end
        end
    end
    return best
end

function TooltipManager:draw()
    local game = self.game
    
    -- Draw slot unlock tooltip
    if self.hoverTooltip then
        self:drawSimpleTooltip(self.hoverTooltip.x, self.hoverTooltip.y, self.hoverTooltip.text, self.hoverTooltip.cost or 0)
    end
    
    -- Hovered building/enemy detail now renders in the left column's INSPECT
    -- pane (see InfoColumn). hoveredBuilding/hoveredEnemy are still tracked in
    -- update() so the column can read them.

    -- The "press enter" prompt for startup/preparing is drawn as a single bordered
    -- panel by GUIManager (drawHUD); no plain-text duplicate here.

    -- Draw rarity probabilities tooltip
    if self.rarityProbs then
        local mx, my = love.mouse.getPosition()
        local h = (#self.rarityProbs * 22) + 24
        local ty = my + 15
        if ty + h > VIRTUAL_HEIGHT then ty = my - 15 - h end -- flip above near the bottom
        self:drawRarityTooltip(mx + 15, ty, self.rarityProbs)
    end
end

-- Hover info (detail card / fallback panel) renders at a fixed bottom-right
-- corner rather than following the cursor, so it never blocks units on the map.
local INFO_MARGIN = 6 -- gap from the screen edges

-- Tier-bar geometry.
local BAR_LABEL_W = 34
local BAR_SEG_W   = 9
local BAR_SEG_H   = 7
local BAR_GAP     = 2
local BAR_TIERS   = 5

local TurretStatBars = require("Game.GUI.TurretStatBars")

local function elementWidth(font, el)
    if el.kind == "bar" then
        return BAR_LABEL_W + BAR_TIERS * (BAR_SEG_W + BAR_GAP)
    end
    return font:getWidth(el.text)
end

--- Renders a list of elements as a glass info panel. Each element is either
--- {kind="text", text, color} or {kind="bar", label, tier, color}.
--- Without `anchor` it draws at a fixed canvas location; with
--- anchor={x, y, halfH} it floats centered above that point (flipping below if
--- it would hit the top HUD).
function TooltipManager:drawLineBox(elements, anchor)
    local font = love.graphics.getFont()
    local lineHeight = math.max(font:getHeight(), BAR_SEG_H + 3)
    local padding = 7

    local maxWidth = 0
    for _, el in ipairs(elements) do
        local w = elementWidth(font, el)
        if w > maxWidth then maxWidth = w end
    end
    local boxW = maxWidth + padding * 2
    local boxH = padding * 2 + #elements * lineHeight

    -- Fixed position: bottom-right, anchored to the corner so taller panels
    -- grow upward into the play area instead of off-screen.
    local drawX = (VIRTUAL_WIDTH or 800) - INFO_MARGIN - boxW
    local drawY = (VIRTUAL_HEIGHT or 600) - INFO_MARGIN - boxH
    if anchor then
        drawX = anchor.x - boxW / 2
        drawY = anchor.y - (anchor.halfH or 0) - 8 - boxH
        if drawX < 5 then drawX = 5
        elseif drawX + boxW > VIRTUAL_WIDTH - 5 then drawX = VIRTUAL_WIDTH - 5 - boxW end
        if drawY < 102 then drawY = anchor.y + (anchor.halfH or 0) + 8 end -- flip below if it hits the HUD
    end

    love.graphics.setColor(0.03, 0.05, 0.09, 0.94)
    love.graphics.rectangle("fill", drawX, drawY, boxW, boxH, 4)
    love.graphics.setColor(0.0, 0.7, 1.0, 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", drawX, drawY, boxW, boxH, 4)

    for i, el in ipairs(elements) do
        local y = drawY + padding + (i - 1) * lineHeight
        local x = drawX + padding
        if el.kind == "bar" then
            love.graphics.setColor(0.75, 0.8, 0.88, 1)
            love.graphics.print(el.label, x, y)
            local pipsX = x + BAR_LABEL_W
            for s = 1, BAR_TIERS do
                if s <= el.tier then
                    love.graphics.setColor(el.color)
                else
                    love.graphics.setColor(0.18, 0.2, 0.25, 0.9)
                end
                love.graphics.rectangle("fill", pipsX + (s - 1) * (BAR_SEG_W + BAR_GAP), y + 1, BAR_SEG_W, BAR_SEG_H, 1)
            end
        else
            love.graphics.setColor(el.color)
            love.graphics.print(el.text, x, y)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Hovering a placed building shows its reward-style detail card, anchored
-- bottom-right. For turrets the card is temporarily pointed at the live turret
-- so its DPS/tier bars reflect current (buffed) stats; other building types
-- render from the card's own dummy (their emblem reads its shape footprint).
-- Synthesizes (and caches) a reward-style card for a turret that wasn't drafted
-- from a reward — e.g. the player-controlled main turret. Stats come live from
-- the turret at draw time, so only name/description/rarity need filling in.
local RARITY_ORDER = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5 }

-- Lazily index every main-turret upgrade (id -> {name, rarity, description}) so a
-- turret's applied upgrade flags can be resolved to display identities.
function TooltipManager:mainUpgradeInfo()
    if self._mainUpgradeInfo then return self._mainUpgradeInfo end
    local info = {}
    local NormalRewardIndex = require("Game.Rewards.NormalRewardIndex")
    for rarity, entries in pairs(NormalRewardIndex) do
        if type(entries) == "table" then
            for _, e in ipairs(entries) do
                if e.type == "main_upgrade" and e.id then
                    info[e.id] = { name = e.name, rarity = rarity, description = e.description }
                end
            end
        end
    end
    self._mainUpgradeInfo = info
    return info
end

-- The highest-rarity upgrade currently applied to the turret (or nil).
function TooltipManager:bestMainUpgrade(turret)
    if not turret.upgrades then return nil end
    local info = self:mainUpgradeInfo()
    local best
    for id, on in pairs(turret.upgrades) do
        if on and info[id] then
            if not best or (RARITY_ORDER[info[id].rarity] or 0) > (RARITY_ORDER[best.rarity] or 0) then
                best = info[id]
            end
        end
    end
    return best
end

-- Synthesizes (and caches) a reward-style card for a turret that wasn't drafted
-- from a reward (e.g. the player's main turret). Its identity reflects the
-- highest-rarity applied main-turret upgrade (e.g. legendary PROJECT STORMBREAKER)
-- instead of staying a plain common turret; live stats come from the turret.
function TooltipManager:turretCardFor(turret)
    local name = turret.name or "Turret"
    local rarity = turret.cardRarity or "common"
    local desc = turret.description

    local best = self:bestMainUpgrade(turret)
    if best then
        name, rarity, desc = best.name, best.rarity, best.description
    end
    if not desc or desc == "" then
        desc = turret:isType("mainLazer") and "Aim and fire manually to defend the core." or ""
    end

    -- Rebuild the cached card whenever the resolved identity changes (e.g. a new
    -- upgrade is applied mid-run).
    local sig = name .. "|" .. rarity
    if not turret._detailCard or turret._detailCardSig ~= sig then
        local Reward = require("Game.Rewards.Reward")
        turret._detailCard = Reward:new({
            name = name,
            description = desc,
            type = "building",
            iconCategory = "turret",
            rarity = rarity,
            game = turret.game,
        })
        turret._detailCardSig = sig
    end
    return turret._detailCard
end

function TooltipManager:drawBuildingCard(building, card)
    local cardW, cardH = 175, 205
    local cardX = (VIRTUAL_WIDTH or 800) - INFO_MARGIN - cardW
    local cardY = (VIRTUAL_HEIGHT or 600) - INFO_MARGIN - cardH

    if building:isType("turret") then
        local savedDummy = card.dummyBuilding
        card.dummyBuilding = building
        card:draw(cardX, cardY, cardW, cardH, false)
        card.dummyBuilding = savedDummy
    else
        card:draw(cardX, cardY, cardW, cardH, false)
    end
end

function TooltipManager:drawTurretTooltip(turret)
    local font = love.graphics.getFont()
    local wrapWidth = 190

    local dmg      = turret:getStat("damage", 0)
    local fireRate = turret:getStat("fireRate", 0)
    local pellets  = turret.pelletCount or 1
    local range    = turret:getStat("range", 0)
    local pierce   = turret:getStat("pierce", 1)
    local dtype    = turret:getStat("damageType", "normal")
    local volley   = dmg * pellets          -- effective per-volley damage
    local dps      = volley * fireRate

    local els = {}
    -- Header: name, then a compact type + DPS line.
    els[#els + 1] = { kind = "text", text = turret.name or "Turret", color = {1, 1, 1, 1} }
    els[#els + 1] = {
        kind = "text",
        text = string.format("%s  -  DPS %.0f", DAMAGE_TYPE_NAMES[dtype] or dtype, dps),
        color = DAMAGE_TYPE_COLORS[dtype] or {1, 1, 1, 1}
    }

    -- Relative tier bars (compared against every turret in the pool).
    for _, row in ipairs(TurretStatBars.rows(turret, self.game, BAR_TIERS)) do
        els[#els + 1] = { kind = "bar", label = row.label, tier = row.tier, color = row.color }
    end

    -- Effect payloads (compact).
    if (turret:getStat("dps_poison", 0) or 0) > 0 then
        els[#els + 1] = { kind = "text",
            text = string.format("Poison %.0f/s for %.1fs", turret:getStat("dps_poison", 0), turret:getStat("duration_poison", 0)),
            color = {0.6, 0.9, 0.8, 1} }
    end
    local radius = turret:getStat("radius", 0)
    if radius and radius > 0 then
        local expDmg = turret:getStat("explosionDamage", 0)
        local t = (expDmg and expDmg > 0) and string.format("AoE %.0f dmg, r%d", expDmg, radius)
                                          or string.format("Splash r%d", radius)
        els[#els + 1] = { kind = "text", text = t, color = {0.6, 0.9, 0.8, 1} }
    end
    if (turret:getStat("splitamount", 0) or 0) > 0 then
        els[#els + 1] = { kind = "text", text = "Splits x" .. turret:getStat("splitamount", 0), color = {0.6, 0.9, 0.8, 1} }
    end
    if (turret:getStat("recursion", 0) or 0) > 0 then
        els[#els + 1] = { kind = "text", text = "Chains x" .. turret:getStat("recursion", 0), color = {0.6, 0.9, 0.8, 1} }
    end
    if pierce and pierce > 1 then
        els[#els + 1] = { kind = "text", text = "Pierce " .. pierce, color = {0.6, 0.9, 0.8, 1} }
    end

    -- Ability description (from the reward it came from).
    local desc = turret.rewardCard and turret.rewardCard.description
    if desc and desc ~= "" then
        local _, wrapped = font:getWrap(desc, wrapWidth)
        for _, wl in ipairs(wrapped) do
            els[#els + 1] = { kind = "text", text = wl, color = {0.78, 0.78, 0.84, 1} }
        end
    end

    -- Active buffs (Ammo Cache, totems, etc.).
    if turret.effectManager and turret.effectManager.getTooltipStrings then
        for _, s in ipairs(turret.effectManager:getTooltipStrings()) do
            els[#els + 1] = { kind = "text", text = s, color = {0.3, 0.85, 1.0, 1} }
        end
    end

    self:drawLineBox(els)
end

function TooltipManager:drawEnemyTooltip(enemy)
    local els = {}
    els[#els + 1] = { kind = "text", text = enemy.name or "Enemy", color = {1, 1, 1, 1} }

    local maxHp = enemy.getStat and enemy:getStat("maxHp") or enemy.maxHp
    if maxHp then
        els[#els + 1] = {
            kind = "text",
            text = string.format("HP %d/%d", math.max(0, math.floor(enemy.hp or 0)), math.floor(maxHp)),
            color = {0.7, 0.85, 1.0, 1}
        }
    end

    local resists, weaks = {}, {}
    for dtype, mult in pairs(enemy.affinities or {}) do
        if type(mult) == "number" and mult ~= 1 then
            local nm = DAMAGE_TYPE_NAMES[dtype] or dtype
            if mult < 1 then
                resists[#resists + 1] = string.format("  %s  -%d%%", nm, math.floor((1 - mult) * 100 + 0.5))
            else
                weaks[#weaks + 1] = string.format("  %s  +%d%%", nm, math.floor((mult - 1) * 100 + 0.5))
            end
        end
    end
    table.sort(resists)
    table.sort(weaks)

    if #resists == 0 and #weaks == 0 then
        els[#els + 1] = { kind = "text", text = "Takes full damage", color = {0.6, 0.6, 0.6, 1} }
    else
        if #resists > 0 then
            els[#els + 1] = { kind = "text", text = "RESISTS", color = {0.4, 0.7, 1.0, 1} }
            for _, t in ipairs(resists) do
                els[#els + 1] = { kind = "text", text = t, color = {0.55, 0.8, 1.0, 1} }
            end
        end
        if #weaks > 0 then
            els[#els + 1] = { kind = "text", text = "WEAK TO", color = {1.0, 0.5, 0.3, 1} }
            for _, t in ipairs(weaks) do
                els[#els + 1] = { kind = "text", text = t, color = {1.0, 0.65, 0.45, 1} }
            end
        end
    end

    -- Float above the enemy's head. Enemy is in world space; the tooltip draws
    -- in screen space, so convert the anchor onto the centered field.
    local sx, sy = Layout.worldToScreen(enemy.x, enemy.y)
    self:drawLineBox(els, { x = sx, y = sy, halfH = (enemy.h or enemy.size or 20) / 2 })
end

function TooltipManager:drawSimpleTooltip(x, y, text, cost)
    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    local font = love.graphics.getFont()
    local tw = font:getWidth(text)
    local th = font:getHeight()
    love.graphics.rectangle("fill", x, y, tw + 10, th + 10)
    
    if self.game.tokens >= cost then
        love.graphics.setColor(0, 1, 0, 1)
    else
        love.graphics.setColor(1, 0, 0, 1)
    end
    love.graphics.print(text, x + 5, y + 5)
    love.graphics.setColor(1, 1, 1, 1)
end

function TooltipManager:drawRarityTooltip(x, y, probs)
    local padding = 12
    local lineHeight = 22
    local width = 160
    local height = (#probs * lineHeight) + padding * 2
    
    -- Draw shadow/background
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", x, y, width, height, 6)
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.rectangle("line", x, y, width, height, 6)
    
    for i, p in ipairs(probs) do
        love.graphics.setColor(p.color)
        local text = string.format("%s: %.0f%%", p.rarity, p.percent)
        love.graphics.print(text, x + padding, y + padding + (i-1) * lineHeight)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return TooltipManager
