-- luacheck: globals C_Item C_TransmogCollection C_TransmogSets CHECK_ALL Enum EventUtil EXPANSION_NAME0 EXPANSION_NAME1 EXPANSION_NAME2 EXPANSION_NAME3 EXPANSION_NAME4 EXPANSION_NAME5 EXPANSION_NAME6 EXPANSION_NAME7 EXPANSION_NAME8 EXPANSION_NAME9 EXPANSION_NAME10 EXPANSION_NAME11 LuckysWardrobe Menu MenuResponse TransmogFrame UNCHECK_ALL UnitClass
-- luacheck: ignore 121

-- Covers narrowing Blizzard's Sets tab at the transmogrifier to the sets this
-- character could dress in and to the expansions still ticked, and the switches
-- that drive both, in the tab's own filter menu as well as the settings panel.

LuckysWardrobe = {}

CHECK_ALL = "Check All"
UNCHECK_ALL = "Uncheck All"
MenuResponse = { Refresh = 1 }
for index = 0, 11 do _G["EXPANSION_NAME" .. index] = "Expansion " .. index end

local CLOTH, LEATHER, MAIL, PLATE = 1, 2, 3, 4
local COSMETIC = 5
local MONK = 10

Enum = {
    ItemClass = { Armor = 4, Weapon = 2 },
}

-- Only the armour lookup is wanted here, so the class list the real module
-- builds from the client is left out of the fixture.
LuckysWardrobe.Classes = {
    ArmourType = function(_, classID) return classID == MONK and LEATHER or nil end,
}

local function piece(armour, slot)
    return { armour = armour, slot = slot or "INVTYPE_CHEST" }
end

-- The set names put their own switch in this menu, and the tab that owns the
-- menu is what places it.
LuckysWardrobe.TransmogSetNames = {
    AddFilterOption = function(_, rootDescription)
        rootDescription:CreateCheckbox("Show Set Names", function() end, function() end)
    end,
}

-- The tab's filter menu is Blizzard's, appended to by tag rather than rebuilt.
local menuModifiers = {}
Menu = {
    ModifyMenu = function(tag, callback) menuModifiers[tag] = callback end,
}

local pendingAddOns = {}
EventUtil = {
    ContinueOnAddOnLoaded = function(addOn, callback) pendingAddOns[addOn] = callback end,
}

dofile("src/Strings.lua")
dofile("src/Utils.lua")
dofile("src/TransmogSets.lua")

local TransmogSets = LuckysWardrobe.TransmogSets

-- Which sets a character could dress in.

assert(TransmogSets.WearsArmourOf({ piece(LEATHER), piece(LEATHER) }, LEATHER),
    "a set of the armour this class wears is one to dress in")

-- The monk's own complaint: another leather class's set goes on just the same,
-- so class is the wrong thing to judge a set by.
assert(TransmogSets.WearsArmourOf({ piece(LEATHER, "INVTYPE_HEAD"), piece(LEATHER) }, LEATHER),
    "leather is leather whoever the set was built for")

assert(not TransmogSets.WearsArmourOf({ piece(PLATE, "INVTYPE_HEAD"), piece(PLATE) }, LEATHER),
    "another armour type's set is not one to dress in")
assert(not TransmogSets.WearsArmourOf({ piece(CLOTH), piece(MAIL) }, LEATHER),
    "a set of armour types this class never wears is left out whichever they are")

-- The whole reason the tab offers these sets at all: a cloak fits anybody, and
-- one cloak is not a set.
assert(not TransmogSets.WearsArmourOf({ piece(PLATE), piece(CLOTH, "INVTYPE_CLOAK") }, LEATHER),
    "a plate set is still a plate set when its cloak would go on")
assert(not TransmogSets.WearsArmourOf({
    piece(PLATE),
    piece(CLOTH, "INVTYPE_CLOAK"),
    piece(COSMETIC, "INVTYPE_TABARD"),
    piece(COSMETIC, "INVTYPE_BODY"),
}, LEATHER), "several pieces anybody could wear still do not make a set this class can dress in")

-- Sets nobody is held out of.
assert(TransmogSets.WearsArmourOf({ piece(COSMETIC), piece(COSMETIC, "INVTYPE_LEGS") }, LEATHER),
    "a cosmetic set belongs to everybody")
assert(TransmogSets.WearsArmourOf({ piece(CLOTH, "INVTYPE_CLOAK") }, LEATHER),
    "a set of nothing but cloaks holds nobody out")
assert(TransmogSets.WearsArmourOf({}, LEATHER),
    "a set the client has said nothing about is not judged on nothing")

-- A class this version has no armour type for is held to none.
assert(TransmogSets.WearsArmourOf({ piece(PLATE) }, nil),
    "a class with no armour type of its own is offered every set")

