-- luacheck: globals C_TransmogSets LuckysWardrobe TransmogFrame UnitClass

-- Covers narrowing Blizzard's Sets tab at the transmogrifier to the sets this
-- character could put on, and the setting that turns the narrowing off.

LuckysWardrobe = {}

local MONK, WARRIOR, PRIEST = 10, 1, 5

local function maskFor(...)
    local mask = 0
    for _, classID in ipairs({ ... }) do mask = mask + 2 ^ (classID - 1) end
    return mask
end

-- Only the mask arithmetic is wanted here, so the class list the rest of the
-- module builds from the client is left out of the fixture.
LuckysWardrobe.Classes = {
    MaskHasClass = function(_, classMask, classID)
        local flag = 2 ^ (classID - 1)
        return classMask % (flag + flag) >= flag
    end,
}

local monkSet = { setID = 1, classMask = maskFor(MONK), validForCharacter = true }
local warriorSet = { setID = 2, classMask = maskFor(WARRIOR), validForCharacter = false }
local sharedSet = { setID = 3, classMask = maskFor(MONK, PRIEST), validForCharacter = true }
local cosmeticSet = { setID = 4, classMask = 0, validForCharacter = true }
-- A set the client turns down for a reason other than class: the Kul Tiran
-- quest sets read this way to a Horde character.
local factionSet = { setID = 5, classMask = 0, validForCharacter = false }
-- The client only ever leaves the mask out on older builds, and a set naming
-- nothing belongs to everybody.
local masklessSet = { setID = 6, validForCharacter = true }

local availableSets = {
    monkSet, warriorSet, sharedSet, cosmeticSet, factionSet, masklessSet,
}

local nativeCalls = 0
C_TransmogSets = {
    GetAvailableSets = function()
        nativeCalls = nativeCalls + 1
        return availableSets
    end,
}

UnitClass = function() return "Monk", "MONK", MONK end

dofile("src/TransmogSets.lua")

local TransmogSets = LuckysWardrobe.TransmogSets

-- Which sets a character could put on.

assert(TransmogSets.CanWear(monkSet, MONK), "a set naming this class is one to wear")
assert(not TransmogSets.CanWear(warriorSet, MONK), "another class's set is not")
assert(TransmogSets.CanWear(sharedSet, MONK),
    "a set naming several classes is wearable by every one of them")
assert(TransmogSets.CanWear(cosmeticSet, MONK),
    "a set naming no class at all belongs to everybody")
assert(TransmogSets.CanWear(masklessSet, MONK),
    "a set with no mask at all is not read as another class's")

-- The client's own verdict covers the locks a class mask says nothing about.
assert(not TransmogSets.CanWear(factionSet, MONK),
    "a set the client refuses is not offered, whatever its mask says")

-- A set carrying this character's class is kept even where the client has not
-- answered: the tab is narrowed by what it can prove, not by silence.
assert(TransmogSets.CanWear({ setID = 7, classMask = maskFor(MONK) }, MONK),
    "a set the client says nothing about is judged on its mask alone")

local wearable = TransmogSets.WearableSets(availableSets, MONK)
assert(#wearable == 4, "kept only the sets this character could put on")
assert(wearable[1] == monkSet and wearable[2] == sharedSet
    and wearable[3] == cosmeticSet and wearable[4] == masklessSet,
    "kept the sets in the order the tab already had them")

-- The tab reads its cards through the wrapped call.

local db = { hideUnwearableSets = true }
TransmogSets:Init(db)

local narrowed = C_TransmogSets.GetAvailableSets()
assert(nativeCalls == 1, "asked the client for its own list first")
assert(#narrowed == 4 and narrowed[1] == monkSet, "the tab is handed the narrowed list")

db.hideUnwearableSets = false
assert(C_TransmogSets.GetAvailableSets() == availableSets,
    "turning the setting off hands back the client's own list untouched")

-- Wrapping twice would filter a filtered list and lose the original.
TransmogSets:Init(db)
db.hideUnwearableSets = true
assert(#C_TransmogSets.GetAvailableSets() == 4, "a second init left the wrapper alone")
assert(nativeCalls == 3, "every read still reaches the client exactly once")

-- Redrawing the tab after the setting changes.

local refreshes = 0
local setsFrame = {
    shown = true,
    IsShown = function(self) return self.shown end,
    Refresh = function() refreshes = refreshes + 1 end,
}
TransmogFrame = { WardrobeCollection = { TabContent = { SetsFrame = setsFrame } } }

TransmogSets:Refresh()
assert(refreshes == 1, "redrew the tab that was on screen")

setsFrame.shown = false
TransmogSets:Refresh()
assert(refreshes == 1, "left a tab nobody is looking at to redraw when it opens")

-- The transmogrifier has never been opened, so its frames do not exist yet.
TransmogFrame = nil
TransmogSets:Refresh()

print("Lucky's Wardrobe transmog sets tests passed")
