-- luacheck: globals C_TransmogOutfitInfo CreateFrame

-- Lucky's Wardrobe: Say which outfit you are now wearing whenever it changes.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.OutfitAnnounce = {}

local strings = LuckysWardrobe.Strings.outfitAnnounce
local db
local lastOutfitID

local function outfitByID(outfitID)
    for _, outfit in ipairs(C_TransmogOutfitInfo.GetOutfitsInfo() or {}) do
        if outfit.outfitID == outfitID then return outfit end
    end
end

local function announce(outfitID)
    local outfit = outfitByID(outfitID)
    if not outfit then
        LuckysWardrobe.Utils.Say(strings.cleared)
        return
    end
    local situations = outfit.situationCategories
    if situations and #situations > 0 then
        LuckysWardrobe.Utils.Say(strings.wearingFor:format(outfit.name, table.concat(situations, ", ")))
    else
        LuckysWardrobe.Utils.Say(strings.wearing:format(outfit.name))
    end
end

local function onOutfitChanged()
    local outfitID = C_TransmogOutfitInfo.GetActiveOutfitID()
    -- The event repeats for one swap, and fires at login for the outfit you logged out in.
    if outfitID == lastOutfitID then return end
    local isFirstReading = lastOutfitID == nil
    lastOutfitID = outfitID
    if db.announceOutfitChanges and not isFirstReading then announce(outfitID) end
end

function LuckysWardrobe.OutfitAnnounce:Init(database)
    db = database
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("TRANSMOG_DISPLAYED_OUTFIT_CHANGED")
    events:SetScript("OnEvent", onOutfitChanged)
end
