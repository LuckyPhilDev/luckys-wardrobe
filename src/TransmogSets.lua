-- luacheck: globals C_TransmogSets TransmogFrame UnitClass

-- Lucky's Wardrobe: Blizzard's own Sets tab at the transmogrifier, narrowed to
-- the sets this character could actually put on. The tab offers a set for every
-- class, so a monk is shown warrior plate and priest cloth it can never wear:
-- clicking one changes nothing, and they crowd out the sets that would. The
-- Collections journal is left alone, because browsing a set is not wearing it.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.TransmogSets = {}

local TransmogSets = LuckysWardrobe.TransmogSets

local db
local getAvailableSets

-- Whether this character could ever put a set on. The client's own verdict
-- leads: validForCharacter is what Blizzard's own tooltips answer to, and it
-- knows about the faction and race locks a set carries as well as the class
-- one. The class mask is read behind it because class is the lock this tab lets
-- through, and a set naming no class at all, the cosmetic and outfit
-- collections among them, belongs to everybody.
function TransmogSets.CanWear(set, classID)
    if set.validForCharacter == false then return false end

    local classMask = set.classMask or 0
    return classMask == 0 or LuckysWardrobe.Classes:MaskHasClass(classMask, classID)
end

function TransmogSets.WearableSets(sets, classID)
    local wearable = {}
    for _, set in ipairs(sets) do
        if TransmogSets.CanWear(set, classID) then wearable[#wearable + 1] = set end
    end
    return wearable
end

-- Live glue from here down.

local function playerClassID()
    return select(3, UnitClass("player"))
end

local function setsFrame()
    local wardrobe = TransmogFrame and TransmogFrame.WardrobeCollection
    local content = wardrobe and wardrobe.TabContent
    return content and content.SetsFrame
end

-- Redraws the tab for a setting changed while the transmogrifier is open. The
-- frame reads the set list afresh on every refresh, so there is nothing of ours
-- to clear first.
function TransmogSets:Refresh()
    local frame = setsFrame()
    if frame and frame:IsShown() and type(frame.Refresh) == "function" then frame:Refresh() end
end

function TransmogSets:Init(database)
    db = database

    -- The tab builds its cards from this one call, so narrowing the answer
    -- narrows the tab without touching a frame the client owns. Blizzard_Transmog
    -- loads on demand, but the namespace this wraps is there from the start and
    -- nothing reads it until the transmogrifier opens.
    if getAvailableSets or type(C_TransmogSets.GetAvailableSets) ~= "function" then return end
    getAvailableSets = C_TransmogSets.GetAvailableSets
    C_TransmogSets.GetAvailableSets = function(...)
        local sets = getAvailableSets(...)
        if not db.hideUnwearableSets then return sets end
        return TransmogSets.WearableSets(sets, playerClassID())
    end
end
