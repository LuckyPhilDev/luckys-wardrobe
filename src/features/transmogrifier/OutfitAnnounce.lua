-- luacheck: globals C_Timer C_TransmogOutfitInfo CreateFrame

-- Lucky's Wardrobe: Say which outfit you are now wearing whenever it changes.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.OutfitAnnounce = {}

local strings = LuckysWardrobe.Strings.outfitAnnounce
-- A situation can swap outfits several times in a row; only the one it settles on is announced.
local SETTLE_SECONDS = 0.3

local db
local lastOutfitID
local hasReading = false
local settleTimer

local function outfitByID(outfitID)
    for _, outfit in ipairs(C_TransmogOutfitInfo.GetOutfitsInfo() or {}) do
        if outfit.outfitID == outfitID then return outfit end
    end
end

-- Selected values are only readable at the transmogrifier, so this uses what SituationLabels cached there.
local function situationText(outfit)
    local cached = LuckysWardrobe.SituationLabels:ValuesFor(outfit.outfitID) or {}
    local parts = {}
    for _, categoryName in ipairs(outfit.situationCategories or {}) do
        local selected = cached[categoryName]
        parts[#parts + 1] = (selected and selected ~= "") and selected or categoryName
    end
    return (table.concat(parts, ", "):gsub("%+", ", "))
end

local function announce(outfitID)
    local outfit = outfitByID(outfitID)
    if not outfit then
        LuckysWardrobe.Utils.Say(strings.cleared)
        return
    end
    local situations = situationText(outfit)
    if situations ~= "" then
        LuckysWardrobe.Utils.Say(strings.wearingFor:format(outfit.name, situations))
    else
        LuckysWardrobe.Utils.Say(strings.wearing:format(outfit.name))
    end
end

local function onOutfitSettled()
    settleTimer = nil
    local outfitID = C_TransmogOutfitInfo.GetActiveOutfitID()
    -- The event repeats for one swap, and fires at login for the outfit you logged out in.
    if outfitID == lastOutfitID and hasReading then return end
    local isFirstReading = not hasReading
    hasReading = true
    lastOutfitID = outfitID
    if not db.muteOutfitAnnouncements and not isFirstReading then announce(outfitID) end
end

local function onOutfitChanged()
    if settleTimer then settleTimer:Cancel() end
    settleTimer = C_Timer.NewTimer(SETTLE_SECONDS, onOutfitSettled)
end

function LuckysWardrobe.OutfitAnnounce:Init(database)
    db = database
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("TRANSMOG_DISPLAYED_OUTFIT_CHANGED")
    events:SetScript("OnEvent", onOutfitChanged)
end