-- Narrowing the list itself.

local kept = TransmogSets.WearableSets(
    { { setID = 1 }, { setID = 2 }, { setID = 3 } },
    function(setID) return setID ~= 2 end)
assert(#kept == 2 and kept[1].setID == 1 and kept[2].setID == 3,
    "kept the sets in the order the tab already had them")

-- Reading a set through the client.

local ARMOUR_ITEM = {
    [101] = { equipLoc = "INVTYPE_CHEST", classID = Enum.ItemClass.Armor, subClassID = LEATHER },
    [102] = { equipLoc = "INVTYPE_HEAD", classID = Enum.ItemClass.Armor, subClassID = LEATHER },
    [201] = { equipLoc = "INVTYPE_CHEST", classID = Enum.ItemClass.Armor, subClassID = PLATE },
    [202] = { equipLoc = "INVTYPE_CLOAK", classID = Enum.ItemClass.Armor, subClassID = CLOTH },
    -- A weapon carries no armour type at all, so it decides nothing.
    [301] = { equipLoc = "INVTYPE_2HWEAPON", classID = Enum.ItemClass.Weapon, subClassID = 8 },
}

local setSources = {
    [1] = { 101, 102 },
    [2] = { 201, 202 },
    [3] = { 301 },
    -- The client has nothing to say about this one yet.
    [4] = {},
}

local primaryAppearanceCalls = {}
C_TransmogSets = {
    GetSetPrimaryAppearances = function(setID)
        primaryAppearanceCalls[setID] = (primaryAppearanceCalls[setID] or 0) + 1
        local appearances = {}
        for index, sourceID in ipairs(setSources[setID] or {}) do
            appearances[index] = { appearanceID = sourceID, collected = true }
        end
        return appearances
    end,
    GetAvailableSets = function()
        return {
            { setID = 1, expansionID = 0 },
            { setID = 2, expansionID = 1 },
            { setID = 3, expansionID = 1 },
            { setID = 4, expansionID = 1 },
        }
    end,
}

C_TransmogCollection = {
    GetSourceInfo = function(sourceID)
        if not ARMOUR_ITEM[sourceID] then return nil end
        return { itemID = sourceID }
    end,
}

C_Item = {
    GetItemInfoInstant = function(itemID)
        local item = ARMOUR_ITEM[itemID]
        if not item then return nil end
        return itemID, nil, nil, item.equipLoc, nil, item.classID, item.subClassID
    end,
}

UnitClass = function() return "Monk", "MONK", MONK end

local db = { hideUnwearableSets = true }
TransmogSets:Init(db)

