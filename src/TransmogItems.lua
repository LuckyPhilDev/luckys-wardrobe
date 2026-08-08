-- luacheck: globals C_Item C_TransmogCollection CHECK_ALL CreateFrame EventUtil FILTERS MenuResponse SOURCES TransmogFrame UNCHECK_ALL WardrobeCollectionFrame

-- Lucky's Wardrobe: the Expansion submenu the set lists carry, brought to the
-- Items tab at the transmogrifier. Picking a weapon to go with a set from one
-- expansion means reading a category of hundreds with nothing to go on but the
-- look of each, and the tab's own button narrows by where a piece came from
-- rather than when.
--
-- With two things to narrow by, the button is Filters rather than Sources and
-- holds one submenu for each. Blizzard's own source boxes are rebuilt here to
-- get there: the menu API can add to the menu they build but cannot take
-- anything out of it, and a page of loose boxes with a submenu on the end reads
-- as two different kinds of thing.
--
-- The Collections journal's Appearances tab reads the same call and carries no
-- box of ours to undo a filter with, so it is left alone.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.TransmogItems = {}

local TransmogItems = LuckysWardrobe.TransmogItems
local ExtraSets = LuckysWardrobe.ExtraSets
local Utils = LuckysWardrobe.Utils

-- The box for a piece the client files under no expansion at all, keyed by a
-- name so it can never collide with an expansionID. Shop and promotional pieces
-- land in it, and it is the Items tab's alone: only a piece carries an item to
-- read a source off, which is what places it there.
local NO_EXPANSION = "none"

-- Which expansions the tab is showing, keyed by Blizzard's expansionID, plus the
-- one box below the divider. Held for the session rather than saved, as every
-- other list here holds its own.
--
-- There is no Unknown box, which the Extra Sets lists carry. Theirs holds sets a
-- bundled snapshot cannot date and never will; an appearance here is undated
-- only for the moment before the client answers about its item, so a box for it
-- would read as permanently empty and hide half a cold slot if it were ticked
-- off. Undated appearances are simply kept.
local expansions = {}

local function setAllExpansions(shown)
    Utils.SetAllExpansions(expansions, shown)
    expansions[NO_EXPANSION] = shown
end

local function anyExpansionHidden()
    if not expansions[NO_EXPANSION] then return true end
    return Utils.AnyExpansionHidden(expansions)
end

setAllExpansions(true)

-- Hiding a slot belongs to no expansion, and is the one entry a filter must
-- never take away: without it there is no way to wear nothing. It is asked
-- about first so nothing goes looking for a date it could not have.
local function keeps(appearance, shownExpansions, expansionOf)
    if appearance.isHideVisual then return true end

    -- No box for it covers two things, and neither is taken away on the strength
    -- of having nowhere to go. An appearance the client has not answered about
    -- yet is answered a moment later and filed properly, and one dated to an
    -- expansion this version has no name for would otherwise vanish from a
    -- filtered page the patch it shipped in.
    local shown = shownExpansions[expansionOf(appearance.visualID)]
    return shown ~= false
end

