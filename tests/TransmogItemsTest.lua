-- luacheck: globals C_Item C_Timer C_TransmogCollection CHECK_ALL CreateFrame Enum EventUtil EXPANSION_NAME0 EXPANSION_NAME1 EXPANSION_NAME2 EXPANSION_NAME3 EXPANSION_NAME4 EXPANSION_NAME5 EXPANSION_NAME6 EXPANSION_NAME7 EXPANSION_NAME8 EXPANSION_NAME9 EXPANSION_NAME10 EXPANSION_NAME11 FILTERS LuckysWardrobe MenuResponse SOURCES TransmogFrame UNCHECK_ALL UNKNOWN WardrobeCollectionFrame
-- luacheck: ignore 121

-- Covers narrowing the Items tab at the transmogrifier to the expansions still
-- ticked: which appearances a pass keeps, how one is dated through the item
-- behind it, and the filter button this addon takes over to drive it.

LuckysWardrobe = {}
LuckysWardrobe.DevLog = function() end

-- The strip reads its swatches off the presets, the reset included: clearing the
-- colour is a pick of nothing rather than a separate undo.
LuckysWardrobe.Colours = {
    PRESETS = { { key = "green", shades = { { 40, 160, 60 } } } },
    Target = function(preset) return preset.shades end,
}

CHECK_ALL = "Check All"
UNCHECK_ALL = "Uncheck All"
FILTERS = "Filters"
SOURCES = "Sources"
UNKNOWN = "Unknown"
MenuResponse = { Refresh = 1 }
Enum = { TransmogSource = { None = 0, JournalEncounter = 1, Vendor = 3 } }
for index = 0, 11 do _G["EXPANSION_NAME" .. index] = "Expansion " .. index end

-- Source 3 is one this version of the client does not offer, so the menu is
-- expected to walk past it rather than draw a box with no name.
local SOURCE_NAMES = { "Boss Drop", "Quest", "Retired", "Vendor" }
for index, name in ipairs(SOURCE_NAMES) do _G["TRANSMOG_SOURCE_" .. index] = name end
local validSource = { [1] = true, [2] = true, [4] = true }
local sourceChecked = { [1] = true, [2] = true, [4] = true }

