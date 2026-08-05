-- luacheck: globals AutoScalingFontStringMixin CHECK_ALL COLLECTED CollectionWardrobeUtil CreateDataProvider CreateScrollBoxListLinearView DEFAULT EXPANSION_NAME0 EXPANSION_NAME1 EXPANSION_NAME2 EXPANSION_NAME3 EXPANSION_NAME4 EXPANSION_NAME5 EXPANSION_NAME6 EXPANSION_NAME7 EXPANSION_NAME8 EXPANSION_NAME9 EXPANSION_NAME10 EXPANSION_NAME11 EventUtil GetUICameraInfo IsShiftKeyDown IsUnitModelReadyForUI MenuResponse Mixin Model_ApplyUICamera NOT_COLLECTED PanelTemplates_ResizeTabsToFit PanelTemplates_SetNumTabs PanelTemplates_TabResize QUESTION_MARK_ICON ScrollBoxConstants ScrollUtil UNCHECK_ALL UnitClass WardrobeCollectionFrame WardrobeSetsDetailsModelMixin hooksecurefunc

-- Lucky's Wardrobe: Extra Sets, a third Appearances subtab listing the armour
-- sets Blizzard defines, most of which its own Sets tab never shows. Records
-- come from the session catalogue ExtraSetsCatalog.lua builds out of the
-- bundled snapshot; everything derived (names, icons, collected state) is read
-- live from Blizzard APIs and never persisted.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.ExtraSets = {}

local ExtraSets = LuckysWardrobe.ExtraSets

local TAB_FIT_WIDTH = 275
local NATIVE_ITEMS_TAB_ID = 1
local NATIVE_SETS_TAB_ID = 2
-- How long a burst of collection events is allowed to gather before the page
-- reads the catalogue again. Long enough to collapse a burst, short enough
-- that collecting something still updates the list while you are looking at it.
local REBUILD_DELAY_SECONDS = 0.25
-- How long the page waits for the items behind a set's pieces to arrive before
-- reading them again. Some never arrive, so the wait is given up after a few
-- passes rather than run until it succeeds.
local ITEM_LOAD_DELAY_SECONDS = 0.5
local ITEM_LOAD_PASSES = 3

-- The smallest the Sets tab lets a set name shrink to before it gives up and
-- wraps it instead.
local NAME_MIN_LINE_HEIGHT = 16

-- The offsets Blizzard gives the class dropdown above the Sets page.
local CLASS_DROPDOWN_X = -9
local CLASS_DROPDOWN_Y = 4

-- Blizzard places the collected-sets bar for a two-tab strip, so a third tab
-- runs underneath it. It moves into the gap between the end of the strip and
-- the class dropdown, and gives up some width to sit there.
local PROGRESS_BAR_WIDTH = 150
local PROGRESS_BAR_TAB_GAP = 10
local PROGRESS_BAR_TAB_DROP = -11
local PROGRESS_BAR_BORDER_MARGIN = 9

-- Blizzard's localized slot-name globals, for the tooltip's slot line. A slot
-- with no entry here is one the page could not label, so records are held to
-- the slots named below.
local SLOT_TOOLTIP_GLOBALS = {
    HEAD = "HEADSLOT",
    SHOULDER = "SHOULDERSLOT",
    BACK = "BACKSLOT",
    CHEST = "CHESTSLOT",
    BODY = "SHIRTSLOT",
    TABARD = "TABARDSLOT",
    WRIST = "WRISTSLOT",
    HANDS = "HANDSSLOT",
    WAIST = "WAISTSLOT",
    LEGS = "LEGSSLOT",
    FEET = "FEETSLOT",
}

local expansionNames = {
    EXPANSION_NAME0,
    EXPANSION_NAME1,
    EXPANSION_NAME2,
    EXPANSION_NAME3,
    EXPANSION_NAME4,
    EXPANSION_NAME5,
    EXPANSION_NAME6,
    EXPANSION_NAME7,
    EXPANSION_NAME8,
    EXPANSION_NAME9,
    EXPANSION_NAME10,
    EXPANSION_NAME11,
}

-- Session-only view state behind the filter button, matching the Sets tab menu.
-- The class is not in here: it narrows the catalogue before entries are built,
-- rather than hiding rows that have already been worked out.
local filters = {
    collected = true,
    uncollected = true,
    expansions = {},
    sortMode = "default",
    sortDirection = "ascending",
}

-- Keyed by Blizzard's expansionID, which counts from 0 for Classic. The name
-- list is a Lua array counting from 1, so every lookup here is index - 1.
local function setAllExpansions(shown)
    for index = 1, #expansionNames do filters.expansions[index - 1] = shown end
end

-- Which colourway each set is showing, keyed by group. Session-only, like the
-- filters: which tint you were last looking at is not worth keeping past logout.
local selectedVariants = {}

local function isNarrowed()
    if not (filters.collected and filters.uncollected) then return true end
    for index = 1, #expansionNames do
        if not filters.expansions[index - 1] then return true end
    end
    return false
end

setAllExpansions(true)

local attachedWardrobe
local extraPage
local extraTab
local extraTabID

-- The colourway picker, sized and placed like the one the Sets tab hangs in the
-- top corner of its own details pane.
local VARIANT_DROPDOWN_WIDTH = 170
local VARIANT_DROPDOWN_HEIGHT = 22
local VARIANT_DROPDOWN_X = -10
local VARIANT_DROPDOWN_Y = -8

-- Pure catalogue logic. Everything below takes plain tables plus injected
-- resolvers so the rules stay testable outside the client.

function ExtraSets.ValidateRecord(record)
    if type(record) ~= "table" then return nil, "record must be a table" end
    if type(record.setID) ~= "number" or record.setID <= 0 or record.setID % 1 ~= 0 then
        return nil, "setID must be a positive integer"
    end
    if type(record.name) ~= "string" or record.name == "" then return nil, "name is required" end
    if record.label ~= nil and type(record.label) ~= "string" then return nil, "label must be a string" end
    if record.expansionID ~= nil and type(record.expansionID) ~= "number" then
        return nil, "expansionID must be a number"
    end
    if type(record.armorType) ~= "number" then return nil, "armorType is required" end
    if type(record.classMask) ~= "number" or record.classMask < 0 then return nil, "classMask is required" end
    if type(record.pieces) ~= "table" or #record.pieces == 0 then return nil, "pieces are required" end

    local seenSourceIDs = {}
    for _, piece in ipairs(record.pieces) do
        if not SLOT_TOOLTIP_GLOBALS[piece.slot] then return nil, "unknown slot: " .. tostring(piece.slot) end
        if type(piece.sourceID) ~= "number" or piece.sourceID <= 0 or piece.sourceID % 1 ~= 0 then
            return nil, "sourceID must be a positive integer"
        end
        if seenSourceIDs[piece.sourceID] then return nil, "duplicate sourceID: " .. piece.sourceID end
        seenSourceIDs[piece.sourceID] = true
    end
    return true
end

function ExtraSets.ClassAllowed(classMask, classID)
    if classMask == 0 or not classID then return true end
    local classBit = 2 ^ (classID - 1)
    return math.floor(classMask / classBit) % 2 == 1
end

-- What one class has any use for: the sets named for it, plus the sets named
-- for nobody in the armour that class wears. A set belonging to another class,
-- or to nobody in armour this class cannot transmogrify, is not a set this
-- character will ever wear, so it never becomes a row.
function ExtraSets.MatchesClass(record, classID)
    if not classID then return true end
    if record.classMask ~= 0 then return ExtraSets.ClassAllowed(record.classMask, classID) end

    local armourType = LuckysWardrobe.Classes:ArmourType(classID)
    return armourType == nil or record.armorType == armourType
end

-- Both pages read one class dropdown, so a set Blizzard's Sets tab lists for
-- the chosen class is a row the player has already seen. A set it lists only
-- under another class is not: that dropdown is showing this one.
function ExtraSets.ListedNatively(record, classID)
    local listedFor = record.officialClassMask or 0
    if listedFor == 0 then return false end
    if not classID then return true end
    return ExtraSets.ClassAllowed(listedFor, classID)
end

