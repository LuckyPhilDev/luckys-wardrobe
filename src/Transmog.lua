-- luacheck: globals C_Timer CreateFrame TransmogFrame hooksecurefunc

-- Lucky's Ensemble: Keep the active transmog tab during outfit refreshes, and
-- host the appearance randomiser's session on the same transmogrifier events.
LuckysEnsemble = LuckysEnsemble or {}
LuckysEnsemble.Transmog = {}

local db
local hooked = false
local userTab
local watcher

local function installHooks()
    if hooked then return end
    local wardrobe = TransmogFrame and TransmogFrame.WardrobeCollection
    if not wardrobe or not wardrobe.TabHeaders or type(wardrobe.SetTab) ~= "function" then return end
    if type(TransmogFrame.SelectSlot) ~= "function" then return end

    local tabHeaders = wardrobe.TabHeaders
    watcher = CreateFrame("Frame")
    watcher:SetScript("OnUpdate", function()
        userTab = tabHeaders.selectedTabID or userTab
    end)

    hooksecurefunc(TransmogFrame, "SelectSlot", function(_, _, forceRefresh)
        if not forceRefresh or not db.keepTransmogTab then return end
        if not userTab or tabHeaders.selectedTabID == userTab then return end
        wardrobe:SetTab(userTab)
    end)
    hooked = true
end

-- Blizzard_Transmog loads on demand, so its frames are not there the instant
-- the transmogrifier opens.
local function setUpFrames()
    installHooks()
    LuckysEnsemble.Randomiser:OnTransmogOpen()
end

function LuckysEnsemble.Transmog:Init(database)
    db = database

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("TRANSMOGRIFY_OPEN")
    eventFrame:RegisterEvent("TRANSMOGRIFY_CLOSE")
    eventFrame:SetScript("OnEvent", function(_, event)
        userTab = nil
        if event == "TRANSMOGRIFY_OPEN" then
            if watcher then watcher:Show() end
            C_Timer.After(0.1, setUpFrames)
        else
            if watcher then watcher:Hide() end
            LuckysEnsemble.Randomiser:OnTransmogClose()
        end
    end)
end