-- The debounce behind the redraw runs on the client's timer, wound by hand here
-- so a burst of item answers can be collapsed on purpose.
local timers = {}
C_Timer = { After = function(_, action) timers[#timers + 1] = action end }

local function runTimers()
    local due = timers
    timers = {}
    for _, action in ipairs(due) do action() end
end

local createdFrames = {}
CreateFrame = function()
    local frame = { events = {} }
    frame.RegisterEvent = function(self, event) self.events[event] = true end
    frame.UnregisterEvent = function(self, event) self.events[event] = nil end
    frame.SetScript = function(self, _, handler) self.handler = handler end
    createdFrames[#createdFrames + 1] = frame
    return frame
end

local pendingAddOns = {}
EventUtil = {
    ContinueOnAddOnLoaded = function(addOn, callback) pendingAddOns[addOn] = callback end,
}

local MOP = 4

-- Which expansion the client would date each item to, and whether it holds that
-- data yet. Nothing is warm to begin with but the two the tab is meant to place
-- straight away, which is what a client part way through a session looks like.
-- Item 601 is the shop piece: the client dates it to expansion 0 the way it
-- dates a Classic drop, and says nothing at all about where it came from.
local ITEM_EXPANSION = { [101] = 0, [201] = MOP, [301] = MOP, [501] = 0, [502] = MOP, [601] = 0 }
local warm = { [101] = true, [201] = true, [502] = true, [601] = true }

-- What the client says each source is. A shop piece carries no source type at
-- all, which is what separates it from a Classic drop, both being dated to
-- expansion 0. Sources with no entry here answer nil.
local SOURCE_TYPE = { [101] = 1, [201] = 3, [301] = 0, [502] = 0 }
local ITEM_NAME = {
    [101] = "Old Helm", [201] = "Pandaren Hat", [301] = "Shop Hood", [601] = "Spiritbringer Crest",
}

local requests = {}
C_Item = {
    GetItemInfo = function(itemID)
        if not warm[itemID] then return nil end
        return "name", "link", 1, 1, 1, "type", "sub", 1, "loc", 1, 0, 4, 1, 1, ITEM_EXPANSION[itemID]
    end,
    RequestLoadItemDataByID = function(itemID) requests[#requests + 1] = itemID end,
}

-- Appearance 4 hides the slot, so it carries no source and belongs to no
-- expansion. Appearance 5 has a cold source before a warm one.
local APPEARANCE_SOURCES = {
    [1] = { 101 },
    [2] = { 201 },
    [3] = { 301 },
    [4] = {},
    [5] = { 501, 502 },
    [6] = { 601 },
}

local sourceLookups = 0
local blizzardFiltersDefault = true
local blizzardFiltersRestored = false

C_TransmogCollection = {
    GetCategoryAppearances = function()
        return {
            { visualID = 4, isHideVisual = true },
            { visualID = 1 },
            { visualID = 2 },
            { visualID = 3 },
            { visualID = 5 },
            { visualID = 6 },
        }
    end,
    GetAllAppearanceSources = function(visualID)
        sourceLookups = sourceLookups + 1
        return APPEARANCE_SOURCES[visualID]
    end,
    GetSourceInfo = function(sourceID)
        return { itemID = sourceID, sourceType = SOURCE_TYPE[sourceID], name = ITEM_NAME[sourceID] }
    end,
    GetCategoryInfo = function() return "Head", false end,
    IsUsingDefaultFilters = function() return blizzardFiltersDefault end,
    SetDefaultFilters = function() blizzardFiltersRestored = true end,
    GetNumTransmogSources = function() return #SOURCE_NAMES end,
    IsValidTransmogSource = function(source) return validSource[source] == true end,
    IsSourceTypeFilterChecked = function(source) return sourceChecked[source] == true end,
    SetSourceTypeFilter = function(source, checked) sourceChecked[source] = checked end,
    SetAllSourceTypeFilters = function(checked)
        for source in pairs(validSource) do sourceChecked[source] = checked end
    end,
}

dofile("src/Strings.lua")
dofile("src/Utils.lua")
dofile("src/Data/ExtraSetsData.lua")
dofile("src/Classes.lua")
dofile("src/Perf.lua")
-- The submenu and the Unknown box are the Extra Sets lists' own, shared rather
-- than built again, so the real ones run here.
dofile("src/ExtraSets.lua")
dofile("src/TransmogItems.lua")

local TransmogItems = LuckysWardrobe.TransmogItems
local Utils = LuckysWardrobe.Utils
local S = LuckysWardrobe.Strings.filterMenu

-- Which appearances a pass keeps.

local function visualIDs(appearances)
    local ids = {}
    for index, appearance in ipairs(appearances) do ids[index] = appearance.visualID end
    return table.concat(ids, ",")
end

local everything = {}
Utils.SetAllExpansions(everything, true)
local classicOnly = {}
Utils.SetAllExpansions(classicOnly, true)
classicOnly[MOP] = false

local listed = {
    { visualID = 4, isHideVisual = true },
    { visualID = 1 },
    { visualID = 2 },
    { visualID = 3 },
}
local function dateAs(dates)
    return function(visualID) return dates[visualID] end
end

local dates = { [1] = 0, [2] = MOP }
assert(visualIDs(TransmogItems.AppearancesFromExpansions(listed, everything, dateAs(dates)))
    == "4,1,2,3", "every box ticked keeps the page in the order the tab already had it")

-- Appearance 3 carries no date, so there is no box holding it and no box to
-- take it away: nothing is hidden on the strength of an answer that has not
-- arrived, and the one that arrives a moment later files it properly.
assert(visualIDs(TransmogItems.AppearancesFromExpansions(listed, classicOnly, dateAs(dates)))
    == "4,1,3", "left out the expansion unticked, and kept the one nothing has answered about")

-- The colour strip narrows the same page. A piece the bundled colours cannot
-- place is dropped rather than kept: nothing to go on means a piece newer than
-- the snapshot, and a page of pieces nobody can vouch for is the one thing a
-- colour filter must not answer with. Hiding a slot survives it regardless.

local inColour = { [1] = 12, [3] = 4 }
local function ranked(visualID) return inColour[visualID] end

assert(visualIDs(TransmogItems.AppearancesInColour(listed, ranked)) == "4,1,3",
    "kept the pieces carrying the colour, and the way to wear nothing")
assert(visualIDs(TransmogItems.AppearancesInColour(listed, function() return nil end)) == "4",
    "a colour nothing on the page carries leaves only the way to wear nothing")

-- The tab sorts what it is given and reads uiOrder highest first, so the rank
-- rides on uiOrder negated rather than on the order of the list. The rank is how
-- little of the piece is that colour, so the smaller rank is the piece more of
-- it and the one that has to come first.

local byColour = TransmogItems.AppearancesInColour(listed, ranked)
local order = {}
for _, appearance in ipairs(byColour) do order[appearance.visualID] = appearance.uiOrder end
assert(order[3] > order[1], "the piece more of that colour sorts ahead of the other")
assert(order[1] == -12 and order[3] == -4, "carrying the rank the colours worked out")
assert(order[4] == nil, "and the way to wear nothing is left as the tab had it")

-- The roll beside the strip draws from the page as the filters have left it, so
-- a colour is what it keeps to. A piece nobody can wear is no use to it, and
-- hiding the slot is on the page only because no filter may take it away.

local page = {
    { visualID = 4, isHideVisual = true, isCollected = true, isUsable = true },
    { visualID = 1, isCollected = true, isUsable = true },
    { visualID = 2, isCollected = false, isUsable = true },
    { visualID = 3, isCollected = true, isUsable = false },
    { visualID = 5, isCollected = true, isUsable = true },
}
local function first() return 1 end
local function last(count) return count end

assert(TransmogItems.RollVisual(page, nil, first) == 1
    and TransmogItems.RollVisual(page, nil, last) == 5,
    "drew from the pieces that can be worn alone, hiding the slot among those left out")

-- Landing where the last roll landed is a button that appears to do nothing.
assert(TransmogItems.RollVisual(page, 1, first) == 5,
    "took the next piece along rather than the one already worn")
assert(TransmogItems.RollVisual(page, 5, last) == 1, "and came round the end of the page")

local alone = { { visualID = 7, isCollected = true, isUsable = true } }
assert(TransmogItems.RollVisual(alone, 7, first) == 7,
    "a page holding one piece answers with that piece however often it is rolled")
assert(TransmogItems.RollVisual({ page[1] }, nil, first) == nil,
    "a page with nothing wearable on it rolls nothing at all")

-- Hiding a slot is the one entry a filter must never take away: unticking every
-- expansion still has to leave a way to wear nothing.
local nothing = {}
Utils.SetAllExpansions(nothing, false)
assert(visualIDs(TransmogItems.AppearancesFromExpansions(listed, nothing, dateAs(dates)))
    == "4,3", "kept the entry that hides the slot with every expansion unticked")

-- An appearance dated to an expansion this version has no box for is kept the
-- same way, rather than vanishing from a filtered page the patch it shipped in.
local unnamed = { [1] = 0, [2] = MOP, [3] = 99 }
assert(visualIDs(TransmogItems.AppearancesFromExpansions(listed, classicOnly, dateAs(unnamed)))
    == "4,1,3", "kept the appearance dated to an expansion with no box of its own")

-- Narrowing the tab itself.

local refreshes = 0
local itemsFrame = {
    shown = true,
    activeCategoryID = 1,
    transmogLocation = { GetData = function() return "head" end },
    IsShown = function(self) return self.shown end,
    IsVisible = function(self) return self.shown end,
    RefreshCollectionEntries = function() refreshes = refreshes + 1 end,
}
TransmogFrame = { WardrobeCollection = { TabContent = { ItemsFrame = itemsFrame } } }

TransmogItems:Init()

assert(visualIDs(C_TransmogCollection.GetCategoryAppearances(1)) == "4,1,2,3,5,6"
    and sourceLookups == 0,
    "nothing unticked hands back the client's own list without reading a single item")

-- The filter button, which this addon takes over once the transmogrifier's own
-- code has built it.
local filterButton = {
    SetText = function(self, text) self.text = text end,
    SetupMenu = function(self, builder) self.builder = builder end,
    SetIsDefaultCallback = function(self, callback) self.isDefault = callback end,
    SetDefaultCallback = function(self, callback) self.restoreDefaults = callback end,
}
itemsFrame.FilterButton = filterButton
pendingAddOns["Blizzard_Transmog"]()

assert(filterButton.text == FILTERS,
    "the button holds more than sources now, so it stops calling itself Sources")

local menuEntries = {}
local submenus = {}
local menuTag
local rootDescription = {
    SetTag = function(_, tag) menuTag = tag end,
    CreateDivider = function() menuEntries[#menuEntries + 1] = { divider = true } end,
    CreateCheckbox = function(_, label) menuEntries[#menuEntries + 1] = { label = label } end,
    CreateButton = function(_, label)
        local submenu = { buttons = {}, checkboxes = {}, boxOrder = {}, dividers = 0 }
        submenu.CreateDivider = function(self) self.dividers = self.dividers + 1 end
        submenu.CreateButton = function(_, buttonLabel, click)
            submenu.buttons[buttonLabel] = click
        end
        submenu.CreateCheckbox = function(_, boxLabel, isChecked, toggle, argument)
            submenu.checkboxes[boxLabel] =
                { isChecked = isChecked, toggle = toggle, argument = argument }
            submenu.boxOrder[#submenu.boxOrder + 1] = boxLabel
        end
        menuEntries[#menuEntries + 1] = { label = label, submenu = submenu }
        submenus[label] = submenu
        return submenu
    end,
}
filterButton.builder(nil, rootDescription)

assert(menuTag == "MENU_TRANSMOG_ITEMS_FILTER",
    "kept the tag Blizzard put on the menu, so another addon appending to it still finds it")
assert(#menuEntries == 2 and menuEntries[1].label == SOURCES and menuEntries[2].label == S.expansion,
    "two submenus and nothing loose beside them, sources first as they always were")

-- Blizzard's own source boxes, read off the client rather than named here, so a
-- patch that adds one brings it along and one it drops goes with it.
local sources = submenus[SOURCES]
assert(table.concat(sources.boxOrder, ",") == "Boss Drop,Quest,Vendor",
    "listed a box for every source the client offers, and walked past the one it does not")
assert(sources.dividers == 1, "held Check All and Uncheck All apart from the boxes, as expansions does")

local bossDrop = sources.checkboxes["Boss Drop"]
assert(bossDrop.isChecked(bossDrop.argument), "the box reads the client's own filter as it stands")
bossDrop.toggle(bossDrop.argument)
assert(not bossDrop.isChecked(bossDrop.argument), "unticking a source turned the client's own filter off")
bossDrop.toggle(bossDrop.argument)

assert(sources.buttons[UNCHECK_ALL]() == MenuResponse.Refresh
    and not sources.checkboxes["Quest"].isChecked(2),
    "Uncheck All turned every source off and had the menu redraw its ticks")
sources.buttons[CHECK_ALL]()
assert(sources.checkboxes["Quest"].isChecked(2), "Check All turned them back on")

local expansions = submenus[S.expansion]
assert(#expansions.boxOrder == 13,
    "a box for every expansion the game names, plus the one for what it files under none")
assert(expansions.boxOrder[13] == S.noExpansion,
    "left it behind the expansions themselves")
-- The Extra Sets lists' Unknown box holds sets a snapshot can never date. An
-- appearance is undated only until the client answers, so a box for it would
-- read as permanently empty and hide half a cold slot if it were unticked.
assert(expansions.checkboxes[S.unknownExpansion] == nil,
    "no Unknown box here, unlike the lists that share this submenu")

refreshes = 0
expansions.checkboxes["Expansion 0"].toggle()
assert(refreshes == 1, "unticking an expansion redrew the tab")
assert(not expansions.checkboxes["Expansion 0"].isChecked(),
    "the box reads the filter as it stands rather than a copy of it")

-- Dating an appearance through the item behind it.

local shown = C_TransmogCollection.GetCategoryAppearances(1)
assert(visualIDs(shown) == "4,2,3,5,6",
    "dropped the Classic appearance and kept the Mists ones, the hide entry, and the undated")
assert(#requests == 1 and requests[1] == 301,
    "asked the client after the one item it holds nothing about")
assert(createdFrames[1].events["GET_ITEM_INFO_RECEIVED"],
    "listened for the answer to come back")

-- Appearance 5's first source is cold and its second is not, so the one that
-- answers dates it without anything being asked for.
sourceLookups = 0
C_TransmogCollection.GetCategoryAppearances(1)
assert(sourceLookups == 1 and #requests == 1,
    "read only the appearance still undated, and asked nothing twice")

-- The answer landing redraws the tab once for the burst rather than once each.
refreshes = 0
createdFrames[1].handler()
createdFrames[1].handler()
assert(refreshes == 0, "waited for the burst of answers to finish")
warm[301] = true
runTimers()
assert(refreshes == 1 and not createdFrames[1].events["GET_ITEM_INFO_RECEIVED"],
    "redrew the tab once and stopped listening, the event firing all game long")

assert(visualIDs(C_TransmogCollection.GetCategoryAppearances(1)) == "4,2,3,5,6",
    "the item's answer moved the appearance into its own expansion, which is shown")
expansions.checkboxes["Expansion " .. MOP].toggle()
assert(visualIDs(C_TransmogCollection.GetCategoryAppearances(1)) == "4,6",
    "unticking Mists took away the appearances the client had just dated")
expansions.checkboxes["Expansion " .. MOP].toggle()

-- The shop piece the client dates to expansion 0 without saying where it came
-- from. Classic is unticked and it is still on the page, so it is not being
-- counted as Classic; unticking its own box is what takes it away.
assert(not expansions.checkboxes["Expansion 0"].isChecked(),
    "Classic is unticked, so anything left on the page is not in the Classic box")
refreshes = 0
expansions.checkboxes[S.noExpansion].toggle()
assert(refreshes == 1 and visualIDs(C_TransmogCollection.GetCategoryAppearances(1)) == "4,2,3,5",
    "unticking No Expansion took away the piece the client files under nothing")
expansions.checkboxes[S.noExpansion].toggle()
assert(visualIDs(C_TransmogCollection.GetCategoryAppearances(1)) == "4,2,3,5,6",
    "ticking it again brought the piece back")

-- The Collections journal reads the same call and carries no box of ours, so
-- while it is on screen it takes the client's own list back.
WardrobeCollectionFrame = { visible = true, IsVisible = function(self) return self.visible end }
assert(visualIDs(C_TransmogCollection.GetCategoryAppearances(1)) == "4,1,2,3,5,6",
    "left the Collections journal's own appearance list alone")
WardrobeCollectionFrame.visible = false
assert(visualIDs(C_TransmogCollection.GetCategoryAppearances(1)) == "4,2,3,5,6",
    "narrowed the transmogrifier's tab again once the journal was closed")

itemsFrame.shown = false
assert(visualIDs(C_TransmogCollection.GetCategoryAppearances(1)) == "4,1,2,3,5,6",
    "narrowed nothing with the tab nobody is looking at")
refreshes = 0
TransmogItems:Refresh()
assert(refreshes == 0, "left a tab nobody is looking at to redraw when it opens")
itemsFrame.shown = true

-- The button says whether anything is narrowing the list, and offers to put it
-- back. Both have to count our filter or it is the one the reset walks past.

assert(not filterButton.isDefault(), "an expansion unticked marks the button")
blizzardFiltersDefault = false
assert(not filterButton.isDefault(), "one of Blizzard's own boxes still marks the button")
blizzardFiltersDefault = true

refreshes = 0
filterButton.restoreDefaults()
assert(blizzardFiltersRestored and refreshes == 1 and filterButton.isDefault(),
    "the reset put our expansions back alongside Blizzard's own boxes and redrew the tab")
assert(visualIDs(C_TransmogCollection.GetCategoryAppearances(1)) == "4,1,2,3,5,6",
    "the whole list came back with it")

-- Wrapping twice would filter a filtered list and lose the original.
TransmogItems:Init()
expansions.checkboxes["Expansion 0"].toggle()
assert(visualIDs(C_TransmogCollection.GetCategoryAppearances(1)) == "4,2,3,5,6",
    "a second init left the wrapper alone")

-- Reading the client's own answers behind a box, which is how a box that looks
-- wrong gets settled rather than guessed at.

local said = {}
local realPrint = print
print = function(line) said[#said + 1] = line end

TransmogItems:PrintDates(tostring(MOP))
print = realPrint

assert(said[1]:find("Head: 3 of 6 appearances dated to Expansion 4", 1, true),
    "counted the appearances in the box against the whole category, and named both")
assert(said[2]:find("Vendor: 1", 1, true) and said[3]:find("None: 1", 1, true)
    and said[4]:find("Unknown: 1", 1, true),
    "grouped them by the source type behind each, in the order the box met them")
assert(said[5]:find("Pandaren Hat (item 201, Vendor)", 1, true)
    and said[6]:find("Shop Hood (item 301, None)", 1, true),
    "named a few so the pieces behind a source type can be recognised")

-- Nothing typed reads the Classic box, which now holds only what really is
-- Classic; the piece filed under nothing is asked after by name.
said = {}
print = function(line) said[#said + 1] = line end
TransmogItems:PrintDates("")
TransmogItems:PrintDates("none")
itemsFrame.transmogLocation = nil
TransmogItems:PrintDates("")
print = realPrint

assert(said[1]:find("Head: 1 of 6 appearances dated to Expansion 0", 1, true)
    and said[2]:find("JournalEncounter: 1", 1, true),
    "the Classic box holds the one appearance the client really dates to Classic")
assert(said[4]:find("Head: 1 of 6 appearances dated to none", 1, true)
    and said[5]:find("Unknown: 1", 1, true)
    and said[6]:find("Spiritbringer Crest (item 601, Unknown)", 1, true),
    "the shop piece is in its own box, with nothing said about where it came from")
assert(said[7]:find("Open the Items tab", 1, true),
    "said what to do rather than reading a category nobody has opened")

-- The transmogrifier has never been opened, so its frames do not exist yet.
TransmogFrame = nil
TransmogItems:Refresh()
assert(visualIDs(C_TransmogCollection.GetCategoryAppearances(1)) == "4,1,2,3,5,6",
    "narrowed nothing before the transmogrifier has built its frames")

print("Lucky's Wardrobe transmog items tests passed")
