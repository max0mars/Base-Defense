local mockGame = {
    base = {
        buildGrid = {
            width = 4,
            height = 16,
            buildings = {}
        },
        addBuilding = function(self, b, s)
            self.buildGrid.buildings[s] = b
            b.slot = s
            b.slotsOccupied = {s}
        end
    },
    objects = {},
    newBuilding = function(self, b, s)
        self.base:addBuilding(b, s)
        table.insert(self.objects, b)
    end
}

local InstantCardRegistry = require("Instants.InstantCardRegistry")
local hasty = InstantCardRegistry.HastyDefenses

hasty:execute(mockGame)

local count = 0
for i, v in pairs(mockGame.base.buildGrid.buildings) do
    count = count + 1
    print("Slot " .. i .. " occupied by " .. v.name)
end
print("Total Sentries spawned: " .. count)
