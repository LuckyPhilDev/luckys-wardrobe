-- luacheck: globals C_TransmogOutfitInfo CreateFrame LuckyStrings LuckysWardrobe

LuckysWardrobe = {}

LuckyStrings = { New = function(_, tbl) return tbl end }
dofile("src/Strings.lua")

local said
LuckysWardrobe.Utils = { Say = function(message) said = message end }

local cache = {
    [1] = { Specializations = "Frost+Unholy", Locations = "" },
}
LuckysWardrobe.SituationLabels = { ValuesFor = function(_, outfitID) return cache[outfitID] end }

local activeOutfitID
C_TransmogOutfitInfo = {
    GetActiveOutfitID = function() return activeOutfitID end,
    GetOutfitsInfo = function()
        return {
            { outfitID = 1, name = "Frosticles", situationCategories = { "Specializations", "Locations" } },
            { outfitID = 2, name = "Uncached", situationCategories = { "Specializations" } },
            { outfitID = 3, name = "Plain", situationCategories = {} },
        }
    end,
}

local onEvent
function CreateFrame()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, handler) onEvent = handler end,
    }
end

dofile("src/features/transmogrifier/OutfitAnnounce.lua")
local db = { muteOutfitAnnouncements = false }
LuckysWardrobe.OutfitAnnounce:Init(db)

local function wear(outfitID)
    said = nil
    activeOutfitID = outfitID
    onEvent()
    return said
end

assert(wear(3) == nil, "the outfit worn at login is not announced")
assert(wear(1) == "Now wearing Frosticles, set for Frost, Unholy, Locations.",
    "cached values replace their category, which is kept where none are cached")
assert(wear(2) == "Now wearing Uncached, set for Specializations.",
    "an outfit with nothing cached falls back to its category names")
assert(wear(3) == "Now wearing Plain.", "an outfit with no situations names only itself")
assert(wear(nil) == "Now wearing your own gear.", "clearing the outfit says so")

db.muteOutfitAnnouncements = true
assert(wear(1) == nil, "muted announcements stay quiet")

print("OutfitAnnounceTest passed")
