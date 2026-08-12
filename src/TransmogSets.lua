-- luacheck: globals C_Item C_TransmogCollection C_TransmogSets CHECK_ALL Enum EventUtil Menu MenuResponse TransmogFrame UNCHECK_ALL UnitClass

-- Lucky's Wardrobe: Blizzard's own Sets tab at the transmogrifier, narrowed to
-- the sets this character could actually dress in. The tab lists a set the
-- moment one piece of it is usable, and every class can wear a cloak, so a monk
-- is offered warrior plate and priest cloth it can take nothing but the cloak
-- from: pages of cards for the sake of one item each. The Collections journal is
-- left alone, because browsing a set is not wearing it.
--
-- The tab's Filter button also gains the Expansion submenu the other two set
-- lists carry, so a wall of cards can be cut down to the expansion you are
-- actually working through.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.TransmogSets = {}

local TransmogSets = LuckysWardrobe.TransmogSets
local Utils = LuckysWardrobe.Utils

local db

-- Which expansions the tab is showing, keyed by Blizzard's expansionID. Held
-- for the session rather than saved, as the other two set lists hold theirs: a
-- filter that outlives a login is one you have forgotten setting when half your
-- sets are missing a week later.
local expansions = {}

local function setAllExpansions(shown)
    Utils.SetAllExpansions(expansions, shown)
end

setAllExpansions(true)

-- The slots anybody can wear whatever their class. A cloak is cloth however
-- plated the set it hangs off, so a set judged on its cloak would be kept for
-- every class at once, which is the whole complaint.
local UNIVERSAL_SLOTS = {
    INVTYPE_CLOAK = true,
    INVTYPE_BODY = true,
    INVTYPE_TABARD = true,
}

-- The armour subclasses a class is held to one of, as the client's own IDs and
-- the same ones Classes:ArmourType answers in. Everything else a set can be
-- made of, cosmetic pieces among them, is worn by anybody.
local RESTRICTED_ARMOUR = { [1] = true, [2] = true, [3] = true, [4] = true }

-- Whether a set is one this character could dress in rather than take a single
-- piece from. pieces are { slot = equip location, armour = armour subclass },
-- one per look the set covers.
--
-- Leather is leather whoever the set was built for, so a monk keeps the druid
-- and rogue sets: their pieces go on. A set holding no restricted armour at all
-- belongs to everybody, which is how the cosmetic and outfit collections read,
-- and so does every set at once for a class this version has no armour type for.
function TransmogSets.WearsArmourOf(pieces, wornArmour)
    if not wornArmour then return true end

    local restricted = false
    for _, piece in ipairs(pieces) do
        if not UNIVERSAL_SLOTS[piece.slot] and RESTRICTED_ARMOUR[piece.armour] then
            if piece.armour == wornArmour then return true end
            restricted = true
        end
    end
    return not restricted
end

