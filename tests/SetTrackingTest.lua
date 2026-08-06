-- luacheck: globals C_ContentTracking C_TransmogCollection C_TransmogSets ContentTrackingUtil Enum EventUtil IsShiftKeyDown LuckysWardrobe PlaySound SOUNDKIT WardrobeCollectionFrame WardrobeSetsScrollFrameButtonMixin

LuckysWardrobe = {
    Strings = {
        addon = { prefix = "Wardrobe:" },
        tracking = {
            hint = "Shift-click to track this appearance.",
            stopHint = "Shift-click to stop tracking it.",
            stopped = "Stopped tracking %d from %s.",
            tracked = "Tracking %d from %s.",
            failed = "%d failed.",
            nothing = "Nothing from %s.",
        },
    },
}

Enum = {
    ContentTrackingType = { Appearance = 1 },
    ContentTrackingError = { Untrackable = 2 },
    ContentTrackingStopType = { Manual = 2 },
}

local shiftDown = false
local tracked = {}
local stopped = {}
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

-- The details pane stamps its piece frames from this mixin, so wrapping it is
-- what reaches a click on one piece of the set on show.
local stockPieceClicks = 0
WardrobeSetsDetailsItemMixin = {
    OnMouseDown = function()
        stockPieceClicks = stockPieceClicks + 1
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
    [102] = { visualID = 1002, playerCanCollect = true, isCollected = true },
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
    StopTracking = function(_, sourceID, stopType)
        assert(sourceInfoByID[sourceID], "StopTracking got an ID outside the source ID space")
        table.insert(stopped, { id = sourceID, stopType = stopType })
    end,
}

ContentTrackingUtil = {
    DisplayTrackingError = function(err)
        table.insert(errors, err)
    end,
}

SOUNDKIT = { UI_TRANSMOG_ITEM_CLICK = 1, CONTENT_TRACKING_STOP_TRACKING = 2 }
function PlaySound() end

WardrobeCollectionFrame = {
    SetsCollectionFrame = {
        GetDefaultSetIDForBaseSet = function(_, setID)
            return setID + 1
        end,
        GetSelectedSetID = function()
            return 11
        end,
    },
}

dofile("src/Utils.lua")
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

-- Shift-clicking the set again calls all of it off, the way a single piece
-- already toggles, as long as every last piece it tracked is still tracked.
C_ContentTracking.IsTracking = function(_, sourceID) return sourceID == 103 or sourceID == 201 end
setRow:OnClick("LeftButton")
assert(#stopped == 2 and stopped[1].id == 201 and stopped[2].id == 103,
    "called off the whole set it had just tracked")
assert(#tracked == 1, "tracked nothing new on the untracking click")
C_ContentTracking.IsTracking = function(_, sourceID) return sourceID == 103 end

-- Source 101 is not itself tracked, but 201 teaches the same look and is, which
-- is what the crosshair on a set's pieces asks about.
assert(LuckysWardrobe.SetTracking:IsTracking(103), "saw a source tracked outright")
assert(LuckysWardrobe.SetTracking:IsTracking(101) == false, "saw a look nothing tracks as untracked")
C_ContentTracking.IsTracking = function(_, sourceID) return sourceID == 201 end
assert(LuckysWardrobe.SetTracking:IsTracking(101), "saw a look tracked through another item that teaches it")
C_ContentTracking.IsTracking = function(_, sourceID) return sourceID == 103 end

-- One piece of the set on show, for someone hunting a single item. The stock
-- click still runs, so a shift-click with chat open links the item as well.
local piece = setmetatable({ sourceID = 201, collected = false }, { __index = WardrobeSetsDetailsItemMixin })
local collectedPiece = setmetatable({ sourceID = 202, collected = true }, { __index = WardrobeSetsDetailsItemMixin })

piece:OnMouseDown("LeftButton")
assert(#tracked == 2 and tracked[2] == 201, "shift-clicking a piece tracked that piece")
assert(stockPieceClicks == 1, "left the stock piece click running underneath")

collectedPiece:OnMouseDown("LeftButton")
assert(#tracked == 2, "left a piece already collected alone")

shiftDown = false
piece:OnMouseDown("LeftButton")
assert(#tracked == 2, "ignored a piece click without Shift")
assert(stockPieceClicks == 3, "still ran the stock piece click")
shiftDown = true

-- The Sets tab says nothing about tracking of its own, so the tooltip is where
-- the shift-click is offered, on a piece it would actually act on.
local tooltip = { lines = {}, AddLine = function(self, text) self.lines[#self.lines + 1] = text end, Show = function() end }
assert(LuckysWardrobe.SetTracking:AddTrackHint(tooltip, 101), "offered the shift-click on a missing piece")
assert(tooltip.lines[1] == LuckysWardrobe.Strings.tracking.hint, "offered it in words")
assert(LuckysWardrobe.SetTracking:AddTrackHint(tooltip, 102) == false, "said nothing over a piece already collected")
assert(#tooltip.lines == 1, "added no line for a collected piece")

-- Clicking a piece already tracked calls it off instead, and it is the item that
-- taught the look that stops, which is not always the one clicked.
C_ContentTracking.IsTracking = function(_, sourceID) return sourceID == 201 end

assert(LuckysWardrobe.SetTracking:AddTrackHint(tooltip, 101), "offered the shift-click over a tracked piece too")
assert(tooltip.lines[2] == LuckysWardrobe.Strings.tracking.stopHint, "offered the way out rather than the way in")

local trackedSoFar = #tracked
piece:OnMouseDown("LeftButton")
assert(#tracked == trackedSoFar, "did not track a piece that is already tracked")
assert(#stopped == 3 and stopped[3].id == 201, "stopped tracking it instead")
assert(stopped[3].stopType == Enum.ContentTrackingStopType.Manual, "and stopped it as a deliberate choice")

local sharedLookPiece = setmetatable({ sourceID = 101, collected = false }, { __index = WardrobeSetsDetailsItemMixin })
sharedLookPiece:OnMouseDown("LeftButton")
assert(#stopped == 4 and stopped[4].id == 201,
    "called off the item that taught the look, not the one clicked")

C_ContentTracking.IsTracking = function(_, sourceID) return sourceID == 103 end

db.trackSetsOnShiftClick = false
setRow:OnClick("LeftButton")
assert(#tracked == 2, "respected disabled setting")
assert(stockClicks == 3, "restored stock Shift-left-click when disabled")

piece:OnMouseDown("LeftButton")
assert(#tracked == 2, "left piece clicks alone when disabled")
assert(LuckysWardrobe.SetTracking:AddTrackHint(tooltip, 101) == false, "stopped offering the shift-click when disabled")
db.trackSetsOnShiftClick = true

tracked = {}
LuckysWardrobe.SetTracking:TrackSources({ 102, 103, 201 }, "Extra Set")
assert(#tracked == 2 and tracked[1] == 102 and tracked[2] == 201,
    "tracked the exact sources given, skipping the already-tracked one")
assert(#errors == 0, "did not report an error for trackable sources")

print("Lucky's Wardrobe set tracking test passed")
