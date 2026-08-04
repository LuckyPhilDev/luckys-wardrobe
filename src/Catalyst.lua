-- luacheck: globals GetInventoryItemLink TransmogUpgradeMaster INVSLOT_FIRST_EQUIPPED INVSLOT_LAST_EQUIPPED

-- Lucky's Wardrobe: Everything the addon knows about the catalyst, which is
-- everything Transmog Upgrade Master will tell it. The game exposes no way to ask
-- what the catalyst turns an item into, so without that addon there is no honest
-- answer and this module says no to everything rather than guessing. Nowhere else
-- names it.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.Catalyst = {}

local Catalyst = LuckysWardrobe.Catalyst

function Catalyst:IsAvailable()
    return TransmogUpgradeMaster_API ~= nil
end

-- Its data loads on a delay and it answers nils until that finishes, which reads
-- as "no" and would silently swallow everything asked early in a session.
local function warmAPI()
    local api = TransmogUpgradeMaster_API
    if not api then return nil end
    if api.IsCacheWarmedUp and not api.IsCacheWarmedUp() then return nil end
    return api
end

--- Whether the catalyst would turn this item into an appearance the player wants.
function Catalyst:WouldTeachAppearance(itemLink)
    local api = warmAPI()
    if not api then return false end

    local ok, canCatalyse, _canUpgrade, catalystMissing = pcall(api.IsAppearanceMissing, itemLink)
    if not ok then
        LuckysWardrobe.DevLog(("Catalyst lookup failed for %s. %s"):format(itemLink, tostring(canCatalyse)))
        return false
    end

    return canCatalyse and catalystMissing or false
end

local playerClassID
local function classID()
    if not playerClassID then
        playerClassID = select(3, UnitClass("player"))
    end
    return playerClassID
end

-- Catalysing an item produces the tier set piece of its own slot, so what a held
-- item is worth is a season, a tier and a slot. Turning that back into the piece
-- itself means reading the tables behind Transmog Upgrade Master, since the API it
-- promises to keep stable only answers yes or no. Those tables are not a promised
-- interface: where they move, this goes quiet rather than pointing at the wrong
-- piece.
--
-- It keeps two, and which one holds the answer depends on how old the season is.
-- Recent seasons are listed as sets, which Blizzard then resolves to sources.
-- Older ones are listed only as the catalyst's own items, one per slot, which
-- carry their sources directly. Both are tried, because a season in one is not
-- necessarily in the other.
local function setSources(seasonID, tier, slot)
    local tum = TransmogUpgradeMaster
    if not tum or not tum.GetSetsForClass then return nil end

    local ok, sets = pcall(tum.GetSetsForClass, tum, classID(), seasonID)
    if not ok then
        LuckysWardrobe.DevLog(("Catalyst set lookup failed for season %s tier %s. %s")
            :format(tostring(seasonID), tostring(tier), tostring(sets)))
        return nil
    end

    -- An empty list is the set knowing nothing about the slot, which is the other
    -- table's cue rather than an answer of none.
    local setID = sets and sets[tier]
    local sources = setID and C_TransmogSets.GetSourcesForSlot(setID, slot)
    return sources and #sources > 0 and sources or nil
end

local function catalystItemSources(seasonID, tier, slot)
    local tum = TransmogUpgradeMaster
    local season = tum and tum.catalystItems and tum.catalystItems[seasonID]
    local byClass = season and season[classID()]
    local itemID = byClass and byClass[slot]
    if not itemID or not tum.GetSourceIDsForItemID then return nil end

    local ok, sourceIDs = pcall(tum.GetSourceIDsForItemID, tum, itemID)
    if not ok then
        LuckysWardrobe.DevLog(("Catalyst item lookup failed for item %s tier %s. %s")
            :format(tostring(itemID), tostring(tier), tostring(sourceIDs)))
        return nil
    end

    local sourceID = sourceIDs and sourceIDs[tier]
    if not sourceID then return nil end

    -- The set path comes back with Blizzard's own collected flag on each source.
    -- This one comes back with a bare source, so the flag is fetched to match.
    local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
    return { { sourceID = sourceID, isCollected = sourceInfo and sourceInfo.isCollected or false } }
end

--- Every source catalysing this item right now would teach, or nil if catalysing
--- it would teach nothing.
local function targetSources(api, itemLink)
    local ok, data = pcall(api.GetAppearanceMissingData, itemLink)
    if not ok or not data or not data.canCatalyse or not data.catalystAppearanceMissing then
        return nil
    end

    local context = data.contextData
    if not context or not context.tier or not context.slot then return nil end

    return setSources(context.seasonID, context.tier, context.slot)
        or catalystItemSources(context.seasonID, context.tier, context.slot)
end

-- Where a catalysable item can be without a bank or a mailbox being open. Worn
-- gear counts the same as bagged gear: a piece looted and put straight on would
-- otherwise drop off the list at the moment it became interesting.
local function heldItemLinks()
    local links = {}
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            links[#links + 1] = C_Container.GetContainerItemLink(bag, slot)
        end
    end

    for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        links[#links + 1] = GetInventoryItemLink("player", slot)
    end

    return links
end

local EMPTY_TARGETS = { bySource = {}, bySet = {}, items = 0 }

local function scan()
    local api = warmAPI()
    if not api then return nil end

    local bySource, bySet, items = {}, {}, 0
    for _, itemLink in ipairs(heldItemLinks()) do
        local counted = false
        for _, source in ipairs(targetSources(api, itemLink) or {}) do
            if not source.isCollected and not bySource[source.sourceID] then
                bySource[source.sourceID] = itemLink
                counted = true
            end
        end
        if counted then items = items + 1 end
    end

    for sourceID in pairs(bySource) do
        for _, setID in ipairs(C_TransmogSets.GetSetsContainingSourceID(sourceID) or {}) do
            bySet[setID] = (bySet[setID] or 0) + 1
        end
    end

    return { bySource = bySource, bySet = bySet, items = items }
end

-- A lookup per held item is too much to repeat on every redraw, and the answer
-- only changes when what is held does.
local held

--- Which pieces the player is already carrying the makings of, keyed by source,
--- and how many sets those pieces belong to. Empty where there is no catalyst data
--- to ask, which is the same shape as carrying nothing.
function Catalyst:GetHeldTargets()
    if not held then held = scan() end
    return held or EMPTY_TARGETS
end

function Catalyst:ForgetHeldTargets()
    held = nil
end

function Catalyst:Init()
    local events = CreateFrame("Frame")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    events:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
    events:SetScript("OnEvent", function()
        Catalyst:ForgetHeldTargets()
        LuckysWardrobe.SetCompletion:RedrawIfShown()
    end)
end
