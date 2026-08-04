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

function SetTracking:TrackSet(setID)
    local setInfo = C_TransmogSets.GetSetInfo(setID)
    local appearances = C_TransmogSets.GetSetPrimaryAppearances(setID) or {}
    local tracked, failed, lastError = 0, 0, nil

    for _, appearance in ipairs(appearances) do
        if not appearance.collected then
            local didTrack, err = trackAppearance(appearance.appearanceID)
            if didTrack then
                tracked = tracked + 1
            elseif err then
                failed = failed + 1
                lastError = err
            end
        end
    end

    local setName = (setInfo and setInfo.name) or tostring(setID)
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
