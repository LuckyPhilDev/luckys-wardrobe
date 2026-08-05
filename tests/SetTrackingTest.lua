-- luacheck: globals C_ContentTracking C_TransmogCollection C_TransmogSets ContentTrackingUtil Enum EventUtil IsShiftKeyDown LuckysWardrobe PlaySound SOUNDKIT WardrobeCollectionFrame WardrobeSetsScrollFrameButtonMixin

LuckysWardrobe = {
    Strings = {
        addon = { prefix = "Wardrobe:" },
        tracking = {
            tracked = "Tracking %d from %s.",
            failed = "%d failed.",
            nothing = "Nothing from %s.",
        },
    },
}

Enum = {
    ContentTrackingType = { Appearance = 1 },
    ContentTrackingError = { Untrackable = 2 },
}

local shiftDown = false
local tracked = {}
local errors = {}
local requestedSetID
local stockClicks = 0

EventUtil = {
    ContinueOnAddOnLoaded = function(_, callback)
        callback()
    end,
}

WardrobeSetsScrollFrameButtonMixin = {
    OnClick = function()
        stockClicks = stockClicks + 1
    end,
}

function IsShiftKeyDown()
    return shiftDown
end

C_TransmogSets = {
    GetSetInfo = function()
        return { name = "Test Set" }
    end,
    GetSetPrimaryAppearances = function(setID)
        requestedSetID = setID
        return {
            { appearanceID = 101, collected = false },
            { appearanceID = 102, collected = true },
            { appearanceID = 103, collected = false },
        }
    end,
}

-- Source IDs live in the 100s and visual IDs in the 1000s, and each lookup only
-- answers for its own ID space, so code that mixes up the two spaces finds
-- nothing instead of echoed-back plausible data. The set's appearanceID values
-- above sit in the source table because GetSetPrimaryAppearances really returns
-- itemModifiedAppearanceIDs; Blizzard's own sets UI passes them straight to
-- GetSourceInfo.
local sourceInfoByID = {
    [101] = { visualID = 1001, playerCanCollect = false },
    [201] = { visualID = 1001, playerCanCollect = true },
    [102] = { visualID = 1002, playerCanCollect = true },
    [103] = { visualID = 1003, playerCanCollect = true },
}
local sourcesByVisualID = {
    [1001] = { 101, 201 },
    [1002] = { 102 },
    [1003] = { 103 },
}

C_TransmogCollection = {
    GetSourceInfo = function(sourceID)
        return sourceInfoByID[sourceID]
    end,
    GetAllAppearanceSources = function(visualID)
        return sourcesByVisualID[visualID]
    end,
}

C_ContentTracking = {
    IsTracking = function(_, sourceID)
        return sourceID == 103
    end,
    StartTracking = function(_, sourceID)
        assert(sourceInfoByID[sourceID], "StartTracking got an ID outside the source ID space")
        table.insert(tracked, sourceID)
    end,
}

ContentTrackingUtil = {
    DisplayTrackingError = function(err)
        table.insert(errors, err)
    end,
}

SOUNDKIT = { UI_TRANSMOG_ITEM_CLICK = 1 }
function PlaySound() end

WardrobeCollectionFrame = {
    SetsCollectionFrame = {
        GetDefaultSetIDForBaseSet = function(_, setID)
            return setID + 1
        end,
    },
}

dofile("src/SetTracking.lua")

local db = { trackSetsOnShiftClick = true }
LuckysWardrobe.SetTracking:Init(db)
local setRow = { setID = 10 }
setmetatable(setRow, { __index = WardrobeSetsScrollFrameButtonMixin })

setRow:OnClick("LeftButton")
assert(#tracked == 0, "ignored clicks without Shift")
assert(stockClicks == 1, "preserved normal stock clicks")

shiftDown = true
setRow:OnClick("RightButton")
assert(#tracked == 0, "ignored Shift-right-click")
assert(stockClicks == 2, "preserved stock clicks other than Shift-left-click")

setRow:OnClick("LeftButton")
assert(requestedSetID == 11, "tracked the selected variant of the clicked base set")
assert(#tracked == 1 and tracked[1] == 201, "tracked a collectible source for each missing visual")
assert(#errors == 0, "did not report an error for a tracked set")
assert(stockClicks == 2, "consumed Shift-left-click")

db.trackSetsOnShiftClick = false
setRow:OnClick("LeftButton")
assert(#tracked == 1, "respected disabled setting")
assert(stockClicks == 3, "restored stock Shift-left-click when disabled")

tracked = {}
LuckysWardrobe.SetTracking:TrackSources({ 102, 103, 201 }, "Extra Set")
assert(#tracked == 2 and tracked[1] == 102 and tracked[2] == 201,
    "tracked the exact sources given, skipping the already-tracked one")
assert(#errors == 0, "did not report an error for trackable sources")

print("Lucky's Wardrobe set tracking test passed")
