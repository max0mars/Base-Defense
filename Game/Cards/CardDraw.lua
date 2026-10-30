local Neon = require("Game.GUI.Neon")
local CardIcons = require("Game.Cards.CardIcons")

local CardDraw = {}
CardDraw.__index = CardDraw

-- Card Dimensions (Static Class Constants)
CardDraw.WIDTH = 250
CardDraw.HEIGHT = 350
CardDraw.RADIUS = 10

-- Synergy icon row, bottom left of the description box (card space)
local ICON_X = 21
local ICON_Y = 325 - CardIcons.SIZE - 6

-- Neon Rarity Colors (RGB values from 0 to 1)
local rarityColors = {
    common = {0.6, 0.6, 0.6},      -- Grey
    uncommon = {0.2, 0.9, 0.2},    -- Green
    rare = {0.2, 0.6, 1.0},        -- Blue
    epic = {0.7, 0.2, 0.9},        -- Purple
    legendary = {1.0, 0.6, 0.0},   -- Orange
    main_weapon = {0.0, 1.0, 0.8}  -- Cyan/Teal
}

-- Calculate continuous fractional bar score (e.g. 1.0 to 5.0)
local STAT_BOUNDS = {
    damage = { min = 5, max = 250 },
    range = { min = 150, max = 1000 },
    fireRate = { min = 0.10, max = 10.0 }
}

function CardDraw.calcBars(statType, value)
    if not value or value <= 0 then return 0 end
    local bounds = STAT_BOUNDS[statType]
    if not bounds then return math.min(5, math.max(0, value)) end
    
    local lo = math.log(bounds.min)
    local hi = math.log(bounds.max)
    local val = math.log(math.max(value, bounds.min * 0.5))
    local norm = (val - lo) / (hi - lo)
    norm = math.max(0, math.min(1, norm))
    
    -- Map norm [0, 1] to continuous 0.0 to 5.0 bars
    local rawBars = norm * 5.0
    -- Round to nearest 1/4th (0.25), with a minimum of 0.25 bars
    local rounded = math.floor(rawBars * 4 + 0.5) / 4
    return math.max(0.25, math.min(5.0, rounded))
end

-- Constructor to create a new card instance
function CardDraw.new(x, y, data)
    local self = setmetatable({}, CardDraw)
    
    -- Positioning
    self.x = x or 0
    self.y = y or 0
    
    -- Card Data
    self.name = data.name or "Unknown Tower"
    self.cost = data.cost or 0
    self.rarity = string.lower(data.rarity or "common")
    self.description = data.description or ""
    
    -- Font setup (high-resolution for crisp scaling)
    -- removed per user request
    -- Adapter Logic for mapping existing properties
    self.cardType = "Building"
    if data.type == "main_upgrade" or data.type == "effect" or data.type == "spell" then
        self.cardType = "Instant"
        if data.type == "main_upgrade" then
            self.instantType = "MainUpgrade"
        elseif data.type == "spell" then
            self.instantType = "Spell"
        elseif data.isTargeted then
            self.instantType = "SingleBuff"
        else
            self.instantType = "GlobalBuff"
        end
    elseif data.type == "building" then
        self.cardType = "Building"
    end
    
    self.buildingType = "Turret"
    if data.iconCategory == "buff" then
        self.buildingType = "Buffer"
    elseif data.iconCategory == "turret" then
        self.buildingType = "Turret"
    end
    
    self.damageBars = data.damageBars or 0
    self.rangeBars = data.rangeBars or 0
    self.firerateBars = data.firerateBars or 0
    
    if (self.damageBars == 0 and self.rangeBars == 0 and self.firerateBars == 0) and self.cardType == "Building" and self.buildingType == "Turret" then
        local t = (data.building and type(data.building) == "table" and data.building.template) or data.template or data.config or data
        if not (t and (t.damage or t.range or t.fireRate)) and data.id then
            local success, rewardIndex = pcall(require, "Game.Rewards.RewardIndex")
            if success and rewardIndex then
                for _, category in pairs(rewardIndex) do
                    if type(category) == "table" then
                        for _, reward in ipairs(category) do
                            if reward.id == data.id then
                                t = (reward.building and type(reward.building) == "table" and reward.building.template) or reward
                                break
                            end
                        end
                    end
                end
            end
        end

        if t and (t.damage or t.range or t.fireRate) then
            local dmg = t.damage or 0
            if t.pelletCount and t.pelletCount > 1 then
                dmg = dmg * t.pelletCount
            elseif t.splitamount and t.splitamount > 0 then
                dmg = dmg * (t.splitamount + 1)
            end
            local rng = t.range or 0
            local fr = t.fireRate or 1
            
            if CardDraw.calcBars then
                self.damageBars = CardDraw.calcBars("damage", dmg)
                self.rangeBars = CardDraw.calcBars("range", rng)
                self.firerateBars = CardDraw.calcBars("fireRate", fr)
            else
                if dmg < 10 then self.damageBars = 1 elseif dmg < 25 then self.damageBars = 2 elseif dmg < 50 then self.damageBars = 3 elseif dmg < 100 then self.damageBars = 4 else self.damageBars = 5 end
                if rng < 250 then self.rangeBars = 1 elseif rng < 350 then self.rangeBars = 2 elseif rng < 550 then self.rangeBars = 3 elseif rng < 750 then self.rangeBars = 4 else self.rangeBars = 5 end
                if fr < 0.3 then self.firerateBars = 1 elseif fr < 0.5 then self.firerateBars = 2 elseif fr < 0.8 then self.firerateBars = 3 elseif fr < 1.5 then self.firerateBars = 4 else self.firerateBars = 5 end
            end
        elseif t and (t.damageBars or t.rangeBars or t.firerateBars) then
            self.damageBars = t.damageBars or self.damageBars
            self.rangeBars = t.rangeBars or self.rangeBars
            self.firerateBars = t.firerateBars or self.firerateBars
        end
    end
    
    self.damageBarsBonus = data.damageBarsBonus or 0
    self.rangeBarsBonus = data.rangeBarsBonus or 0
    self.firerateBarsBonus = data.firerateBarsBonus or 0
    self.tier = data.tier or 1
    self.upgradable = data.upgradable
    
    self.affectedSlots = data.affectedSlots or {}
    self.icons = CardIcons.resolve(data, data.id)
    
    return self
