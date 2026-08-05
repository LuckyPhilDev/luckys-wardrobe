-- luacheck: globals EventUtil WardrobeCollectionFrame WardrobeSetsDetailsItemMixin

-- Lucky's Wardrobe: Shift-click tracking for Blizzard's stock set list. A whole
-- set from the list itself, or one piece of the set on show, which the same
-- click calls off again.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.SetTracking = {}

local SetTracking = LuckysWardrobe.SetTracking
local APPEARANCE = Enum.ContentTrackingType.Appearance
local db

local function getCandidates(sourceID)
    local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
    local candidates = { sourceID }
    local alternates = sourceInfo and sourceInfo.visualID
        and C_TransmogCollection.GetAllAppearanceSources(sourceInfo.visualID) or {}

    for _, alternateID in ipairs(alternates) do
        if alternateID ~= sourceID then
            table.insert(candidates, alternateID)
        end
    end

    return candidates
end

-- A set piece is one item of a look several items share, and tracking any of
-- them is hunting for this piece.
function SetTracking:IsTracking(sourceID)
    for _, candidateID in ipairs(getCandidates(sourceID)) do
        if C_ContentTracking.IsTracking(APPEARANCE, candidateID) then
            return true
        end
    end

    return false
end

local function trackAppearance(sourceID)
    if SetTracking:IsTracking(sourceID) then
        return false
    end

    local lastError = Enum.ContentTrackingError.Untrackable
    for _, candidateID in ipairs(getCandidates(sourceID)) do
        local sourceInfo = C_TransmogCollection.GetSourceInfo(candidateID)
        if sourceInfo and sourceInfo.playerCanCollect then
            local ok, err = pcall(C_ContentTracking.StartTracking, APPEARANCE, candidateID)
            if ok and not err then
                return true
            end
            lastError = ok and err or Enum.ContentTrackingError.Untrackable
        end
    end

    return false, lastError
end

local function reportTracking(setName, tracked, failed, lastError)
    if tracked > 0 then
        local message = LuckysWardrobe.Strings.tracking.tracked:format(tracked, setName)
        if failed > 0 then
            message = message .. " " .. LuckysWardrobe.Strings.tracking.failed:format(failed)
        end
        LuckysWardrobe.Utils.Say(message)
        PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
    elseif lastError then
        ContentTrackingUtil.DisplayTrackingError(lastError)
    else
        LuckysWardrobe.Utils.Say(LuckysWardrobe.Strings.tracking.nothing:format(setName))
    end
end

local function trackAll(sourceIDs)
    local tracked, failed, lastError = 0, 0, nil
    for _, sourceID in ipairs(sourceIDs) do
        local didTrack, err = trackAppearance(sourceID)
        if didTrack then
            tracked = tracked + 1
        elseif err then
            failed = failed + 1
            lastError = err
        end
    end
    return tracked, failed, lastError
end

function SetTracking:TrackSet(setID)
    local setInfo = C_TransmogSets.GetSetInfo(setID)
    -- Despite the field name, appearanceID holds an itemModifiedAppearanceID
    -- (source ID); Blizzard's own sets UI feeds it straight to GetSourceInfo.
    local missingSources = {}
    for _, appearance in ipairs(C_TransmogSets.GetSetPrimaryAppearances(setID) or {}) do
        if not appearance.collected then
            missingSources[#missingSources + 1] = appearance.appearanceID
        end
    end

    reportTracking((setInfo and setInfo.name) or tostring(setID), trackAll(missingSources))
end

-- Tracks exact appearance sources by ID, used by the Extra Sets page where the
-- catalogue rather than a runtime set defines the membership.
function SetTracking:TrackSources(sourceIDs, setName)
    reportTracking(setName or "?", trackAll(sourceIDs))
end

-- Whichever item taught the look is the one being tracked, and it is not always
-- the one clicked, so every item that teaches it is called off.
local function untrackAppearance(sourceID, setName)
    local stopped = 0
    for _, candidateID in ipairs(getCandidates(sourceID)) do
        if C_ContentTracking.IsTracking(APPEARANCE, candidateID) then
            C_ContentTracking.StopTracking(APPEARANCE, candidateID, Enum.ContentTrackingStopType.Manual)
            stopped = stopped + 1
        end
    end

    if stopped == 0 then return end

    LuckysWardrobe.Utils.Say(LuckysWardrobe.Strings.tracking.stopped:format(setName or "?"))
    PlaySound(SOUNDKIT.CONTENT_TRACKING_STOP_TRACKING)
end

-- Shift-clicking one piece is a toggle: the first click starts hunting it, the
-- next calls it off, the way the game's own appearance list works.
function SetTracking:TogglePiece(sourceID, setName)
    if self:IsTracking(sourceID) then
        untrackAppearance(sourceID, setName)
    else
        self:TrackSources({ sourceID }, setName)
    end
end

-- Every place that answers a shift-click asks here, which is also where turning
-- the setting off hands the click back.
function SetTracking:HandlesShiftClick(button)
    return button == "LeftButton" and IsShiftKeyDown() and db.trackSetsOnShiftClick or false
end

-- Says which way the shift-click would go, on a piece it would act on. The Sets
-- tab says nothing about tracking of its own, so a piece there is silent about
-- the one thing you can do with it.
function SetTracking:AddTrackHint(tooltip, sourceID)
    if not db.trackSetsOnShiftClick or not sourceID then return false end

    local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
    if not sourceInfo or sourceInfo.isCollected then return false end

    local S = LuckysWardrobe.Strings.tracking
    tooltip:AddLine(self:IsTracking(sourceID) and S.stopHint or S.hint, 0.5, 0.8, 1)
    tooltip:Show()
    return true
end

-- One piece of the set on show, for someone hunting a single item rather than
-- the whole thing. The set names it so the report reads the same either way.
local function togglePiece(itemFrame)
    if itemFrame.collected or not itemFrame.sourceID then return end

    local setID = WardrobeCollectionFrame.SetsCollectionFrame:GetSelectedSetID()
    local setInfo = setID and C_TransmogSets.GetSetInfo(setID)
    SetTracking:TogglePiece(itemFrame.sourceID, setInfo and setInfo.name)
end

function SetTracking:Init(database)
    db = database

    EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", function()
        local stockOnClick = WardrobeSetsScrollFrameButtonMixin.OnClick
        function WardrobeSetsScrollFrameButtonMixin:OnClick(mouseButton, ...)
            if SetTracking:HandlesShiftClick(mouseButton) then
                local setID = WardrobeCollectionFrame.SetsCollectionFrame:GetDefaultSetIDForBaseSet(self.setID)
                SetTracking:TrackSet(setID or self.setID)
                return
            end

            return stockOnClick(self, mouseButton, ...)
        end

        -- The details pane stamps its piece frames from this mixin on demand, so
        -- wrapping it reaches every one of them. Shift-click adds to the stock
        -- click here rather than taking it, the way the Items tab does, so a
        -- shift-click with chat open still links the item as well.
        local stockPieceMouseDown = WardrobeSetsDetailsItemMixin.OnMouseDown
        function WardrobeSetsDetailsItemMixin:OnMouseDown(button, ...)
            stockPieceMouseDown(self, button, ...)
            if SetTracking:HandlesShiftClick(button) then
                togglePiece(self)
            end
        end
    end)
end
