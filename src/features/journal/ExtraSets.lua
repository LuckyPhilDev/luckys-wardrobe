-- luacheck: globals AutoScalingFontStringMixin CHECK_ALL COLLECTED CollectionWardrobeUtil CreateDataProvider CreateScrollBoxListLinearView DEFAULT DressUpVisual EventUtil GetUICameraInfo InCombatLockdown IsModifiedClick IsShiftKeyDown IsUnitModelReadyForUI MenuResponse Mixin Model_ApplyUICamera NOT_COLLECTED PanelTemplates_DeselectTab PanelTemplates_SelectTab PanelTemplates_TabResize PlaySound QUESTION_MARK_ICON ResetCursor SOUNDKIT ScrollBoxConstants ScrollUtil ShowInspectCursor UNCHECK_ALL UnitClass WARDROBE_CYCLE_KEY WardrobeCollectionFrame WardrobeSetsDetailsModelMixin hooksecurefunc

-- Lucky's Wardrobe: Extra Sets, a third Appearances subtab listing the armour
-- sets Blizzard defines, most of which its own Sets tab never shows. Records
-- come from the session catalogue ExtraSetsCatalog.lua builds out of the
-- bundled snapshot; everything derived (names, icons, collected state) is read
-- live from Blizzard APIs and never persisted.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.ExtraSets = {}

local ExtraSets = LuckysWardrobe.ExtraSets
local Utils = LuckysWardrobe.Utils
-- What a row says about itself, worded once for both set lists.
local SetRow = LuckysWardrobe.Strings.setRow

local TAB_FIT_WIDTH = 275

-- The smallest the Sets tab lets a set name shrink to before it gives up and
-- wraps it instead.
local NAME_MIN_LINE_HEIGHT = 16

-- The row of piece icons, as the Sets tab draws it: one strip under the set's
-- counts. The sets an ensemble teaches run to dozens of pieces where a tier
-- runs to nine, so a set too wide for the pane wraps onto further strips, and
-- one with more pieces than the pane has room for shows what fits and says how
-- many it left off rather than burying the model it is describing.
local PIECES_PER_ROW = 10
local PIECE_SPACING = 37
local PIECE_ROW_HEIGHT = 37
local PIECE_ROW_TOP = -98
local PIECE_ROW_BACKGROUND_TOP = -82
local MAX_PIECE_ROWS = 4

-- The offsets Blizzard gives the class dropdown above the Sets page.
local CLASS_DROPDOWN_X = -9
local CLASS_DROPDOWN_Y = 4

-- Blizzard places the collected-sets bar for a two-tab strip, so the tabs this
-- addon adds run underneath it. It moves into the gap past the end of the strip,
-- where it holds one place and one width whichever tab is on screen rather than
-- shifting about as the room beside it changes.
local PROGRESS_BAR_WIDTH = 150
local PROGRESS_BAR_TAB_GAP = 10
local PROGRESS_BAR_TAB_DROP = -11
local PROGRESS_BAR_BORDER_MARGIN = 9
-- Where Blizzard's own SetTab parks the Items tab's search box, as a distance in
-- from the wardrobe's right edge: 107 for the box itself and 115 of width.
local ITEMS_SEARCH_BOX_INSET = 222
-- Narrower than this and the counts stop fitting inside the bar, so it stops
-- giving up width and lets the strip come to it instead.
local PROGRESS_BAR_MIN_WIDTH = 80

-- Blizzard's localized slot-name globals, for the tooltip's slot line. A slot
-- with no entry here is one the page could not label, so records are held to
-- the slots the addon knows.
local SLOT_TOOLTIP_GLOBALS = Utils.SLOT_TOOLTIP_GLOBALS

-- Where the snapshot says a set comes from, as the source bits Wowhead sets. A
-- set carries as many as apply: a tier that dropped in a raid and was sold by a
-- vendor later is both, which is why these are checkboxes rather than a radio.
--
-- Wowhead sets bits above these that it does not document, and a set can carry
-- nothing but those. Naming them in the menu would mean guessing at what they
-- mean, so they are left out of it, and the rule below keeps the sets that carry
-- them on screen rather than behind a box that does not describe them.
ExtraSets.SOURCES = {
    { bit = 1, label = "crafted" },
    { bit = 2, label = "drop" },
    { bit = 4, label = "pvp" },
    { bit = 8, label = "quest" },
    { bit = 16, label = "vendor" },
}

-- The one source bit the search box asks about by name, since PvP is the only
-- one of these the game itself sorts sets by.
local PVP_SOURCE_BIT = 4

--- Whether a mask carries a bit, the way Classes:MaskHas reads a class out of
--- one. Arithmetic rather than the bit library, so the rules stay testable
--- outside the client.
function ExtraSets.MaskHas(mask, bit)
    if not mask then return false end
    return mask % (bit + bit) >= bit
end

-- The box for sets that cannot be dated, keyed by a name rather than a number so
-- it can never collide with an expansionID. Both Extra Sets lists carry it and
-- neither Sets tab does: Blizzard dates every set it lists itself, while these
-- come from a bundled snapshot the client may know nothing about.
ExtraSets.UNKNOWN_EXPANSION = "unknown"

--- Which box an entry answers to. A set the client cannot name carries no
--- expansion at all, and a set dated to an expansion this version has no box for
--- is just as unplaceable, so both answer to Unknown rather than to a box that
--- does not describe them or to none at all.
function ExtraSets.ExpansionBox(expansionID, expansions)
    if expansionID ~= nil and expansions[expansionID] ~= nil then return expansionID end
    return ExtraSets.UNKNOWN_EXPANSION
end

--- Utils' own pair, plus the Unknown box, for the two lists that offer it.
function ExtraSets.SetAllExpansions(expansions, shown)
    Utils.SetAllExpansions(expansions, shown)
    expansions[ExtraSets.UNKNOWN_EXPANSION] = shown
end

function ExtraSets.AnyExpansionHidden(expansions)
    if not expansions[ExtraSets.UNKNOWN_EXPANSION] then return true end
    return Utils.AnyExpansionHidden(expansions)
end

--- The Expansion submenu the Extra Sets lists and the Items tab carry, built
--- once so they cannot drift apart. onChange redraws whichever page asked.
--- belowDivider, when given, replaces the Unknown box with the caller's own
--- { key = , label = } list, for a list that cannot place a thing the same way.
function ExtraSets.AddExpansionFilter(rootDescription, expansions, onChange, belowDivider)
    local S = LuckysWardrobe.Strings.filterMenu
    local menu = rootDescription:CreateButton(S.expansion)
    menu:CreateButton(CHECK_ALL, function()
        ExtraSets.SetAllExpansions(expansions, true)
        onChange()
        return MenuResponse.Refresh
    end)
    menu:CreateButton(UNCHECK_ALL, function()
        ExtraSets.SetAllExpansions(expansions, false)
        onChange()
        return MenuResponse.Refresh
    end)
    menu:CreateDivider()

    local function addBox(key, label)
        menu:CreateCheckbox(label, function() return expansions[key] end, function()
            expansions[key] = not expansions[key]
            onChange()
        end)
    end

    for index, name in ipairs(Utils.EXPANSION_NAMES) do addBox(index - 1, name) end
    -- Behind a divider, because these hold whatever the other boxes could not
    -- place rather than an expansion of their own.
    belowDivider = belowDivider
        or { { key = ExtraSets.UNKNOWN_EXPANSION, label = S.unknownExpansion } }
    if #belowDivider == 0 then return end

    menu:CreateDivider()
    for _, box in ipairs(belowDivider) do addBox(box.key, box.label) end
end

-- Session-only view state behind the filter button, matching the Sets tab menu.
-- The class is not in here: it narrows the catalogue before entries are built,
-- rather than hiding rows that have already been worked out.
local filters = {
    collected = true,
    uncollected = true,
    expansions = {},
    sources = {},
    sortMode = "default",
    sortDirection = "ascending",
}

local function setAllExpansions(shown)
    ExtraSets.SetAllExpansions(filters.expansions, shown)
end

local function setAllSources(shown)
    for _, source in ipairs(ExtraSets.SOURCES) do filters.sources[source.bit] = shown end
end

-- Which colourway each set is showing, keyed by group. Session-only, like the
-- filters: which tint you were last looking at is not worth keeping past logout.
local selectedVariants = {}

local function anySourceHidden()
    for _, source in ipairs(ExtraSets.SOURCES) do
        if not filters.sources[source.bit] then return true end
    end
    return false
end

local function isNarrowed()
    if not (filters.collected and filters.uncollected) then return true end
    if anySourceHidden() then return true end
    return ExtraSets.AnyExpansionHidden(filters.expansions)
end

setAllExpansions(true)
setAllSources(true)

local attachedWardrobe
local extraPage

-- The colourway picker, sized like the one the Sets tab hangs in the top
-- corner of its own details pane.
local VARIANT_DROPDOWN_WIDTH = 170
local VARIANT_DROPDOWN_HEIGHT = 22