end

-- Draw method
function CardDraw:draw(targetX, targetY, targetW, targetH, isHovered)
    targetX = targetX or self.x
    targetY = targetY or self.y
    targetW = targetW or CardDraw.WIDTH
    targetH = targetH or CardDraw.HEIGHT

    local scaleX = targetW / CardDraw.WIDTH
    local scaleY = targetH / CardDraw.HEIGHT

    local baseColor = rarityColors[self.rarity] or {1, 1, 1}
    local color = {baseColor[1], baseColor[2], baseColor[3]}
    if isHovered then
        color[1] = math.min(1, color[1] + 0.2)
        color[2] = math.min(1, color[2] + 0.2)
        color[3] = math.min(1, color[3] + 0.2)
    end

    local deferredText = {}

    love.graphics.push()
    love.graphics.translate(targetX, targetY)
    love.graphics.scale(scaleX, scaleY)

    -- 1-2. Near-black base with a faint rarity tint, framed by a neon rarity tube
    Neon.rect(0, 0, CardDraw.WIDTH, CardDraw.HEIGHT, color, { radius = CardDraw.RADIUS, width = isHovered and 4 or 3,
        bg = 1, tint = isHovered and 0.1 or 0.05 })

    -- 3. Name Banner (Top). Inner boxes are dimmer so only the frame glows.
    love.graphics.setColor(color[1], color[2], color[3], 0.55)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", 15, 15, CardDraw.WIDTH - 30, 40, 5)

    -- 4. Art/Image Box (Middle)
    love.graphics.rectangle("line", 15, 65, CardDraw.WIDTH - 30, 100, 5)

    -- 5. Text/Description Box (Bottom)
    love.graphics.rectangle("line", 15, 175, CardDraw.WIDTH - 30, 150, 5)

    if self.cardType == "Building" then
        -- Draw Turret Stats or Buffer Icon
        if self.buildingType == "Turret" then
            local startX = 25
            local startY = 75
            local labels = {"Dmg", "Range", "Firerate"}
            local stats = {self.damageBars, self.rangeBars, self.firerateBars}
            local bonusStats = {self.damageBarsBonus, self.rangeBarsBonus, self.firerateBarsBonus}
            local defaultBarColor = {0.6, 0.6, 0.6, 1} -- Standard grey for default stat bars on all cards
            local greenBonusColor = {0.2, 0.9, 0.3, 1} -- Green fill for tier upgrades bonus
            for j = 1, 3 do
                table.insert(deferredText, {t = labels[j], x = startX, y = startY + (j-1)*30, w = 80, a = "left"})
                
                local base = stats[j]
                local bonus = bonusStats[j]
                
                for i = 1, 5 do
                    local rx = startX + 80 + (i-1)*20
                    local ry = startY + (j-1)*30
                    local size = 15
                    
                    -- 1. Slot background (dark subtle grey slot)
                    love.graphics.setColor(defaultBarColor[1], defaultBarColor[2], defaultBarColor[3], 0.25)
                    love.graphics.rectangle("fill", rx, ry, size, size)
                    
                    -- 2. Fill calculation
                    local totalStat = base + bonus
                    
                    -- Check if wrapped bonus (exceeds 5) covers this block
                    if totalStat > 5 and i <= (totalStat - 5 + 0.001) then
                        local wrapFrac = math.min(1, math.max(0, (totalStat - 5) - (i - 1)))
                        if wrapFrac > 0.001 then
                            love.graphics.setColor(greenBonusColor) -- Green bonus
                            love.graphics.rectangle("fill", rx, ry, size, size)
                            love.graphics.setColor(1, 1, 1, 1) -- White inner indicator
                            local fillW = math.max(1, math.floor(9 * wrapFrac + 0.5))
                            love.graphics.rectangle("fill", rx + 3, ry + 3, fillW, 9)
                        end
                    else
                        -- Base stat fill for this block [i-1, i] (Default grey stat bar)
                        local rawBaseFrac = math.min(1, math.max(0, base - (i - 1)))
                        if rawBaseFrac > 0.001 then
                            local fillW = (rawBaseFrac >= 0.999) and size or math.floor(size * rawBaseFrac + 0.5)
                            love.graphics.setColor(defaultBarColor)
                            love.graphics.rectangle("fill", rx, ry, fillW, size)
                        end
                        
                        -- Bonus fill for this block (Vibrant green bonus)
                        local bonusStart = base
                        local bonusEnd = base + bonus
                        local blockStart = i - 1
                        local blockEnd = i
                        
                        local activeStart = math.max(blockStart, bonusStart)
                        local activeEnd = math.min(blockEnd, bonusEnd)
                        if activeEnd - activeStart > 0.001 then
                            local xOffset = math.floor((activeStart - blockStart) * size + 0.5)
                            local w = math.floor((activeEnd - activeStart) * size + 0.5)
                            if xOffset + w > size then w = size - xOffset end
                            love.graphics.setColor(greenBonusColor) -- Green bonus
                            love.graphics.rectangle("fill", rx + xOffset, ry, w, size)
                        end
                    end
                    
                    -- 3. Draw clean 1px border outline ON TOP of the fill
                    love.graphics.setLineWidth(1)
                    love.graphics.setColor(defaultBarColor)
                    love.graphics.rectangle("line", rx, ry, size, size)
                end
            end
            love.graphics.setColor(color) -- reset color for the rest of the drawing
        elseif self.buildingType == "Buffer" then
            local cx = CardDraw.WIDTH / 2
            local cy = 115
            local sqSize = 20
            local spacing = 22
            
            -- draw center (0,0)
            love.graphics.setColor(0.5, 0.5, 0.5, 1) -- Grey
            love.graphics.rectangle("fill", cx - sqSize/2, cy - sqSize/2, sqSize, sqSize)
            
            -- draw affected slots
            love.graphics.setColor(0.2, 0.9, 0.2, 1) -- Green
            for _, slot in ipairs(self.affectedSlots) do
                local dx, dy = slot[1], slot[2]
                love.graphics.rectangle("fill", cx + dx*spacing - sqSize/2, cy + dy*spacing - sqSize/2, sqSize, sqSize)
            end
            love.graphics.setColor(color) -- Reset to border color
        end
    elseif self.cardType == "Instant" then
        local cx = CardDraw.WIDTH / 2
        local cy = 115
        
        if self.instantType == "SingleBuff" then
            love.graphics.setColor(0.2, 0.9, 0.2, 1) -- Green
            love.graphics.setLineWidth(4)
            love.graphics.line(cx - 15, cy, cx + 15, cy)
            love.graphics.line(cx, cy - 15, cx, cy + 15)
            
            -- Small red reticle in bottom left
            love.graphics.setColor(0.9, 0.1, 0.1, 1) -- Red
            love.graphics.setLineWidth(2)
            local rx, ry = cx - 18, cy + 18
            love.graphics.circle("line", rx, ry, 6)
            love.graphics.line(rx - 9, ry, rx - 4, ry)
            love.graphics.line(rx + 4, ry, rx + 9, ry)
            love.graphics.line(rx, ry - 9, rx, ry - 4)
            love.graphics.line(rx, ry + 4, rx, ry + 9)
            love.graphics.circle("fill", rx, ry, 1.5)
            
            love.graphics.setLineWidth(1)
        elseif self.instantType == "GlobalBuff" then
            love.graphics.setColor(0.2, 0.9, 0.2, 1) -- Green
            love.graphics.setLineWidth(4)
            -- Center +
            love.graphics.line(cx - 15, cy, cx + 15, cy)
            love.graphics.line(cx, cy - 15, cx, cy + 15)
            -- 4 smaller + around
            love.graphics.setLineWidth(2)
            local offset = 25
            local smallSize = 8
            local positions = {
                {cx - offset, cy - offset},
                {cx + offset, cy - offset},
                {cx - offset, cy + offset},
                {cx + offset, cy + offset}
            }
            for _, pos in ipairs(positions) do
                local px, py = pos[1], pos[2]
                love.graphics.line(px - smallSize, py, px + smallSize, py)
                love.graphics.line(px, py - smallSize, px, py + smallSize)
            end
            love.graphics.setLineWidth(1)
        elseif self.instantType == "MainUpgrade" then
            -- Draw a turret symbol with a small plus sign in the top right
            love.graphics.setColor(0.4, 0.4, 0.4, 1) -- Dark grey silhouette
            -- Turret side-view silhouette
            -- Base: wide and short, but skinnier
            love.graphics.rectangle("fill", cx - 10, cy + 10, 20, 5, 1) 
            -- Middle part: taller, narrower, sitting on base
            love.graphics.rectangle("fill", cx - 6, cy, 12, 10, 1) 
            -- Barrel: long, thin, pointing right from the middle part
            love.graphics.rectangle("fill", cx, cy + 2, 20, 4, 1)
            
            -- small plus sign in top right
            love.graphics.setColor(0.2, 0.9, 0.2, 1) -- Green plus
            love.graphics.setLineWidth(3)
            local px, py = cx + 18, cy - 18
            love.graphics.line(px - 5, py, px + 5, py)
            love.graphics.line(px, py - 5, px, py + 5)
            love.graphics.setLineWidth(1)
        elseif self.instantType == "Spell" then
            love.graphics.setColor(0.9, 0.1, 0.1, 1) -- Red
            love.graphics.setLineWidth(3)
            -- Outer circle
            love.graphics.circle("line", cx, cy, 20)
            -- Crosshair lines
            love.graphics.line(cx - 30, cy, cx - 10, cy)
            love.graphics.line(cx + 10, cy, cx + 30, cy)
            love.graphics.line(cx, cy - 30, cx, cy - 10)
            love.graphics.line(cx, cy + 10, cx, cy + 30)
            -- Center dot
            love.graphics.circle("fill", cx, cy, 3)
            love.graphics.setLineWidth(1)
        end
        love.graphics.setColor(color) -- Reset border color
    end

    -- 6. Energy Circle/Hexagon (Top Left)
    -- Mask out the banner lines underneath the circle/hexagon
    local isSpellCard = (self.cardType == "Instant" and self.instantType == "Spell")
    if isSpellCard then
        love.graphics.setColor(0.1, 0.45, 0.9, 1) -- Blue hexagon for mana
        local vertices = {}
        for i = 1, 6 do
            local angle = (i - 1) * (math.pi / 3) - math.pi / 6
            table.insert(vertices, 15 + math.cos(angle) * 25)
            table.insert(vertices, 35 + math.sin(angle) * 25)
        end
        love.graphics.polygon("fill", vertices)
    else
        love.graphics.setColor(Neon.BG[1], Neon.BG[2], Neon.BG[3], 1)
        love.graphics.circle("fill", 15, 35, 25)
    end
    
    -- Outer/inner neon ring/hexagon detailing
    if isSpellCard then
        local vertices = {}
        for i = 1, 6 do
            local angle = (i - 1) * (math.pi / 3) - math.pi / 6
            table.insert(vertices, 15 + math.cos(angle) * 25)
            table.insert(vertices, 35 + math.sin(angle) * 25)
        end
        Neon.polygon(vertices, color, 3)
        love.graphics.setColor(color)
        
        love.graphics.setLineWidth(1)
        local vertices_inner = {}
        for i = 1, 6 do
            local angle = (i - 1) * (math.pi / 3) - math.pi / 6
            table.insert(vertices_inner, 15 + math.cos(angle) * 18)
            table.insert(vertices_inner, 35 + math.sin(angle) * 18)
        end
        love.graphics.polygon("line", vertices_inner)
    else
        Neon.circle(15, 35, 25, color, 3)
        love.graphics.setColor(color[1], color[2], color[3], 0.55)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", 15, 35, 18)
    end

    -- 7. Populate Text Fields dynamically
    love.graphics.setColor(1, 1, 1, 1) -- Set text color to white
    
    -- Render Cost Text (Centered inside the circle)
    table.insert(deferredText, {t = tostring(self.cost), x = -10, y = 25, w = 50, a = "center"})
    
    -- Render Name and Tier Text (Slight offset inside the name banner)
    local isUpgradable = self.upgradable
    if isUpgradable == nil then
        isUpgradable = self.cardType == "Building" and self.buildingType == "Turret"
    end
    if isUpgradable then
        local tierRoman = ({"I", "II", "III", "IV", "V"})[self.tier or 1] or "I"
        table.insert(deferredText, {t = self.name, x = 45, y = 27, w = CardDraw.WIDTH - 115, a = "left"})
        table.insert(deferredText, {t = tierRoman, x = CardDraw.WIDTH - 70, y = 27, w = 45, a = "center"})
    else
        table.insert(deferredText, {t = self.name, x = 45, y = 27, w = CardDraw.WIDTH - 65, a = "left"})
    end
    
    -- 8. Synergy icons (bottom left of the description box)
    local iconStrip = 0
    if self.icons and #self.icons > 0 then
        iconStrip = CardIcons.SIZE + 8
        CardIcons.drawRow(self.icons, ICON_X, ICON_Y)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Render Description Text (centred in the space above the icons)
    local boxHeight = 150 - iconStrip
    local descLimit = CardDraw.WIDTH - 50
    
    -- Calculate wrapped text height using the scaled limit that printf will use
    local screenLimit = descLimit * scaleX
    local _, wrappedText = love.graphics.getFont():getWrap(self.description, screenLimit)
    local screenTextHeight = #wrappedText * love.graphics.getFont():getHeight()
    
    -- Calculate center in screen space, then map back to local Y
    local screenBoxHeight = boxHeight * scaleY
    local screenBoxCenter = 175 * scaleY + screenBoxHeight / 2
    local screenTextY = screenBoxCenter - screenTextHeight / 2
    local textY = screenTextY / scaleY
    
    table.insert(deferredText, {t = self.description, x = 25, y = textY, w = descLimit, a = "center"})

    love.graphics.pop()
    
    love.graphics.setColor(1, 1, 1, 1)
    for _, dt in ipairs(deferredText) do
        love.graphics.printf(dt.t, targetX + dt.x * scaleX, targetY + dt.y * scaleY, dt.w * scaleX, dt.a, 0)
    end
end

--- The synergy icon under the screen point (px, py) on a card drawn at the given rect.
-- @return string|nil: icon name, plus the icon's top-centre in screen space
function CardDraw:iconAt(px, py, targetX, targetY, targetW, targetH)
    if not self.icons or #self.icons == 0 then return nil end
    targetX = targetX or self.x
    targetY = targetY or self.y
    local scaleX = (targetW or CardDraw.WIDTH) / CardDraw.WIDTH
    local scaleY = (targetH or CardDraw.HEIGHT) / CardDraw.HEIGHT
    local name, i = CardIcons.iconAt(self.icons, ICON_X, ICON_Y, (px - targetX) / scaleX, (py - targetY) / scaleY)
    if not name then return nil end
    local iconCentreX = ICON_X + (i - 1) * (CardIcons.SIZE + CardIcons.SPACING) + CardIcons.SIZE / 2
    return name, targetX + iconCentreX * scaleX, targetY + ICON_Y * scaleY
end

-- Shared so other UI (e.g. the building hover window) matches the cards
CardDraw.RARITY_COLORS = rarityColors

return CardDraw
