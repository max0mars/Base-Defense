-- Shop XP: each shop level needs 2 more XP than the last (level N needs 2N),
-- and the XP dots stay inside the 200px stat column at every level.

_G.love = {
    graphics = {
        getFont = function() return { getHeight = function() return 10 end, getWidth = function() return 10 end } end,
        print = function() end,
        printf = function() end,
        rectangle = function() end,
        setColor = function() end,
        circle = function() end
    },
    mouse = { getPosition = function() return 0, 0 end, setVisible = function() end, setCursor = function() end },
    math = { colorFromBytes = function() return 1, 1, 1, 1 end, random = math.random },
    timer = { getTime = function() return 0 end }
}
_G.VIRTUAL_WIDTH = 1280
_G.VIRTUAL_HEIGHT = 720

local preparation_scene = require("Scenes.preparation_scene")

print("--- STARTING SHOP XP VERIFICATION ---")

-- 1. Requirement grows +2 per level
for level = 1, 9 do
    local req = preparation_scene:getRequiredXP(level)
    assert(req == 2 * level, string.format("Level %d should need %d XP, got %d", level, 2 * level, req))
end
print("[PASS] Shop level N needs 2N XP.")

-- 2. addShopXP levels up with the new requirements and carries overflow
_G.PersistentState = { shopLevel = 1, shopXP = 0 }
preparation_scene:addShopXP(2)
assert(_G.PersistentState.shopLevel == 2 and _G.PersistentState.shopXP == 0, "2 XP should reach level 2")
preparation_scene:addShopXP(3)
assert(_G.PersistentState.shopLevel == 2 and _G.PersistentState.shopXP == 3, "Level 2 needs 4 XP, 3 should not level up")
preparation_scene:addShopXP(7) -- 10 total: 4 for level 3, 6 for level 4, 0 left
assert(_G.PersistentState.shopLevel == 4 and _G.PersistentState.shopXP == 0, "Overflow should carry through levels 3 and 4")
print("[PASS] addShopXP follows the new requirements.")

-- 3. Reaching max level from 1 takes 2 + 4 + ... + 18 = 90 XP
_G.PersistentState = { shopLevel = 1, shopXP = 0 }
preparation_scene:addShopXP(89)
assert(_G.PersistentState.shopLevel == 9, "89 XP should stop at level 9")
preparation_scene:addShopXP(1)
assert(_G.PersistentState.shopLevel == 10 and _G.PersistentState.shopXP == 0, "90 XP should reach max level")
print("[PASS] Max level takes 90 XP.")

-- 4. XP dots fit the stat column without overlapping
for level = 1, 9 do
    local req = preparation_scene:getRequiredXP(level)
    local startX, spacing, radius = preparation_scene:getXPDotLayout(req)
    local lastRight = startX + (req - 1) * spacing + radius
    assert(startX - radius >= 0, "First dot clipped at level " .. level)
    assert(lastRight <= startX + preparation_scene.XP_DOT_COLUMN_WIDTH, string.format("Level %d dots overflow the column (%.1f)", level, lastRight))
    assert(req == 1 or spacing - 2 * radius >= 2, string.format("Level %d dots need a 2px gap (spacing %.1f, radius %.1f)", level, spacing, radius))
end
local _, lowSpacing, lowRadius = preparation_scene:getXPDotLayout(2)
assert(lowSpacing == 18 and lowRadius == 6, "Short rows keep the original 18px spacing and 6px dots")
print("[PASS] XP dots fit the stat column at every level.")

print("--- ALL SHOP XP TESTS PASSED ---")