local narrowed = C_TransmogSets.GetAvailableSets()
assert(#narrowed == 3, "kept the leather set, the weapon set and the one not yet described")
assert(narrowed[1].setID == 1 and narrowed[2].setID == 3 and narrowed[3].setID == 4,
    "dropped only the plate set the monk could take a cloak from")

-- The verdict is worked out once. The tab asks about every set it lists on
-- every refresh, so asking the client again each time would be hundreds of
-- reads a keystroke.
C_TransmogSets.GetAvailableSets()
assert(primaryAppearanceCalls[1] == 1 and primaryAppearanceCalls[2] == 1,
    "read what a set is made of once and remembered the answer")

-- A set the client had nothing to say about is asked again rather than kept
-- forever on the strength of an empty answer.
assert(primaryAppearanceCalls[4] == 2, "asked again about the set with no pieces yet")
setSources[4] = { 201 }
narrowed = C_TransmogSets.GetAvailableSets()
assert(#narrowed == 2, "judged the set once the client described it")

db.hideUnwearableSets = false
assert(#C_TransmogSets.GetAvailableSets() == 4,
    "turning the setting off hands back the client's own list untouched")

-- Wrapping twice would filter a filtered list and lose the original.
TransmogSets:Init(db)
db.hideUnwearableSets = true
assert(#C_TransmogSets.GetAvailableSets() == 2, "a second init left the wrapper alone")

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

-- The same switch in the tab's own Filter button.

local filterButton = {
    SetIsDefaultCallback = function(self, callback) self.isDefault = callback end,
    SetDefaultCallback = function(self, callback) self.restoreDefaults = callback end,
}
setsFrame.FilterButton = filterButton
setsFrame.shown = true
pendingAddOns["Blizzard_Transmog"]()

local menuEntries = {}
local submenus = {}
local rootDescription = {
    CreateDivider = function() menuEntries[#menuEntries + 1] = { divider = true } end,
    CreateCheckbox = function(_, label, isSelected, setSelected)
        menuEntries[#menuEntries + 1] =
            { label = label, isSelected = isSelected, setSelected = setSelected }
    end,
    CreateButton = function(_, label)
        local submenu = { buttons = {}, checkboxes = {}, boxOrder = {} }
        submenu.CreateDivider = function() end
        submenu.CreateButton = function(_, buttonLabel, click)
            submenu.buttons[buttonLabel] = click
        end
        submenu.CreateCheckbox = function(_, boxLabel, isChecked, toggle)
            submenu.checkboxes[boxLabel] = { isChecked = isChecked, toggle = toggle }
            submenu.boxOrder[#submenu.boxOrder + 1] = boxLabel
        end
        menuEntries[#menuEntries + 1] = { label = label, submenu = submenu }
        submenus[label] = submenu
        return submenu
    end,
}
menuModifiers["MENU_TRANSMOG_SETS_FILTER"](nil, rootDescription)

assert(#menuEntries == 4 and menuEntries[2].divider,
    "appended this addon's own switches, kept apart from the filters above them")
assert(menuEntries[1].label == LuckysWardrobe.Strings.filterMenu.expansion,
    "left the expansion submenu above the divider, among the filters Blizzard put there")
assert(menuEntries[4].label == "Show Set Names",
    "brought the set names switch along under the same divider rather than behind one of its own")

local checkbox = menuEntries[3]
assert(checkbox.label == LuckysWardrobe.Strings.settings.hideUnwearableSets.label,
    "the menu and the settings panel name the one switch the same way")
assert(checkbox.isSelected(), "the box reads the setting as it stands rather than a copy of it")

refreshes = 0
checkbox.setSelected()
assert(db.hideUnwearableSets == false and refreshes == 1,
    "unticking the box turned the filter off and redrew the tab")
checkbox.setSelected()
assert(db.hideUnwearableSets == true, "ticking it again turned the filter back on")

-- The button says whether anything is narrowing the list, and offers to put it
-- back. Both have to count our filter or it is the one the reset walks past.
local blizzardFiltersDefault = true
C_TransmogSets.IsUsingDefaultSetsFilters = function() return blizzardFiltersDefault end
local blizzardFiltersRestored = false
C_TransmogSets.SetDefaultSetsFilters = function() blizzardFiltersRestored = true end

assert(filterButton.isDefault(), "everything at its default reads as untouched")
blizzardFiltersDefault = false
assert(not filterButton.isDefault(), "one of Blizzard's own boxes still marks the button")
blizzardFiltersDefault = true
db.hideUnwearableSets = false
assert(not filterButton.isDefault(), "our filter turned off marks the button too")

refreshes = 0
filterButton.restoreDefaults()
assert(db.hideUnwearableSets == true and blizzardFiltersRestored and refreshes == 1,
    "the reset put our filter back alongside Blizzard's own and redrew the tab")

-- Narrowing the tab to the expansions you are working through, the same submenu
-- the Collections journal's Sets tab and the Extra Sets tab both carry.

local expansions = submenus[LuckysWardrobe.Strings.filterMenu.expansion]
assert(#expansions.boxOrder == 12, "listed a box for every expansion the game names")

refreshes = 0
expansions.checkboxes["Expansion 0"].toggle()
assert(refreshes == 1, "unticking an expansion redrew the tab")
assert(not expansions.checkboxes["Expansion 0"].isChecked(),
    "the box reads the filter as it stands rather than a copy of it")

local shown = C_TransmogSets.GetAvailableSets()
assert(#shown == 1 and shown[1].setID == 3, "left out the sets from the expansion unticked")
assert(not filterButton.isDefault(), "an expansion unticked marks the button too")

-- The two filters are independent: browsing the lot again still leaves out the
-- expansions you unticked.
db.hideUnwearableSets = false
assert(#C_TransmogSets.GetAvailableSets() == 3,
    "the expansion filter narrows the list whether or not the armour one does")
db.hideUnwearableSets = true

refreshes = 0
expansions.buttons[UNCHECK_ALL]()
assert(#C_TransmogSets.GetAvailableSets() == 0 and refreshes == 1,
    "unticking every expansion emptied the tab")

expansions.buttons[CHECK_ALL]()
assert(#C_TransmogSets.GetAvailableSets() == 2 and filterButton.isDefault(),
    "ticking them all back handed the whole list over again")

expansions.checkboxes["Expansion 1"].toggle()
filterButton.restoreDefaults()
assert(filterButton.isDefault() and #C_TransmogSets.GetAvailableSets() == 2,
    "the reset put the expansions back alongside everything else")

setsFrame.shown = false

-- The transmogrifier has never been opened, so its frames do not exist yet.
TransmogFrame = nil
TransmogSets:Refresh()

print("Lucky's Wardrobe transmog sets tests passed")