-- The top corner of the details pane, where the Sets tab parks its variant
-- dropdown. Here the preview-slots button holds the corner and the dropdown
-- hangs beside it, on this pane and the Sets tab's both.
local DETAILS_CORNER_X = -10
local DETAILS_CORNER_Y = -8

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
    if record.sourceMask ~= nil and (type(record.sourceMask) ~= "number" or record.sourceMask < 0) then
        return nil, "sourceMask must be a positive number"
    end
    if type(record.armorType) ~= "number" then return nil, "armorType is required" end
    if type(record.classMask) ~= "number" or record.classMask < 0 then return nil, "classMask is required" end
    if type(record.pieces) ~= "table" or #record.pieces == 0 then return nil, "pieces are required" end
    if record.ensembles ~= nil then
        if type(record.ensembles) ~= "table" or #record.ensembles == 0 then
            return nil, "ensembles must list at least one item"
        end
        for _, itemID in ipairs(record.ensembles) do
            if type(itemID) ~= "number" or itemID <= 0 or itemID % 1 ~= 0 then
                return nil, "ensemble item IDs must be positive integers"
            end
        end
    end

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

-- What tells one record from another. The bundled armour lists number their
-- sets the way Wowhead does, while the ensembles carry the client's own
-- numbering, so the same number stands for two unrelated sets across the two
-- listings and the number alone cannot say which record is which.
function ExtraSets.RecordKey(record)
    if record.ensembles then return "ensemble:" .. record.setID end
    return record.setID
end

