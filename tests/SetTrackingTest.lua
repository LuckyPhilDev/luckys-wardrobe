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

C_TransmogCollection = {
    GetSourceInfo = function(sourceID)
        return {
            visualID = sourceID == 101 and 1001 or sourceID,
            playerCanCollect = sourceID ~= 101,
        }
    end,
    GetAllAppearanceSources = function(visualID)
        return visualID == 1001 and { 101, 201 } or { visualID }
    end,
}

C_ContentTracking = {
    IsTracking = function(_, sourceID)
        return sourceID == 103
    end,
    StartTracking = function(_, sourceID)
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

print("Lucky's Wardrobe set tracking test passed")
