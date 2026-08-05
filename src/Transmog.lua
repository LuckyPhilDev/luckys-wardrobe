-- luacheck: globals C_Timer CreateFrame TransmogFrame hooksecurefunc

-- Lucky's Wardrobe: Keep the active transmog tab during outfit refreshes, and
-- host the appearance randomiser's session on the same transmogrifier events.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.Transmog = {}

local db
local hooked = false
local userTab

local function installHooks()
    if hooked then return end
    local wardrobe = TransmogFrame and TransmogFrame.WardrobeCollection
    if not wardrobe or not wardrobe.TabHeaders or type(wardrobe.SetTab) ~= "function" then return end
    if type(TransmogFrame.SelectSlot) ~= "function" then return end

    local tabHeaders = wardrobe.TabHeaders
    -- The tab system says whether a tab change came from the player, and only
    -- those are worth remembering: selecting a slot switches to Items on its
    -- way through, so recording every change would record the very thing this
    -- is here to undo.
    hooksecurefunc(wardrobe, "SetTab", function(_, tabID, isUserAction)
        if isUserAction then userTab = tabID end
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
    LuckysWardrobe.Randomiser:OnTransmogOpen()
end

function LuckysWardrobe.Transmog:Init(database)
    db = database

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("TRANSMOGRIFY_OPEN")
    eventFrame:RegisterEvent("TRANSMOGRIFY_CLOSE")
    eventFrame:SetScript("OnEvent", function(_, event)
        userTab = nil
        if event == "TRANSMOGRIFY_OPEN" then
            C_Timer.After(0.1, setUpFrames)
        else
            LuckysWardrobe.Randomiser:OnTransmogClose()
        end
    end)
end