-- What is left for this page to show: the sets the class could wear, less the
-- ones the Sets tab is already showing them.
function ExtraSets.RecordsForClass(records, classID)
    local matching = {}
    for _, record in ipairs(records) do
        if ExtraSets.MatchesClass(record, classID) and not ExtraSets.ListedNatively(record, classID) then
            matching[#matching + 1] = record
        end
    end
    return matching
end

-- What a set looks like, as one comparable value: its distinct appearances in a
-- fixed order. Two sets with the same key are one look wearing two names, which
-- is what makes the second a duplicate rather than something else to collect.
--
-- A set still loading has no key. Its unresolved pieces would leave it looking
-- like a shorter set and fold it into one it has nothing to do with, so it waits
-- for the rebuild that follows the client answering.
function ExtraSets.AppearanceKey(appearances, loading)
    if loading then return nil end

    local ids = {}
    for id in pairs(appearances) do ids[#ids + 1] = id end
    if #ids == 0 then return nil end

    table.sort(ids)
    return table.concat(ids, ",")
end

-- The colourways of one set share a name and differ only in the parenthetical
-- the snapshot puts after it: "(Heroic Recolor)", "(Alliance Recolor)". Dropping
-- that gives the set itself, which is what gathers its colourways together. A
-- name the client supplied carries no parenthetical, so it is its own base name.
function ExtraSets.BaseName(name)
    local stripped = name:gsub("%s*%b()%s*$", "")
    if stripped == "" then return name end
    return stripped
end

-- What a colourway is called once its set name is the row above it. Repeating
-- the set name on every one of its colourways is the noise the grouping exists
-- to remove, so only the parenthetical that tells them apart is left.
function ExtraSets.VariantLabel(name)
    return name:match("%(([^()]*)%)%s*$") or name
end

-- Sets gathered by the name they share, in the order they first appear, so
-- whatever sort produced the list still decides where each set lands.
local function families(entries)
    local byName, order = {}, {}
    for _, entry in ipairs(entries) do
        local key = tostring(entry.armorType) .. "|" .. ExtraSets.BaseName(entry.name)
        if not byName[key] then
            byName[key] = { key = key }
            order[#order + 1] = byName[key]
        end
        table.insert(byName[key], entry)
    end
    return order
end

local function containsLookOf(larger, smaller)
    for id in pairs(smaller.appearances) do
        if larger.appearances[id] == nil then return false end
    end
    return true
end

-- Whether the Sets tab's set already shows most of this set's looks. All of
-- them would be the natural bar, but the old five-piece tiers make it too
-- high: Blizzard's listing and the bundled one each pad the tier out with
-- off-set accessories for the empty slots, they rarely pick the same ones,
-- and three stray accessories should not keep a tier's worth of looks listed
-- twice. Most-of agreement is the standard SameSet already applies to set
-- identity. A true recolour stays listed either way: its tinted pieces are
-- the majority of it, and they are exactly what the tab's set does not hold.
local function nativeHolds(rival, entry)
    local matched = 0
    for id in pairs(entry.appearances) do
        if rival.appearances[id] ~= nil then matched = matched + 1 end
    end
    return matched * 2 >= entry.total
end

-- The first set in the family this one adds nothing worth a row to: a native
-- look holding most of it, or an earlier row whose looks include all of this
-- one's and more.
local function containedIn(entry, family)
    if not entry.appearanceKey then return nil end

    for _, other in ipairs(family) do
        if other.native then
            if nativeHolds(other, entry) then return other end
        elseif other.appearanceKey and other.total > entry.total and containsLookOf(other, entry) then
            return other
        end
    end
end

-- The looks the Sets tab itself shows, shaped to stand in a family beside this
-- page's own entries: named, keyed on their looks, and marked native so no row
-- is ever built from one. A look the client answered nothing for has no key
-- and cannot fold anything, so it is left out here.
local function nativeRivals(nativeLooks)
    local rivals = {}
    for _, look in ipairs(nativeLooks or {}) do
        local appearanceKey = ExtraSets.AppearanceKey(look.appearances)
        if appearanceKey then
            local total = 0
            for _ in pairs(look.appearances) do total = total + 1 end
            rivals[#rivals + 1] = {
                native = true,
                name = look.name,
                armorType = look.armorType,
                appearances = look.appearances,
                appearanceKey = appearanceKey,
                total = total,
            }
        end
    end
    return rivals
end

-- Folds the sets that are the same look into one row. Wowhead names a single
-- appearance twice, once "(... Recolor)" and once "(... Lookalike)", and the
-- snapshot carries each as its own set: around a fifth of the catalogue is a
-- look already listed under another name.
--
-- Identical looks fold whatever they are called, because two names for one look
-- are one row however far apart the names sit. A look merely *contained* in
-- another, a Lookalike that is its Recolor without the helm, folds only within
-- one set name: containment happens often enough between unrelated sets that
-- allowing it across names would hide small sets inside big ones.
--
-- The surviving row keeps the names it absorbed, so searching for one still
-- finds it.
--
-- The Sets tab's own looks fold the same way, only with a lower bar inside a
-- name: identical looks fold whatever they are called, and under the tab's own
-- set name a set folds once the tab already shows most of its looks, which is
-- what keeps a tier's "(... Recolor)" listings off this page even where the
-- two sides padded the tier's empty slots with different accessories. A set
-- folded into a native look leaves no row and no absorbed name, because the
-- place to see it is the Sets tab; it is answered for in the second return,
-- which is what the report and the find command read.
function ExtraSets.CollapseDuplicates(entries, nativeLooks)
    local rivals = nativeRivals(nativeLooks)
    local survivorOf, firstOfLook, kept = {}, {}, {}
    for _, rival in ipairs(rivals) do
        if not firstOfLook[rival.appearanceKey] then firstOfLook[rival.appearanceKey] = rival end
    end
    for _, entry in ipairs(entries) do
        local twin = entry.appearanceKey and firstOfLook[entry.appearanceKey]
        if twin then
            survivorOf[entry] = twin
        else
            if entry.appearanceKey then firstOfLook[entry.appearanceKey] = entry end
            kept[#kept + 1] = entry
        end
    end

    -- Native looks stand first in their family, so a set they contain folds to
    -- the Sets tab rather than into a larger row of this page.
    local candidates = {}
    for _, rival in ipairs(rivals) do candidates[#candidates + 1] = rival end
    for _, entry in ipairs(kept) do candidates[#candidates + 1] = entry end
    for _, family in ipairs(families(candidates)) do
        for _, entry in ipairs(family) do
            if not entry.native then
                survivorOf[entry] = containedIn(entry, family)
            end
        end
    end

    -- Names are gathered against the row that survives, following a chain of
    -- containments to its end: each step holds strictly more looks than the
    -- last, so the walk always finishes. A chain ending at a native look has
    -- no row to gather against, so the whole chain is folded away with it.
    local absorbedNames, nativeFolds = {}, {}
    for _, entry in ipairs(entries) do
        local survivor = survivorOf[entry]
        if survivor then
            while survivorOf[survivor] do survivor = survivorOf[survivor] end
            if survivor.native then
                nativeFolds[#nativeFolds + 1] = {
                    setID = entry.setID,
                    name = entry.name,
                    nativeName = survivor.name,
                }
            else
                absorbedNames[survivor] = absorbedNames[survivor] or {}
                table.insert(absorbedNames[survivor], entry.name)
            end
        end
    end

    local rows = {}
    for _, entry in ipairs(kept) do
        if not survivorOf[entry] then
            entry.alternateNames = absorbedNames[entry]
            rows[#rows + 1] = entry
        end
    end
    return rows, nativeFolds
end

-- One row standing for a set's several colourways: named for the set, counting
-- every look across them so the row says how much of the whole set is collected.
-- It carries the first colourway's pieces, which is what the details pane shows
-- when the row is picked.
function ExtraSets.BuildGroup(variants)
    local first = variants[1]
    local collected, total, unavailable, loading = 0, 0, 0, false
    local appearances = {}
    for _, variant in ipairs(variants) do
        loading = loading or variant.loading
        unavailable = unavailable + variant.unavailable
        for id, isCollected in pairs(variant.appearances) do
            if appearances[id] == nil then
                appearances[id] = isCollected
                total = total + 1
                if isCollected then collected = collected + 1 end
            end
        end
    end

    return {
        key = "group:" .. first.armorType .. "|" .. ExtraSets.BaseName(first.name),
        isGroup = true,
        variants = variants,
        name = ExtraSets.BaseName(first.name),
        label = LuckysWardrobe.Strings.extraSets.colours:format(#variants),
        expansionID = first.expansionID,
        armorType = first.armorType,
        classMask = first.classMask,
        pieces = first.pieces,
        appearances = appearances,
        collected = collected,
        total = total,
        missing = total - collected,
        unavailable = unavailable,
        loading = loading,
    }
end

-- The rows the list shows: one per set, whatever it has been called and however
-- many colourways it comes in. A set with one look is that row unchanged; a set
-- with several is one row standing for them, and the details pane picks between
-- them the way the Sets tab does. Filters can leave a set with a single
-- colourway, and it goes back to being that plain row.
function ExtraSets.BuildRows(entries)
    local rows = {}
    for _, family in ipairs(families(entries)) do
        rows[#rows + 1] = #family == 1 and family[1] or ExtraSets.BuildGroup(family)
    end
    return rows
end

-- Which colourway of a set is on show. Defaults to the first, and falls back to
-- it when the one last picked has been filtered out from under the row.
function ExtraSets.VariantOf(row, chosenSetID)
    if not row.isGroup then return row end

    for _, variant in ipairs(row.variants) do
        if variant.setID == chosenSetID then return variant end
    end
    return row.variants[1]
end

-- resolver.sourceState(sourceID) returns nil when the source does not exist on
-- this client, or { appearanceID, collected } where collected == nil means the
-- appearance data has not loaded yet.
function ExtraSets.BuildEntries(records, resolver)
    local entries = {}
    local seenSetIDs = {}

    for _, record in ipairs(records) do
        local valid, problem = ExtraSets.ValidateRecord(record)
        if not valid then
            LuckysWardrobe.DevLog("Extra Sets record rejected: " .. tostring(problem))
        elseif seenSetIDs[record.setID] then
            LuckysWardrobe.DevLog("Extra Sets record rejected: duplicate set " .. record.setID)
        else
            seenSetIDs[record.setID] = true
            entries[#entries + 1] = ExtraSets.BuildEntry(record, resolver)
        end
    end

    return entries
end

function ExtraSets.BuildEntry(record, resolver)
    local pieces = {}
    for index, piece in ipairs(record.pieces) do
        pieces[index] = { slot = piece.slot, sourceID = piece.sourceID, itemID = piece.itemID }
    end

    -- Pieces the catalogue could not resolve at all never became sources, so
    -- they are counted here rather than shown as rows the tooltip cannot fill.
    local collected, total = 0, 0
    local unavailable = record.unresolvedPieces or 0
    local loading = false
    local appearances = {}
    for _, piece in ipairs(pieces) do
        local state = resolver.sourceState(piece.sourceID)
        if not state then
            piece.state = "unavailable"
            unavailable = unavailable + 1
        elseif state.collected == nil or state.appearanceID == nil then
            piece.state = "loading"
            loading = true
            total = total + 1
        else
            -- Sources sharing an appearance count once, matching how Blizzard
            -- counts official set completion.
            piece.state = state.collected and "collected" or "missing"
            -- Kept on the piece so the transmogrifier page can say whether the
            -- outfit on show is wearing this piece's look, whichever source of
            -- it the outfit actually carries.
            piece.appearanceID = state.appearanceID
            if appearances[state.appearanceID] == nil then
                appearances[state.appearanceID] = state.collected and true or false
                total = total + 1
                if state.collected then collected = collected + 1 end
            end
        end
    end

    return {
        key = record.setID,
        setID = record.setID,
        name = record.name,
        label = record.label or "",
        expansionID = record.expansionID,
        armorType = record.armorType,
        classMask = record.classMask,
        pieces = pieces,
        -- Which looks this set is made of, and whether each is collected. What
        -- makes two sets the same set, and what lets one row speak for several.
        appearances = appearances,
        appearanceKey = ExtraSets.AppearanceKey(appearances, loading),
        collected = collected,
        total = total,
        missing = total - collected,
        unavailable = unavailable,
        loading = loading,
    }
end

-- Why the chosen class could not wear the set, or nil when it could, which is
-- what the details panel says when it could not. Armour type is what keeps
-- most sets off a character and the class mask does not encode it, so the
-- refusal comes from the sources themselves and only then is it worth asking
-- what the class wears. Anything the client turns down for a reason of its
-- own, a race or faction lock among them, answers "other": there is nothing
-- more to tell the player than that it turned it down. Worked out for the set
-- on screen rather than for every set in the list, because only the one on
-- screen ever says so.
--
-- sourceValidity is the client's answer about the character being played, so it
-- is passed only while the chosen class is that character's own. Browsing
-- another class's sets is left with what the record itself says, which is the
-- honest limit: nothing here can ask the client how a class nobody is playing
-- would fare.
function ExtraSets.UnwearableReason(entry, classID, sourceValidity)
    if not ExtraSets.ClassAllowed(entry.classMask or 0, classID) then return "class" end
    if not sourceValidity then return nil end

    local judged, valid = 0, 0
    for _, piece in ipairs(entry.pieces) do
        local isValid = sourceValidity(piece.sourceID)
        if isValid ~= nil then
            judged = judged + 1
            if isValid then valid = valid + 1 end
        end
    end
    if judged == 0 or valid == judged then return nil end

    local wornArmour = LuckysWardrobe.Classes:ArmourType(classID)
    if wornArmour and entry.armorType and entry.armorType ~= wornArmour then return "armour" end
    return "other"
end

-- The line the details panel shows for a set out of reach, naming the reason
-- where there is one to name. A set whose mask holds no class this client has,
-- or an armour type it has no name for, falls back to saying only that the set
-- is out of reach rather than to a sentence with a hole in it.
function ExtraSets.UnwearableNotice(entry, reason, classID)
    local S = LuckysWardrobe.Strings.extraSets
    if reason == "class" then
        local classes = LuckysWardrobe.Classes:FromMask(entry.classMask)
        if #classes > 0 then return S.notUsableClass:format(LuckysWardrobe.Classes:Names(classes)) end
    elseif reason == "armour" then
        local setArmour = S.armourTypes[entry.armorType]
        local wornArmour = S.armourTypes[LuckysWardrobe.Classes:ArmourType(classID)]
        if setArmour and wornArmour then return S.notUsableArmour:format(setArmour, wornArmour) end
    end
    return S.notUsable
end

-- One row per piece of a set, saying what the client answers about its source,
-- alongside the reason the set as a whole was called out of reach. A refusal
-- the set-level notice can only call "other" is one piece answering no, and
-- this is what says which piece and, where the client offers one, in what
-- words. The rows are the client's answers about the character being played
-- whoever the reason speaks for, so ownClass decides only whether the reason
-- was allowed to weigh them. Dev dump only: the page never asks this of a set
-- it is not showing.
function ExtraSets.PieceDiagnosis(entry, classID, resolver, ownClass)
    local rows = {}
    for index, piece in ipairs(entry.pieces) do
        local detail = resolver.sourceDetail(piece.sourceID)
        rows[index] = {
            slot = piece.slot,
            state = piece.state,
            sourceID = piece.sourceID,
            itemID = piece.itemID or (detail and detail.itemID),
            itemLoaded = detail ~= nil and detail.itemLoaded,
            wardrobe = detail ~= nil and detail.wardrobe,
            valid = detail and detail.valid,
            useError = detail and detail.useError,
        }
    end
    return rows, ExtraSets.UnwearableReason(entry, classID, ownClass and resolver.sourceValidity or nil)
end

function ExtraSets.IsComplete(entry)
    return not entry.loading and entry.total > 0 and entry.collected == entry.total
end

-- Collected/Not Collected and expansion narrowing, mirroring the Sets tab
-- filter menu. Only sets the client itself knows carry an expansion, so the
-- rest stay visible while any expansion is still checked rather than vanishing
-- behind a box that does not describe them.
function ExtraSets.ApplyFilters(entries, filterState)
    local anyExpansion = false
    for _, shown in pairs(filterState.expansions) do
        if shown then
            anyExpansion = true
            break
        end
    end

    local result = {}
    for _, entry in ipairs(entries) do
        local shown
        if ExtraSets.IsComplete(entry) then
            shown = filterState.collected
        else
            shown = filterState.uncollected
        end
        if shown then
            if entry.expansionID ~= nil and filterState.expansions[entry.expansionID] ~= nil then
                shown = filterState.expansions[entry.expansionID]
            else
                shown = anyExpansion
            end
        end
        if shown then result[#result + 1] = entry end
    end
    return result
end

function ExtraSets.FilterEntries(entries, query)
    local normalized = (query or ""):match("^%s*(.-)%s*$"):gsub("%s+", " "):lower()
    if normalized == "" then return entries end

    local filtered = {}
    for _, entry in ipairs(entries) do
        -- A collapsed row answers for the names it absorbed as well as its own,
        -- or folding "(Heroic Lookalike)" away would make it unsearchable.
        local words = { entry.name, entry.label }
        for _, name in ipairs(entry.alternateNames or {}) do words[#words + 1] = name end
        if table.concat(words, " "):lower():find(normalized, 1, true) then
            filtered[#filtered + 1] = entry
        end
    end
    return filtered
end

-- "default" keeps catalogue order: armour type, then set ID, which puts a set's
-- recolours next to each other. "name" is alphabetical. "completion" puts the
-- fewest missing pieces first; sets with nothing resolvable sort last because
-- there is nothing left to finish there. "pieces" puts the smallest sets first,
-- sized by the same total the row displays, so the order can be read off the
-- list. Descending inverts any of them.
function ExtraSets.SortEntries(entries, mode, direction)
    local descending = direction == "descending"
    if mode ~= "completion" and mode ~= "name" and mode ~= "pieces" then
        if not descending then return entries end
        local reversed = {}
        for index = #entries, 1, -1 do reversed[#reversed + 1] = entries[index] end
        return reversed
    end

    local decorated = {}
    for index, entry in ipairs(entries) do
        decorated[index] = { entry = entry, order = index }
    end
    table.sort(decorated, function(left, right)
        local before
        if mode == "name" then
            if left.entry.name ~= right.entry.name then
                before = left.entry.name < right.entry.name
            else
                before = left.order < right.order
            end
        elseif mode == "pieces" then
            if left.entry.total ~= right.entry.total then
                before = left.entry.total < right.entry.total
            else
                before = left.order < right.order
            end
        else
            local leftMissing = left.entry.total > 0 and left.entry.missing or math.huge
            local rightMissing = right.entry.total > 0 and right.entry.missing or math.huge
            if leftMissing ~= rightMissing then
                before = leftMissing < rightMissing
            elseif left.entry.total ~= right.entry.total then
                before = left.entry.total > right.entry.total
            else
                before = left.order < right.order
            end
        end
        if descending then return not before end
        return before
    end)

    local sorted = {}
    for index, item in ipairs(decorated) do sorted[index] = item.entry end
    return sorted
end

-- Live resolvers, split out so tests can replace them wholesale.

function ExtraSets.LiveResolver()
    return {
        -- Asked of every piece of every set on this page, so it asks the client
        -- once where it can. Appearance info counts any source of the same look
        -- as collected, which is what the Sets tab shows, and answering means
        -- the source exists. The client declines for looks outside the player's
        -- wardrobe context, such as another armour type, and only then is the
        -- source itself worth the second question.
        sourceState = function(sourceID)
            local appearance = C_TransmogCollection.GetAppearanceInfoBySource(sourceID)
            if appearance then
                return {
                    appearanceID = appearance.appearanceID,
                    collected = appearance.appearanceIsCollected and true or false,
                }
            end

            local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
            if not sourceInfo then return nil end
            return {
                appearanceID = sourceInfo.visualID,
                collected = sourceInfo.isCollected and true or false,
            }
        end,
        -- Whether this character could wear a piece at all, which is armour
        -- type more often than class. Asked only of the set on screen: it costs
        -- a table for every piece, and nothing in the list is built from it.
        --
        -- The client works the answer out from the item's own data, and a piece
        -- it has not loaded yet says no rather than declining. Cold is not the
        -- same as no, so an unloaded piece goes unjudged and the set waits for
        -- a real answer instead of being called unwearable on first sight.
        sourceValidity = function(sourceID)
            local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
            if not sourceInfo then return nil end
            if not sourceInfo.itemID or not C_Item.GetItemInfo(sourceInfo.itemID) then return nil end
            return sourceInfo.isValidSourceForPlayer and true or false
        end,
        -- Everything the client will say about one source, gathered for the dev
        -- dump. Each question is one the page already asks somewhere; what the
        -- dump adds is asking them together, so a refusal can be read against
        -- the state it was made in. wardrobe is whether the appearance API
        -- claimed the source at all, which it declines to do for looks outside
        -- the player's own wardrobe context.
        sourceDetail = function(sourceID)
            local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
            if not sourceInfo then return nil end
            local itemID = sourceInfo.itemID
            return {
                itemID = itemID,
                itemLoaded = itemID ~= nil and C_Item.GetItemInfo(itemID) ~= nil,
                wardrobe = C_TransmogCollection.GetAppearanceInfoBySource(sourceID) ~= nil,
                valid = sourceInfo.isValidSourceForPlayer and true or false,
                useError = sourceInfo.useError,
            }
        end,
        playerClassID = function()
            local _, _, classID = UnitClass("player")
            return classID
        end,
    }
end

function ExtraSets.Records()
    return LuckysWardrobe.ExtraSetsCatalog:GetRecords()
end

-- The looks the Sets tab already shows the chosen class, each stamped with the
-- armour that class wears so it can stand in a family beside this page's rows.
-- The stamp is what lets a "(... Recolor)" fold into its tier by containment;
-- identical looks fold without it.
function ExtraSets.NativeLooks(classID)
    local armourType = LuckysWardrobe.Classes:ArmourType(classID)
    local looks = {}
    for _, look in ipairs(LuckysWardrobe.ExtraSetsCatalog:OfficialLooks(classID)) do
        looks[#looks + 1] = { name = look.name, armorType = armourType, appearances = look.appearances }
    end
    return looks
end

-- How many sets the page folded into another row as the same look. Without it
-- the report's own count of what this class is shown looks short by hundreds
-- with nothing to say why.
function ExtraSets.FoldedCount(entries)
    local folded = 0
    for _, entry in ipairs(entries) do
        folded = folded + #(entry.alternateNames or {})
    end
    return folded
end

-- Thousands of sets, each asking the client about every one of its pieces, is
-- far too much work to redo for a keystroke in the search box. Entries are
-- built once for the chosen class and kept until something the client owns
-- actually changes.
local cachedEntries
local cachedNativeFolds = {}
local selectedClassID

function ExtraSets.InvalidateEntries()
    cachedEntries = nil
end

--- Takes the class the Sets tab is showing, so the one dropdown Blizzard draws
--- above both pages means the same thing on either. Answers whether the page
--- now has a different class to list.
function ExtraSets.SyncClassFilter()
    local classID = C_TransmogSets.GetTransmogSetsClassFilter()
    if not classID or classID == selectedClassID then return false end

    selectedClassID = classID
    ExtraSets.InvalidateEntries()
    return true
end

--- The class the page is listing, which every answer about a set is about.
function ExtraSets.SelectedClassID()
    return selectedClassID
end

function ExtraSets.Entries()
    if not cachedEntries then
        LuckysWardrobe.Perf:Begin("entries built")
        cachedEntries, cachedNativeFolds = ExtraSets.CollapseDuplicates(
            ExtraSets.BuildEntries(
                ExtraSets.RecordsForClass(ExtraSets.Records(), selectedClassID),
                ExtraSets.LiveResolver()
            ),
            ExtraSets.NativeLooks(selectedClassID)
        )
        LuckysWardrobe.Perf:End("entries built")
    end
    return cachedEntries
end

-- The sets the last build folded away because the Sets tab already shows their
-- looks to the class the page is listing. What the report counts and the find
-- command names when a set is not where the bundled list says it should be.
function ExtraSets.NativeFolds()
    return cachedNativeFolds
end

-- Page UI. Mirrors the native Sets layout: list on the left, dressing-room
-- model on the right, with search and a session-only sort choice.

function ExtraSets:CreatePage(wardrobe)
    local S = LuckysWardrobe.Strings.extraSets
    local page = CreateFrame("Frame", "LuckysWardrobeExtraSetsFrame", wardrobe)
    page:SetPoint("TOPLEFT", 4, -60)
    page:SetPoint("BOTTOMRIGHT", -6, 5)

    local leftInset = CreateFrame("Frame", nil, page, "InsetFrameTemplate")
    leftInset:SetWidth(260)
    leftInset:SetPoint("TOPLEFT")
    leftInset:SetPoint("BOTTOMLEFT")

    local rightInset = CreateFrame("Frame", nil, page, "CollectionsBackgroundTemplate")
    rightInset:SetPoint("TOPLEFT", leftInset, "TOPRIGHT", 22, 0)
    rightInset:SetPoint("BOTTOMRIGHT")
    rightInset.BGCornerTopLeft:Hide()
    rightInset.BGCornerTopRight:Hide()

    local searchBox = CreateFrame("EditBox", nil, page, "SearchBoxTemplate")
    searchBox:SetSize(145, 20)
    searchBox:SetPoint("TOPLEFT", 15, -9)

    local filterButton = CreateFrame("DropdownButton", nil, page, "WowStyle1FilterDropdownTemplate")
    filterButton:SetSize(93, 22)
    filterButton:SetPoint("TOPLEFT", 166, -8)

    local progressBar = CreateFrame("StatusBar", nil, page, "CollectionsProgressBarTemplate")
    page.progressBar = progressBar

    local listContainer = CreateFrame("Frame", nil, page)
    listContainer:SetSize(255, 499)
    listContainer:SetPoint("TOPLEFT", 3, -36)
    listContainer:SetFrameStrata("HIGH")

    local scrollBox = CreateFrame("Frame", nil, listContainer, "WowScrollBoxList")
    scrollBox:SetAllPoints()

    local scrollBar = CreateFrame("EventFrame", nil, listContainer, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 8, 31)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 8, -1)

    local emptyText = leftInset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("CENTER")
    emptyText:SetWidth(220)
    emptyText:SetText(S.empty)

    local model = CreateFrame("DressUpModel", nil, page)
    Mixin(model, WardrobeSetsDetailsModelMixin)
    model:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 3, -3)
    model:SetPoint("BOTTOMRIGHT", rightInset, "BOTTOMRIGHT", -4, 3)
    model:SetScript("OnShow", model.OnShow)
    -- Blizzard's own model script, run through the stopwatch: it is the only
    -- thing on this page that runs every frame by design, so it has to be
    -- ruled in or out before anything else is blamed.
    model:SetScript("OnUpdate", function(self, elapsed)
        LuckysWardrobe.Perf:Begin("model updated")
        self.OnUpdate(self, elapsed)
        LuckysWardrobe.Perf:End("model updated")
    end)
    model:SetScript("OnMouseDown", model.OnMouseDown)
    model:SetScript("OnMouseUp", model.OnMouseUp)
    model:SetScript("OnMouseWheel", model.OnMouseWheel)
    model:SetScript("OnModelLoaded", model.OnModelLoaded)
    model:OnLoad()
    model:Hide()

    local detailsFrame = CreateFrame("Frame", nil, page)
    detailsFrame:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 0, -3)
    detailsFrame:SetPoint("BOTTOMRIGHT", rightInset, "BOTTOMRIGHT", -3, 2)
    -- Relative to the model, not a fixed level: the model fills the same area
    -- and takes the mouse, so anything below it stops receiving hover.
    detailsFrame:SetFrameLevel(model:GetFrameLevel() + 10)
    detailsFrame:Hide()

    -- The Sets tab shrinks a long set name to keep it on one line, and only
    -- wraps it, smaller again, when even the smallest size will not fit.
    local nameText = detailsFrame:CreateFontString(nil, "OVERLAY", "Fancy24Font")
    nameText:SetPoint("TOP", 0, -37)
    nameText:SetWidth(380)
    nameText:SetTextColor(1, 0.82, 0)
    Mixin(nameText, AutoScalingFontStringMixin)
    nameText:SetMaxLines(1)
    nameText:SetMinLineHeight(NAME_MIN_LINE_HEIGHT)

    local longNameText = detailsFrame:CreateFontString(nil, "OVERLAY", "Fancy16Font")
    longNameText:SetPoint("TOP", 0, -30)
    longNameText:SetWidth(380)
    longNameText:SetTextColor(1, 0.82, 0)
    longNameText:SetMaxLines(2)
    longNameText:Hide()

    local labelText = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelText:SetPoint("TOP", nameText, "BOTTOM", 0, -2)
    labelText:SetWidth(380)

    local countsText = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countsText:SetPoint("TOP", labelText, "BOTTOM", 0, -2)
    countsText:SetWidth(380)

    local iconRowBackground = detailsFrame:CreateTexture(nil, "BORDER")
    iconRowBackground:SetAtlas("transmog-set-iconrow-background", true)
    iconRowBackground:SetPoint("TOP", 0, -82)

    local modelFade = detailsFrame:CreateTexture(nil, "BACKGROUND")
    modelFade:SetAtlas("transmog-set-model-cutoff-fade")
    modelFade:SetHeight(178)
    modelFade:SetPoint("TOPLEFT", 2, 0)
    modelFade:SetPoint("TOPRIGHT")

    local noticeText = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    noticeText:SetPoint("BOTTOM", 0, 12)
    noticeText:SetWidth(380)

    -- Where the Sets tab puts the same control: the top corner of the details
    -- pane, over the model rather than beside the list.
    local variantDropdown = CreateFrame("DropdownButton", nil, detailsFrame, "WowStyle1DropdownTemplate")
    variantDropdown:SetSize(VARIANT_DROPDOWN_WIDTH, VARIANT_DROPDOWN_HEIGHT)
    variantDropdown:SetPoint("TOPRIGHT", detailsFrame, "TOPRIGHT", VARIANT_DROPDOWN_X, VARIANT_DROPDOWN_Y)
    variantDropdown:Hide()

    local detailsText = rightInset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    detailsText:SetPoint("CENTER")
    detailsText:SetWidth(340)
    detailsText:SetText(S.select)

    local itemFrames = {}
    local selectedEntry

    local function refreshCamera()
        local detailsCameraID = C_TransmogSets.GetCameraIDs()
        if not detailsCameraID then return end

        model:RefreshCamera()
        Model_ApplyUICamera(model, detailsCameraID)
        if model.cameraID ~= detailsCameraID then
            model.cameraID = detailsCameraID
            model.defaultPosX, model.defaultPosY, model.defaultPosZ, model.yaw = GetUICameraInfo(detailsCameraID)
        end
    end

    -- Every source sharing this piece's look, so the tooltip can list where the
    -- appearance comes from the way the native Sets tab does.
    local function pieceSources(piece)
        local sourceInfo = C_TransmogCollection.GetSourceInfo(piece.sourceID)
        if not sourceInfo then return nil end

        local sources = {}
        for _, sourceID in ipairs(C_TransmogCollection.GetAllAppearanceSources(sourceInfo.visualID) or {}) do
            local info = C_TransmogCollection.GetSourceInfo(sourceID)
            if info then sources[#sources + 1] = info end
        end
        if #sources == 0 then sources[1] = sourceInfo end

        CollectionWardrobeUtil.SortSources(sources, sourceInfo.visualID, piece.sourceID)
        return sources
    end

    -- The tooltip offers Tab to cycle through the items sharing a look, and it
    -- is the wardrobe's own key handler that does the cycling: it moves the
    -- source index and asks whichever frame owns the tooltip to draw it again.
    -- A page that draws its tooltips behind the wardrobe's back never gets
    -- asked, which is why the offer went unanswered here.
    local hoveredPiece

    local function drawPieceTooltip()
        local piece = hoveredPiece
        local sources = piece.state ~= "unavailable" and pieceSources(piece) or nil
        if not sources then
            GameTooltip:SetText(S.pieceUnavailable, 1, 0.25, 0.25, 1, true)
            GameTooltip:Show()
            return
        end

        wardrobe.tooltipContentFrame = page
        wardrobe.tooltipSourceIndex, wardrobe.tooltipCycle =
            CollectionWardrobeUtil.SetAppearanceTooltip(GameTooltip, {
                sources = sources,
                primarySourceID = piece.sourceID,
                selectedIndex = wardrobe.tooltipSourceIndex,
                showUseError = true,
                showTrackingInfo = false,
                slotType = _G[SLOT_TOOLTIP_GLOBALS[piece.slot]],
            })
        if piece.state == "missing" then
            GameTooltip:AddLine(S.trackHint, 0.5, 0.8, 1)
        end
        GameTooltip:Show()
    end

    local function pieceTooltip(itemFrame)
        hoveredPiece = itemFrame.piece
        GameTooltip:SetOwner(itemFrame, "ANCHOR_RIGHT")
        drawPieceTooltip()
    end

    -- Handing the tooltip back matters as much as claiming it: the index Tab
    -- walks belongs to the piece that was hovered, and the next piece starts
    -- again from its own item.
    local function hidePieceTooltip()
        hoveredPiece = nil
        wardrobe:HideAppearanceTooltip()
    end

    local function getItemFrame(index)
        if itemFrames[index] then return itemFrames[index] end

        local itemFrame = CreateFrame("Button", nil, detailsFrame)
        itemFrame:SetSize(32, 32)
        itemFrame:RegisterForClicks("LeftButtonUp")
        itemFrame.icon = itemFrame:CreateTexture(nil, "BORDER")
        itemFrame.icon:SetSize(28, 28)
        itemFrame.icon:SetPoint("CENTER")
        itemFrame.border = itemFrame:CreateTexture(nil, "OVERLAY")
        -- The border art is wider than the icon and off-centre within itself, so
        -- Blizzard hangs it by its right edge rather than its middle. Centring it
        -- instead leaves the frame sitting beside the icon it frames.
        itemFrame.border:SetPoint("RIGHT", itemFrame.icon, "CENTER", 20, 1)
        itemFrame:SetScript("OnEnter", pieceTooltip)
        itemFrame:SetScript("OnLeave", hidePieceTooltip)
        itemFrame:SetScript("OnClick", function(self, buttonName)
            if LuckysWardrobe.WowheadLink:HandlesClick(buttonName)
                and LuckysWardrobe.WowheadLink:ShowForSource(self.piece.sourceID) then
                return
            end
            if IsShiftKeyDown() and self.piece.state == "missing" then
                LuckysWardrobe.SetTracking:TrackSources({ self.piece.sourceID }, selectedEntry and selectedEntry.name)
            end
        end)
        itemFrames[index] = itemFrame
        return itemFrame
    end

    -- A name that fits once shrunk stays on its one line; one that still will
    -- not fit wraps onto two smaller ones. Answers the line the rest of the
    -- details hang from, since the two sit at different heights.
    local function showSetName(name)
        nameText:SetText(name)
        local wrap = nameText:IsTruncated()
        nameText:SetShown(not wrap)
        longNameText:SetShown(wrap)
        if wrap then longNameText:SetText(name) end
        return wrap and longNameText or nameText
    end

    -- The page lists one class at a time, so the class on the dropdown is the
    -- one the notice speaks for. The client will only answer about the
    -- character being played, so its per-source verdict is asked for while that
    -- character's own class is the one on show and left alone otherwise: a set
    -- the player cannot use says nothing about the class they are browsing.
    local function showNotice(entry)
        local resolver = ExtraSets.LiveResolver()
        local classID = ExtraSets.SelectedClassID() or resolver.playerClassID()
        local ownClass = classID == resolver.playerClassID()
        local unwearable =
            ExtraSets.UnwearableReason(entry, classID, ownClass and resolver.sourceValidity or nil)
        if entry.unavailable > 0 then
            noticeText:SetFormattedText(S.unavailableNotice, entry.unavailable)
        elseif unwearable then
            noticeText:SetText(ExtraSets.UnwearableNotice(entry, unwearable, classID))
        end
        noticeText:SetShown(entry.unavailable > 0 or unwearable ~= nil)
    end

    -- Asking for a set's items is what starts them loading, and the answers
    -- land frames later. Sets this character can wear are the ones that arrive
    -- cold, since building the list only asks the client about pieces it will
    -- not judge, so without this pass the notice would be wrong exactly where
    -- it matters and right only after leaving the set and coming back.
    local function loadPieceItems(entry, pass)
        local waiting = false
        for _, piece in ipairs(entry.pieces) do
            if piece.itemID and not C_Item.GetItemInfo(piece.itemID) then
                C_Item.RequestLoadItemDataByID(piece.itemID)
                waiting = true
            end
        end
        if not waiting or pass >= ITEM_LOAD_PASSES then return end

        C_Timer.After(ITEM_LOAD_DELAY_SECONDS, function()
            -- The set on screen may have moved on while the client answered.
            if not selectedEntry or selectedEntry.key ~= entry.key then return end
            showNotice(entry)
            loadPieceItems(entry, pass + 1)
        end)
    end

    -- Dressing the model is the most expensive thing this page does, and the
    -- pieces of a set never change while a session runs. Only a different set,
    -- or a model that has been rebuilt underneath us, is worth redressing for.
    local dressedKey

    -- A row standing for several colourways has no look of its own, so the pane
    -- shows the one the dropdown is set to and names and counts that set rather
    -- than a summary of several.
    local displayEntry

    -- The colourways of the set on screen, each with what it is worth
    -- collecting, the way the Sets tab offers its own variants.
    local function fillVariantDropdown(row)
        variantDropdown:SetShown(row.isGroup or false)
        if not row.isGroup then return end

        local chosen = ExtraSets.VariantOf(row, selectedVariants[row.key])
        variantDropdown:SetText(S.variantOption:format(
            ExtraSets.VariantLabel(chosen.name), chosen.collected, chosen.total))
        variantDropdown:SetupMenu(function(_, menu)
            for _, variant in ipairs(row.variants) do
                menu:CreateRadio(
                    S.variantOption:format(
                        ExtraSets.VariantLabel(variant.name), variant.collected, variant.total),
                    function() return ExtraSets.VariantOf(row, selectedVariants[row.key]) == variant end,
                    function()
                        selectedVariants[row.key] = variant.setID
                        displayEntry(row)
                    end
                )
            end
        end)
    end

    displayEntry = function(row)
        LuckysWardrobe.Perf:Begin("set displayed")
        selectedEntry = row
        local entry = row and ExtraSets.VariantOf(row, selectedVariants[row.key])
        local shown = entry ~= nil
        model:SetShown(shown)
        detailsFrame:SetShown(shown)
        detailsText:SetShown(not shown)
        if not shown then
            dressedKey = nil
            variantDropdown:Hide()
            LuckysWardrobe.Perf:End("set displayed")
            return
        end
        fillVariantDropdown(row)

        local redress = dressedKey ~= entry.key
        dressedKey = entry.key
        if redress then LuckysWardrobe.Perf:Count("model dressed") end

        labelText:ClearAllPoints()
        labelText:SetPoint("TOP", showSetName(entry.name), "BOTTOM", 0, -2)
        labelText:SetText(entry.label)
        countsText:SetFormattedText(S.counts, entry.collected, entry.total)
        showNotice(entry)
        loadPieceItems(entry, 1)
        if redress then model:Undress() end

        for _, itemFrame in ipairs(itemFrames) do itemFrame:Hide() end
        local spacing = 37
        local xOffset = -math.floor((#entry.pieces - 1) * spacing / 2)
        for index, piece in ipairs(entry.pieces) do
            local itemFrame = getItemFrame(index)
            local collected = piece.state == "collected"
            itemFrame.piece = piece
            itemFrame.icon:SetTexture(
                piece.state ~= "unavailable" and C_TransmogCollection.GetSourceIcon(piece.sourceID)
                or QUESTION_MARK_ICON
            )
            itemFrame.icon:SetDesaturated(not collected)
            itemFrame.icon:SetAlpha(collected and 1 or 0.3)
            itemFrame.border:SetAtlas(collected and "loottab-set-itemborder-green" or "loottab-set-itemborder-white", true)
            itemFrame.border:SetDesaturated(not collected)
            -- The Sets tab fades the frame with the icon it holds, or an
            -- uncollected piece reads as a bright frame around nothing.
            itemFrame.border:SetAlpha(collected and 1 or 0.3)
            itemFrame:ClearAllPoints()
            itemFrame:SetPoint("TOP", detailsFrame, "TOP", xOffset + (index - 1) * spacing, -98)
            itemFrame:Show()

            if redress and piece.state ~= "unavailable" and C_TransmogCollection.GetSourceInfo(piece.sourceID) then
                model:TryOn(piece.sourceID)
            end
        end

        if redress then refreshCamera() end
        LuckysWardrobe.Perf:End("set displayed")
    end

    local function refreshVisibleSelection()
        scrollBox:ForEachFrame(function(button)
            local entry = button:GetElementData()
            button.SelectedTexture:SetShown(selectedEntry and entry.key == selectedEntry.key)
        end)
    end

    local function selectEntry(entry)
        displayEntry(entry)
        refreshVisibleSelection()
    end

    local view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("WardrobeSetsScrollFrameButtonTemplate", function(button, entry)
        local complete = ExtraSets.IsComplete(entry)
        button.Name:SetText(entry.name)
        -- Counts beat a loading notice as soon as anything resolves, so a set
        -- with one slow piece still says something useful.
        if entry.total > 0 then
            button.Label:SetText(entry.label ~= "" and entry.label or S.counts:format(entry.collected, entry.total))
        elseif entry.loading then
            button.Label:SetText(S.loading)
        else
            button.Label:SetText(S.pieceUnavailableShort)
        end
        if complete then
            button.Name:SetTextColor(1, 0.82, 0)
        elseif entry.collected == 0 then
            button.Name:SetTextColor(0.5, 0.5, 0.5)
        else
            button.Name:SetTextColor(0.251, 0.753, 0.251)
        end

        local firstPiece = entry.pieces[1]
        button.IconFrame.Icon:SetTexture(
            firstPiece and firstPiece.state ~= "unavailable"
                and C_TransmogCollection.GetSourceIcon(firstPiece.sourceID)
            or QUESTION_MARK_ICON
        )
        button.IconFrame.Icon:SetDesaturated(entry.collected == 0)
        button.IconFrame.Cover:SetShown(not complete)
        button.IconFrame.Favorite:Hide()
        button.New:Hide()
        button.SelectedTexture:SetShown(selectedEntry and entry.key == selectedEntry.key)

        local showProgress = not entry.loading and entry.collected > 0 and not complete
        button.ProgressBar:SetShown(showProgress)
        if showProgress then button.ProgressBar:SetWidth(204 * entry.collected / entry.total) end

        button:SetScript("OnClick", function(_, buttonName)
            if buttonName ~= "LeftButton" then return end
            if IsShiftKeyDown() then
                ExtraSets:TrackMissing(entry)
                return
            end
            selectEntry(entry)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end)
        button.IconFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(entry.name)
            if entry.label ~= "" then GameTooltip:AddLine(entry.label, 1, 1, 1) end
            GameTooltip:AddLine(S.counts:format(entry.collected, entry.total), 1, 1, 1)
            -- A row that folded other names in says so, or the set the player
            -- was looking for reads as missing from the list.
            for _, name in ipairs(entry.alternateNames or {}) do
                GameTooltip:AddLine(S.alsoListed:format(name), 0.6, 0.6, 0.6)
            end
            GameTooltip:Show()
        end)
        button.IconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end)
    view:SetPadding(0, 0, 44, 0, 0)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

    local function refresh()
        LuckysWardrobe.Perf:Begin("page refresh")
        local allEntries = ExtraSets.Entries()
        local narrowed = ExtraSets.ApplyFilters(allEntries, filters)
        local matching = ExtraSets.SortEntries(
            ExtraSets.FilterEntries(narrowed, searchBox:GetText()),
            filters.sortMode,
            filters.sortDirection
        )
        local entries = ExtraSets.BuildRows(matching)

        if selectedEntry then
            local selectedKey = selectedEntry.key
            selectedEntry = nil
            for _, entry in ipairs(entries) do
                if entry.key == selectedKey then
                    selectedEntry = entry
                    break
                end
            end
        end
        selectedEntry = selectedEntry or entries[1]

        LuckysWardrobe.Perf:Begin("list filled")
        scrollBox:SetDataProvider(CreateDataProvider(entries), ScrollBoxConstants.RetainScrollPosition)
        LuckysWardrobe.Perf:End("list filled")

        if not LuckysWardrobe.ExtraSetsCatalog:IsReady() then
            emptyText:SetText(S.building)
        elseif #allEntries == 0 then
            emptyText:SetText(S.empty)
        else
            emptyText:SetText(S.noResults)
        end
        emptyText:SetShown(#entries == 0)

        -- Like the Sets tab, the progress bar counts what the filters leave
        -- on screen, not the whole catalogue.
        progressBar:SetMinMaxValues(0, math.max(#narrowed, 1))
        local completed = 0
        for _, entry in ipairs(narrowed) do
            if ExtraSets.IsComplete(entry) then completed = completed + 1 end
        end
        progressBar:SetValue(completed)
        progressBar.text:SetFormattedText(S.progress, completed, #narrowed)
        displayEntry(selectedEntry)
        LuckysWardrobe.Perf:End("page refresh")
    end

    filterButton:SetIsDefaultCallback(function()
        return not isNarrowed()
    end)

    filterButton:SetDefaultCallback(function()
        filters.collected = true
        filters.uncollected = true
        setAllExpansions(true)
        refresh()
    end)

    filterButton:SetupMenu(function(_, root)
        root:CreateCheckbox(COLLECTED, function() return filters.collected end, function()
            filters.collected = not filters.collected
            refresh()
        end)
        root:CreateCheckbox(NOT_COLLECTED, function() return filters.uncollected end, function()
            filters.uncollected = not filters.uncollected
            refresh()
        end)
        root:CreateDivider()

        local sort = root:CreateButton("Sort By")
        for _, option in ipairs({
            { key = "default", label = DEFAULT },
            { key = "name", label = "Name" },
            { key = "completion", label = "Completion" },
            { key = "pieces", label = "Pieces" },
        }) do
            local mode = option
            sort:CreateRadio(mode.label, function() return filters.sortMode == mode.key end, function()
                filters.sortMode = mode.key
                refresh()
            end)
        end

        local direction = root:CreateButton("Sort Direction")
        for _, option in ipairs({ { key = "ascending", label = "Ascending" }, { key = "descending", label = "Descending" } }) do
            local sortDirection = option
            direction:CreateRadio(sortDirection.label, function() return filters.sortDirection == sortDirection.key end, function()
                filters.sortDirection = sortDirection.key
                refresh()
            end)
        end

        local expansions = root:CreateButton("Expansion")
        expansions:CreateButton(CHECK_ALL, function()
            setAllExpansions(true)
            refresh()
            return MenuResponse.Refresh
        end)
        expansions:CreateButton(UNCHECK_ALL, function()
            setAllExpansions(false)
            refresh()
            return MenuResponse.Refresh
        end)
        expansions:CreateDivider()
        for index, name in ipairs(expansionNames) do
            local expansionID = index - 1
            expansions:CreateCheckbox(name, function() return filters.expansions[expansionID] end, function()
                filters.expansions[expansionID] = not filters.expansions[expansionID]
                refresh()
            end)
        end
    end)

    -- Collecting an appearance changes what these sets have collected, so the
    -- cached entries go and the page builds them again. Searching and filtering
    -- reuse what is already there.
    local function rebuildNow()
        ExtraSets.InvalidateEntries()
        refresh()
    end

    -- Learning one appearance fires the collection event several times over,
    -- and reading every set again costs far more than a frame, so a burst
    -- collapses into a single pass a moment later. The delay is not felt:
    -- nothing on screen changes until the pass runs either way.
    local rebuildQueued = false
    local function queueRebuild()
        if rebuildQueued then return end

        rebuildQueued = true
        C_Timer.After(REBUILD_DELAY_SECONDS, function()
            rebuildQueued = false
            -- A page that has since closed rebuilds when it opens again.
            if page:IsShown() then rebuildNow() end
        end)
    end

    searchBox:HookScript("OnTextChanged", refresh)
    page:SetScript("OnShow", function(self)
        -- TRANSMOG_COLLECTION_UPDATED is the one that means the collection
        -- changed. TRANSMOG_COLLECTION_ITEM_UPDATE means the client finished
        -- loading an item's data, which asking about a source is what causes:
        -- answering it here made the page feed itself, hundreds of times over.
        self:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
        -- Watching frames only matters while the page is the thing on screen,
        -- and this is the only work it does every frame: a counter and a
        -- comparison, so that measuring a slow page cannot be what slows it.
        self:SetScript("OnUpdate", function(_, elapsed) LuckysWardrobe.Perf:Frame(elapsed) end)
        ExtraSets.SyncClassFilter()
        rebuildNow()
    end)
    page:SetScript("OnHide", function(self)
        self:UnregisterEvent("TRANSMOG_COLLECTION_UPDATED")
        self:SetScript("OnUpdate", nil)
        -- A page that leaves the screen mid-hover would otherwise keep the
        -- tooltip, and Tab would still be cycling it from another tab.
        hidePieceTooltip()
    end)
    page:SetScript("OnEvent", function(_, event)
        LuckysWardrobe.Perf:Count("event " .. event)
        queueRebuild()
    end)
    page.Refresh = rebuildNow
    page.RefreshCameras = refreshCamera
    page.SelectedEntry = function() return selectedEntry end
    page.OnSearchUpdate = function() end
    -- What the wardrobe calls on the frame that owns the tooltip once Tab has
    -- moved the index along.
    page.RefreshAppearanceTooltip = function()
        if hoveredPiece then drawPieceTooltip() end
    end
    -- Blizzard retries this every frame until it answers true, so a version of
    -- it that never does, or that makes the client change the model again,
    -- would cost a full redress on every frame. The counter says which.
    page.OnUnitModelChangedEvent = function()
        LuckysWardrobe.Perf:Count("model change handled")
        if not IsUnitModelReadyForUI("player") then
            LuckysWardrobe.Perf:Count("model change deferred")
            return false
        end

        model:RefreshUnit()
        model.cameraID = nil
        model:UpdatePanAndZoomModelType()
        -- A fresh model wears nothing, whatever it was showing before.
        dressedKey = nil
        displayEntry(selectedEntry)
        return true
    end
    page:Hide()
    LuckysWardrobe.DevLog("Extra Sets page built; model level=" .. model:GetFrameLevel()
        .. " details level=" .. detailsFrame:GetFrameLevel())
    return page
end

-- The client answers yes, no, or nothing at all, and the third is worth telling
-- apart from the second: a piece it has not judged is not a piece it refused.
local function answer(value)
    local S = LuckysWardrobe.Strings.extraSets.report
    if value == nil then return S.pieceUnanswered end
    return value and S.pieceYes or S.pieceNo
end

function ExtraSets:PrintPieceReport()
    local S = LuckysWardrobe.Strings.extraSets.report
    local function say(line) print(LuckysWardrobe.Strings.addon.prefix .. " " .. line) end

    local entry = extraPage and extraPage.SelectedEntry()
    if not entry then
        say(S.piecesNoSelection)
        return
    end

    -- The verdict is read for the class on the dropdown, as the panel reads it,
    -- while the per-piece rows below stay the client's raw answers about the
    -- character being played. The two disagreeing is worth seeing, not hiding.
    local resolver = ExtraSets.LiveResolver()
    local classID = ExtraSets.SelectedClassID() or resolver.playerClassID()
    local ownClass = classID == resolver.playerClassID()
    local rows, reason = ExtraSets.PieceDiagnosis(entry, classID, resolver, ownClass)
    say(S.piecesHeader:format(entry.setID, entry.name, reason or S.piecesWearable))
    for _, row in ipairs(rows) do
        say(S.pieceLine:format(
            row.slot,
            row.state,
            row.sourceID,
            row.itemID or S.pieceNoItem,
            answer(row.itemLoaded),
            answer(row.wardrobe),
            answer(row.valid)
        ))
        if row.useError then say(S.pieceUseErrorLine:format(row.useError)) end
    end
end

-- The client's own answer to why a set did or did not fold: the appearance IDs
-- behind every bundled set matching the query, beside the appearance IDs the
-- Sets tab counts for its own same-named sets. Dev dump for when a fold, or
-- the lack of one, surprises someone: two lines that share most of their IDs
-- name a fold, two that share none name a genuine recolour.
function ExtraSets:PrintLooks(query)
    local S = LuckysWardrobe.Strings.extraSets.report
    local function say(line) print(LuckysWardrobe.Strings.addon.prefix .. " " .. line) end
    local catalog = LuckysWardrobe.ExtraSetsCatalog
    local report = catalog:GetReport()
    if not report then
        say(S.notStarted)
        return
    end
    if not catalog:IsReady() then
        say(S.building)
        return
    end

    local normalized = (query or ""):lower()
    local resolver = ExtraSets.LiveResolver()
    local lines = {}
    for _, record in ipairs(ExtraSets.Records()) do
        if record.name:lower():find(normalized, 1, true) then
            local entry = ExtraSets.BuildEntry(record, resolver)
            lines[#lines + 1] = S.lookLine:format(
                record.setID, record.name, entry.appearanceKey or S.lookUnresolved)
        end
    end

    local natives = {}
    for setID, name in pairs(report.official or {}) do
        if name ~= "" and name:lower():find(normalized, 1, true) then
            natives[#natives + 1] = { setID = setID, name = name }
        end
    end
    table.sort(natives, function(left, right) return left.setID < right.setID end)
    for _, native in ipairs(natives) do
        local appearances = {}
        for _, appearance in ipairs(C_TransmogSets.GetSetPrimaryAppearances(native.setID) or {}) do
            if appearance.appearanceID then appearances[appearance.appearanceID] = true end
        end
        lines[#lines + 1] = S.lookNativeLine:format(
            native.setID, native.name, ExtraSets.AppearanceKey(appearances) or S.lookUnresolved)
    end

    if #lines == 0 then
        say(S.findNone:format(query))
        return
    end
    say(S.looksHeader:format(query))
    for _, line in ipairs(lines) do say(line) end
end

-- Shift-clicking a set tracks everything left in it, across every colourway it
-- stands for: the row says how much of the whole set is missing, so tracking it
-- is expected to go after all of it.
function ExtraSets:TrackMissing(entry)
    local missing = {}
    for _, variant in ipairs(entry.variants or { entry }) do
        for _, piece in ipairs(variant.pieces) do
            if piece.state == "missing" then missing[#missing + 1] = piece.sourceID end
        end
    end
    LuckysWardrobe.SetTracking:TrackSources(missing, entry.name)
end

-- Blizzard hangs the class dropdown above the Sets page rather than inside it,
-- and SetTab re-anchors it to whichever native page it just chose. This page
-- occupies the same corner, so the same offsets leave the dropdown exactly
-- where the Sets tab has it.
local function layOutClassDropdown(dropdown)
    dropdown:ClearAllPoints()
    dropdown:SetPoint("BOTTOMRIGHT", extraPage, "TOPRIGHT", CLASS_DROPDOWN_X, CLASS_DROPDOWN_Y)
end

-- Which control the bar shares its row with changes with the tab: the set pages
-- give the top right corner to the class dropdown and drop their search box to
-- the row below, while the Items tab keeps its search box up there and parks
-- the class dropdown beside the slot column on the far left.
local function cornerControl()
    if attachedWardrobe.selectedCollectionTab == NATIVE_ITEMS_TAB_ID then
        return attachedWardrobe.SearchBox
    end

    return attachedWardrobe.ClassDropdown
end

-- Centring the bar in the gap means measuring both of its edges, which no
-- single anchor can do, so the centre is worked out from where the two frames
-- landed. Neither has a position until the wardrobe has been shown; until then
-- the bar sits just past the last tab, and every tab change measures again.
local function progressBarCentreOffset()
    local stripEdge = extraTab:GetRight()
    local cornerEdge = cornerControl():GetLeft()
    if not (stripEdge and cornerEdge) then
        return PROGRESS_BAR_TAB_GAP + PROGRESS_BAR_WIDTH / 2
    end

    return (cornerEdge - stripEdge) / 2
end

-- The border art is a fixed texture, so it has to be narrowed alongside the bar
-- it frames.
local function layOutProgressBar(progressBar)
    progressBar:ClearAllPoints()
    progressBar:SetPoint("TOP", extraTab, "TOPRIGHT", progressBarCentreOffset(), PROGRESS_BAR_TAB_DROP)
    progressBar:SetWidth(PROGRESS_BAR_WIDTH)
    progressBar.border:SetWidth(PROGRESS_BAR_WIDTH + PROGRESS_BAR_BORDER_MARGIN)
end

local function layOutProgressBars()
    layOutProgressBar(attachedWardrobe.progressBar)
    layOutProgressBar(extraPage.progressBar)
end

local function updateSelectedTab(wardrobe, selectedTabID)
    local selected = selectedTabID == extraTabID
    extraPage:SetShown(selected)
    layOutProgressBars()

    if selected then
        wardrobe.ItemsCollectionFrame:Hide()
        wardrobe.SetsCollectionFrame:Hide()
        wardrobe.SearchBox:Hide()
        wardrobe.FilterButton:Hide()
        wardrobe.progressBar:Hide()
        wardrobe.activeFrame = extraPage
        layOutClassDropdown(wardrobe.ClassDropdown)
        wardrobe.ClassDropdown:Show()
        -- Blizzard refreshes the dropdown from the active page's filter while
        -- the active page is still the one being left, so it reads the name on
        -- the button again now that this page is the active one.
        wardrobe.ClassDropdown:Refresh()
    elseif selectedTabID == NATIVE_ITEMS_TAB_ID or selectedTabID == NATIVE_SETS_TAB_ID then
        wardrobe.SearchBox:Show()
        wardrobe.FilterButton:Show()
        wardrobe.ClassDropdown:Show()
    end
end

function ExtraSets:Attach(wardrobe)
    if attachedWardrobe or not wardrobe or not wardrobe.numTabs then return end

    attachedWardrobe = wardrobe
    extraTabID = wardrobe.numTabs + 1
    extraPage = self:CreatePage(wardrobe)
    extraPage.searchType = wardrobe.SetsCollectionFrame.searchType
    table.insert(wardrobe.ContentFrames, extraPage)

    extraTab = CreateFrame(
        "Button",
        wardrobe:GetName() .. "Tab" .. extraTabID,
        wardrobe,
        "PanelTopTabButtonTemplate"
    )
    extraTab:SetID(extraTabID)
    extraTab:SetText(LuckysWardrobe.Strings.extraSets.tab)
    extraTab.minWidth = 75
    PanelTemplates_TabResize(extraTab, 0)
    extraTab:SetScript("OnClick", function()
        wardrobe:ClickTab(extraTab)
    end)

    hooksecurefunc(wardrobe, "SetTab", updateSelectedTab)
    hooksecurefunc(wardrobe, "ClickTab", function(self)
        PanelTemplates_ResizeTabsToFit(self, TAB_FIT_WIDTH)
        layOutProgressBars()
    end)

    -- One class for both pages: the Sets tab's dropdown is the only class
    -- control there is, so a choice made in it is a choice made here.
    hooksecurefunc(wardrobe.ClassDropdown, "SetClassFilter", function()
        if ExtraSets.SyncClassFilter() and extraPage:IsShown() then extraPage.Refresh() end
    end)

    -- The catalogue may still be building when the page first shows; repaint the
    -- moment it lands.
    LuckysWardrobe.ExtraSetsCatalog:OnReady(function()
        ExtraSets.InvalidateEntries()
        if extraPage:IsShown() then extraPage.Refresh() end
    end)

    PanelTemplates_SetNumTabs(wardrobe, extraTabID)
    PanelTemplates_ResizeTabsToFit(wardrobe, TAB_FIT_WIDTH)
    updateSelectedTab(wardrobe, wardrobe.selectedCollectionTab)
end

function ExtraSets:Init()
    filters.collected = true
    filters.uncollected = true
    filters.sortMode = "default"
    filters.sortDirection = "ascending"
    setAllExpansions(true)
    selectedVariants = {}
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", function()
        LuckysWardrobe.ExtraSetsCatalog:StartBuild()
        ExtraSets:Attach(WardrobeCollectionFrame)
    end)
end
