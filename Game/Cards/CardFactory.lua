-- CardFactory.lua - Builds the deck card a reward choice turns into.
-- Shared by the shop and the card draft so both show (and grant) the same card.
local Card = require("Game.Cards.Card")
local ExecutionType = require("Game.Cards.ExecutionType")
local Utils = require("Classes.Utils")

local CardFactory = {}

local function copyFromRegistry(registry, id)
    for _, entry in pairs(registry) do
        if type(entry) == "table" and entry.id == id then
            local card = Utils.deepCopy(entry)
            card.quantity = 1
            return card
        end
    end
    return nil
end

--- Creates a deck card for a reward choice.
-- @param reward table: Reward choice (from RewardPool or a Reward object)
-- @param config table: Building config for placement cards (defaults to the reward itself)
-- @return table: Card, Spell or Instant ready to add to the deck
function CardFactory.fromReward(reward, config)
    if reward.type == "spell" then
        local card = copyFromRegistry(require("Spells.SpellCardRegistry"), reward.id)
        if card then return card end
    elseif reward.type == "instant" then
        local card = copyFromRegistry(require("Instants.InstantCardRegistry"), reward.id)
        if card then return card end
    end

    local isGlobal = reward.type == "main_upgrade"
    local cardPayload = { rarity = reward.rarity or "common" }
    if isGlobal then
        cardPayload.isMainUpgrade = true
        cardPayload.icons = reward.icons
    else
        cardPayload.buildingClass = reward.building
        cardPayload.config = config or reward
    end

    local card = Card:new({
        id = reward.id,
        name = reward.name,
        description = reward.description,
        cost = reward.cost,
        executionType = isGlobal and ExecutionType.Targeted or ExecutionType.Placement,
        payload = cardPayload
    })
    cardPayload.rewardCard = card:getCardDraw()
    return card
end

return CardFactory