-- The ensembles that teach a look, gathered without repeats. Merging never
-- writes into either list it was given: the first belongs to a catalogue record
-- that outlives every rebuild of the page.
function ExtraSets.MergeEnsembles(into, from)
    if not from then return into end

    local merged, seen = {}, {}
    for _, list in ipairs({ into or {}, from }) do
        for _, itemID in ipairs(list) do
            if not seen[itemID] then
                seen[itemID] = true
                merged[#merged + 1] = itemID
            end
        end
    end
    return merged
end

-- A mask of zero names every class at once, which is how the game marks the
-- sets that are nobody's in particular.
function ExtraSets.ClassAllowed(classMask, classID)
    if classMask == 0 or not classID then return true end
    return LuckysWardrobe.Classes:MaskHas(classMask, classID)
end

-- What one class has any use for: the sets named for it, plus the sets named
-- for nobody in the armour that class wears. A set belonging to another class,
-- or to nobody in armour this class cannot transmogrify, is not a set this
-- character will ever wear, so it never becomes a row.
function ExtraSets.MatchesClass(record, classID)
    if not classID then return true end
    if record.classMask ~= 0 then return ExtraSets.ClassAllowed(record.classMask, classID) end

    local armourType = LuckysWardrobe.Classes:ArmourType(classID)
    -- A set of nothing but cloaks, tabards, shirts, and cosmetics is nobody's
    -- armour in particular, which zero says, and anybody can wear it.
    return armourType == nil or record.armorType == 0 or record.armorType == armourType
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

-- Plenty of ensembles are one appearance rather than a set: a cloak sold on its
-- own, a set of shoulders in four colours. A row here is a set to collect and,
-- at the transmogrifier, an outfit to put on, and one slot is neither, so those
-- are left off both pages. An item tooltip still names the set a piece belongs
-- to, which is where a single appearance is worth answering for.
--
-- Only the ensembles are held to this. A set from the armour lists reaching one
-- slot is one this client could only partly resolve rather than a set of one
-- piece, and dropping it would hide the little of it there is left to collect.
function ExtraSets.IsSingleSlotEnsemble(record)
    if not record.ensembles then return false end

    local slot
    for _, piece in ipairs(record.pieces) do
        if slot and piece.slot ~= slot then return false end
        slot = piece.slot
    end
    return true
end

-- What is left for this page to show: the sets the class could wear, less the
-- ones the Sets tab is already showing them and the ensembles that are a single
-- slot's worth of appearances rather than a set.
function ExtraSets.RecordsForClass(records, classID)
    local matching = {}
    for _, record in ipairs(records) do
        if ExtraSets.MatchesClass(record, classID)
            and not ExtraSets.ListedNatively(record, classID)
            and not ExtraSets.IsSingleSlotEnsemble(record) then
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

-- The colourways of one set share a name and differ only in the qualifier the
-- snapshot puts after it: a parenthetical, "(Heroic Recolor)", or a colon
-- clause, "Barkbloom Warleathers Set: World Drops". Dropping the qualifier
-- gives the set itself, which is what gathers its colourways together. A name
-- the client supplied carries neither, so it is its own base name.
--
-- The snapshot spells one set's colon names both with and without a trailing
-- "Set": "Barkbloom Warleathers Set: World Drops" sits beside "Barkbloom
-- Warleathers: Emerald Bounties". That word comes off a colon name too, or the
-- two spellings never meet. A name with no colon clause keeps its "Set"; it
-- has no second spelling to meet, and its parenthetical colourways already
-- share it.
function ExtraSets.BaseName(name)
    local stripped = name:gsub("%s*%b()%s*$", "")
    if stripped == "" then return name end

    local base = stripped:match("^(.-)%s*:%s")
    if not base then return stripped end
    base = base:gsub("%s+Set$", "")
    if base == "" then return stripped end
    return base
end

-- What a colourway is called once its set name is the row above it. Repeating
-- the set name on every one of its colourways is the noise the grouping exists
-- to remove, so only the qualifier that tells them apart is left: the
-- parenthetical, or the clause after the colon.
function ExtraSets.VariantLabel(name)
    return name:match("%(([^()]*)%)%s*$") or name:match(":%s+(.+)$") or name
end

-- What a colourway is called in the picker: the one word that tells it from its
-- siblings where the family was found that way, and otherwise the qualifier the
-- set's own name carries.
--
-- The client names two sets of one family the same thing often enough to matter,
-- and two rows reading alike is a picker that cannot be used. Where that
-- happens the ensemble each is bought from stands in, since that is both what
-- tells them apart and what the player would go after. It is only known once
-- the client has loaded the item, so until then the repeated word stands.
function ExtraSets.VariantLabelFor(variant, itemName)
    local label = variant.variantLabel or ExtraSets.VariantLabel(variant.name)
    if not (variant.ambiguousLabel and itemName) then return label end

    local names = ExtraSets.EnsembleNames(variant, itemName)
    return names[1] or label
end

-- A set named like another but for a single word is that set in another colour:
-- "Midnight Sweatsuit" beside "Azure Sweatsuit", "Vagabond's Brick Threads"
-- beside "Vagabond's Camo Threads". The client says nothing about this. Asked
-- directly, through GetBaseSetID and GetVariantSets, it answers nothing for
-- every one of them, so the only place the relationship is written down is the
-- names, and reading it there is an inference rather than a fact the way the
-- rest of this catalogue is.
--
-- Three things keep the inference narrow.
--
-- It is held to the ensembles, because they are the listing where the
-- relationship is written down nowhere else. The armour lists say it themselves,
-- with "(Recolor)" after a shared set name, and the grouping above already reads
-- that. Turned loose on them this rule joins "Mystic's Regalia (Recolor)" to
-- "Pagan Regalia (Recolor)", which are two sets rather than two colours.
--
-- A family agrees on piece count, class mask, and armour, which is what stops
-- the armour types of one PvP set folding together: "Gladiator's Leather Armor"
-- and "Gladiator's Silk Armor" differ by one word too, and are not one garment
-- in two colours.
--
-- And it is held to small sets, because the Trading Post sells these in twos and
-- threes while a tier or a PvP season runs to dozens, and those are sets people
-- work through separately even where they do share a model.
local MAX_COLOUR_FAMILY_PIECES = 4

-- Every word is a candidate for the one that varies, so a set belongs to as
-- many possible families as it has words and joins the largest of them. That is
-- what keeps "Vagabond's * Threads" whole rather than split across whichever
-- other position happens to match a set somewhere else in the list. A tie goes
-- to the earlier word, so the same list always groups the same way.
-- A row standing for several sets that share a name is a candidate like any
-- other, and answers on the name they share. The client gives two of these sets
-- one name often enough that leaving those rows out strands them beside the
-- family they plainly belong to.
local function colourCandidates(row)
    if row.isColourFamily or not row.fromEnsemble then return nil end
    if #row.pieces > MAX_COLOUR_FAMILY_PIECES then return nil end

    local words = {}
    for word in row.name:gmatch("%S+") do words[#words + 1] = word end
    if #words < 2 then return nil end

    local candidates = {}
    for index = 1, #words do
        local varying = table.remove(words, index)
        candidates[index] = {
            key = table.concat(words, " ") .. "@" .. index
                .. "|" .. #row.pieces .. "|" .. row.classMask .. "|" .. tostring(row.armorType),
            name = table.concat(words, " "),
            label = varying,
        }
        table.insert(words, index, varying)
    end
    return candidates
end

-- One family, out of the rows that joined it. A row already standing for
-- several sets that share a name brings them in one by one: the picker offers
-- colourways, and a pair the client happens to call the same thing is two of
-- those rather than one.
--
-- Which leaves two colourways under one word, since that is what the client
-- named them. They are marked so the picker can fall back to naming the
-- ensemble each is bought from, which is what really tells them apart.
local function buildColourFamily(rows, chosen, name)
    local variants, seen, repeated = {}, {}, {}
    for _, row in ipairs(rows) do
        local label = chosen[row].label
        for _, variant in ipairs(row.variants or { row }) do
            variant.variantLabel = label
            variant.ambiguousLabel = nil
            variants[#variants + 1] = variant
            if seen[label] then repeated[label] = true end
            seen[label] = true
        end
    end
    for _, variant in ipairs(variants) do
        if repeated[variant.variantLabel] then variant.ambiguousLabel = true end
    end

    local group = ExtraSets.BuildGroup(variants, name)
    group.isColourFamily = true
    return group
end

-- Rows gathered into colourway families, in the order they were already in: a
-- family becomes one row where its first member stood, and the rest go with it.
local function colourFamilies(rows)
    local counts, candidatesOf = {}, {}
    for _, row in ipairs(rows) do
        candidatesOf[row] = colourCandidates(row)
        for _, candidate in ipairs(candidatesOf[row] or {}) do
            counts[candidate.key] = (counts[candidate.key] or 0) + 1
        end
    end

    local chosen, members = {}, {}
    for _, row in ipairs(rows) do
        local best
        for _, candidate in ipairs(candidatesOf[row] or {}) do
            if counts[candidate.key] > 1 and (not best or counts[candidate.key] > counts[best.key]) then
                best = candidate
            end
        end
        if best then
            chosen[row] = best
            members[best.key] = members[best.key] or {}
            table.insert(members[best.key], row)
        end
    end

    local grouped, built = {}, {}
    for _, row in ipairs(rows) do
        local candidate = chosen[row]
        -- A candidate two sets shared can still end up holding one of them, when
        -- the other found a larger family to join. One member is no family.
        if not candidate or #members[candidate.key] == 1 then
            grouped[#grouped + 1] = row
        elseif not built[candidate.key] then
            built[candidate.key] = true
            grouped[#grouped + 1] = buildColourFamily(members[candidate.key], chosen, candidate.name)
        end
    end
    return grouped
end

-- The armour a row is built on, for the rows that are one garment throughout. A
-- row already standing for several sets answers only when every one of them is
-- the same armour: a shared name gathers two models together now and again, and
-- a row that answered on its first member would take the odd one with it into a
-- family it does not belong to.
local function modelOf(row)
    if not row.variants then return row.model end

    local model = row.variants[1].model
    for _, variant in ipairs(row.variants) do
        if variant.model ~= model then return nil end
    end
    return model
end

-- Rows gathered by the armour they are built on, from the bundled model index:
-- sets wearing one model in different textures are one garment in several
-- colours, whatever each is called. "Nitroclad Kit" and "Smoketrail Racer Suit"
-- share nothing but the armour underneath them, and the client says so in the
-- display records the index is read from.
--
-- This is the one grouping on this page that reads a Blizzard relationship
-- rather than a name, so none of the caution the name rules need applies: it
-- takes sets of any size, from either listing, whose names have nothing in
-- common. It runs last, so a family the names already gathered arrives as the
-- single row it became rather than as its members.
local function modelFamilies(rows)
    local members = {}
    for _, row in ipairs(rows) do
        local model = modelOf(row)
        if model then
            members[model] = members[model] or {}
            table.insert(members[model], row)
        end
    end

    local grouped, built = {}, {}
    for _, row in ipairs(rows) do
        local model = modelOf(row)
        if not model or #members[model] == 1 then
            grouped[#grouped + 1] = row
        elseif not built[model] then
            built[model] = true
            local variants = {}
            for _, member in ipairs(members[model]) do
                for _, variant in ipairs(member.variants or { member }) do
                    variants[#variants + 1] = variant
                end
            end
            -- Named for the first row rather than the first set, because a row
            -- that already stood for several sets has a name covering all of
            -- them, and reaching past it to a single colourway inside would
            -- throw that away for the narrower name.
            local group = ExtraSets.BuildGroup(variants, ExtraSets.BaseName(members[model][1].name))
            -- Named for its first member, which two families of one armour type
            -- can share: these are gathered without reading names at all, so
            -- nothing else keeps their keys apart, and a repeated key would have
            -- the two rows showing each other's colourway.
            group.key = group.key .. "#" .. model
            group.isColourFamily = true
            grouped[#grouped + 1] = group
        end
    end
    return grouped
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
    local absorbedNames, absorbedEnsembles, nativeFolds = {}, {}, {}
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
                -- The surviving row is the only place this look is shown, so
                -- where a folded one could be bought as an ensemble that comes
                -- with it. Losing it would fold away the one thing that says
                -- how to get the look.
                absorbedEnsembles[survivor] =
                    ExtraSets.MergeEnsembles(absorbedEnsembles[survivor], entry.ensembles)
            end
        end
    end

    local rows = {}
    for _, entry in ipairs(kept) do
        if not survivorOf[entry] then
            entry.alternateNames = absorbedNames[entry]
            entry.ensembles = ExtraSets.MergeEnsembles(entry.ensembles, absorbedEnsembles[entry])
            rows[#rows + 1] = entry
        end
    end
    return rows, nativeFolds
end

-- One row standing for a set's several colourways: named for the set, counting
-- every look across them so the row says how much of the whole set is collected.
-- It carries the first colourway's pieces, which is what the details pane shows
-- when the row is picked.
-- name is what the family is called where the caller worked it out for itself,
-- as the colourway families do; otherwise the row takes the set name its
-- colourways share.
function ExtraSets.BuildGroup(variants, name)
    local first = variants[1]
    name = name or ExtraSets.BaseName(first.name)
    local collected, total, unavailable, loading = 0, 0, 0, false
    local appearances, ensembles = {}, nil
    for _, variant in ipairs(variants) do
        loading = loading or variant.loading
        unavailable = unavailable + variant.unavailable
        ensembles = ExtraSets.MergeEnsembles(ensembles, variant.ensembles)
        for id, isCollected in pairs(variant.appearances) do
            if appearances[id] == nil then
                appearances[id] = isCollected
                total = total + 1
                if isCollected then collected = collected + 1 end
            end
        end
    end

    return {
        key = "group:" .. first.armorType .. "|" .. name,
        isGroup = true,
        variants = variants,
        name = name,
        label = LuckysWardrobe.Strings.setRow.colours:format(#variants),
        expansionID = first.expansionID,
        armorType = first.armorType,
        classMask = first.classMask,
        ensembles = ensembles,
        fromEnsemble = first.fromEnsemble,
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
--
-- Sets that share a name gather first, since that qualifier is one the listing
-- itself supplies. Whatever is left over is offered to the colourway rule,
-- which reads the same relationship off names that differ by a single word.
-- The model index goes last and needs no name at all, so it gathers what the
-- names could not: two sets built on one model that were never called anything
-- alike.
function ExtraSets.BuildRows(entries)
    local rows = {}
    for _, family in ipairs(families(entries)) do
        rows[#rows + 1] = #family == 1 and family[1] or ExtraSets.BuildGroup(family)
    end
    return modelFamilies(colourFamilies(rows))
end

-- Which colourway of a set is on show. Defaults to the first, and falls back to
-- it when the one last picked has been filtered out from under the row.
function ExtraSets.VariantOf(row, chosenKey)
    if not row.isGroup then return row end

    for _, variant in ipairs(row.variants) do
        if variant.key == chosenKey then return variant end
    end
    return row.variants[1]
end

-- resolver.sourceState(sourceID) returns nil when the source does not exist on
-- this client, or { appearanceID, collected } where collected == nil means the
-- appearance data has not loaded yet.
--
-- entries and seenSetIDs are for a caller building the list a slice at a time
-- across several frames: handing back the same two each slice gives the same
-- answer as one call over the whole lot, because a set listed twice is dropped
-- whichever slice its second listing lands in. Left out, one call builds both
-- and the whole list comes back at once.
function ExtraSets.BuildEntries(records, resolver, entries, seenSetIDs)
    entries = entries or {}
    seenSetIDs = seenSetIDs or {}

    for _, record in ipairs(records) do
        local key = ExtraSets.RecordKey(record)
        local valid, problem = ExtraSets.ValidateRecord(record)
        if not valid then
            LuckysWardrobe.DevLog("Extra Sets record rejected: " .. tostring(problem))
        elseif seenSetIDs[key] then
            LuckysWardrobe.DevLog("Extra Sets record rejected: duplicate set " .. key)
        else
            seenSetIDs[key] = true
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
        key = ExtraSets.RecordKey(record),
        setID = record.setID,
        name = record.name,
        label = record.label or "",
        expansionID = record.expansionID,
        armorType = record.armorType,
        classMask = record.classMask,
        -- Where the set can simply be bought, for the sets that can be. Kept as
        -- the record's own list until something folds into this row, which is
        -- the only thing that ever gives a row a second one.
        ensembles = record.ensembles,
        -- Which listing the set came from, which is what its number can be read
        -- against. Folding another row in gives this one more ensembles without
        -- changing where the row itself came from.
        fromEnsemble = record.ensembles ~= nil,
        sourceMask = record.sourceMask,
        -- Which armour the set is built on, where the bundled index says another
        -- set is built on the same one. Nil for a set that stands alone.
        model = record.model,
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
-- what the class wears. Worked out for the set on screen rather than for every
-- set in the list, because only the one on screen ever says so.
--
-- The client names some of its own refusals, a faction or race lock among
-- them, and its word beats anything worked out from the record: it knows why
-- it said no. Where it names nothing, its own sentence about the refusal comes
-- back beside the reason so the panel can quote it rather than shrug.
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
    local refused, refusal, refusalMessage
    for _, piece in ipairs(entry.pieces) do
        local isValid, pieceRefusal, pieceMessage = sourceValidity(piece.sourceID)
        if isValid ~= nil then
            judged = judged + 1
            if isValid then
                valid = valid + 1
            elseif not refused then
                refused = true
                refusal, refusalMessage = pieceRefusal, pieceMessage
            end
        end
    end
    if judged == 0 or valid == judged then return nil end
    if refusal then return refusal, refusalMessage end

    local wornArmour = LuckysWardrobe.Classes:ArmourType(classID)
    if wornArmour and entry.armorType and entry.armorType ~= wornArmour then return "armour" end
    return "other", refusalMessage
end

-- The line the details panel shows for a set out of reach, naming the reason
-- where there is one to name. A set whose mask holds no class this client has,
-- or an armour type it has no name for, falls back to the client's own words
-- for the refusal, and to saying only that the set is out of reach when there
-- are none, rather than to a sentence with a hole in it.
--
-- detail carries what only the client can supply: the faction a set locked
-- against this character must belong to, and the sentence the client gave with
-- its refusal.
function ExtraSets.UnwearableNotice(entry, reason, classID, detail)
    local S = LuckysWardrobe.Strings.extraSets
    if reason == "class" then
        local classes = LuckysWardrobe.Classes:FromMask(entry.classMask)
        if #classes > 0 then return S.notUsableClass:format(LuckysWardrobe.Classes:Names(classes)) end
    elseif reason == "armour" then
        local setArmour = S.armourTypes[entry.armorType]
        local wornArmour = S.armourTypes[LuckysWardrobe.Classes:ArmourType(classID)]
        if setArmour and wornArmour then return S.notUsableArmour:format(setArmour, wornArmour) end
    elseif reason == "faction" then
        local faction = detail and detail.faction
        if faction then return S.notUsableFaction:format(faction) end
    elseif reason == "race" then
        return S.notUsableRace
    end

    local message = detail and detail.message
    if message and message ~= "" then return S.notUsableReason:format(message) end
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

-- The ensembles that teach a set, named the way the player reads them on the
-- item itself. An ensemble whose item the client has not loaded yet is left out
-- rather than named by its number, and asking for it is what starts it loading.
function ExtraSets.EnsembleNames(entry, itemName)
    local names = {}
    for _, itemID in ipairs(entry.ensembles or {}) do
        local name = itemName(itemID)
        if name then names[#names + 1] = name end
    end
    return names
end

-- One piece per look in its slot, which is how the Sets tab draws its own
-- strip. An ensemble often teaches several items carrying one appearance, and
-- an icon per item says 78 pieces where the counts say 22 looks: the first
-- source of a look stands for it, and the piece tooltip already names every
-- item that shares it. The fold stays inside a slot so the preview-slot
-- toggles keep a piece for every slot they govern, and a piece the client has
-- not resolved yet has no look to fold on, so it stands alone.
function ExtraSets.DistinctLookPieces(pieces)
    local distinct, seen = {}, {}
    for _, piece in ipairs(pieces) do
        local key = piece.appearanceID and (piece.slot .. "|" .. piece.appearanceID)
        if not key or not seen[key] then
            if key then seen[key] = true end
            distinct[#distinct + 1] = piece
        end
    end
    return distinct
end

-- Where each piece icon sits in the block under the set's counts: filled left
-- to right, each strip centred on the pane, and no more strips than the pane
-- has room for. Answers the places and how many pieces were left off the end.
function ExtraSets.PieceLayout(count)
    local shown = math.min(count, MAX_PIECE_ROWS * PIECES_PER_ROW)
    local places = {}
    for index = 1, shown do
        local row = math.ceil(index / PIECES_PER_ROW)
        local column = index - (row - 1) * PIECES_PER_ROW
        local acrossRow = math.min(shown - (row - 1) * PIECES_PER_ROW, PIECES_PER_ROW)
        places[index] = {
            row = row,
            x = (column - 1) * PIECE_SPACING - math.floor((acrossRow - 1) * PIECE_SPACING / 2),
            y = PIECE_ROW_TOP - (row - 1) * PIECE_ROW_HEIGHT,
        }
    end
    return places, count - shown
end

function ExtraSets.IsComplete(entry)
    return not entry.loading and entry.total > 0 and entry.collected == entry.total
end

-- Whether any source box the entry answers to is checked. A set the snapshot
-- gave no source, and one carrying only the bits Wowhead does not document,
-- answer to no box at all: those stay on screen while any box is checked, the
-- same way a set with no expansion does, rather than vanishing behind boxes that
-- do not describe them. The ensembles are the largest group of these; their
-- listing carries no source field.
local function sourceShown(entry, filterState, anySource)
    local described = false
    for _, source in ipairs(ExtraSets.SOURCES) do
        if ExtraSets.MaskHas(entry.sourceMask, source.bit) then
            if filterState.sources[source.bit] then return true end
            described = true
        end
    end
    return not described and anySource
end

-- Collected/Not Collected, source, and expansion narrowing, mirroring the Sets
-- tab filter menu.
function ExtraSets.ApplyFilters(entries, filterState)
    local anySource = false
    for _, shown in pairs(filterState.sources or {}) do
        if shown then
            anySource = true
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
        if shown and filterState.sources then
            shown = sourceShown(entry, filterState, anySource)
        end
        if shown then
            shown = filterState.expansions[
                ExtraSets.ExpansionBox(entry.expansionID, filterState.expansions)] == true
        end
        if shown then result[#result + 1] = entry end
    end
    return result
end

function ExtraSets.FilterEntries(entries, query)
    local normalized = (query or ""):match("^%s*(.-)%s*$"):gsub("%s+", " "):lower()
    if normalized == "" then return entries end

    local filtered = {}
    -- An expansion or a kind of set typed into the box narrows to it, the way it
    -- does in the search box on either Sets tab. The client answers for none of
    -- these sets, so both come out of the snapshot: whether a set is PvP off its
    -- own source bits, and whether it is tier off the difficulty it is named by,
    -- which is the same test the Sources filter puts Blizzard's sets through.
    -- A set the snapshot could not date is not the expansion asked for.
    local narrowedTo = LuckysWardrobe.SetSearch.Parse(normalized)
    if narrowedTo then
        for _, entry in ipairs(entries) do
            if LuckysWardrobe.SetSearch.Matches(narrowedTo, entry.expansionID,
                ExtraSets.MaskHas(entry.sourceMask, PVP_SOURCE_BIT),
                LuckysWardrobe.SetSources:IsRaidDifficulty(entry.label)) then
                filtered[#filtered + 1] = entry
            end
        end
        return filtered
    end

    for _, entry in ipairs(entries) do
        -- A collapsed row answers for the names it absorbed as well as its own,
        -- or folding "(Heroic Lookalike)" away would make it unsearchable.
        local words = { entry.name, entry.label }
        -- A set that can simply be bought answers to the word too, so searching
        -- for it lists everything there is an ensemble for.
        if entry.ensembles then words[#words + 1] = LuckysWardrobe.Strings.extraSets.ensembleTerm end
        for _, name in ipairs(entry.alternateNames or {}) do words[#words + 1] = name end
        if table.concat(words, " "):lower():find(normalized, 1, true) then
            filtered[#filtered + 1] = entry
        end
    end
    return filtered
end

-- How many colourways each set is one of, taken by building the rows and asking
-- them. There are several ways a set can end up a colourway of another, a shared
-- set name and a name differing by a single word among them, and the row is
-- where they all come out as one number: the one it goes on to show.
--
-- Counted over the list being sorted rather than the whole catalogue, so a
-- filter that leaves a set showing a single tint sorts it as the plain row it
-- becomes. Which rows the entries gather into does not depend on the order they
-- arrive in, so counting them before the sort answers for the list after it.
local function variantCounts(entries)
    local counts = {}
    for _, row in ipairs(ExtraSets.BuildRows(entries)) do
        if row.variants then
            for _, variant in ipairs(row.variants) do counts[variant] = #row.variants end
        else
            counts[row] = 1
        end
    end
    return counts
end

local SORT_MODES = {
    name = true,
    completion = true,
    pieces = true,
    variants = true,
}

-- "default" keeps catalogue order: armour type, then set ID, which puts a set's
-- recolours next to each other. "name" is alphabetical. "completion" puts the
-- fewest missing pieces first; sets with nothing resolvable sort last because
-- there is nothing left to finish there. "pieces" puts the smallest sets first,
-- sized by the same total the row displays, so the order can be read off the
-- list. "variants" puts the sets with the fewest colourways first, by the count
-- the row goes on to show. Descending inverts any of them.
--
-- Colourways of one set share a count, so they stay together whichever way the
-- list is turned, and the row built from them lands where they do.
function ExtraSets.SortEntries(entries, mode, direction)
    local descending = direction == "descending"
    if not SORT_MODES[mode] then
        if not descending then return entries end
        local reversed = {}
        for index = #entries, 1, -1 do reversed[#reversed + 1] = entries[index] end
        return reversed
    end

    local variants = mode == "variants" and variantCounts(entries) or nil
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
        elseif mode == "variants" then
            local leftCount, rightCount = variants[left.entry], variants[right.entry]
            if leftCount ~= rightCount then
                before = leftCount < rightCount
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

-- The client's own word for why it turned a source down, as a locale-free key
-- the notice can answer to. Faction and race are worth a sentence of their own
-- because they say something the player can act on, or stop trying to; every
-- other refusal it names is left to the wording it supplies with it.
local refusalKeys
local function refusalKey(useErrorType)
    if not useErrorType then return nil end

    if not refusalKeys then
        local useErrors = Enum.TransmogUseErrorType
        refusalKeys = {
            [useErrors.Faction] = "faction",
            [useErrors.Race] = "race",
        }
    end
    return refusalKeys[useErrorType]
end

-- The faction a set this character is locked out of must belong to: the one
-- they are not. A character with no side of its own, a pandaren who has not
-- chosen, is told no faction rather than the wrong one.
function ExtraSets.OpposingFactionName()
    local faction = UnitFactionGroup("player")
    if faction == "Alliance" then return FACTION_HORDE end
    if faction == "Horde" then return FACTION_ALLIANCE end
    return nil
end

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
        --
        -- A refusal comes back with the client's own account of it: the kind of
        -- lock where that is one the page can name, and the sentence the client
        -- would show for it either way.
        sourceValidity = function(sourceID)
            local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
            if not sourceInfo then return nil end
            if not sourceInfo.itemID or not C_Item.GetItemInfo(sourceInfo.itemID) then return nil end
            if sourceInfo.isValidSourceForPlayer then return true end
            return false, refusalKey(sourceInfo.useErrorType), sourceInfo.useError
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

-- The cursor the Sets tab puts up while the dressing-room modifier is held, and
-- the only sign the ctrl-click is there to be made. Watched rather than read
-- once, since the key can go down over a piece already hovered.
local function updateCursor()
    if IsModifiedClick("DRESSUP") then
        ShowInspectCursor()
    else
        ResetCursor()
    end
end

-- The tooltip a set's piece shows, as the native Sets tab shows its own,
-- offering Tab to cycle through the items sharing a look.
--
-- The wardrobe does its cycling through fields on its own frame, and those are
-- fields this addon must not write (see addonTabs): a written one re-poisons
-- the wardrobe's every later read of it. So the index and the offer live on
-- the page, and the page listens for the key itself while a piece is hovered,
-- passing through everything it does not handle. The index still belongs to
-- the piece that was hovered, so the next piece starts again from its own
-- item.
--
-- Both of this addon's set pages hover the same kind of piece, so both take
-- their tooltip from here and neither can drift from the other. Answers the
-- two scripts a piece frame hangs on.
function ExtraSets.PieceTooltips(page)
    local hovered
    local hoveredFrame

    local function draw()
        local S = LuckysWardrobe.Strings.extraSets
        local sources = hovered.state ~= "unavailable" and pieceSources(hovered) or nil
        if not sources then
            GameTooltip:SetText(S.pieceUnavailable, 1, 0.25, 0.25, 1, true)
            GameTooltip:Show()
            return
        end

        page.tooltipSourceIndex, page.tooltipCycle =
            CollectionWardrobeUtil.SetAppearanceTooltip(GameTooltip, {
                sources = sources,
                primarySourceID = hovered.sourceID,
                selectedIndex = page.tooltipSourceIndex,
                showUseError = true,
                showTrackingInfo = false,
                slotType = _G[SLOT_TOOLTIP_GLOBALS[hovered.slot] or hovered.slot],
            })
        -- A piece already tracked says so, then the shift-click offers the way
        -- back out of it rather than offering to track it again.
        LuckysWardrobe.TrackedAppearances:AddTooltipLine(GameTooltip, hovered.sourceID)
        LuckysWardrobe.SetTracking:AddTrackHint(GameTooltip, hovered.sourceID)
        GameTooltip:Show()
    end

    page.RefreshAppearanceTooltip = function()
        if hovered then draw() end
    end

    page:SetScript("OnKeyDown", function(self, key)
        local handled = self.tooltipCycle and key == WARDROBE_CYCLE_KEY
        -- Setting propagation is combat-protected for addon code; in combat
        -- the keyboard was never claimed, so there is nothing to answer.
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(not handled) end
        if handled then
            self.tooltipSourceIndex = self.tooltipSourceIndex + (IsShiftKeyDown() and -1 or 1)
            draw()
        end
    end)

    local function show(itemFrame)
        hovered = itemFrame.piece
        hoveredFrame = itemFrame
        itemFrame:SetScript("OnUpdate", updateCursor)
        -- Claimed only while a piece is hovered, and only when propagation can
        -- be granted, or every other key would be swallowed with no way to
        -- hand it back.
        if not InCombatLockdown() then
            page:EnableKeyboard(true)
            page:SetPropagateKeyboardInput(true)
        end
        GameTooltip:SetOwner(itemFrame, "ANCHOR_RIGHT")
        draw()
    end

    -- Also called bare when the page puts itself away under the mouse, so the
    -- frame it stops watching is the one it remembers rather than one passed in.
    local function hide()
        hovered = nil
        page.tooltipSourceIndex, page.tooltipCycle = nil, nil
        page:EnableKeyboard(false)
        if hoveredFrame then
            hoveredFrame:SetScript("OnUpdate", nil)
            hoveredFrame = nil
        end
        ResetCursor()
        GameTooltip:Hide()
    end

    return show, hide
end

-- The clicks a set's piece answers, which are the same on both of this addon's
-- set pages. Ctrl-click previews the piece in the dressing room as the Sets tab
-- does; the other two are this addon's own and hand the click back when their
-- setting is off. Takes the name of the set on show, for the tracking report.
function ExtraSets.PieceClicks(setName)
    return function(itemFrame, buttonName)
        local piece = itemFrame.piece
        if not piece then return end

        if LuckysWardrobe.WowheadLink:HandlesClick(buttonName)
            and LuckysWardrobe.WowheadLink:ShowForSource(piece.sourceID) then
            return
        end
        if LuckysWardrobe.SetTracking:HandlesShiftClick(buttonName) and piece.state == "missing" then
            LuckysWardrobe.SetTracking:TogglePiece(piece.sourceID, setName())
            return
        end
        -- Only for the pieces the client still knows: an unavailable one has no
        -- look left to put on, and asking would open an empty dressing room.
        if IsModifiedClick("DRESSUP") and piece.state ~= "unavailable" then
            DressUpVisual(piece.sourceID)
        end
    end
end

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

    -- Being shown rebuilds the player's figure from scratch, and anything put
    -- on a figure still on its way is dropped, so a dress that lands while
    -- this is up has to be asked for again once the figure arrives.
    local modelLoading

    local model = CreateFrame("DressUpModel", nil, page)
    Mixin(model, WardrobeSetsDetailsModelMixin)
    model:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 3, -3)
    model:SetPoint("BOTTOMRIGHT", rightInset, "BOTTOMRIGHT", -4, 3)
    model:SetScript("OnShow", function(self)
        modelLoading = true
        self.OnShow(self)
    end)
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
    -- OnModelLoaded is attached below displayEntry, which it needs in reach.
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

    local modelFade = detailsFrame:CreateTexture(nil, "BACKGROUND")
    modelFade:SetAtlas("transmog-set-model-cutoff-fade")
    modelFade:SetHeight(178)
    modelFade:SetPoint("TOPLEFT", 2, 0)
    modelFade:SetPoint("TOPRIGHT")

    -- Where a set can simply be bought, for the sets sold as ensembles. It
    -- takes the bottom of the pane, and pushes the notice above it on the sets
    -- that have something to say there as well.
    local sourceText = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sourceText:SetPoint("BOTTOM", 0, 12)
    sourceText:SetWidth(380)

    local noticeText = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    noticeText:SetWidth(380)

    local overflowText = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    overflowText:SetWidth(380)

    -- Which slots this preview dresses, in the corner every set pane keeps the
    -- same control in.
    local previewSlotsButton = LuckysWardrobe.PreviewSlots:CreateButton(detailsFrame)
    previewSlotsButton:SetPoint("TOPRIGHT", detailsFrame, "TOPRIGHT", DETAILS_CORNER_X, DETAILS_CORNER_Y)

    -- Where the Sets tab puts the same control: the top corner of the details
    -- pane, over the model rather than beside the list.
    local variantDropdown = CreateFrame("DropdownButton", nil, detailsFrame, "WowStyle1DropdownTemplate")
    variantDropdown:SetSize(VARIANT_DROPDOWN_WIDTH, VARIANT_DROPDOWN_HEIGHT)
    variantDropdown:SetPoint("RIGHT", previewSlotsButton, "LEFT", -4, 0)
    variantDropdown:Hide()

    local detailsText = rightInset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    detailsText:SetPoint("CENTER")
    detailsText:SetWidth(340)
    detailsText:SetText(S.select)

    local itemFrames = {}
    local rowBackgrounds = {}
    local selectedEntry

    -- One strip of Blizzard's icon-row art per row of pieces, built as the
    -- rows are needed. The art is a single strip, so a set wide enough to wrap
    -- gets another laid under each row rather than one row of pieces framed and
    -- the rest floating over the model.
    local function getRowBackground(index)
        if rowBackgrounds[index] then return rowBackgrounds[index] end

        local background = detailsFrame:CreateTexture(nil, "BORDER")
        background:SetAtlas("transmog-set-iconrow-background", true)
        background:SetPoint("TOP", 0, PIECE_ROW_BACKGROUND_TOP - (index - 1) * PIECE_ROW_HEIGHT)
        rowBackgrounds[index] = background
        return background
    end

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

    local pieceTooltip, hidePieceTooltip = ExtraSets.PieceTooltips(page)
    local pieceClick = ExtraSets.PieceClicks(function() return selectedEntry and selectedEntry.name end)

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
        itemFrame:SetScript("OnClick", pieceClick)
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
        local unwearable, clientReason =
            ExtraSets.UnwearableReason(entry, classID, ownClass and resolver.sourceValidity or nil)
        if entry.unavailable > 0 then
            noticeText:SetFormattedText(S.unavailableNotice, entry.unavailable)
        elseif unwearable then
            noticeText:SetText(ExtraSets.UnwearableNotice(entry, unwearable, classID, {
                faction = ExtraSets.OpposingFactionName(),
                message = clientReason,
            }))
        end
        noticeText:SetShown(entry.unavailable > 0 or unwearable ~= nil)
    end

    -- Which ensembles teach the set, for the sets there is one to buy. Nothing
    -- else on the page says where a look comes from, and for these it is the
    -- whole answer.
    local function showSource(entry)
        local names = ExtraSets.EnsembleNames(entry, C_Item.GetItemInfo)
        sourceText:SetShown(#names > 0)
        if #names > 0 then sourceText:SetFormattedText(S.ensembleSource, table.concat(names, ", ")) end

        -- Both lines sit at the bottom edge, so the notice stands on top of the
        -- source line when there is one and takes the edge itself when there is
        -- not, rather than leaving a gap where the missing line would be.
        noticeText:ClearAllPoints()
        if #names > 0 then
            noticeText:SetPoint("BOTTOM", sourceText, "TOP", 0, 2)
        else
            noticeText:SetPoint("BOTTOM", detailsFrame, "BOTTOM", 0, 12)
        end
    end

    -- Asking for a set's items is what starts them loading, and the answers
    -- land frames later. Sets this character can wear are the ones that arrive
    -- cold, since building the list only asks the client about pieces it will
    -- not judge, so without this pass the notice would be wrong exactly where
    -- it matters and right only after leaving the set and coming back. The
    -- ensembles ride along: their names come off the same item data, and every
    -- colourway's is asked for rather than only the one on show, because two
    -- that the client named alike are told apart in the picker by theirs.
    local fillVariantDropdown

    local function loadSetItems(row, pass)
        local waiting = false
        local function request(itemID)
            if itemID and not C_Item.GetItemInfo(itemID) then
                C_Item.RequestLoadItemDataByID(itemID)
                waiting = true
            end
        end

        for _, piece in ipairs(ExtraSets.VariantOf(row, selectedVariants[row.key]).pieces) do
            request(piece.itemID)
        end
        for _, variant in ipairs(row.variants or { row }) do
            for _, itemID in ipairs(variant.ensembles or {}) do request(itemID) end
        end
        if not waiting or pass >= Utils.ITEM_LOAD_PASSES then return end

        C_Timer.After(Utils.ITEM_LOAD_DELAY_SECONDS, function()
            -- The row on screen may have moved on while the client answered, and
            -- the colourway on show may have changed under a row that has not.
            if selectedEntry ~= row then return end
            local shown = ExtraSets.VariantOf(row, selectedVariants[row.key])
            showNotice(shown)
            showSource(shown)
            fillVariantDropdown(row)
            loadSetItems(row, pass + 1)
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
    fillVariantDropdown = function(row)
        variantDropdown:SetShown(row.isGroup or false)
        if not row.isGroup then return end

        local chosen = ExtraSets.VariantOf(row, selectedVariants[row.key])
        variantDropdown:SetText(SetRow.variantOption:format(
            ExtraSets.VariantLabelFor(chosen, C_Item.GetItemInfo), chosen.collected, chosen.total))
        variantDropdown:SetupMenu(function(_, menu)
            for _, variant in ipairs(row.variants) do
                menu:CreateRadio(
                    SetRow.variantOption:format(
                        ExtraSets.VariantLabelFor(variant, C_Item.GetItemInfo),
                        variant.collected, variant.total),
                    function() return ExtraSets.VariantOf(row, selectedVariants[row.key]) == variant end,
                    function()
                        selectedVariants[row.key] = variant.key
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
        countsText:SetFormattedText(SetRow.counts, entry.collected, entry.total)
        showNotice(entry)
        showSource(entry)
        loadSetItems(row, 1)
        if redress then model:Undress() end

        for _, itemFrame in ipairs(itemFrames) do itemFrame:Hide() end
        for _, background in ipairs(rowBackgrounds) do background:Hide() end
        local shownPieces = ExtraSets.DistinctLookPieces(entry.pieces)
        local places, leftOff = ExtraSets.PieceLayout(#shownPieces)
        for strip = 1, places[#places].row do getRowBackground(strip):Show() end
        for index, place in ipairs(places) do
            local piece = shownPieces[index]
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
            itemFrame:SetPoint("TOP", detailsFrame, "TOP", place.x, place.y)
            itemFrame:Show()
            LuckysWardrobe.TrackedAppearances:Mark(
                itemFrame, piece.state ~= "unavailable" and piece.sourceID or nil)

            -- The model wears what the icons show, so the two never describe
            -- different outfits, and a set of dozens does not cost dozens of
            -- redresses to say the same thing. Slots the previews are told not
            -- to dress stay bare. Worn without asking the client about the
            -- source first: on a fresh cache it has no answer yet, and a piece
            -- skipped for that would stay off until something else redressed.
            if redress and piece.state ~= "unavailable"
                and LuckysWardrobe.PreviewSlots:IsSlotShown(piece.slot) then
                model:TryOn(piece.sourceID)
            end
        end

        overflowText:SetShown(leftOff > 0)
        if leftOff > 0 then
            overflowText:ClearAllPoints()
            overflowText:SetPoint("TOP", detailsFrame, "TOP", 0,
                places[#places].y - PIECE_ROW_HEIGHT + 8)
            overflowText:SetFormattedText(S.piecesNotShown, leftOff)
        end

        if redress then refreshCamera() end
        LuckysWardrobe.Perf:End("set displayed")
    end

    -- The first dress after a show goes onto a figure that is still loading,
    -- and is dropped with it, so the set on screen is dressed again once the
    -- figure lands. A frame later rather than here: pieces put on while the
    -- load is still settling are wiped with it, the same reason the tooltip
    -- preview waits a frame before dressing. The loads that come of dressing
    -- are left alone, or every piece going on would strip and redress in a
    -- loop.
    model:SetScript("OnModelLoaded", function(self)
        self.OnModelLoaded(self)
        if not modelLoading then return end
        modelLoading = false
        C_Timer.After(0, function()
            dressedKey = nil
            displayEntry(selectedEntry)
        end)
    end)

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

    -- The colourways behind a row, one tooltip line each, named the way the
    -- pane's picker names them, with how much of each is collected.
    local function addColourwayLines(entry)
        for _, variant in ipairs(entry.variants or {}) do
            Utils.AddColourwayLine(GameTooltip,
                ExtraSets.VariantLabelFor(variant, C_Item.GetItemInfo),
                variant.collected, variant.total)
        end
    end

    local view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("WardrobeSetsScrollFrameButtonTemplate", function(button, entry)
        local complete = ExtraSets.IsComplete(entry)
        button.Name:SetText(entry.name)

        -- A row standing for several colourways counts them in the corner, which
        -- leaves the line under the name free to say how much of the whole
        -- family is collected. That count is the useful one: it is what the row
        -- is offering to finish, where one colourway's own progress says nothing
        -- about the rest of what is folded behind it.
        local several = Utils.MarkVariantCount(button, entry.variants and #entry.variants)

        -- The badge answers a hover with what it counted, minus the name that
        -- sits beside it. Cleared when the pooled row goes back to a plain set,
        -- whose badge is hidden and must have nothing to say.
        button.luckysBadgeTooltip = several and function(badge)
            GameTooltip:SetOwner(badge, "ANCHOR_RIGHT")
            GameTooltip:SetText(entry.label, 1, 1, 1)
            addColourwayLines(entry)
            GameTooltip:Show()
        end or nil

        -- Counts beat a loading notice as soon as anything resolves, so a set
        -- with one slow piece still says something useful.
        if entry.total > 0 then
            local label = not several and entry.label ~= "" and entry.label
            button.Label:SetText(label or SetRow.counts:format(entry.collected, entry.total))
        elseif entry.loading then
            button.Label:SetText(S.loading)
        else
            button.Label:SetText(S.pieceUnavailableShort)
        end
        Utils.ColourSetName(button, complete, entry.collected)

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
        LuckysWardrobe.TrackedAppearances:MarkSet(button, ExtraSets.MissingSources(entry))
        button.SelectedTexture:SetShown(selectedEntry and entry.key == selectedEntry.key)

        local showProgress = not entry.loading and entry.collected > 0 and not complete
        button.ProgressBar:SetShown(showProgress)
        if showProgress then button.ProgressBar:SetWidth(204 * entry.collected / entry.total) end

        button:SetScript("OnClick", function(_, buttonName)
            if buttonName ~= "LeftButton" then return end
            if LuckysWardrobe.SetTracking:HandlesShiftClick(buttonName) then
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
            GameTooltip:AddLine(SetRow.counts:format(entry.collected, entry.total), 1, 1, 1)
            addColourwayLines(entry)
            for _, name in ipairs(ExtraSets.EnsembleNames(entry, C_Item.GetItemInfo)) do
                GameTooltip:AddLine(S.ensembleSource:format(name), 0.6, 0.8, 1)
            end
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
        setAllSources(true)
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

        local menu = LuckysWardrobe.Strings.filterMenu
        local sort = root:CreateButton(menu.sortBy)
        for _, option in ipairs({
            { key = "default", label = DEFAULT },
            { key = "name", label = menu.byName },
            { key = "completion", label = menu.byCompletion },
            { key = "pieces", label = menu.byPieces },
            { key = "variants", label = menu.byVariants },
        }) do
            local mode = option
            sort:CreateRadio(mode.label, function() return filters.sortMode == mode.key end, function()
                filters.sortMode = mode.key
                refresh()
            end)
        end

        local direction = root:CreateButton(menu.sortDirection)
        for _, option in ipairs({ { key = "ascending", label = menu.ascending }, { key = "descending", label = menu.descending } }) do
            local sortDirection = option
            direction:CreateRadio(sortDirection.label, function() return filters.sortDirection == sortDirection.key end, function()
                filters.sortDirection = sortDirection.key
                refresh()
            end)
        end

        local sourceLabels = LuckysWardrobe.Strings.snapshotSources
        local sources = root:CreateButton(menu.source)
        sources:CreateButton(CHECK_ALL, function()
            setAllSources(true)
            refresh()
            return MenuResponse.Refresh
        end)
        sources:CreateButton(UNCHECK_ALL, function()
            setAllSources(false)
            refresh()
            return MenuResponse.Refresh
        end)
        sources:CreateDivider()
        for _, option in ipairs(ExtraSets.SOURCES) do
            local source = option
            sources:CreateCheckbox(sourceLabels[source.label], function()
                return filters.sources[source.bit]
            end, function()
                filters.sources[source.bit] = not filters.sources[source.bit]
                refresh()
            end)
        end

        ExtraSets.AddExpansionFilter(root, filters.expansions, refresh)
    end)

    -- Collecting an appearance changes what these sets have collected, so the
    -- cached entries go and the page builds them again. Searching and filtering
    -- reuse what is already there.
    local function rebuildNow()
        ExtraSets.InvalidateEntries()
        refresh()
    end

    local queueRebuild = Utils.Debounced(Utils.REBUILD_DELAY_SECONDS, function()
        -- A page that has since closed rebuilds when it opens again.
        if page:IsShown() then rebuildNow() end
    end)

    -- A changed slot choice outdates whatever the model is wearing, wherever
    -- it was changed from, so the memory of what it wears goes even while the
    -- page is off screen and the set on screen is dressed again on the spot.
    LuckysWardrobe.PreviewSlots:OnChanged(function()
        dressedKey = nil
        if page:IsShown() then displayEntry(selectedEntry) end
    end)

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
    local say = Utils.Say

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
-- Every family the colourway rule gathered, and what it put in each. This is an
-- inference rather than a fact the client supplied, so it is worth being able to
-- read the whole of it in one go: a family that has taken in a set it should not
-- have shows up here as a colour name that is not a colour.
--
-- Read off the rows the page builds for the class it is listing, before search
-- or filters, so it says what the list would hold rather than what it happens to
-- be showing.
function ExtraSets:PrintColourFamilies()
    local S = LuckysWardrobe.Strings.extraSets.report
    local say = Utils.Say
    local catalog = LuckysWardrobe.ExtraSetsCatalog
    if not catalog:GetReport() then
        say(S.notStarted)
        return
    end
    if not catalog:IsReady() then
        say(S.building)
        return
    end

    local formed = {}
    for _, row in ipairs(ExtraSets.BuildRows(ExtraSets.Entries())) do
        if row.isColourFamily then formed[#formed + 1] = row end
    end
    if #formed == 0 then
        say(S.coloursNone)
        return
    end

    say(S.coloursHeader:format(#formed))
    local grouped = 0
    for _, family in ipairs(formed) do
        local labels = {}
        for index, variant in ipairs(family.variants) do
            labels[index] = ExtraSets.VariantLabelFor(variant, C_Item.GetItemInfo)
        end
        grouped = grouped + #family.variants
        say(S.coloursLine:format(
            family.name, #family.variants, #family.pieces, table.concat(labels, ", ")))
    end
    say(S.coloursTotal:format(grouped, #formed))
end

-- What the client itself says about a set's colourways. Blizzard marks the
-- difficulty tints of a tier as variants of one base set, and the Sets tab shows
-- them behind one row with a dropdown rather than as rows of their own. Whether
-- it marks a batch of recolours the same way decides whether this page has
-- anything to infer: a set that names a base other than itself is already
-- grouped, in the client's own words and the player's own language.
--
-- Dev dump, for settling that one family at a time. A record the client answers
-- nothing for is the answer too, and is printed rather than skipped.
function ExtraSets:PrintVariants(query)
    local S = LuckysWardrobe.Strings.extraSets.report
    local say = Utils.Say
    local catalog = LuckysWardrobe.ExtraSetsCatalog
    if not catalog:GetReport() then
        say(S.notStarted)
        return
    end
    if not catalog:IsReady() then
        say(S.building)
        return
    end

    local normalized = (query or ""):lower()
    local lines = {}
    for _, record in ipairs(ExtraSets.Records()) do
        if record.name:lower():find(normalized, 1, true) then
            local baseSetID = C_TransmogSets.GetBaseSetID(record.setID)
            local variants = {}
            for _, variant in ipairs(C_TransmogSets.GetVariantSets(record.setID) or {}) do
                variants[#variants + 1] = variant.setID
            end
            lines[#lines + 1] = S.variantLine:format(
                record.setID,
                record.name,
                baseSetID or S.variantNoBase,
                #variants > 0 and table.concat(variants, ", ") or S.variantNone
            )
        end
    end

    if #lines == 0 then
        say(S.findNone:format(query))
        return
    end
    say(S.variantsHeader:format(query))
    for _, line in ipairs(lines) do say(line) end
end

function ExtraSets:PrintLooks(query)
    local S = LuckysWardrobe.Strings.extraSets.report
    local say = Utils.Say
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

-- Every source still missing from an entry, across every colourway it stands
-- for. Shared by the shift-click, which goes after all of it, and the
-- set-level crosshair, which asks whether all of it is already being hunted.
function ExtraSets.MissingSources(entry)
    local missing = {}
    for _, variant in ipairs(entry.variants or { entry }) do
        for _, piece in ipairs(variant.pieces) do
            if piece.state == "missing" then missing[#missing + 1] = piece.sourceID end
        end
    end
    return missing
end

-- Shift-clicking a set tracks everything left in it: the row says how much of
-- the whole set is missing, so tracking it is expected to go after all of it.
-- Shift-clicking it again calls all of that off, the way a single piece
-- already toggles.
function ExtraSets:TrackMissing(entry)
    LuckysWardrobe.SetTracking:ToggleSources(ExtraSets.MissingSources(entry), entry.name)
end

-- Blizzard hangs the class dropdown above the Sets page rather than inside it,
-- and SetTab re-anchors it to whichever native page it just chose. This page
-- occupies the same corner, so the same offsets leave the dropdown exactly
-- where the Sets tab has it.
local function layOutClassDropdown(dropdown)
    dropdown:ClearAllPoints()
    dropdown:SetPoint("BOTTOMRIGHT", extraPage, "TOPRIGHT", CLASS_DROPDOWN_X, CLASS_DROPDOWN_Y)
end

-- The tabs this addon hangs past the end of the journal's own strip, in the
-- order they were attached. They are deliberately not enrolled in Blizzard's
-- tab machinery: no numTabs bump, no ContentFrames entry, no activeFrame, and
-- no SetTab call ever selects one. Any field an addon writes on the wardrobe is
-- tainted, the wardrobe's secure SetTab reads numTabs on every tab change, and
-- that one read sours its whole execution, down to the tooltipCycle field the
-- key handler checks on every keypress. A tainted "propagate this key" answer
-- is one the client ignores, which ate WASD whenever an appearance tooltip was
-- up. So the tabs live entirely on this side of the fence: selection is a
-- plain OnClick that swaps pages, and the one hook below puts everything back
-- when a native tab is chosen.
local addonTabs = {}

local function nativeTab(wardrobe, index)
    return wardrobe.Tabs and wardrobe.Tabs[index]
        or _G[wardrobe:GetName() .. "Tab" .. index]
end

-- The bar sits past the end of the tab strip, so it hangs off whichever tab is
-- last, which is the last one this addon added.
local function lastTab()
    return addonTabs[#addonTabs].tab
end

-- How much room the strip leaves the bar, measured against the nearest anything
-- comes to it on any tab. That is the Items tab's search box: the set pages give
-- the top right corner to the class dropdown, which sits further out, and drop
-- their own search box to the row below. Measuring the tightest tab rather than
-- the one on screen is what keeps the bar in one place as the tabs change, and
-- keeps the Items tab from drawing its search box over it.
--
-- The wardrobe has no position until it has been shown, so until then the bar
-- takes its full width and every tab change measures again.
local function progressBarWidth(tab)
    local stripEdge = tab:GetRight()
    local wardrobeEdge = attachedWardrobe:GetRight()
    if not (stripEdge and wardrobeEdge) then return PROGRESS_BAR_WIDTH end

    local room = wardrobeEdge - ITEMS_SEARCH_BOX_INSET - stripEdge - PROGRESS_BAR_TAB_GAP * 2
    return math.max(PROGRESS_BAR_MIN_WIDTH, math.min(PROGRESS_BAR_WIDTH, room))
end

-- The border art is a fixed texture, so it has to be narrowed alongside the bar
-- it frames.
local function layOutProgressBar(progressBar)
    local tab = lastTab()
    local width = progressBarWidth(tab)
    progressBar:ClearAllPoints()
    progressBar:SetPoint("TOPLEFT", tab, "TOPRIGHT", PROGRESS_BAR_TAB_GAP, PROGRESS_BAR_TAB_DROP)
    progressBar:SetWidth(width)
    progressBar.border:SetWidth(width + PROGRESS_BAR_BORDER_MARGIN)
end

local function layOutProgressBars()
    layOutProgressBar(attachedWardrobe.progressBar)
    layOutProgressBar(extraPage.progressBar)
end

-- Every SetTab call means a native tab: ours never go through it. Blizzard
-- redraws its own tab visuals securely, so this only has to take our pages off
-- the screen and put back the chrome selecting one of ours hid.
local function showNativeChrome(wardrobe)
    for _, entry in ipairs(addonTabs) do
        entry.page:Hide()
        PanelTemplates_DeselectTab(entry.tab)
    end
    wardrobe.SearchBox:Show()
    wardrobe.FilterButton:Show()
    wardrobe.ClassDropdown:Show()
    if extraPage then layOutProgressBars() end
end

-- Selecting one of our tabs by hand. The native tabs are drawn deselected with
-- the same widget calls Blizzard's own strip uses, which touch no field the
-- secure side reads, and the next real SetTab draws them again itself.
local function selectAddonTab(wardrobe, chosen)
    for index = 1, wardrobe.numTabs do
        PanelTemplates_DeselectTab(nativeTab(wardrobe, index))
    end
    wardrobe.ItemsCollectionFrame:Hide()
    wardrobe.SetsCollectionFrame:Hide()
    wardrobe.SearchBox:Hide()
    wardrobe.FilterButton:Hide()
    wardrobe.progressBar:Hide()

    for _, entry in ipairs(addonTabs) do
        local selected = entry.tab == chosen
        entry.page:SetShown(selected)
        if selected then
            PanelTemplates_SelectTab(entry.tab)
            entry.onSelected()
        else
            PanelTemplates_DeselectTab(entry.tab)
        end
    end

    if extraPage then layOutProgressBars() end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

-- What PanelTemplates_ResizeTabsToFit does for the strip it can see: the whole
-- row squeezed once it outgrows the room. It reads the count off the frame,
-- which is the field this addon must not write, so the squeeze runs here over
-- the native tabs and ours together.
local function resizeTabStrip(wardrobe)
    local tabs = {}
    for index = 1, wardrobe.numTabs do tabs[#tabs + 1] = nativeTab(wardrobe, index) end
    for _, entry in ipairs(addonTabs) do tabs[#tabs + 1] = entry.tab end

    local width = 0
    for _, tab in ipairs(tabs) do width = width + tab:GetWidth() end
    if width <= TAB_FIT_WIDTH then return end

    local widthPerTab = TAB_FIT_WIDTH / #tabs
    for _, tab in ipairs(tabs) do
        PanelTemplates_TabResize(tab, 0, nil, tab.minWidth, widthPerTab)
    end
end

--- Adds a tab to the journal for the given page, kept outside Blizzard's tab
--- state entirely; see addonTabs for why. The Custom tab attaches through here
--- too, so both stay outside it the same way. onSelected is the page's own
--- chrome: what it wants done with the class dropdown the pages share.
---
--- order fixes where the tab sits in the strip. The pages attach from
--- load-order callbacks that arrive in no promised order, so the strip is
--- re-anchored from the order asked for rather than from whoever came first.
function ExtraSets.AddWardrobeTab(wardrobe, name, label, page, onSelected, order)
    local tab = CreateFrame("Button", name, wardrobe, "PanelTopTabButtonTemplate")
    tab:SetText(label)
    tab.minWidth = 75
    PanelTemplates_TabResize(tab, 0)
    PanelTemplates_DeselectTab(tab)
    tab:SetScript("OnClick", function() selectAddonTab(wardrobe, tab) end)

    addonTabs[#addonTabs + 1] = { tab = tab, page = page, onSelected = onSelected, order = order }
    table.sort(addonTabs, function(a, b) return a.order < b.order end)
    local previous = nativeTab(wardrobe, wardrobe.numTabs)
    for _, entry in ipairs(addonTabs) do
        entry.tab:ClearAllPoints()
        entry.tab:SetPoint("TOPLEFT", previous, "TOPRIGHT", 3, 0)
        previous = entry.tab
    end

    if #addonTabs == 1 then
        hooksecurefunc(wardrobe, "SetTab", showNativeChrome)
    end
    resizeTabStrip(wardrobe)
    page:Hide()
    return tab
end

function ExtraSets:Attach(wardrobe)
    if attachedWardrobe or not wardrobe or not wardrobe.numTabs then return end

    attachedWardrobe = wardrobe
    extraPage = self:CreatePage(wardrobe)
    ExtraSets.AddWardrobeTab(wardrobe, "LuckysWardrobeExtraSetsTab",
        LuckysWardrobe.Strings.extraSets.tab, extraPage, function()
            layOutClassDropdown(wardrobe.ClassDropdown)
            wardrobe.ClassDropdown:Show()
            -- The dropdown was last refreshed for the page being left, so it
            -- reads the name on the button again now that this page is the one
            -- on screen.
            wardrobe.ClassDropdown:Refresh()
        end, 1)

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

    layOutProgressBars()
end

function ExtraSets:Init()
    filters.collected = true
    filters.uncollected = true
    filters.sortMode = "default"
    filters.sortDirection = "ascending"
    setAllExpansions(true)
    setAllSources(true)
    selectedVariants = {}
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", function()
        LuckysWardrobe.ExtraSetsCatalog:StartBuild()
        ExtraSets:Attach(WardrobeCollectionFrame)
    end)
end