-- The appearances from the expansions still ticked. expansionOf answers with an
-- expansionID, the No Expansion box, or nil for an appearance nothing dates yet.
function TransmogItems.AppearancesFromExpansions(appearances, shownExpansions, expansionOf)
    local kept = {}
    for _, appearance in ipairs(appearances) do
        if keeps(appearance, shownExpansions, expansionOf) then kept[#kept + 1] = appearance end
    end
    return kept
end

-- Live glue from here down.

-- What an appearance is dated to, worked out once and kept for the session. The
-- tab asks about every appearance it lists on every refresh and a category runs
-- to hundreds, so asking the client again each time would be thousands of reads
-- a keystroke.
local dated = {}

-- Items already asked about, so a pass asks after the ones nothing has been
-- asked about rather than asking again for answers still in flight.
local requested = {}

-- How many items one pass is willing to ask about, matching the Extra Sets tab.
-- A cold client knows almost nothing about the collection, and asking after
-- every appearance at once is thousands of requests in a single frame.
local ITEM_LOAD_BUDGET = 200
local budget = 0

-- Listens for the answers to come back, so the tab can read the dates again.
local itemFrame = CreateFrame("Frame")

local refreshWhenItemsLand = Utils.Debounced(Utils.ITEM_LOAD_DELAY_SECONDS, function()
    -- Answers stop being interesting the moment the pass has nothing left to
    -- wait for, and this event fires all game long. The next pass asks for more
    -- and registers again if anything is still cold.
    itemFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    TransmogItems:Refresh()
end)

itemFrame:SetScript("OnEvent", refreshWhenItemsLand)

-- Only an item's own data carries the expansion it belongs to, and the client
-- holds none of it until asked. An appearance has several sources and any one
-- of them dates it, so the first that answers settles the matter. Where none
-- answers, one item is asked after rather than all of them: the rest would be
-- a thousand requests for an answer the first will bring back anyway.
--
-- Expansion 0 is what the client answers both for a piece that really is
-- Classic and for one it files under no expansion at all, so a shop crest lands
-- beside Ragnaros' drops. Whether anything says where the piece came from is
-- what separates them: the pieces filed under nothing carry no source either,
-- while a Classic drop is a boss drop, a quest reward, or a vendor's.
local function expansionOf(visualID)
    local known = dated[visualID]
    if known ~= nil then return known end

    local expansionID, sourced, cold
    for _, sourceID in ipairs(C_TransmogCollection.GetAllAppearanceSources(visualID) or {}) do
        local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
        local itemID = sourceInfo and sourceInfo.itemID
        if itemID then
            if sourceInfo.sourceType ~= nil then sourced = true end
            if expansionID == nil then
                expansionID = select(15, C_Item.GetItemInfo(itemID))
                if expansionID == nil then cold = cold or itemID end
            end
        end
    end

    if expansionID == nil then
        if cold and not requested[cold] and budget > 0 then
            budget = budget - 1
            requested[cold] = true
            C_Item.RequestLoadItemDataByID(cold)
            itemFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        end
        return nil
    end

    if expansionID == 0 and not sourced then expansionID = NO_EXPANSION end
    dated[visualID] = expansionID
    return expansionID
end

local function itemsFrame()
    local wardrobe = TransmogFrame and TransmogFrame.WardrobeCollection
    local content = wardrobe and wardrobe.TabContent
    return content and content.ItemsFrame
end

-- Redraws the tab for a filter changed while the transmogrifier is open. The
-- frame reads the appearance list afresh, so there is nothing of ours to clear
-- first.
function TransmogItems:Refresh()
    local frame = itemsFrame()
    if frame and frame:IsShown() and type(frame.RefreshCollectionEntries) == "function" then
        frame:RefreshCollectionEntries()
    end
end

-- Whether this call is the transmogrifier's Items tab asking with something
-- actually narrowed. The Collections journal reads the same call, and while it
-- is on screen it is the one asking, so it takes the client's own list back.
local function narrowing()
    if not anyExpansionHidden() then return false end
    if WardrobeCollectionFrame and WardrobeCollectionFrame:IsVisible() then return false end

    local frame = itemsFrame()
    return frame ~= nil and frame:IsVisible()
end

-- Blizzard's own source boxes, put behind a submenu to sit beside the expansion
-- one. Every box is read off the client rather than named here, so a patch that
-- adds a source brings it along, and each does exactly what it did loose: the
-- tab redraws off the collection changing rather than off the menu.
local function addSourceFilter(rootDescription)
    local menu = rootDescription:CreateButton(SOURCES)
    menu:CreateButton(CHECK_ALL, function()
        C_TransmogCollection.SetAllSourceTypeFilters(true)
        return MenuResponse.Refresh
    end)
    menu:CreateButton(UNCHECK_ALL, function()
        C_TransmogCollection.SetAllSourceTypeFilters(false)
        return MenuResponse.Refresh
    end)
    menu:CreateDivider()

    local function isChecked(source)
        return C_TransmogCollection.IsSourceTypeFilterChecked(source)
    end
    local function setChecked(source)
        C_TransmogCollection.SetSourceTypeFilter(source, not isChecked(source))
    end
    for source = 1, C_TransmogCollection.GetNumTransmogSources() do
        if C_TransmogCollection.IsValidTransmogSource(source) then
            menu:CreateCheckbox(_G["TRANSMOG_SOURCE_" .. source], isChecked, setChecked, source)
        end
    end
end

-- The tab's own filter button, where somebody narrowing the list is already
-- looking. The tag Blizzard put on the menu they built comes along, so another
-- addon that appends to it still finds it here.
local function buildFilterMenu(_dropdown, rootDescription)
    rootDescription:SetTag("MENU_TRANSMOG_ITEMS_FILTER")

    addSourceFilter(rootDescription)
    ExtraSets.AddExpansionFilter(rootDescription, expansions, function()
        TransmogItems:Refresh()
    end, { { key = NO_EXPANSION, label = LuckysWardrobe.Strings.filterMenu.noExpansion } })
end

-- The button also marks itself as holding a filter, and offers to put it back.
-- Left alone it would answer for Blizzard's own boxes and quietly ignore ours,
-- so a list narrowed by ours would look untouched and the reset would leave it
-- narrowed.
local function claimFilterButton()
    local frame = itemsFrame()
    local button = frame and frame.FilterButton
    if not button then return end

    -- Sources is no longer the whole of what the button holds.
    button:SetText(FILTERS)
    button:SetupMenu(buildFilterMenu)

    button:SetIsDefaultCallback(function()
        return not anyExpansionHidden() and C_TransmogCollection.IsUsingDefaultFilters()
    end)
    button:SetDefaultCallback(function()
        setAllExpansions(true)
        C_TransmogCollection.SetDefaultFilters()
        TransmogItems:Refresh()
    end)
end

-- Dev only. Expansion 0 is what the client answers both for a piece that really
-- is Classic and for one it will not date at all, so shop and promotional pieces
-- land in the Classic box beside Ragnaros' drops. Which of the client's own
-- answers separates the two has to be read off the client rather than guessed
-- at, so this lists them for the category on screen: the source type behind
-- every appearance in a box, counted, with a few named.
local EXAMPLE_LIMIT = 20

local function sourceNames()
    local names = {}
    for name, value in pairs(Enum.TransmogSource or {}) do names[value] = name end
    return names
end

local function firstSourceInfo(visualID)
    for _, sourceID in ipairs(C_TransmogCollection.GetAllAppearanceSources(visualID) or {}) do
        local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
        if sourceInfo and sourceInfo.itemID then return sourceInfo end
    end
end

-- box is what was typed after the command: an expansion's number, or the name
-- of one of the boxes below the divider, and Classic when nothing was.
function TransmogItems:PrintDates(box)
    local S = LuckysWardrobe.Strings.transmogItems
    local frame = itemsFrame()
    if not frame or not frame.activeCategoryID or not frame.transmogLocation then
        return Utils.Say(S.noCategory)
    end

    local expansionID = tonumber(box) or (box ~= "" and box) or 0
    local read = TransmogItems.getCategoryAppearances or C_TransmogCollection.GetCategoryAppearances
    local appearances = read(frame.activeCategoryID, frame.transmogLocation:GetData()) or {}

    -- The probe warms the cache the same way a filtered pass does, so running it
    -- twice says more than running it once.
    budget = ITEM_LOAD_BUDGET
    local names = sourceNames()
    local counts, order, examples, inBox = {}, {}, {}, 0
    for _, appearance in ipairs(appearances) do
        if not appearance.isHideVisual and expansionOf(appearance.visualID) == expansionID then
            inBox = inBox + 1
            local sourceInfo = firstSourceInfo(appearance.visualID)
            local source = names[sourceInfo and sourceInfo.sourceType] or UNKNOWN
            if not counts[source] then order[#order + 1] = source end
            counts[source] = (counts[source] or 0) + 1
            if #examples < EXAMPLE_LIMIT then
                local itemID = sourceInfo and sourceInfo.itemID
                local name = sourceInfo and sourceInfo.name
                if (not name or name == "") and itemID then name = C_Item.GetItemInfo(itemID) end
                examples[#examples + 1] =
                    S.datesExample:format(name or UNKNOWN, tostring(itemID), source)
            end
        end
    end

    local label = type(expansionID) == "number"
        and (Utils.EXPANSION_NAMES[expansionID + 1] or expansionID)
        or expansionID
    -- The client will not always name a category, so its number stands in
    -- rather than an empty space where the slot should be.
    local category = C_TransmogCollection.GetCategoryInfo(frame.activeCategoryID)
    if not category or category == "" then category = frame.activeCategoryID end
    Utils.Say(S.datesHeader:format(tostring(category), inBox, #appearances, tostring(label)))
    for _, source in ipairs(order) do
        Utils.Say(S.datesSource:format(source, counts[source]))
    end
    for _, example in ipairs(examples) do Utils.Say(example) end
end

function TransmogItems:Init()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Transmog", claimFilterButton)

    -- The tab builds its page from this one call, so narrowing the answer
    -- narrows the tab without touching a frame the client owns.
    if TransmogItems.getCategoryAppearances
        or type(C_TransmogCollection.GetCategoryAppearances) ~= "function" then
        return
    end
    TransmogItems.getCategoryAppearances = C_TransmogCollection.GetCategoryAppearances
    C_TransmogCollection.GetCategoryAppearances = function(...)
        local appearances = TransmogItems.getCategoryAppearances(...)
        if not appearances or not narrowing() then return appearances end

        budget = ITEM_LOAD_BUDGET
        return TransmogItems.AppearancesFromExpansions(appearances, expansions, expansionOf)
    end
end
