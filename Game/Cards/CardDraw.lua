local CardDraw = {}
CardDraw.__index = CardDraw

-- Card Dimensions (Static Class Constants)
CardDraw.WIDTH = 250
CardDraw.HEIGHT = 350
CardDraw.RADIUS = 10

-- Neon Rarity Colors (RGB values from 0 to 1)
local rarityColors = {
    common = {0.6, 0.6, 0.6},      -- Grey
    uncommon = {0.2, 0.9, 0.2},    -- Green
    rare = {0.2, 0.6, 1.0},        -- Blue
    epic = {0.7, 0.2, 0.9},        -- Purple
    legendary = {1.0, 0.6, 0.0},   -- Orange
    main_weapon = {0.0, 1.0, 0.8}  -- Cyan/Teal
}

-- Constructor to create a new card instance
function CardDraw.new(x, y, data)
    local self = setmetatable({}, CardDraw)
    
    -- Positioning
    self.x = x or 0
    self.y = y or 0
    
    -- Card Data
    self.name = data.name or "Unknown Tower"
    self.cost = data.cost or 0
    self.rarity = data.rarity or "common"
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
    if data.iconCategory == "buff" or data.iconCategory == "blocker" then
        self.buildingType = "Buffer"
    elseif data.iconCategory == "turret" then
        self.buildingType = "Turret"
    end
    
    self.damageBars = data.damageBars or 0
    self.rangeBars = data.rangeBars or 0
    self.firerateBars = data.firerateBars or 0
    self.affectedSlots = data.affectedSlots or {}
    
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

    -- 1. Card Base (Dark contrast background)
    love.graphics.setColor(0.08, 0.08, 0.08, 1)
    love.graphics.rectangle("fill", 0, 0, CardDraw.WIDTH, CardDraw.HEIGHT, CardDraw.RADIUS)

    -- 2. Outer Neon Border
    love.graphics.setLineWidth(3)
    love.graphics.setColor(color)
    love.graphics.rectangle("line", 0, 0, CardDraw.WIDTH, CardDraw.HEIGHT, CardDraw.RADIUS)

    -- 3. Name Banner (Top)
    love.graphics.setLineWidth(2)
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
            for j = 1, 3 do
                table.insert(deferredText, {t = labels[j], x = startX, y = startY + (j-1)*30, w = 80, a = "left"})
                for i = 1, 5 do
                    if i <= stats[j] then
                        love.graphics.rectangle("fill", startX + 80 + (i-1)*20, startY + (j-1)*30, 15, 15)
                    else
                        love.graphics.rectangle("line", startX + 80 + (i-1)*20, startY + (j-1)*30, 15, 15)
                    end
                end
            end
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

    -- 6. Energy Circle (Top Left)
    -- Mask out the banner lines underneath the circle
    love.graphics.setColor(0.08, 0.08, 0.08, 1)
    love.graphics.circle("fill", 15, 35, 25)
    
    -- Outer/inner neon ring detailing
    love.graphics.setColor(color)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 15, 35, 25)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", 15, 35, 18)

    -- 7. Populate Text Fields dynamically
    love.graphics.setColor(1, 1, 1, 1) -- Set text color to white
    
    -- Render Cost Text (Centered inside the circle)
    table.insert(deferredText, {t = tostring(self.cost), x = -10, y = 25, w = 50, a = "center"})
    
    -- Render Name Text (Slight offset inside the name banner)
    table.insert(deferredText, {t = self.name, x = 45, y = 27, w = CardDraw.WIDTH - 65, a = "left"})
    
    -- Render Description Text
    local boxHeight = 150
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

return CardDraw
