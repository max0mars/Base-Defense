local Blocker = require("Buildings.Blockers.Blocker")
local SlottedBlocker = require("Buildings.Blockers.SlottedBlocker")

local function applyRandomRotation(self)
    local rotations = math.random(0, 3)
    if rotations > 0 then
        for _ = 1, rotations do
            for _, coord in ipairs(self.shapePattern) do
                local dx, dy = coord[1], coord[2]
                -- 90 degree rotation: (-dy, dx)
                coord[1] = -dy
                coord[2] = dx
            end
        end
    end
    
    if math.random() <= 0.20 then
        self.building = SlottedBlocker
        local slotIndex = math.random(1, #self.shapePattern)
        local slotCell = self.shapePattern[slotIndex]
        self.turretSlots = { { slotCell[1], slotCell[2] } }
        self.isSlotted = true
    end
end

local BlockerRewardIndex = {
    blocker = {
        {
            id = "blocker_L",
            name = "BLOCKER",
            description = "",
            building = Blocker,
            type = "building",
            iconCategory = "blocker",
            shapePattern = { {0,0}, {1,0}, {0,1} },
            color = {0.9, 0.5, 0.1, 1},
            rarity = "blocker",
            cost = 1,
            affectedSlots = {{0,0}},
            onGenerate = applyRandomRotation
        },
        {
            id = "blocker_T",
            name = "BLOCKER",
            description = "",
            building = Blocker,
            type = "building",
            iconCategory = "blocker",
            shapePattern = { {0,0}, {-1,0}, {1,0}, {0,1} },
            color = {0.9, 0.5, 0.1, 1},
            rarity = "blocker",
            cost = 1,
            affectedSlots = {{0,0}},
            onGenerate = applyRandomRotation
        },
        {
            id = "blocker_Line",
            name = "BLOCKER",
            description = "",
            building = Blocker,
            type = "building",
            iconCategory = "blocker",
            shapePattern = { {0,0}, {0,1}, {0,2} },
            color = {0.9, 0.5, 0.1, 1},
            rarity = "blocker",
            cost = 1,
            affectedSlots = {{0,0}},
            onGenerate = applyRandomRotation
        },
        {
            id = "blocker_Square",
            name = "BLOCKER",
            description = "",
            building = Blocker,
            type = "building",
            iconCategory = "blocker",
            shapePattern = { {0,0}, {1,0}, {0,1}, {1,1} },
            color = {0.9, 0.5, 0.1, 1},
            rarity = "blocker",
            cost = 1,
            affectedSlots = {{0,0}},
            onGenerate = applyRandomRotation
        },
        {
            id = "blocker_BigL",
            name = "BLOCKER",
            description = "",
            building = Blocker,
            type = "building",
            iconCategory = "blocker",
            shapePattern = { {0,0}, {1,0}, {2,0}, {0,1} },
            color = {0.9, 0.5, 0.1, 1},
            rarity = "blocker",
            cost = 1,
            affectedSlots = {{0,0}},
            onGenerate = applyRandomRotation
        },
        {
            id = "blocker_LongT",
            name = "BLOCKER",
            description = "",
            building = Blocker,
            type = "building",
            iconCategory = "blocker",
            shapePattern = { {0,0}, {-1,0}, {1,0}, {0,1}, {0,2} },
            color = {0.9, 0.5, 0.1, 1},
            rarity = "blocker",
            cost = 1,
            affectedSlots = {{0,0}},
            onGenerate = applyRandomRotation
        },
        {
            id = "blocker_Line4",
            name = "BLOCKER",
            description = "",
            building = Blocker,
            type = "building",
            iconCategory = "blocker",
            shapePattern = { {0,0}, {0,1}, {0,2}, {0,3} },
            color = {0.9, 0.5, 0.1, 1},
            rarity = "blocker",
            cost = 1,
            affectedSlots = {{0,0}},
            onGenerate = applyRandomRotation
        },
        {
            id = "blocker_WideT",
            name = "BLOCKER",
            description = "",
            building = Blocker,
            type = "building",
            iconCategory = "blocker",
            shapePattern = { {0,0}, {-1,0}, {1,0}, {2,0}, {0,1} },
            color = {0.9, 0.5, 0.1, 1},
            rarity = "blocker",
            cost = 1,
            affectedSlots = {{0,0}},
            onGenerate = applyRandomRotation
        }
    }
}

-- Blocker pool only has the "blocker" rarity, so we'll duplicate it into all rarity pools
-- so the RewardPool logic doesn't crash when it searches through RarityOrder.
local fullIndex = {
    common = BlockerRewardIndex.blocker,
    uncommon = BlockerRewardIndex.blocker,
    rare = BlockerRewardIndex.blocker,
    epic = BlockerRewardIndex.blocker,
    legendary = BlockerRewardIndex.blocker,
}

return fullIndex