function TransmogSets.WearableSets(sets, canWearSet)
    local wearable = {}
    for _, set in ipairs(sets) do
        if canWearSet(set.setID) then wearable[#wearable + 1] = set end
    end
    return wearable
end

-- The sets from the expansions still ticked. shownExpansions is keyed by
-- Blizzard's expansionID, which the client hands out with every set.
--
-- matchesSearch, where given, narrows the list a second time to whatever the
-- search box was told. It is injected rather than read here so the rules stay
-- testable outside the client.
function TransmogSets.SetsFromExpansions(sets, shownExpansions, matchesSearch)
    local kept = {}
    for _, set in ipairs(sets) do
        if shownExpansions[set.expansionID] and (not matchesSearch or matchesSearch(set)) then
            kept[#kept + 1] = set
        end
    end
    return kept
end

-- What the search box means by "pvp" here: the same category the Sets tab's own
-- Sources filter puts a set under, so typing it and ticking it agree.
function TransmogSets.MatchesSearch(set)
    local SetSources = LuckysWardrobe.SetSources
    local SetSearch = LuckysWardrobe.SetSearch
    return SetSearch.Matches(SetSearch.Narrowing(), set.expansionID,
        SetSources:Classify(set) == SetSources.PVP)
end

-- Live glue from here down.

-- What a set is made of, asked of the item data that ships with the client
-- rather than the item cache: GetItemInfoInstant answers about an item nobody
-- has looked at this session, so a set is judged the first time it is listed
-- rather than on a later visit.
local function setPieces(setID)
    local pieces = {}
    for _, appearance in ipairs(C_TransmogSets.GetSetPrimaryAppearances(setID) or {}) do
        local sourceInfo = C_TransmogCollection.GetSourceInfo(appearance.appearanceID)
        local itemID = sourceInfo and sourceInfo.itemID
        if itemID then
            local _, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
            if classID == Enum.ItemClass.Armor then
                pieces[#pieces + 1] = { slot = equipLoc, armour = subClassID }
            end
        end
    end
    return pieces
end

-- What a set is made of never changes, and neither does the armour this
-- character wears, so a verdict is reached once and kept for the session. The
-- tab asks about every set it lists on every refresh, and there are hundreds.
local verdicts = {}

local function canWearSet(setID, wornArmour)
    local verdict = verdicts[setID]
    if verdict ~= nil then return verdict end

    -- A set the client has not described yet is kept rather than judged on
    -- nothing, and no verdict is written down for it either.
    local pieces = setPieces(setID)
    if #pieces == 0 then return true end

    verdict = TransmogSets.WearsArmourOf(pieces, wornArmour)
    verdicts[setID] = verdict
    return verdict
end

local function wornArmourType()
    return LuckysWardrobe.Classes:ArmourType(select(3, UnitClass("player")))
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

function TransmogSets:Toggle()
    db.hideUnwearableSets = not db.hideUnwearableSets
    self:Refresh()
end

-- The Expansion submenu the Sets tab in the Collections journal and the Extra
-- Sets tab both carry, so narrowing to the expansion you are working through
-- reads the same wherever sets are listed.
local function addExpansionFilter(rootDescription)
    local menu = rootDescription:CreateButton(LuckysWardrobe.Strings.filterMenu.expansion)
    menu:CreateButton(CHECK_ALL, function()
        setAllExpansions(true)
        TransmogSets:Refresh()
        return MenuResponse.Refresh
    end)
    menu:CreateButton(UNCHECK_ALL, function()
        setAllExpansions(false)
        TransmogSets:Refresh()
        return MenuResponse.Refresh
    end)
    menu:CreateDivider()
    for index, name in ipairs(Utils.EXPANSION_NAMES) do
        local expansionID = index - 1
        menu:CreateCheckbox(name, function() return expansions[expansionID] end, function()
            expansions[expansionID] = not expansions[expansionID]
            TransmogSets:Refresh()
        end)
    end
end

-- The tab's own Filter button, where somebody narrowing the list is already
-- looking. Blizzard tags the menu for exactly this, so the entry is appended to
-- the menu they built rather than to one of ours built over the top: their
-- boxes stay theirs, and a patch that adds another brings it along.
local function addFilterEntry(_owner, rootDescription)
    -- The expansion submenu joins Blizzard's own boxes above the divider, since
    -- it narrows the list exactly as they do. That leaves the divider marking
    -- off what this addon adds rather than sitting in the middle of the filters.
    addExpansionFilter(rootDescription)
    rootDescription:CreateDivider()
    rootDescription:CreateCheckbox(
        LuckysWardrobe.Strings.settings.hideUnwearableSets.label,
        function() return db.hideUnwearableSets end,
        function() TransmogSets:Toggle() end)
    -- The set names belong under the same divider rather than behind one of
    -- their own, so everything this addon adds to the menu reads as one group.
    LuckysWardrobe.TransmogSetNames:AddFilterOption(rootDescription)
end

-- The button marks itself as holding a filter, and offers to put it back. Left
-- alone it would answer for Blizzard's own boxes and quietly ignore ours, so a
-- list narrowed by ours would look untouched and the reset would leave it
-- narrowed.
local function claimFilterDefaults()
    local frame = setsFrame()
    local button = frame and frame.FilterButton
    if not button then return end

    button:SetIsDefaultCallback(function()
        return db.hideUnwearableSets
            and not Utils.AnyExpansionHidden(expansions)
            and C_TransmogSets.IsUsingDefaultSetsFilters()
    end)
    button:SetDefaultCallback(function()
        db.hideUnwearableSets = true
        setAllExpansions(true)
        C_TransmogSets.SetDefaultSetsFilters()
        TransmogSets:Refresh()
    end)
end

function TransmogSets:Init(database)
    db = database

    Menu.ModifyMenu("MENU_TRANSMOG_SETS_FILTER", addFilterEntry)
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Transmog", claimFilterDefaults)

    -- The tab builds its cards from this one call, so narrowing the answer
    -- narrows the tab without touching a frame the client owns. Blizzard_Transmog
    -- loads on demand, but the namespace this wraps is there from the start and
    -- nothing reads it until the transmogrifier opens.
    if TransmogSets.getAvailableSets or type(C_TransmogSets.GetAvailableSets) ~= "function" then return end
    TransmogSets.getAvailableSets = C_TransmogSets.GetAvailableSets
    C_TransmogSets.GetAvailableSets = function(...)
        local sets = TransmogSets.SetsFromExpansions(TransmogSets.getAvailableSets(...), expansions,
            TransmogSets.MatchesSearch)
        if not db.hideUnwearableSets then return sets end

        local wornArmour = wornArmourType()
        return TransmogSets.WearableSets(sets, function(setID)
            return canWearSet(setID, wornArmour)
        end)
    end
end
