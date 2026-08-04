-- luacheck: globals EventUtil

-- Lucky's Wardrobe: Shift-click tracking for Blizzard's stock set list.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.SetTracking = {}

local SetTracking = LuckysWardrobe.SetTracking
local APPEARANCE = Enum.ContentTrackingType.Appearance

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

local function trackAppearance(sourceID)
    local candidates = getCandidates(sourceID)

    for _, candidateID in ipairs(candidates) do
        if C_ContentTracking.IsTracking(APPEARANCE, candidateID) then
            return false
        end
    end

    local lastError = Enum.ContentTrackingError.Untrackable
    for _, candidateID in ipairs(candidates) do
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
        print(LuckysWardrobe.Strings.addon.prefix .. " " .. message)
        PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
    elseif lastError then
        ContentTrackingUtil.DisplayTrackingError(lastError)
    else
        print(LuckysWardrobe.Strings.addon.prefix .. " " .. LuckysWardrobe.Strings.tracking.nothing:format(setName))
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
    local missing = {}
    for _, appearance in ipairs(C_TransmogSets.GetSetPrimaryAppearances(setID) or {}) do
        if not appearance.collected then missing[#missing + 1] = appearance.appearanceID end
    end

    reportTracking((setInfo and setInfo.name) or tostring(setID), trackAll(missing))
end

-- Tracks exact appearance sources by ID, used by the Extra Sets page where the
-- catalogue rather than a runtime set defines the membership.
function SetTracking:TrackSources(sourceIDs, setName)
    reportTracking(setName or "?", trackAll(sourceIDs))
end

function SetTracking:Init(db)
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", function()
        local stockOnClick = WardrobeSetsScrollFrameButtonMixin.OnClick
        function WardrobeSetsScrollFrameButtonMixin:OnClick(mouseButton, ...)
            if db.trackSetsOnShiftClick and mouseButton == "LeftButton" and IsShiftKeyDown() then
                local setID = WardrobeCollectionFrame.SetsCollectionFrame:GetDefaultSetIDForBaseSet(self.setID)
                SetTracking:TrackSet(setID or self.setID)
                return
            end

            return stockOnClick(self, mouseButton, ...)
        end
    end)
end
