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
    if not wardrobe or type(wardrobe.SetTab) ~= "function" then return end
    if type(TransmogFrame.SelectSlot) ~= "function" then return end

    local tabHeaders = wardrobe.TabHeaders
    if not tabHeaders or type(tabHeaders.SetTab) ~= "function" then return end

    -- The strip is what hears a tab click, and it has to be asked rather than
    -- the wardrobe: the wardrobe hands the strip its own SetTab as a closure
    -- when the frame loads, so a hook put on the wardrobe afterwards never sees
    -- a click come through. Everything else reaches the wardrobe directly,
    -- which is the distinction this needs anyway: selecting a slot switches to
    -- Items on its way through, so recording every change would record the very
    -- thing this is here to undo.
    hooksecurefunc(tabHeaders, "SetTab", function(_, tabID, isUserAction)
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
