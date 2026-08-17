-- luacheck: globals C_Container C_TransmogCollection C_TransmogSets CreateFrame GetInventoryItemLink INVSLOT_FIRST_EQUIPPED INVSLOT_LAST_EQUIPPED LuckysWardrobe NUM_BAG_SLOTS TransmogUpgradeMaster TransmogUpgradeMaster_API UnitClass
-- luacheck: ignore 121

-- Covers reading what the catalyst would make out of what the player is
-- carrying. Transmog Upgrade Master keeps its answers in two tables and which
-- one holds a season depends on how old that season is, so the fallback between
-- them is what most of this exercises.

local devLogs = {}
LuckysWardrobe = { DevLog = function(message) devLogs[#devLogs + 1] = message end }

local ROGUE = 4
_G.UnitClass = function() return "Rogue", "ROGUE", ROGUE end
_G.CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function() end }
end

-- Two bag slots and one worn slot, which is the shortest inventory that still
-- covers both places a catalysable item can be.
_G.NUM_BAG_SLOTS = 0
_G.INVSLOT_FIRST_EQUIPPED, _G.INVSLOT_LAST_EQUIPPED = 1, 1

local bagLinks = {}
local wornLink
_G.C_Container = {
    GetContainerNumSlots = function() return #bagLinks end,
    GetContainerItemLink = function(_, slot) return bagLinks[slot] end,
}
_G.GetInventoryItemLink = function() return wornLink end

-- What Transmog Upgrade Master says about each held item: which season, tier and
-- slot catalysing it would land on.
local itemContexts = {}
local warmedUp = true
_G.TransmogUpgradeMaster_API = {
    IsCacheWarmedUp = function() return warmedUp end,
    IsAppearanceMissing = function(itemLink)
        local context = itemContexts[itemLink]
        if not context then return false, false, false end
        return true, false, context.catalystMissing ~= false
    end,
    GetAppearanceMissingData = function(itemLink)
        local context = itemContexts[itemLink]
        if not context then return nil end
        return {
            canCatalyse = true,
            catalystAppearanceMissing = context.catalystMissing ~= false,
            contextData = { seasonID = context.seasonID, tier = context.tier, slot = context.slot },
        }
    end,
}

-- The recent-season table: a class's sets per season, which Blizzard then
-- resolves to the sources filling one slot.
local setsByClassSeason = {}
local sourcesForSlot = {}
-- The older-season table: the catalyst's own item per season, class and slot,
-- whose sources are read directly.
local catalystItems = {}
local sourceIDsForItem = {}
local setLookupErrors = {}

_G.TransmogUpgradeMaster = {
    catalystItems = catalystItems,
    GetSetsForClass = function(_, classID, seasonID)
        if setLookupErrors[seasonID] then error("season " .. seasonID .. " is not in this table") end
        local byClass = setsByClassSeason[seasonID]
        return byClass and byClass[classID]
    end,
    GetSourceIDsForItemID = function(_, itemID) return sourceIDsForItem[itemID] end,
}

local collectedSources = {}
_G.C_TransmogSets = {
    GetSourcesForSlot = function(setID, slot) return (sourcesForSlot[setID] or {})[slot] end,
    GetSetsContainingSourceID = function(sourceID)
        return sourceID == 5001 and { 900, 901 } or { 900 }
    end,
}
_G.C_TransmogCollection = {
    GetSourceInfo = function(sourceID) return { isCollected = collectedSources[sourceID] or false } end,
}

dofile("src/domain/Catalyst.lua")
local Catalyst = LuckysWardrobe.Catalyst

-- Without Transmog Upgrade Master there is no honest answer, so everything is no.

local api = _G.TransmogUpgradeMaster_API
_G.TransmogUpgradeMaster_API = nil
assert(not Catalyst:IsAvailable(), "reported the catalyst available with nothing to ask")
assert(not Catalyst:WouldTeachAppearance("item:1"), "answered about an item with nothing to ask")
local none = Catalyst:GetHeldTargets()
assert(next(none.bySource) == nil and next(none.bySet) == nil and none.items == 0,
    "carrying nothing and knowing nothing look the same to the caller")
_G.TransmogUpgradeMaster_API = api
assert(Catalyst:IsAvailable(), "did not notice Transmog Upgrade Master")

-- Its data loads late, and a cold cache answers no to everything. Believing it
-- would swallow every question asked early in a session.

itemContexts["item:tier"] = { seasonID = 2, tier = 3, slot = 5 }
setsByClassSeason[2] = { [ROGUE] = { [3] = 700 } }
sourcesForSlot[700] = { [5] = { { sourceID = 5001, isCollected = false } } }
bagLinks = { "item:tier" }

warmedUp = false
Catalyst:ForgetHeldTargets()
assert(not Catalyst:WouldTeachAppearance("item:tier"), "answered from a cache that had not loaded yet")
assert(Catalyst:GetHeldTargets().items == 0, "scanned against a cache that had not loaded yet")
warmedUp = true

Catalyst:ForgetHeldTargets()
assert(Catalyst:WouldTeachAppearance("item:tier"), "a catalysable item teaching a missing look is worth saying so")
assert(not Catalyst:WouldTeachAppearance("item:nothing"), "an item the catalyst does nothing with is not")

-- The recent-season table answers, and its sources arrive with Blizzard's own
-- collected flag already on them.

local targets = Catalyst:GetHeldTargets()
assert(targets.bySource[5001] == "item:tier", "named the item that would make the missing piece")
assert(targets.items == 1, "counted the item once")
assert(targets.bySet[900] == 1 and targets.bySet[901] == 1, "counted the piece towards every set holding it")

-- A season that table has nothing for falls through to the older one rather than
-- being reported as teaching nothing. Its sources come bare, so the collected
-- flag is fetched to match what the first path hands back.

itemContexts["item:old"] = { seasonID = 1, tier = 2, slot = 6 }
catalystItems[1] = { [ROGUE] = { [6] = 88001 } }
sourceIDsForItem[88001] = { [2] = 6002 }
bagLinks = { "item:old" }
Catalyst:ForgetHeldTargets()

targets = Catalyst:GetHeldTargets()
assert(targets.bySource[6002] == "item:old", "a season only the older table knows was reported as nothing")

-- An empty source list from the first table is the set knowing nothing about the
-- slot, which is the other table's cue rather than an answer of none.

itemContexts["item:both"] = { seasonID = 4, tier = 1, slot = 7 }
setsByClassSeason[4] = { [ROGUE] = { [1] = 701 } }
sourcesForSlot[701] = { [7] = {} }
catalystItems[4] = { [ROGUE] = { [7] = 88002 } }
sourceIDsForItem[88002] = { [1] = 6003 }
bagLinks = { "item:both" }
Catalyst:ForgetHeldTargets()

assert(Catalyst:GetHeldTargets().bySource[6003] == "item:both",
    "an empty slot list was taken as an answer instead of a cue to look elsewhere")

-- These tables are not a promised interface. Where one moves, the lookup goes
-- quiet and tries the other rather than taking the addon down with it.

setLookupErrors[4] = true
Catalyst:ForgetHeldTargets()
assert(Catalyst:GetHeldTargets().bySource[6003] == "item:both",
    "a table that moved stopped the fallback rather than being stepped around")
assert(#devLogs > 0, "said nothing in dev mode about the lookup that failed")
setLookupErrors[4] = nil

-- A piece the player already owns is not something they are carrying the makings
-- of, so it is not counted and neither is the item that would make it.

collectedSources[6003] = true
Catalyst:ForgetHeldTargets()
local owned = Catalyst:GetHeldTargets()
assert(owned.bySource[6003] == nil and owned.items == 0, "counted a piece the player already owns")
collectedSources[6003] = false

-- Worn gear counts the same as bagged gear: a piece looted and put straight on
-- would otherwise drop off the list the moment it became interesting.

bagLinks = {}
wornLink = "item:tier"
Catalyst:ForgetHeldTargets()
assert(Catalyst:GetHeldTargets().bySource[5001] == "item:tier", "ignored what the player is wearing")

-- A lookup per held item is too much for every redraw, so the answer is kept
-- until what is held changes.

local scans = 0
local countingLinks = _G.GetInventoryItemLink
_G.GetInventoryItemLink = function(...)
    scans = scans + 1
    return countingLinks(...)
end
Catalyst:ForgetHeldTargets()
Catalyst:GetHeldTargets()
Catalyst:GetHeldTargets()
assert(scans == 1, "read the player's gear again for an answer it already had")
Catalyst:ForgetHeldTargets()
Catalyst:GetHeldTargets()
assert(scans == 2, "kept a stale answer after what the player holds changed")

print("Lucky's Wardrobe catalyst tests passed")
