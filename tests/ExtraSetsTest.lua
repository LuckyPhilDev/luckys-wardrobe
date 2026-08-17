-- luacheck: globals AutoScalingFontStringMixin CHECK_ALL COLLECTED CollectionWardrobeUtil CreateFrame Enum FACTION_ALLIANCE FACTION_HORDE UnitFactionGroup CreateDataProvider CreateScrollBoxListLinearView DEFAULT DressUpVisual dressUp EventUtil GameTooltip GetUICameraInfo IsModifiedClick IsShiftKeyDown IsUnitModelReadyForUI LuckysWardrobe ResetCursor ShowInspectCursor MenuResponse Mixin Model_ApplyUICamera NOT_COLLECTED PanelTemplates_DeselectTab PanelTemplates_SelectTab PanelTemplates_TabResize PlaySound QUESTION_MARK_ICON SOUNDKIT ScrollBoxConstants ScrollUtil UNCHECK_ALL UnitClass WARDROBE_CYCLE_KEY InCombatLockdown WardrobeCollectionFrame WardrobeSetsDetailsModelMixin hooksecurefunc GetNumClasses C_ClassColor C_CreatureInfo C_TransmogSets C_TransmogCollection C_Item C_Timer
-- luacheck: ignore 121

LuckysWardrobe = {}

local devLogs = {}
LuckysWardrobe.DevLog = function(message) devLogs[#devLogs + 1] = message end

DEFAULT = "Default"
COLLECTED = "Collected"
NOT_COLLECTED = "Not Collected"
CHECK_ALL = "Check All"
UNCHECK_ALL = "Uncheck All"
MenuResponse = { Refresh = 1 }
for index = 0, 11 do _G["EXPANSION_NAME" .. index] = "Expansion " .. index end

-- Classes are real: the page asks them what armour a class wears and how to
-- colour its name.
GetNumClasses = function() return 13 end
C_CreatureInfo = {
    GetClassInfo = function(classID)
        return { classFile = "CLASS" .. classID, className = "Class " .. classID }
    end,
}
C_ClassColor = {
    GetClassColor = function(classFile)
        return { WrapTextInColorCode = function(_, text) return "<" .. classFile .. ">" .. text end }
    end,
}

dofile("src/Strings.lua")
dofile("src/Utils.lua")
dofile("src/domain/SetSources.lua")
dofile("src/domain/SetSearch.lua")
dofile("src/Data/ExtraSetsData.lua")
dofile("src/domain/Classes.lua")
-- The page measures its own work, so the real stopwatch runs here too, wound
-- by hand rather than by the clock the client would provide.
dofile("src/Perf.lua")
local clock = 0
LuckysWardrobe.Perf.Clock = function()
    clock = clock + 1
    return clock
end
dofile("src/features/journal/ExtraSets.lua")
-- The preview-slots choice is real here, so hiding a slot drives the same
-- module the page leans on. Its own Sets tab wiring waits on a collections
-- addon this harness never announces, so that wait is swallowed; the harness
-- below defines the EventUtil the page's attach goes through.
EventUtil = { ContinueOnAddOnLoaded = function() end }
dofile("src/features/journal/PreviewSlots.lua")
LuckysWardrobe.PreviewSlots:Init({ hiddenSetSlots = {} })

local ExtraSets = LuckysWardrobe.ExtraSets
local CLOTH, LEATHER = 1, 2
-- Class 5 is the Priest slot in the client's own order, so it wears cloth;
-- class 4 is the Rogue slot and wears leather.
local CLOTH_CLASS, LEATHER_CLASS = 5, 4

-- Record building has its own test (ExtraSetsCatalogTest.lua); here the
-- catalogue module is stubbed so the page logic can be driven directly.
local catalogRecords = {}
local catalogLooks = {}
local catalogReport
local catalogReady = true
local catalogBuildStarted = false
local catalogReadyCallback
LuckysWardrobe.ExtraSetsCatalog = {
    StartBuild = function() catalogBuildStarted = true end,
    IsReady = function() return catalogReady end,
    GetRecords = function() return catalogRecords end,
    GetReport = function() return catalogReport end,
    OfficialLooks = function() return catalogLooks end,
    OnReady = function(_, callback) catalogReadyCallback = callback end,
}

-- Schema validation.

local function pieces(...)
    local list = {}
    for index, piece in ipairs({ ... }) do
        list[index] = { slot = piece[1], sourceID = piece[2], itemID = piece[3] }
    end
    return list
end

-- The catalogue resolves a set's name once, so a record arrives here already
-- carrying whatever the client or the snapshot called it.
local function validRecord(overrides)
    local record = {
        setID = 20,
        name = "Live Name",
        armorType = CLOTH,
        classMask = 0,
        pieces = pieces({ "HEAD", 2001 }, { "CHEST", 2003 }, { "LEGS", 2004 }),
    }
    for key, value in pairs(overrides or {}) do record[key] = value end
    return record
end

assert(ExtraSets.ValidateRecord(validRecord()), "accepted a well-formed record")
assert(not ExtraSets.ValidateRecord(validRecord({ setID = 1.5 })), "rejected fractional set IDs")
assert(not ExtraSets.ValidateRecord(validRecord({ name = "" })), "rejected empty names")
local noArmorType = validRecord()
noArmorType.armorType = nil
assert(not ExtraSets.ValidateRecord(noArmorType), "rejected records without an armour type")
local noMask = validRecord()
noMask.classMask = nil
assert(not ExtraSets.ValidateRecord(noMask), "rejected records without a class mask")
assert(ExtraSets.ValidateRecord(validRecord({ expansionID = 5 })), "accepted an optional expansion")
assert(not ExtraSets.ValidateRecord(validRecord({ expansionID = "five" })), "rejected non-numeric expansions")
assert(not ExtraSets.ValidateRecord(validRecord({ pieces = {} })), "rejected records without pieces")
assert(not ExtraSets.ValidateRecord(validRecord({ pieces = pieces({ "ELBOW", 1 }) })), "rejected unknown slots")
assert(
    not ExtraSets.ValidateRecord(validRecord({ pieces = pieces({ "HEAD", 7 }, { "CHEST", 7 }) })),
    "rejected the same source twice in one set"
)
assert(
    ExtraSets.ValidateRecord(validRecord({ pieces = pieces({ "CHEST", 7 }, { "CHEST", 8 }) })),
    "accepted two pieces in one slot, as a set with a chest and a robe has"
)
assert(ExtraSets.ValidateRecord(validRecord({ ensembles = { 70001 } })),
    "accepted a set with an ensemble that teaches it")
assert(not ExtraSets.ValidateRecord(validRecord({ ensembles = {} })),
    "rejected an empty ensemble list, which says a set is sold as one without saying which")
assert(not ExtraSets.ValidateRecord(validRecord({ ensembles = { "70001" } })),
    "rejected ensembles that are not item IDs")
assert(ExtraSets.ValidateRecord(validRecord({ armorType = 0 })),
    "accepted a set of tabards and cloaks, which is nobody's armour in particular")

-- The two listings number their sets differently, so a record's identity is the
-- list it came from as well as the number.

local wowheadNumbered = validRecord({ setID = 20 })
local clientNumbered = validRecord({ setID = 20, ensembles = { 70001 } })
assert(ExtraSets.RecordKey(wowheadNumbered) ~= ExtraSets.RecordKey(clientNumbered),
    "one number in two listings is two records")
assert(ExtraSets.RecordKey(validRecord({ setID = 20 })) == ExtraSets.RecordKey(wowheadNumbered),
    "and the same number in one listing is one record")

-- The ensembles that teach a look, gathered as rows fold into one another.

local merged = ExtraSets.MergeEnsembles({ 1, 2 }, { 2, 3 })
assert(#merged == 3 and merged[1] == 1 and merged[2] == 2 and merged[3] == 3,
    "gathered both lists without repeating what they share")
local kept = { 1 }
assert(ExtraSets.MergeEnsembles(kept, nil) == kept, "nothing to add leaves the list alone")
assert(ExtraSets.MergeEnsembles(kept, { 2 }) ~= kept,
    "and a merge never writes into a list the catalogue owns")
assert(#kept == 1, "so the record it came from is untouched")

-- Class mask maths.

assert(ExtraSets.ClassAllowed(0, 5), "zero mask allows every class")
assert(ExtraSets.ClassAllowed(4, 3), "mask bit matches its class")
assert(not ExtraSets.ClassAllowed(4, 1), "mask excludes other classes")
assert(ExtraSets.ClassAllowed(4, nil), "no class information means usable")

-- Which sets a class has any use for: its own, plus everyone's in its armour.

local clothBit = 2 ^ (CLOTH_CLASS - 1)
local lockedCloth = validRecord({ classMask = clothBit, armorType = CLOTH })
local lockedLeather = validRecord({ classMask = 2 ^ (LEATHER_CLASS - 1), armorType = LEATHER })
local anyoneCloth = validRecord({ classMask = 0, armorType = CLOTH })
local anyoneLeather = validRecord({ classMask = 0, armorType = LEATHER })

assert(ExtraSets.MatchesClass(lockedCloth, CLOTH_CLASS), "a set named for the class is theirs")
assert(not ExtraSets.MatchesClass(lockedLeather, CLOTH_CLASS), "a set named for another class is not")
assert(ExtraSets.MatchesClass(anyoneCloth, CLOTH_CLASS), "a set for anyone in their armour is theirs")
assert(not ExtraSets.MatchesClass(anyoneLeather, CLOTH_CLASS),
    "a set for anyone in armour they cannot wear is not")
assert(ExtraSets.MatchesClass(anyoneLeather, LEATHER_CLASS), "the same set belongs to the leather class")
-- A class-locked set stays with its class whatever armour it happens to be:
-- some old sets are named for a class that outgrew that armour type.
assert(ExtraSets.MatchesClass(validRecord({ classMask = clothBit, armorType = LEATHER }), CLOTH_CLASS),
    "armour never overrules a set named for the class")
assert(ExtraSets.MatchesClass(anyoneLeather, nil), "no class chosen means no class narrowing")
local anyoneAnything = validRecord({ classMask = 0, armorType = 0 })
assert(ExtraSets.MatchesClass(anyoneAnything, CLOTH_CLASS)
    and ExtraSets.MatchesClass(anyoneAnything, LEATHER_CLASS),
    "a set of tabards and cloaks belongs to every class, since none of them is barred from it")

local forCloth = ExtraSets.RecordsForClass(
    { lockedCloth, lockedLeather, anyoneCloth, anyoneLeather }, CLOTH_CLASS)
assert(#forCloth == 2 and forCloth[1] == lockedCloth and forCloth[2] == anyoneCloth,
    "narrowed the catalogue to the sets that class could wear")

-- Sets the Sets tab already shows. Both tabs read one class dropdown, so the
-- duplicate is only a duplicate for the classes Blizzard lists the set under.
-- Class 8 is the other cloth class here, and its Sets tab does not list it.

local nativeToCloth = validRecord({ classMask = 0, armorType = CLOTH, officialClassMask = clothBit })
assert(ExtraSets.ListedNatively(nativeToCloth, CLOTH_CLASS), "the Sets tab shows this class the same set")
assert(not ExtraSets.ListedNatively(nativeToCloth, 8), "another class's Sets tab does not show it")
assert(not ExtraSets.ListedNatively(anyoneCloth, CLOTH_CLASS), "a set no Sets tab lists is never a duplicate")
assert(ExtraSets.ListedNatively(nativeToCloth, nil), "with no class chosen, any Sets tab listing is a duplicate")

local deduped = ExtraSets.RecordsForClass({ anyoneCloth, nativeToCloth }, CLOTH_CLASS)
assert(#deduped == 1 and deduped[1] == anyoneCloth, "dropped the set the Sets tab already shows this class")
assert(#ExtraSets.RecordsForClass({ anyoneCloth, nativeToCloth }, 8) == 2,
    "kept it for the class whose Sets tab has no such row")

-- An ensemble that is one slot's worth of appearances is one appearance rather
-- than a set, and neither page has a row for it.

local cloakColours = validRecord({
    setID = 30,
    ensembles = { 70001 },
    pieces = pieces({ "BACK", 8001 }, { "BACK", 8002 }, { "BACK", 8003 }),
})
local oneCloak = validRecord({ setID = 31, ensembles = { 70002 }, pieces = pieces({ "BACK", 8001 }) })
local boughtOutfit = validRecord({
    setID = 32,
    ensembles = { 70003 },
    pieces = pieces({ "HEAD", 8004 }, { "BACK", 8001 }),
})
-- The same three cloaks with no ensemble behind them: an armour list reaching
-- one slot is a set this client could only partly resolve, and the little of it
-- there is left to collect is still worth a row.
local cloakSet = validRecord({ setID = 33, pieces = pieces({ "BACK", 8001 }, { "BACK", 8002 }) })

assert(ExtraSets.IsSingleSlotEnsemble(cloakColours), "several colours of one slot is not a set")
assert(ExtraSets.IsSingleSlotEnsemble(oneCloak), "nor is a single appearance sold on its own")
assert(not ExtraSets.IsSingleSlotEnsemble(boughtOutfit), "an ensemble reaching two slots is a set")
assert(not ExtraSets.IsSingleSlotEnsemble(cloakSet), "and a set from the armour lists is never held to this")

local listed = ExtraSets.RecordsForClass(
    { anyoneCloth, cloakColours, oneCloak, boughtOutfit, cloakSet }, CLOTH_CLASS)
assert(#listed == 3 and listed[1] == anyoneCloth and listed[2] == boughtOutfit and listed[3] == cloakSet,
    "the single-slot ensembles never reach either page")

-- Entry building against a stub resolver.

local sourceStates = {
    [2001] = { appearanceID = 9001, collected = true },
    [2003] = { appearanceID = 9003, collected = false },
    [2004] = { appearanceID = 9003, collected = false }, -- same look as 2003
    [3001] = { appearanceID = 9101, collected = false },
    [3002] = {},                                         -- exists, still loading
}

local function stubResolver(classID)
    return {
        sourceState = function(sourceID) return sourceStates[sourceID] end,
        playerClassID = function() return classID end,
    }
end

local records = {
    validRecord(),
    {
        setID = 500,
        name = "Loading Set",
        label = "Fixture",
        -- Named for the cloth class but made of leather, which some old sets
        -- are: the name on the set wins over the armour it happens to be.
        armorType = LEATHER,
        classMask = 2 ^ (CLOTH_CLASS - 1),
        pieces = pieces({ "HEAD", 3001 }, { "CHEST", 3002 }, { "LEGS", 3999 }),
    },
    validRecord({
        setID = 21,
        name = "Test Garb",
        pieces = pieces({ "HEAD", 4001 }, { "CHEST", 4002 }, { "LEGS", 4003 }),
    }),
    { setID = "twenty-two" },
    validRecord(),
}

local entries = ExtraSets.BuildEntries(records, stubResolver(1))
assert(#entries == 3, "kept valid unique records only")
assert(#devLogs == 2, "reported both rejected records")

local garb = entries[1]
assert(garb.key == 20 and garb.armorType == CLOTH, "keyed entries by set ID and kept the armour type")
assert(garb.ensembles == nil and not garb.fromEnsemble, "a set from an armour list is not sold as an ensemble")
assert(garb.name == "Live Name", "took the name the catalogue resolved")
assert(garb.collected == 1 and garb.total == 2, "counted shared appearances once")
assert(garb.missing == 1, "derived the missing count")
assert(garb.unavailable == 0 and not garb.loading, "fully resolvable set has no caveats")
assert(garb.pieces[1].slot == "HEAD" and garb.pieces[1].state == "collected", "pieces keep slot order and state")
assert(garb.pieces[2].state == "missing" and garb.pieces[3].state == "missing", "uncollected pieces are missing")
assert(garb.pieces[1].appearanceID == 9001 and garb.pieces[2].appearanceID == 9003,
    "pieces keep their look, so the transmogrifier page can match them against an outfit")

local loadingSet = entries[2]
assert(loadingSet.name == "Loading Set", "fell back to the catalogue name")
assert(loadingSet.loading, "unresolved appearance data marks the entry loading")
assert(loadingSet.unavailable == 1, "unknown sources are counted unavailable")
assert(loadingSet.pieces[3].state == "unavailable", "the invalid source is labelled, not hidden")
assert(loadingSet.collected == 0 and loadingSet.total == 2, "unavailable pieces stay out of the totals")

-- Sets an ensemble teaches. They arrive numbered the way the client numbers its
-- own, so a number an armour list also uses is two sets rather than a clash.

local soldAsEnsemble = validRecord({ ensembles = { 70001 } })
local bothListings = ExtraSets.BuildEntries({ validRecord(), soldAsEnsemble }, stubResolver(1))
assert(#bothListings == 2 and bothListings[1].key ~= bothListings[2].key,
    "kept a set from each listing rather than dropping one as a duplicate")
assert(bothListings[2].fromEnsemble and bothListings[2].ensembles[1] == 70001,
    "an entry says it came from an ensemble and which one teaches it")
assert(#ExtraSets.BuildEntries({ soldAsEnsemble, soldAsEnsemble }, stubResolver(1)) == 1,
    "while the same set twice in one listing is still one row")

-- Built a slice at a time, which is how the transmogrifier page spreads the
-- work across frames rather than spending a fifth of a second in one of them.
-- The answer has to be the one a single call gives, duplicates included: a set
-- listed twice can have its second listing land in any slice.

do
    local sliced, sliceSeen = {}, {}
    for _, record in ipairs(records) do
        ExtraSets.BuildEntries({ record }, stubResolver(1), sliced, sliceSeen)
    end
    assert(#sliced == #entries, "slicing the records builds the same number of rows")
    for index, built in ipairs(entries) do
        assert(sliced[index].key == built.key, "and builds them in the same order")
    end

    local split, splitSeen = {}, {}
    ExtraSets.BuildEntries({ soldAsEnsemble }, stubResolver(1), split, splitSeen)
    ExtraSets.BuildEntries({ soldAsEnsemble }, stubResolver(1), split, splitSeen)
    assert(#split == 1,
        "a set whose second listing lands in another slice is still dropped as a duplicate")
end

assert(#ExtraSets.EnsembleNames(bothListings[2], function() return "Ensemble: Test Garb" end) == 1,
    "an ensemble is named the way the client names the item")
assert(#ExtraSets.EnsembleNames(bothListings[2], function() return nil end) == 0,
    "and one the client has not loaded yet is left out rather than named by its number")
assert(#ExtraSets.EnsembleNames(bothListings[1], error) == 0,
    "a set no ensemble teaches asks the client nothing")

-- Whether a character can wear a set is worked out for the one on screen, not
-- for every row: it costs the client a table for every piece it is asked about.

local function validity(unwearableSourceID)
    return function(sourceID)
        if not sourceStates[sourceID] then return nil end
        return sourceID ~= unwearableSourceID
    end
end

assert(ExtraSets.UnwearableReason(loadingSet, 1, validity()) == "class",
    "a set named for another class is out of reach over the name on it")
assert(ExtraSets.UnwearableReason(loadingSet, CLOTH_CLASS, validity()) == nil,
    "the class it is named for can wear it")
assert(ExtraSets.UnwearableReason(garb, 1, validity()) == nil, "an unrestricted set is wearable")
-- Class 1 wears plate and the set is cloth, so armour is what the client is
-- refusing over even though the set is named for nobody.
assert(ExtraSets.UnwearableReason(garb, 1, validity(2003)) == "armour",
    "a set in armour the character does not wear is out of reach over that")
assert(ExtraSets.UnwearableReason(garb, CLOTH_CLASS, validity(2003)) == "other",
    "a set in the character's own armour is refused for a reason only the client knows")
assert(ExtraSets.UnwearableReason(garb, 1, function() return nil end) == nil,
    "a set the client will not judge is left wearable rather than called otherwise")

-- Browsing another class's sets. The client only answers about the character
-- being played, so it is not asked, and what is left is the record itself.
assert(ExtraSets.UnwearableReason(garb, 1, nil) == nil,
    "with no source check to make, an unrestricted set says nothing")
assert(ExtraSets.UnwearableReason(garb, CLOTH_CLASS, nil) == nil,
    "a set the chosen class can wear says nothing either")
assert(ExtraSets.UnwearableReason(loadingSet, 1, nil) == "class",
    "the name on a set still answers for a class that is only being browsed")

-- What the details panel says once it has a reason.

local S = LuckysWardrobe.Strings.extraSets

assert(ExtraSets.UnwearableNotice(loadingSet, "class", 1)
    == "This set is not one your character can wear. It belongs to <CLASS5>Class 5.",
    "named the class the set was made for")
assert(ExtraSets.UnwearableNotice(garb, "armour", 1)
    == "This set is not one your character can wear. It is a cloth set, and your character wears plate.",
    "named the armour the set is and the armour the character wears")
assert(ExtraSets.UnwearableNotice(garb, "other", 1) == S.notUsable,
    "a refusal with nothing to explain says only that the set is out of reach")

-- Refusals the client explains itself. Its own word for why it said no beats
-- anything worked out from the record, and its sentence stands in where the
-- page has nothing of its own to say.

local function refusing(sourceID, refusal, message)
    return function(asked)
        if not sourceStates[asked] then return nil end
        if asked ~= sourceID then return true end
        return false, refusal, message
    end
end

local factionRefusal = refusing(2003, "faction", "Requires Alliance")
local reason, message = ExtraSets.UnwearableReason(garb, CLOTH_CLASS, factionRefusal)
assert(reason == "faction" and message == "Requires Alliance",
    "a lock the client names comes back named, with the words it used")
assert(ExtraSets.UnwearableReason(garb, 1, factionRefusal) == "faction",
    "the client naming the lock beats the armour the record was going to be blamed for")

local _, unnamedMessage = ExtraSets.UnwearableReason(garb, CLOTH_CLASS, refusing(2003, nil, "No good here"))
assert(unnamedMessage == "No good here", "a refusal the client will not name still carries its sentence")

assert(ExtraSets.UnwearableNotice(garb, "faction", CLOTH_CLASS, { faction = "Alliance" })
    == "This set is not one your character can wear. It belongs to the Alliance.",
    "named the faction the set belongs to")
assert(ExtraSets.UnwearableNotice(garb, "race", CLOTH_CLASS) == S.notUsableRace,
    "a race lock says so without naming a race the client never gave")
assert(ExtraSets.UnwearableNotice(garb, "other", CLOTH_CLASS, { message = "No good here" })
    == "This set is not one your character can wear. No good here",
    "a refusal the page cannot name is quoted in the client's own words")
-- A pandaren who has not picked a side is told no faction rather than the
-- wrong one, so the client's own sentence is what is left to show.
assert(ExtraSets.UnwearableNotice(garb, "faction", CLOTH_CLASS, { message = "Requires Alliance" })
    == "This set is not one your character can wear. Requires Alliance",
    "a faction lock with no faction to name falls back to what the client said")
assert(ExtraSets.UnwearableNotice(garb, "faction", CLOTH_CLASS) == S.notUsable,
    "with nothing to say beyond the lock, the set is only called out of reach")

local unknownClassEntry = ExtraSets.BuildEntry(validRecord({ classMask = 2 ^ (20 - 1) }), stubResolver(1))
assert(ExtraSets.UnwearableNotice(unknownClassEntry, "class", 1) == S.notUsable,
    "a set named for a class this client has never heard of names nobody")
local unarmouredEntry = ExtraSets.BuildEntry(validRecord({ armorType = 0 }), stubResolver(1))
assert(ExtraSets.UnwearableNotice(unarmouredEntry, "armour", 1) == S.notUsable,
    "a set in no armour type at all names no armour")

-- The dev dump: one row per piece, carrying the client's answers rather than a
-- verdict drawn from them.

local function detailResolver(unwearableSourceID)
    return {
        sourceValidity = validity(unwearableSourceID),
        sourceDetail = function(sourceID)
            if not sourceStates[sourceID] then return nil end
            local refused = sourceID == unwearableSourceID
            return {
                itemID = sourceID + 90000,
                itemLoaded = true,
                wardrobe = not refused,
                valid = not refused,
                useError = refused and "You cannot use this appearance" or nil,
            }
        end,
    }
end

local diagnosis, diagnosedReason = ExtraSets.PieceDiagnosis(garb, CLOTH_CLASS, detailResolver(2003), true)
assert(#diagnosis == 3, "one row per piece of the set")
assert(diagnosedReason == "other", "reported the same reason the details panel shows")
assert(diagnosis[1].slot == "HEAD" and diagnosis[1].state == "collected", "rows carry the piece as the page has it")
assert(diagnosis[1].valid == true and diagnosis[1].useError == nil, "a piece the client accepts says so")
assert(diagnosis[2].valid == false and diagnosis[2].useError ~= nil,
    "the one refused piece is named, with the client's own words for it")
assert(diagnosis[2].itemID == 92003, "a record carrying no item ID falls back to the one the source reports")

-- A piece the client will not answer for at all has to read differently from
-- one it refuses, or the dump cannot tell a cold cache from a real refusal.
local unanswered = ExtraSets.PieceDiagnosis(loadingSet, CLOTH_CLASS, detailResolver(), true)
assert(unanswered[3].valid == nil and unanswered[3].itemLoaded == false,
    "a source this client has no data for is unanswered, not refused")
assert(unanswered[3].itemID == nil, "an unresolvable piece reports no item")

local ghost = entries[3]
assert(ghost.total == 0 and ghost.unavailable == 3, "a set with no valid sources stays visible")

-- Pieces the catalogue never turned into a source are still part of the set.
local partlyBundled = validRecord({ setID = 22, unresolvedPieces = 2 })
local partlyBundledEntry = ExtraSets.BuildEntries({ partlyBundled }, stubResolver(1))[1]
assert(partlyBundledEntry.unavailable == 2, "pieces this client has no appearance for are counted, not dropped")
assert(partlyBundledEntry.total == 2, "unresolved pieces stay out of the collectable total")

-- Duplicate looks and colourways. The bundled snapshot lists one appearance
-- twice, once "(... Recolor)" and once "(... Lookalike)", and sometimes lists a
-- Lookalike that is its Recolor without a piece. Neither is a second set to
-- collect, while the difficulty tints of one set genuinely are several looks.

sourceStates[5101] = { appearanceID = 9501, collected = true }
sourceStates[5102] = { appearanceID = 9502, collected = true }
sourceStates[5103] = { appearanceID = 9503, collected = true }
sourceStates[5104] = { appearanceID = 9504, collected = true }
sourceStates[5201] = { appearanceID = 9601, collected = true }
sourceStates[5202] = { appearanceID = 9602, collected = false }
sourceStates[5203] = { appearanceID = 9603, collected = false }

local function colourway(setID, name, sourceIDs)
    local slots = { "HEAD", "CHEST", "LEGS", "HANDS" }
    local list = {}
    for index, sourceID in ipairs(sourceIDs) do
        list[index] = { slot = slots[index], sourceID = sourceID }
    end
    return { setID = setID, name = name, armorType = CLOTH, classMask = 0, pieces = list }
end

local colourwayRecords = {
    colourway(601, "Charm Vestments (Heroic Recolor)", { 5101, 5102, 5103 }),
    colourway(602, "Charm Vestments (Heroic Lookalike)", { 5101, 5102, 5103 }),
    colourway(603, "Charm Vestments (Normal Recolor)", { 5201, 5202, 5203 }),
    colourway(604, "Charm Vestments (Normal Lookalike)", { 5201, 5202 }),
    -- The same looks as the Heroic colourway less one, under a name of its own.
    colourway(605, "Other Garb (Heroic Recolor)", { 5101, 5102 }),
    -- The Normal colourway exactly, under a name of its own.
    colourway(606, "Distinct Regalia (Alliance Recolor)", { 5201, 5202, 5203 }),
}

local colourwayEntries = ExtraSets.BuildEntries(colourwayRecords, stubResolver(CLOTH_CLASS))
assert(#colourwayEntries == 6, "every listing starts as its own entry")

assert(ExtraSets.AppearanceKey({ [9502] = true, [9501] = false }) == "9501,9502",
    "a set's looks make one key, in a fixed order whatever order they resolved in")
assert(ExtraSets.AppearanceKey({ [9501] = true }, true) == nil, "a set still loading has no key to fold on")
assert(ExtraSets.AppearanceKey({}) == nil, "a set with nothing resolved has no key")
assert(colourwayEntries[1].appearanceKey == colourwayEntries[2].appearanceKey, "two names for one look share a key")
assert(colourwayEntries[1].appearanceKey ~= colourwayEntries[3].appearanceKey, "two tints of one set do not")

assert(ExtraSets.BaseName("Charm Vestments (Heroic Recolor)") == "Charm Vestments", "dropped the colourway")
assert(ExtraSets.BaseName("Live Name") == "Live Name", "a name with no parenthetical is its own base name")
assert(ExtraSets.BaseName("(Recolor)") == "(Recolor)", "a name that is nothing but a parenthetical keeps it")
assert(ExtraSets.BaseName("Barkbloom Warleathers: Emerald Bounties") == "Barkbloom Warleathers",
    "a colon clause is a colourway qualifier too")
assert(ExtraSets.BaseName("Barkbloom Warleathers Set: World Drops") == "Barkbloom Warleathers",
    "the trailing Set only some colon spellings carry comes off with the clause")
assert(ExtraSets.BaseName("Primal Storms Leather Set") == "Primal Storms Leather Set",
    "a name without a colon clause keeps its Set")
assert(ExtraSets.BaseName(": World Drops") == ": World Drops", "a name that is nothing but a colon clause keeps it")
assert(ExtraSets.VariantLabel("Charm Vestments (Heroic Recolor)") == "Heroic Recolor", "kept what tells it apart")
assert(ExtraSets.VariantLabel("Barkbloom Warleathers Set: World Drops") == "World Drops",
    "a colon colourway is told apart by its clause")
assert(ExtraSets.VariantLabel("Live Name") == "Live Name", "with nothing to strip, the name stands as the label")

local collapsed = ExtraSets.CollapseDuplicates(colourwayEntries)
assert(#collapsed == 3, "six listings of three looks became three rows")
assert(collapsed[1].setID == 601 and collapsed[2].setID == 603 and collapsed[3].setID == 605,
    "the first listing of a look is the one that survives")
assert(#collapsed[1].alternateNames == 1
    and collapsed[1].alternateNames[1] == "Charm Vestments (Heroic Lookalike)",
    "the identical listing folded in and left its name behind")
assert(#collapsed[2].alternateNames == 2
    and collapsed[2].alternateNames[1] == "Charm Vestments (Normal Lookalike)"
    and collapsed[2].alternateNames[2] == "Distinct Regalia (Alliance Recolor)",
    "an identical look folds whatever it is called, a contained one only under the same name")
assert(collapsed[3].alternateNames == nil,
    "a look contained only in a differently-named set keeps its own row")
assert(#ExtraSets.FilterEntries(collapsed, "Lookalike") == 2, "folded names are still searchable")
assert(#ExtraSets.FilterEntries(collapsed, "Distinct Regalia") == 1,
    "a set folded under another name is found by the name it lost")

-- An ensemble teaching a look an armour list already carries folds into that
-- row like any other duplicate, and takes the one thing it knows with it.

local ensembleRecord = colourway(602, "Charm Vestments", { 5101, 5102, 5103 })
ensembleRecord.ensembles = { 70001 }
local withEnsemble = ExtraSets.CollapseDuplicates(ExtraSets.BuildEntries(
    { colourwayRecords[1], ensembleRecord }, stubResolver(CLOTH_CLASS)))
assert(#withEnsemble == 1 and withEnsemble[1].setID == 601,
    "the armour list keeps the row, since it was listed first")
assert(withEnsemble[1].ensembles[1] == 70001,
    "and learns where the look can be bought from the row it folded away")
assert(not withEnsemble[1].fromEnsemble,
    "without becoming a row that came from the ensemble list, which its number is not read against")
assert(colourwayRecords[1].ensembles == nil,
    "the catalogue record the row was built from is left as it was")
assert(#ExtraSets.FilterEntries(withEnsemble, "ensemble") == 1,
    "a set there is an ensemble for answers to the word, so searching it lists what can be bought")
assert(#ExtraSets.FilterEntries(collapsed, "ensemble") == 0, "and a set there is not does not")

-- A set with a piece still loading cannot be told apart from a shorter set, so
-- it waits for the rebuild that follows rather than folding into the wrong row.
local pendingRecords = {
    colourway(611, "Pending Robes (Recolor)", { 5101, 5102 }),
    colourway(612, "Pending Robes (Lookalike)", { 5101, 5102, 3002 }),
}
local pendingRows = ExtraSets.CollapseDuplicates(
    ExtraSets.BuildEntries(pendingRecords, stubResolver(CLOTH_CLASS)))
assert(#pendingRows == 2, "a set still loading is never folded away on what has resolved so far")

-- The Sets tab's own looks fold by the same rules. Wowhead lists "(... Recolor)"
-- sets for the off-set items that wear a tier's appearances, and those are the
-- very looks the tab already shows under the tier's difficulty dropdown, so a
-- listing wearing them belongs to the tab, not to this page.

local tierLooks = {
    { name = "Charm Vestments", armorType = CLOTH, appearances = { [9501] = true, [9502] = true, [9503] = true } },
}

local nativeRows, nativeFolds = ExtraSets.CollapseDuplicates(
    ExtraSets.BuildEntries(colourwayRecords, stubResolver(CLOTH_CLASS)), tierLooks)
assert(#nativeRows == 2 and nativeRows[1].setID == 603 and nativeRows[2].setID == 605,
    "the colourway the tab shows is gone; the ones it does not show remain")
assert(#nativeFolds == 2 and nativeFolds[1].setID == 601 and nativeFolds[2].setID == 602,
    "every listing of the tab's look folded away, identical twins included")
assert(nativeFolds[1].name == "Charm Vestments (Heroic Recolor)"
    and nativeFolds[1].nativeName == "Charm Vestments",
    "each fold says which listing went and which of the tab's sets holds its look")
assert(#nativeRows[1].alternateNames == 2, "the page's own folds are undisturbed beside the tab's")
assert(nativeRows[1].alternateNames[1] == "Charm Vestments (Normal Lookalike)", "and keep their names")

-- Under the tab's own set name the bar is most of the looks, not all of them:
-- the old five-piece tiers get their empty slots padded with off-set
-- accessories, each side picks its own, and three stray accessories should
-- not keep a tier's worth of looks listed twice. A set sharing nothing with
-- the tab's set, a true recolour, stays whatever it is called, and any
-- overlap under another name proves nothing at all.
local nearMissRecords = {
    colourway(621, "Charm Vestments (Dungeon Recolor)", { 5101, 5102 }),
    colourway(622, "Unrelated Garb (Recolor)", { 5101, 5103 }),
    colourway(623, "Charm Vestments (Grand Recolor)", { 5101, 5102, 5103, 5104 }),
    colourway(624, "Charm Vestments (Azure Recolor)", { 5201, 5202, 5203 }),
    colourway(625, "Charm Vestments (Padded Recolor)", { 5101, 5102, 5203 }),
}
local nearMissRows, nearMissFolds = ExtraSets.CollapseDuplicates(
    ExtraSets.BuildEntries(nearMissRecords, stubResolver(CLOTH_CLASS)), tierLooks)
assert(#nearMissFolds == 3, "every listing mostly made of the tab's looks folded away")
assert(nearMissFolds[1].setID == 621, "a listing the tab's set wholly contains folds")
assert(nearMissFolds[2].setID == 623, "so does one carrying a look the tab lacks beside mostly its looks")
assert(nearMissFolds[3].setID == 625, "and one the same size as the tab's set with an odd accessory")
assert(#nearMissRows == 2 and nearMissRows[1].setID == 622 and nearMissRows[2].setID == 624,
    "overlap under another name proves nothing, and a true recolour keeps its row")
assert(nearMissRows[1].alternateNames == nil and nearMissRows[2].alternateNames == nil,
    "the tab's set claimed its listings before any larger row here could absorb them")

-- A chain is folded away whole: the twin of a listing the tab's set contains
-- goes with it, leaving nothing behind.
local chainedRecords = {
    colourway(631, "Charm Vestments (Old Recolor)", { 5101, 5102 }),
    colourway(632, "Charm Vestments (Old Lookalike)", { 5101, 5102 }),
}
local chainedRows, chainedFolds = ExtraSets.CollapseDuplicates(
    ExtraSets.BuildEntries(chainedRecords, stubResolver(CLOTH_CLASS)), tierLooks)
assert(#chainedRows == 0 and #chainedFolds == 2, "both ends of the chain folded to the tab")
assert(chainedFolds[2].nativeName == "Charm Vestments", "the twin answers for the tab's set too")

-- A set still loading cannot be told apart from a shorter one, so the tab's
-- looks never claim it early either.
local slowRecords = { colourway(641, "Charm Vestments (Slow Recolor)", { 5101, 5102, 3002 }) }
local slowRows, slowFolds = ExtraSets.CollapseDuplicates(
    ExtraSets.BuildEntries(slowRecords, stubResolver(CLOTH_CLASS)), tierLooks)
assert(#slowRows == 1 and #slowFolds == 0, "a loading set waits rather than folding to the tab")

local rows = ExtraSets.BuildRows(collapsed)
assert(#rows == 2, "the colourways of one set became one row, and the other set kept its own")

local group = rows[1]
assert(group.isGroup and group.name == "Charm Vestments", "the row is named for the set, not a colourway")
assert(#group.variants == 2, "and holds every colourway of it")
assert(group.label == "2 colours", "saying how many there are without opening it")
assert(group.pieces == collapsed[1].pieces, "the row carries the first colourway's pieces")
assert(rows[2].setID == 605 and not rows[2].isGroup,
    "a set with a single look stays the plain row it was")

-- The row counts every look across its colourways, so it says how much of the
-- whole set is collected rather than of one tint.
assert(group.total == 6 and group.collected == 4, "counted the looks of both colourways, each once")
assert(group.missing == 2, "and derived what is left")
assert(not ExtraSets.IsComplete(group), "a set with a colourway still missing is not complete")

-- Which colourway the details pane is showing. Nothing chosen means the first,
-- and a choice that has been filtered out from under the row means it again.
assert(ExtraSets.VariantOf(group, nil).setID == 601, "a set opens on its first colourway")
assert(ExtraSets.VariantOf(group, 603).setID == 603, "and shows the one that was picked")
assert(ExtraSets.VariantOf(group, 999).setID == 601, "falling back when that one is no longer there")
assert(ExtraSets.VariantOf(rows[2], nil) == rows[2], "a plain row is its own colourway")

-- A row standing for several colourways answers for every ensemble behind them,
-- since the row is the only place any of those looks is shown.
local boughtVariants = {
    ExtraSets.BuildEntries({ colourway(661, "Bought Robes (Recolor)", { 5101 }) }, stubResolver(CLOTH_CLASS))[1],
    ExtraSets.BuildEntries({ colourway(662, "Bought Robes (Heroic)", { 5102 }) }, stubResolver(CLOTH_CLASS))[1],
}
boughtVariants[1].ensembles = { 70001 }
boughtVariants[2].ensembles = { 70002, 70001 }
local boughtGroup = ExtraSets.BuildGroup(boughtVariants)
assert(#boughtGroup.ensembles == 2 and boughtGroup.ensembles[1] == 70001 and boughtGroup.ensembles[2] == 70002,
    "gathered the ensembles across the colourways, each named once")

-- The strip shows one piece per look in a slot: an ensemble teaching several
-- items that carry one appearance folds them behind the first, whose tooltip
-- names the rest. The fold never crosses slots, so the preview-slot toggles
-- keep a piece for every slot they govern, and a piece with no look yet
-- stands alone rather than folding wrongly.

do
    local sharedLook = ExtraSets.BuildEntries({ validRecord({
        pieces = pieces({ "HEAD", 2001 }, { "CHEST", 2003 }, { "CHEST", 2004 }),
    }) }, stubResolver(1))[1]
    local distinctPieces = ExtraSets.DistinctLookPieces(sharedLook.pieces)
    assert(#sharedLook.pieces == 3 and #distinctPieces == 2, "sources sharing a slot's look are one icon")
    assert(distinctPieces[1].sourceID == 2001 and distinctPieces[2].sourceID == 2003,
        "the first source of a look stands for it")

    local crossSlot = ExtraSets.BuildEntries({ validRecord() }, stubResolver(1))[1]
    assert(#ExtraSets.DistinctLookPieces(crossSlot.pieces) == 3,
        "a look shared across slots keeps a piece in each slot")

    local unresolvedPieces = ExtraSets.BuildEntries({ {
        setID = 501,
        name = "Cold Set",
        armorType = CLOTH,
        classMask = 0,
        pieces = pieces({ "HEAD", 3001 }, { "CHEST", 3002 }, { "LEGS", 3999 }),
    } }, stubResolver(1))[1]
    assert(#ExtraSets.DistinctLookPieces(unresolvedPieces.pieces) == 3,
        "loading and unavailable pieces have no look to fold on and stand alone")
end

-- Where the piece icons go. A tier's nine pieces are one strip; the dozens an
-- ensemble can teach wrap, and the ones past what the pane holds are counted.

local oneStrip, noneLeft = ExtraSets.PieceLayout(3)
assert(#oneStrip == 3 and noneLeft == 0, "a small set is placed whole")
assert(oneStrip[1].row == 1 and oneStrip[2].row == 1, "in a single strip")
assert(oneStrip[1].y == oneStrip[3].y, "sitting at one height")
assert(oneStrip[1].x < oneStrip[2].x and oneStrip[2].x < oneStrip[3].x, "filled left to right")
assert(oneStrip[1].x == -oneStrip[3].x, "centred on the pane")

local wrapped = ExtraSets.PieceLayout(12)
assert(#wrapped == 12 and wrapped[10].row == 1 and wrapped[11].row == 2, "a wider set wraps onto a second strip")
assert(wrapped[11].y < wrapped[10].y, "which sits below the first")
assert(wrapped[11].x > wrapped[1].x and wrapped[11].x < 0 and wrapped[12].x > 0,
    "and is centred on the two it holds rather than spread across a full strip")

local capped, leftOff = ExtraSets.PieceLayout(126)
assert(#capped == 40 and leftOff == 86,
    "a set with more pieces than the pane holds shows what fits and counts the rest")

-- Filters can leave a set with one colourway, and it goes back to a plain row.
local lastStanding = ExtraSets.BuildRows({ collapsed[1], collapsed[3] })
assert(#lastStanding == 2 and not lastStanding[1].isGroup,
    "the last colourway left is a plain row again")

-- The Emerald Dream world sets spell their colourways with colon clauses, one
-- of the four without the "Set", and every spelling has to land in one row.
local barkbloomRecords = {
    colourway(651, "Barkbloom Warleathers: Emerald Bounties", { 5101 }),
    colourway(652, "Barkbloom Warleathers Set: World Drops", { 5102 }),
    colourway(653, "Barkbloom Warleathers Set: Quest Rewards", { 5103 }),
    colourway(654, "Barkbloom Warleathers Set: Superbloom Weekly Rewards", { 5104 }),
}
local barkbloomRows = ExtraSets.BuildRows(ExtraSets.CollapseDuplicates(
    ExtraSets.BuildEntries(barkbloomRecords, stubResolver(CLOTH_CLASS))))
assert(#barkbloomRows == 1, "the four colon colourways became one row")
assert(barkbloomRows[1].isGroup and barkbloomRows[1].name == "Barkbloom Warleathers",
    "named for the set, whichever spelling a colourway used")
assert(#barkbloomRows[1].variants == 4, "holding every colourway")

-- Colourway families read off the names. The Trading Post sells one garment in
-- eighteen colours as eighteen sets, and the client says nothing about their
-- being related, so the only place it is written down is the names.

for id = 7001, 7052 do sourceStates[id] = { appearanceID = 8000 + id, collected = false } end

do
local colourRows
-- The rule reads the ensemble listing only, so every fixture below arrives with
-- an ensemble behind it the way a real Trading Post set does.
local function rowsOf(family)
    for at, record in ipairs(family) do record.ensembles = { 79000 + at } end
    return ExtraSets.BuildRows(ExtraSets.BuildEntries(family, stubResolver(CLOTH_CLASS)))
end

colourRows = rowsOf({
    colourway(701, "Midnight Sweatsuit", { 7001, 7002 }),
    colourway(702, "Azure Sweatsuit", { 7003, 7004 }),
    colourway(703, "Sepia Sweatsuit", { 7005, 7006 }),
})
assert(#colourRows == 1 and colourRows[1].isGroup and colourRows[1].isColourFamily,
    "three names differing in one word became one row")
assert(colourRows[1].name == "Sweatsuit", "named for the words the colourways share")
assert(colourRows[1].label == "3 colours", "saying how many there are without opening it")
assert(ExtraSets.VariantLabelFor(colourRows[1].variants[1]) == "Midnight"
    and ExtraSets.VariantLabelFor(colourRows[1].variants[3]) == "Sepia",
    "and each colourway offered under the word that tells it from the rest")
assert(colourRows[1].total == 6, "the row counts every look across the colours")

-- The word that varies is not always the first: the Trading Post's own sets put
-- it in the middle as often as at the front.
colourRows = rowsOf({
    colourway(711, "Vagabond's Brick Threads", { 7007, 7008 }),
    colourway(712, "Vagabond's Camo Threads", { 7009, 7010 }),
})
assert(#colourRows == 1 and colourRows[1].name == "Vagabond's Threads",
    "a word differing in the middle groups as readily as one at the front")
assert(ExtraSets.VariantLabelFor(colourRows[1].variants[2]) == "Camo", "and is what the picker offers")

-- What the rule refuses. A tier or a PvP season also differs by a word, and
-- those are sets people work through separately even where they share a model.
colourRows = rowsOf({
    validRecord({ setID = 721, name = "Gladiator's Leather Armor", pieces = pieces(
        { "HEAD", 7011 }, { "CHEST", 7012 }, { "LEGS", 7013 }, { "HANDS", 7014 }, { "FEET", 7015 }) }),
    validRecord({ setID = 722, name = "Gladiator's Plate Armor", pieces = pieces(
        { "HEAD", 7016 }, { "CHEST", 7017 }, { "LEGS", 7018 }, { "HANDS", 7019 }, { "FEET", 7020 }) }),
})
assert(#colourRows == 2, "a set with more pieces than the ceiling is never read as a colour of another")

colourRows = rowsOf({
    validRecord({ setID = 731, name = "Gladiator's Leather Armor", classMask = 8,
        pieces = pieces({ "HEAD", 7021 }, { "CHEST", 7022 }) }),
    validRecord({ setID = 732, name = "Gladiator's Silk Armor", classMask = 128,
        pieces = pieces({ "HEAD", 7023 }, { "CHEST", 7024 }) }),
})
assert(#colourRows == 2, "the armour types of one set are not colours of each other, and their masks say so")

colourRows = rowsOf({
    validRecord({ setID = 741, name = "Short Robe", pieces = pieces({ "HEAD", 7025 }) }),
    validRecord({ setID = 742, name = "Long Robe", pieces = pieces({ "HEAD", 7026 }, { "CHEST", 7027 }) }),
})
assert(#colourRows == 2, "nor are two sets of different sizes")

-- The armour lists say this relationship themselves, with "(Recolor)" after a
-- shared set name, and the grouping above already reads it. Turned loose on
-- them the rule would join two different sets over a word they share.
colourRows = ExtraSets.BuildRows(ExtraSets.BuildEntries({
    validRecord({ setID = 771, name = "Mystic's Regalia (Recolor)",
        pieces = pieces({ "HEAD", 7041 }, { "CHEST", 7042 }) }),
    validRecord({ setID = 772, name = "Pagan Regalia (Recolor)",
        pieces = pieces({ "HEAD", 7043 }, { "CHEST", 7044 }) }),
}, stubResolver(CLOTH_CLASS)))
assert(#colourRows == 2, "and a set from the armour lists is never read as a colour of another at all")

-- A set can fit several possible families, so it joins the largest. The one
-- left holding a single member is no family at all and stays a plain row.
colourRows = rowsOf({
    validRecord({ setID = 751, name = "Red Silk Robe", pieces = pieces({ "HEAD", 7028 }, { "CHEST", 7029 }) }),
    validRecord({ setID = 752, name = "Blue Silk Robe", pieces = pieces({ "HEAD", 7030 }, { "CHEST", 7031 }) }),
    validRecord({ setID = 753, name = "Green Silk Robe", pieces = pieces({ "HEAD", 7032 }, { "CHEST", 7033 }) }),
    validRecord({ setID = 754, name = "Red Wool Robe", pieces = pieces({ "HEAD", 7034 }, { "CHEST", 7035 }) }),
})
assert(#colourRows == 2, "the three silk robes became one row and the wool one kept its own")
assert(colourRows[1].isColourFamily and colourRows[1].name == "Silk Robe" and #colourRows[1].variants == 3,
    "the larger family is the one every set that could join both went to")
assert(not colourRows[2].isGroup and colourRows[2].name == "Red Wool Robe",
    "and the set left holding a family of one is a plain row again")

-- The row stands where its first colourway stood, so whatever sort produced the
-- list still decides where the family lands.
colourRows = rowsOf({
    validRecord({ setID = 761, name = "Standalone Cowl", pieces = pieces({ "HEAD", 7036 }) }),
    validRecord({ setID = 762, name = "Amber Wrap", pieces = pieces({ "HEAD", 7037 }, { "CHEST", 7038 }) }),
    validRecord({ setID = 763, name = "Jade Wrap", pieces = pieces({ "HEAD", 7039 }, { "CHEST", 7040 }) }),
})
assert(#colourRows == 2 and colourRows[1].name == "Standalone Cowl" and colourRows[2].name == "Wrap",
    "the family took the place of the first of its colourways")

-- The client gives two sets of one family the same name. Those gather by that
-- shared name first, and the row they make still belongs beside its colours
-- rather than being stranded next to them as a family of its own.
colourRows = rowsOf({
    validRecord({ setID = 781, name = "Vagabond's Brick Threads",
        pieces = pieces({ "HEAD", 7045 }, { "CHEST", 7046 }) }),
    validRecord({ setID = 782, name = "Vagabond's Camo Threads",
        pieces = pieces({ "HEAD", 7047 }, { "CHEST", 7048 }) }),
    validRecord({ setID = 783, name = "Vagabond's Snowy Threads",
        pieces = pieces({ "HEAD", 7049 }, { "CHEST", 7050 }) }),
    validRecord({ setID = 784, name = "Vagabond's Snowy Threads",
        pieces = pieces({ "HEAD", 7051 }, { "CHEST", 7052 }) }),
})
assert(#colourRows == 1 and colourRows[1].name == "Vagabond's Threads",
    "the two sets sharing a name came in with the rest rather than standing apart")
assert(#colourRows[1].variants == 4, "and came in one by one, since each is a colourway of its own")

-- Which leaves two colourways under one word, so the picker names the ensemble
-- each is bought from instead. The client answers for one of them and not the
-- other, and the one it will not answer for keeps the word rather than blanking.
local function itemNamed(itemID)
    return itemID == 79003 and "Ensemble: Vagabond's Snowy Threads" or nil
end
assert(ExtraSets.VariantLabelFor(colourRows[1].variants[1], itemNamed) == "Brick",
    "a colourway nothing else is called keeps its word whatever the client says")
assert(ExtraSets.VariantLabelFor(colourRows[1].variants[3], itemNamed)
    == "Ensemble: Vagabond's Snowy Threads",
    "a word two colourways share gives way to the ensemble that tells them apart")
assert(ExtraSets.VariantLabelFor(colourRows[1].variants[4], itemNamed) == "Snowy",
    "and one the client has not loaded the ensemble for waits, rather than showing nothing")
assert(ExtraSets.VariantLabelFor(colourRows[1].variants[3]) == "Snowy",
    "with no way to ask the client at all, the shared word is still what there is")
end

-- Model families, from the bundled index. A season ships one set of armour under
-- half a dozen unrelated names, and no name rule can see that; the client's own
-- display records can, and the index carries what they say.

do
for id = 7100, 7160 do sourceStates[id] = { appearanceID = 8100 + id, collected = false } end

local function modelled(setID, name, model, sourceIDs, overrides)
    local record = validRecord({ setID = setID, name = name, model = model,
        pieces = pieces({ "HEAD", sourceIDs[1] }, { "CHEST", sourceIDs[2] }, { "LEGS", sourceIDs[3] }) })
    for key, value in pairs(overrides or {}) do record[key] = value end
    return record
end

local function rowsOf(family)
    return ExtraSets.BuildRows(ExtraSets.BuildEntries(family, stubResolver(CLOTH_CLASS)))
end

local modelRows = rowsOf({
    modelled(801, "Nitroclad Kit", 176, { 7100, 7101, 7102 }),
    modelled(802, "Smoketrail Racer Suit", 176, { 7103, 7104, 7105 }),
    modelled(803, "Upcycled Outfit", 176, { 7106, 7107, 7108 }),
})
assert(#modelRows == 1 and modelRows[1].isGroup, "three sets built on one model became one row")
assert(modelRows[1].name == "Nitroclad Kit", "named for the first of them, having no name in common")
assert(modelRows[1].label == "3 colours", "and counted as the colours of one garment")
assert(modelRows[1].total == 9, "the row counts every look across them")
assert(ExtraSets.VariantLabelFor(modelRows[1].variants[2]) == "Smoketrail Racer Suit",
    "the picker names each in full, there being no qualifier to tell them apart by")

-- The rule is a fact about the armour rather than a reading of the names, so
-- nothing the name rules refuse applies: these are far past the piece ceiling
-- the colourway rule holds itself to, and come from the armour lists.
local bigRows = rowsOf({
    modelled(811, "Gladiator's Leather Armor", 200, { 7109, 7110, 7111 }),
    modelled(812, "Prized Aspirant's Leather Armor", 200, { 7112, 7113, 7114 }),
})
assert(#bigRows == 1, "a set from the armour lists groups on its model as readily as an ensemble does")

-- Nothing shares a model with these, so the index says nothing about them.
local aloneRows = rowsOf({
    modelled(821, "Lone Garb", 301, { 7115, 7116, 7117 }),
    modelled(822, "Other Garb", 302, { 7118, 7119, 7120 }),
    modelled(823, "Unindexed Garb", nil, { 7121, 7122, 7123 }),
})
assert(#aloneRows == 3, "a model no other set is built on leaves the row standing alone")

-- The names gather first, and hand the model rule a row rather than its members.
local nestedRows = rowsOf({
    modelled(831, "Charm Vestments (Heroic Recolor)", 400, { 7124, 7125, 7126 }),
    modelled(832, "Charm Vestments (Normal Recolor)", 400, { 7127, 7128, 7129 }),
    modelled(833, "Wholly Other Name", 400, { 7130, 7131, 7132 }),
})
assert(#nestedRows == 1 and #nestedRows[1].variants == 3,
    "the pair that shared a name came in as colourways beside the set that did not")

-- A shared name can gather two models together. The row that makes answers for
-- no model at all, or it would drag the odd set into a family it is not part of.
local mixedRows = rowsOf({
    modelled(841, "Twinned Regalia", 500, { 7133, 7134, 7135 }),
    modelled(842, "Twinned Regalia", 501, { 7136, 7137, 7138 }),
    modelled(843, "Elsewhere Robes", 500, { 7139, 7140, 7141 }),
})
assert(#mixedRows == 2, "the row holding two models stayed out of both their families")
assert(mixedRows[1].name == "Twinned Regalia" and #mixedRows[1].variants == 2,
    "keeping the colourways its name gathered")
assert(mixedRows[2].name == "Elsewhere Robes" and not mixedRows[2].isGroup,
    "and the set whose model it shares is a plain row rather than folded into it")

-- Two families can end up named alike: a colourway family is named for the words
-- its members share, and another set can simply be called that. Nothing here
-- reads names, so nothing else keeps the two rows apart, and a repeated key
-- would have each showing the other's colourway.
local twinRows = rowsOf({
    validRecord({ setID = 851, name = "Red Silk Robe", model = 600, ensembles = { 79101 },
        pieces = pieces({ "HEAD", 7142 }, { "CHEST", 7143 }) }),
    validRecord({ setID = 852, name = "Blue Silk Robe", model = 600, ensembles = { 79102 },
        pieces = pieces({ "HEAD", 7144 }, { "CHEST", 7145 }) }),
    modelled(853, "Distinct Name", 600, { 7146, 7147, 7148 }),
    modelled(854, "Silk Robe", 601, { 7149, 7150, 7151 }),
    modelled(855, "Other Thing", 601, { 7152, 7153, 7154 }),
})
assert(#twinRows == 2, "the two colourways and the set beside them formed one family, the other pair another")
assert(twinRows[1].name == "Silk Robe" and twinRows[2].name == "Silk Robe",
    "and both are named Silk Robe, one for the words its colourways share and one for its first set")
assert(twinRows[1].key ~= twinRows[2].key,
    "so the rows are told apart by model rather than by the name they landed on")
end

-- Search.

assert(#ExtraSets.FilterEntries(entries, "") == 3, "blank query keeps everything")
assert(#ExtraSets.FilterEntries(entries, "  live  ") == 1, "matched trimmed case-insensitive names")
assert(#ExtraSets.FilterEntries(entries, "FIXTURE") == 1, "matched labels")
assert(#ExtraSets.FilterEntries(entries, "nothing") == 0, "unmatched query empties the list")

-- An expansion or a kind of set typed into the box narrows to it, as either does
-- on both Sets tabs. 4 is the snapshot's own PvP source bit, and a set is tier
-- when the snapshot names it by a raid difficulty.
do
    local dated = {
        { name = "Fixture Nerubian Weave", expansionID = 10, sourceMask = 2, label = "Mythic" },
        { name = "Fixture Delving Weave", expansionID = 10, sourceMask = 2 },
        { name = "Fixture Gladiator's Weave", expansionID = 10, sourceMask = 4, label = "Elite" },
        { name = "Fixture Draconic Weave", expansionID = 9, sourceMask = 4 },
        { name = "Fixture Undated Weave" },
    }
    local function named(query)
        local matched = {}
        for index, entry in ipairs(ExtraSets.FilterEntries(dated, query)) do matched[index] = entry.name end
        return table.concat(matched, ", ")
    end

    assert(#ExtraSets.FilterEntries(dated, "weave") == 5, "a word out of the names is still a name search")
    assert(named("TWW") == "Fixture Nerubian Weave, Fixture Delving Weave, Fixture Gladiator's Weave",
        "an expansion narrows to the sets from it, leaving out the ones nothing dated")
    assert(named("pvp") == "Fixture Gladiator's Weave, Fixture Draconic Weave",
        "a kind narrows to the sets that carry it, whatever expansion they came from")
    assert(named("tww pvp") == "Fixture Gladiator's Weave", "and the two together take both")
    assert(named("tww pve") == "Fixture Nerubian Weave, Fixture Delving Weave",
        "the other side of the same expansion, raid tier among it")
    assert(named("tww raid") == "Fixture Nerubian Weave",
        "raid takes the set the snapshot names by a raid difficulty")
    assert(named("raid") == "Fixture Nerubian Weave",
        "and Elite is a PvP rank rather than a difficulty, so it is not tier")
end

-- Sorting.

local sorted = ExtraSets.SortEntries(entries, "completion", "ascending")
assert(sorted[1].key == 20, "closest-to-complete leads")
assert(sorted[2].key == 500, "more missing pieces follow")
assert(sorted[3].key == 21, "sets with nothing resolvable sort last")
assert(ExtraSets.SortEntries(entries, "default", "ascending") == entries, "default order is untouched")
assert(entries[1].key == 20, "sorting never mutates the source list")

local defaultDescending = ExtraSets.SortEntries(entries, "default", "descending")
assert(defaultDescending[1].key == entries[3].key and defaultDescending[3].key == entries[1].key,
    "descending reverses the default order")
local completionDescending = ExtraSets.SortEntries(entries, "completion", "descending")
assert(completionDescending[1].key == 21 and completionDescending[3].key == 20,
    "descending reverses the completion order")

-- Thousands of sets make alphabetical order worth having, so it is its own mode.
local byName = ExtraSets.SortEntries(entries, "name", "ascending")
assert(byName[1].name == "Live Name" and byName[2].name == "Loading Set",
    "name order is alphabetical, whatever the catalogue order was")
assert(ExtraSets.SortEntries(entries, "name", "descending")[1].name == "Test Garb",
    "descending inverts the name order")

-- Big sets and small ones are worth telling apart, so piece count is its own
-- mode, sized by the same total the row displays.
local mixedSizes = ExtraSets.SortEntries({ colourwayEntries[1], entries[1] }, "pieces", "ascending")
assert(mixedSizes[1].total == 2 and mixedSizes[2].total == 3, "fewer pieces sort ahead of more")
local bySize = ExtraSets.SortEntries(entries, "pieces", "ascending")
assert(bySize[1].key == 21, "a set with nothing resolvable shows no pieces and leads ascending")
assert(bySize[2].key == 20 and bySize[3].key == 500, "equal sizes keep their catalogue order")
assert(ExtraSets.SortEntries(entries, "pieces", "descending")[1].key == 500,
    "descending puts the biggest sets first")
assert(entries[1].key == 20, "piece sorting never mutates the source list either")

-- A set that comes in several colourways is one row saying how many, so the
-- number of them is worth sorting on. Colourways of one set share a count and
-- travel together, which is what leaves the row where they land.
do
local byVariants = ExtraSets.SortEntries(collapsed, "variants", "ascending")
assert(byVariants[1].setID == 605, "the set with a single colourway leads ascending")
assert(byVariants[2].setID == 601 and byVariants[3].setID == 603,
    "and the colourways of the set with two follow together")
local variantRows = ExtraSets.BuildRows(ExtraSets.SortEntries(collapsed, "variants", "descending"))
assert(#variantRows == 2 and variantRows[1].isGroup and #variantRows[1].variants == 2,
    "descending puts the set with the most colourways first")
assert(variantRows[2].setID == 605, "leaving the single-colourway set behind it")
assert(collapsed[1].setID == 601, "variant sorting never mutates the source list either")

-- The count is taken over the list being sorted, which is the list the rows are
-- built from, so a filter that leaves a set showing one colourway sorts it as
-- the plain row it becomes.
local thinned = ExtraSets.SortEntries({ collapsed[1], collapsed[3] }, "variants", "ascending")
assert(thinned[1].setID == 601 and thinned[2].setID == 605,
    "one colourway left of a set counts as one, so the two tie and keep their order")

-- There is more than one way to be a colourway of another set, and the row is
-- where they all come out as a single number, so the count is taken from the
-- rows themselves: a family read off the names alone is counted like any other.
local familyRecords = {
    colourway(661, "Midnight Sweatsuit", { 7001, 7002 }),
    colourway(662, "Azure Sweatsuit", { 7003, 7004 }),
    colourway(663, "Lone Vestments", { 5101, 5102 }),
}
for at, record in ipairs(familyRecords) do record.ensembles = { 79100 + at } end
local named = ExtraSets.SortEntries(
    ExtraSets.BuildEntries(familyRecords, stubResolver(CLOTH_CLASS)), "variants", "ascending")
assert(named[1].setID == 663, "the set belonging to no family leads ascending")
assert(named[2].setID == 661 and named[3].setID == 662,
    "and the two the names alone made a family of follow, counted as the two they become")
assert(#ExtraSets.BuildRows(named) == 2, "which is the pair of rows the list goes on to show")
end

-- Collected, armour type, and expansion filters.

assert(ExtraSets.IsComplete({ loading = false, total = 2, collected = 2 }), "a full set counts as complete")
assert(not ExtraSets.IsComplete({ loading = true, total = 2, collected = 2 }), "loading sets are not complete yet")
assert(not ExtraSets.IsComplete({ loading = false, total = 0, collected = 0 }), "empty sets are never complete")

do
local UNKNOWN = ExtraSets.UNKNOWN_EXPANSION

-- Which box each set answers to. Only sets the client itself named carry an
-- expansion, so the rest have a box of their own rather than riding along with
-- whatever else is ticked.
local shownExpansions = { true, true }
shownExpansions[UNKNOWN] = true
assert(ExtraSets.ExpansionBox(2, shownExpansions) == 2, "a dated set answers to its own expansion")
assert(ExtraSets.ExpansionBox(nil, shownExpansions) == UNKNOWN, "an undated set answers to Unknown")
assert(ExtraSets.ExpansionBox(9, shownExpansions) == UNKNOWN,
    "and so does a set dated to an expansion this version has no box for")

local everyBox = {}
ExtraSets.SetAllExpansions(everyBox, true)
assert(everyBox[0] and everyBox[11] and everyBox[UNKNOWN],
    "checking them all covers Unknown alongside the expansions themselves")
assert(not ExtraSets.AnyExpansionHidden(everyBox), "which reads as nothing hidden")
everyBox[UNKNOWN] = false
assert(ExtraSets.AnyExpansionHidden(everyBox), "and Unknown alone unticked still narrows the list")

local completeEntry = { loading = false, total = 2, collected = 2, expansionID = 2, armorType = CLOTH }
local partialEntry = { loading = false, total = 2, collected = 1, expansionID = 2, armorType = CLOTH }
local unknownEntry = { loading = false, total = 3, collected = 0, armorType = LEATHER }
local filterEntries = { completeEntry, partialEntry, unknownEntry }
local function expansionsShowing(first, second, unknown)
    local expansions = { first, second }
    expansions[UNKNOWN] = unknown
    return expansions
end
local filterState = { collected = true, uncollected = true,
    expansions = expansionsShowing(true, true, true) }

assert(#ExtraSets.ApplyFilters(filterEntries, filterState) == 3, "default filters keep everything")
filterState.collected = false
local uncollectedOnly = ExtraSets.ApplyFilters(filterEntries, filterState)
assert(#uncollectedOnly == 2 and uncollectedOnly[1] == partialEntry, "unchecking Collected hides complete sets")
filterState.collected = true
filterState.uncollected = false
local collectedOnly = ExtraSets.ApplyFilters(filterEntries, filterState)
assert(#collectedOnly == 1 and collectedOnly[1] == completeEntry, "unchecking Not Collected hides incomplete sets")
filterState.uncollected = true
filterState.expansions = expansionsShowing(true, false, true)
local narrowedExpansions = ExtraSets.ApplyFilters(filterEntries, filterState)
assert(#narrowedExpansions == 1 and narrowedExpansions[1] == unknownEntry,
    "unticking an expansion hides the sets it dates and leaves the undated ones alone")
filterState.expansions = expansionsShowing(true, true, false)
local dated = ExtraSets.ApplyFilters(filterEntries, filterState)
assert(#dated == 2 and dated[1] == completeEntry,
    "unticking Unknown hides the undated sets and leaves the dated ones alone")
filterState.expansions = expansionsShowing(false, false, false)
assert(#ExtraSets.ApplyFilters(filterEntries, filterState) == 0, "unchecking every box empties the list")
end

-- Source filter. The snapshot's bits are 1 crafted, 2 drop, 4 PvP, 8 quest,
-- 16 vendor, and Wowhead sets undocumented ones above them.

assert(ExtraSets.MaskHas(18, 2) and ExtraSets.MaskHas(18, 16), "read both bits out of a mask")
assert(not ExtraSets.MaskHas(18, 1) and not ExtraSets.MaskHas(18, 4), "and left the rest alone")
assert(not ExtraSets.MaskHas(nil, 2), "a set with no mask carries no source")
assert(ExtraSets.MaskHas(32770, 2), "read a bit out from under the ones Wowhead does not document")

do
local droppedEntry = { loading = false, total = 2, collected = 1, sourceMask = 2, armorType = CLOTH }
local craftedEntry = { loading = false, total = 2, collected = 1, sourceMask = 1, armorType = CLOTH }
local bothEntry = { loading = false, total = 2, collected = 1, sourceMask = 3, armorType = CLOTH }
-- No source at all, and only bits Wowhead does not document. The ensembles are
-- the first of these; their listing carries no source field.
local sourcelessEntry = { loading = false, total = 2, collected = 1, armorType = CLOTH }
local undocumentedEntry = { loading = false, total = 2, collected = 1, sourceMask = 32768, armorType = CLOTH }
local sourceEntries = { droppedEntry, craftedEntry, bothEntry, sourcelessEntry, undocumentedEntry }
local allSources = { [1] = true, [2] = true, [4] = true, [8] = true, [16] = true }

-- None of these carry an expansion, so Unknown is the box holding all of them
-- while the source boxes are what the assertions below move.
local function withSources(sources)
    local expansions = { true, true }
    expansions[ExtraSets.UNKNOWN_EXPANSION] = true
    return { collected = true, uncollected = true, expansions = expansions, sources = sources }
end

assert(#ExtraSets.ApplyFilters(sourceEntries, withSources(allSources)) == 5,
    "every source checked keeps everything")

local dropsOnly = ExtraSets.ApplyFilters(sourceEntries, withSources({ [2] = true }))
assert(#dropsOnly == 4, "checking one source keeps the sets that carry it")
assert(dropsOnly[1] == droppedEntry and dropsOnly[2] == bothEntry,
    "a set carrying several sources answers to each of them")
assert(dropsOnly[3] == sourcelessEntry and dropsOnly[4] == undocumentedEntry,
    "a set no box describes stays on screen rather than hiding behind one")

local craftedOnly = ExtraSets.ApplyFilters(sourceEntries, withSources({ [1] = true }))
assert(#craftedOnly == 4 and craftedOnly[1] == craftedEntry,
    "and the same holds for the other way round")
assert(not ExtraSets.MaskHas(craftedEntry.sourceMask, 2), "which is not the drop bit")

assert(#ExtraSets.ApplyFilters(sourceEntries, withSources({})) == 0,
    "unchecking every source empties the list, the undescribed sets included")

-- A page that has never opened the menu has no source state at all, which must
-- filter nothing rather than everything.
assert(#ExtraSets.ApplyFilters(sourceEntries, withSources(nil)) == 5, "no source state filters nothing")
end

-- UI harness: enough of the client to run CreatePage and Attach for real.

local createdFrames = {}
local capturedView

-- Anchors are recorded rather than resolved: the tests only ask what a frame
-- was pinned to, never where it landed on screen.
local function recordAnchors(frame)
    frame.points = {}
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(point, relativeTo, relativePoint, x, y)
        self.points[#self.points + 1] = { point, relativeTo, relativePoint, x, y }
    end
    -- The client answers with the anchor as five values, which is how the row
    -- reads the name's native position before indenting from it.
    function frame:GetPoint(index)
        local anchor = self.points[index or 1]
        if not anchor then return nil end
        return anchor[1], anchor[2], anchor[3], anchor[4], anchor[5]
    end
    return frame
end

-- Blizzard's own scaler, which shrinks a font string until its text fits the
-- lines it is allowed. The stub records that it ran; a test says whether the
-- text still failed to fit by setting truncated.
AutoScalingFontStringMixin = {
    SetText = function(self, text)
        self.text = text
        self.scaled = true
    end,
    SetMinLineHeight = function(self, height) self.minLineHeight = height end,
}

local createdFontStrings = {}

local function newFontString()
    local fontString = recordAnchors({ shown = true, truncated = false })
    function fontString:SetWidth(width) self.width = width end
    function fontString:SetTextColor() end
    function fontString:SetText(text) self.text = text end
    function fontString:SetFormattedText(format, ...) self.text = format:format(...) end
    function fontString:SetShown(shown) self.shown = shown end
    function fontString:Show() self.shown = true end
    function fontString:Hide() self.shown = false end
    function fontString:SetMaxLines(lines) self.maxLines = lines end
    function fontString:IsTruncated() return self.truncated end
    createdFontStrings[#createdFontStrings + 1] = fontString
    return fontString
end

local function newTexture()
    local texture = recordAnchors({})
    function texture:SetAtlas(atlas) self.atlas = atlas end
    function texture:SetTexture(value) self.texture = value end
    function texture:SetDesaturated() end
    function texture:SetAlpha(alpha) self.alpha = alpha end
    function texture:SetSize() end
    function texture:SetHeight() end
    function texture:SetWidth(width) self.width = width end
    function texture:SetShown(shown) self.shown = shown end
    function texture:Show() self.shown = true end
    function texture:Hide() self.shown = false end
    function texture:SetVertexColor(red, green, blue) self.vertexColor = { red, green, blue } end
    return texture
end

function CreateFrame(frameType, name, parent, template)
    local frame = {
        frameType = frameType, name = name, parent = parent, template = template,
        scripts = {}, events = {}, shown = true,
        -- Children inherit the parent's level plus one, as in the client. The
        -- wardrobe starts high so a hardcoded low level would sink below the model.
        frameLevel = (parent and parent.frameLevel or 0) + 1,
    }
    function frame:SetScript(script, handler) self.scripts[script] = handler end
    function frame:HookScript(script, handler) self.scripts[script] = handler end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:RegisterForClicks() end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetShown(shown) self.shown = shown end
    function frame:IsShown() return self.shown end
    recordAnchors(frame)
    function frame:SetAllPoints() end
    function frame:SetSize() end
    function frame:SetWidth(width) self.width = width end
    function frame:GetWidth() return self.width or 0 end
    function frame:SetFrameStrata() end
    function frame:SetFrameLevel(level) self.frameLevel = level end
    function frame:GetFrameLevel() return self.frameLevel end
    function frame:EnableMouse() end
    function frame:EnableKeyboard(enable) self.keyboardEnabled = enable end
    function frame:SetPropagateKeyboardInput(propagate) self.propagateKeys = propagate end
    function frame:SetID(id) self.id = id end
    function frame:GetID() return self.id end
    function frame:SetText(text) self.text = text end
    function frame:GetText() return self.text or "" end
    function frame:GetName() return self.name end
    function frame:GetParent() return self.parent end
    -- The client only answers for a frame's screen edges once it has been laid
    -- out, so this stays unset until a test says where the frame landed.
    function frame:GetRight() return self.right end
    frame.CreateFontString = function() return newFontString() end
    frame.CreateTexture = function() return newTexture() end
    function frame:SetMinMaxValues(minValue, maxValue) self.min, self.max = minValue, maxValue end
    function frame:SetValue(value) self.value = value end
    function frame:SetupMenu(builder) self.menuBuilder = builder end
    function frame:SetSelectionTranslator(translator) self.selectionTranslator = translator end
    function frame:SetIsDefaultCallback(callback) self.isDefaultCheck = callback end
    function frame:SetDefaultCallback(callback) self.defaultReset = callback end
    function frame:SetDataProvider(provider) self.dataProvider = provider end
    function frame:ForEachFrame() end
    function frame:OnLoad() end
    function frame:Undress() self.triedOn = {} end
    function frame:TryOn(sourceID) table.insert(self.triedOn, sourceID) end
    function frame:RefreshCamera() end

    if template == "CollectionsBackgroundTemplate" then
        frame.BGCornerTopLeft = newTexture()
        frame.BGCornerTopRight = newTexture()
    elseif template == "CollectionsProgressBarTemplate" then
        frame.text = newFontString()
        frame.border = newTexture()
    elseif template == "SquareIconButtonTemplate" then
        frame.Icon = newTexture()
    end

    createdFrames[#createdFrames + 1] = frame
    if name then _G[name] = frame end
    return frame
end

local function findFrame(match)
    for _, frame in ipairs(createdFrames) do
        if match(frame) then return frame end
    end
end

function Mixin(target, mixin)
    for key, value in pairs(mixin or {}) do target[key] = value end
    return target
end

local modelUpdates = 0
WardrobeSetsDetailsModelMixin = {
    OnUpdate = function() modelUpdates = modelUpdates + 1 end,
}
CreateDataProvider = function(list) return list end
CreateScrollBoxListLinearView = function()
    capturedView = {
        SetElementInitializer = function(self, template, initializer)
            self.template = template
            self.initializer = initializer
        end,
        SetPadding = function() end,
    }
    return capturedView
end
ScrollUtil = { InitScrollBoxListWithScrollBar = function() end }
ScrollBoxConstants = { RetainScrollPosition = true }
local tooltip = { lines = {} }
GameTooltip = {
    SetOwner = function(_, owner)
        tooltip.owner = owner
        tooltip.lines = {}
        tooltip.appearanceData = nil
        tooltip.shown = false
    end,
    SetText = function(_, text) tooltip.lines[#tooltip.lines + 1] = text end,
    AddLine = function(_, text) tooltip.lines[#tooltip.lines + 1] = text end,
    SetHyperlink = function(_, link) tooltip.lines[#tooltip.lines + 1] = link end,
    Show = function() tooltip.shown = true end,
    Hide = function() tooltip.shown = false end,
}
CollectionWardrobeUtil = {
    SortSources = function(sources) tooltip.sortedSources = sources end,
    -- The real one answers with the item it settled on and whether there are
    -- others to cycle through, which is what drives the Tab key.
    SetAppearanceTooltip = function(_, appearanceData)
        tooltip.appearanceData = appearanceData
        return appearanceData.selectedIndex or 1, #appearanceData.sources > 1
    end,
}
QUESTION_MARK_ICON = 134400
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 42 }
local playedSound
function PlaySound(soundID) playedSound = soundID end
local shiftDown = false
function IsShiftKeyDown() return shiftDown end
-- The dressing-room modifier is the player's to rebind, so the page asks the
-- client which click it is rather than reading the ctrl key itself. Held in a
-- global table rather than in locals because this file has spent every one of
-- Lua's 200 of them.
dressUp = { held = false }
function IsModifiedClick(action) return action == "DRESSUP" and dressUp.held end
function DressUpVisual(sourceID) dressUp.source = sourceID end
function ShowInspectCursor() dressUp.cursor = "inspect" end
function ResetCursor() dressUp.cursor = nil end
function IsUnitModelReadyForUI() return true end
function UnitClass() return "Class 5", "CLASS5", CLOTH_CLASS end
function Model_ApplyUICamera() end
function GetUICameraInfo() return 0, 0, 0, 0 end
function InCombatLockdown() return false end
WARDROBE_CYCLE_KEY = "TAB"
function PanelTemplates_TabResize() end
function PanelTemplates_SelectTab(tab) tab.selected = true end
function PanelTemplates_DeselectTab(tab) tab.selected = false end

function hooksecurefunc(owner, method, hook)
    local original = owner[method]
    owner[method] = function(...)
        original(...)
        hook(...)
    end
end

-- Timers are held rather than run, so a test can fire a burst of events and see
-- how much work the page actually does when the frame ends.
local pendingTimers = {}
C_Timer = {
    After = function(_, callback) pendingTimers[#pendingTimers + 1] = callback end,
}

local function runTimers()
    local due = pendingTimers
    pendingTimers = {}
    for _, callback in ipairs(due) do callback() end
end

local addonLoadedCallback
EventUtil = {
    ContinueOnAddOnLoaded = function(addonName, callback)
        assert(addonName == "Blizzard_Collections", "waited for the collections addon")
        addonLoadedCallback = callback
    end,
}

-- The class the Sets tab is showing, which both set pages read.
local setsClassFilter = CLOTH_CLASS
-- The looks the client counts for the Sets tab's own sets, for the looks dump.
local setPrimaryAppearances = {}
-- What the client calls a colourway of what. Set 603 is one it groups under 601
-- the way it groups a tier's difficulties; 601 is that group's base set, and
-- everything else it says nothing about.
local baseSetIDs = { [601] = 601, [603] = 601 }
local variantSets = { [601] = { { setID = 601 }, { setID = 603 } } }

C_TransmogSets = {
    GetCameraIDs = function() return nil end,
    GetSetInfo = function(setID) return setID == 20 and { name = "Live Name" } or nil end,
    GetTransmogSetsClassFilter = function() return setsClassFilter end,
    SetTransmogSetsClassFilter = function(classID) setsClassFilter = classID end,
    GetSetPrimaryAppearances = function(setID) return setPrimaryAppearances[setID] end,
    GetBaseSetID = function(setID) return baseSetIDs[setID] end,
    GetVariantSets = function(setID) return variantSets[setID] end,
}
-- Item data arrives from the server, so the client holds it only once asked.
local loadedItems = {}
local requestedItems = {}

-- The character being played is Horde, so a set locked against them belongs to
-- the Alliance.
FACTION_ALLIANCE = "Alliance"
FACTION_HORDE = "Horde"
UnitFactionGroup = function() return "Horde" end
Enum = { TransmogUseErrorType = { PlayerCondition = 1, Race = 8, Faction = 9 } }

C_TransmogCollection = {
    GetSourceInfo = function(sourceID)
        local state = sourceStates[sourceID]
        if not state then return nil end
        return {
            sourceID = sourceID,
            visualID = state.appearanceID,
            isCollected = state.sourceCollected or false,
            itemID = state.itemID,
            -- The client answers this from the item's own data, so a source
            -- whose item it has not loaded says no rather than saying nothing.
            isValidSourceForPlayer = loadedItems[state.itemID] ~= nil and not state.unwearable,
            useErrorType = state.useErrorType,
            useError = state.useError,
        }
    end,
    GetAllAppearanceSources = function(visualID)
        local sources = {}
        for sourceID, state in pairs(sourceStates) do
            if state.appearanceID == visualID then sources[#sources + 1] = sourceID end
        end
        table.sort(sources)
        return sources
    end,
    -- MayReturnNothing in the client: it declines for looks outside the
    -- player's wardrobe context, which the stub models with outsideWardrobe.
    GetAppearanceInfoBySource = function(sourceID)
        local state = sourceStates[sourceID]
        if not state or state.appearanceID == nil or state.outsideWardrobe then return nil end
        return { appearanceID = state.appearanceID, appearanceIsCollected = state.collected }
    end,
    GetSourceIcon = function() return 1111 end,
    GetAppearanceSourceInfo = function() return nil end,
}
C_Item = {
    GetItemSetInfo = function() return nil end,
    GetItemSubClassInfo = function(_, subClassID) return "Armour " .. subClassID end,
    GetItemInfo = function(itemID) return loadedItems[itemID] end,
    RequestLoadItemDataByID = function(itemID) requestedItems[#requestedItems + 1] = itemID end,
}

local trackedSources, trackedName
local toggledPiece, toggledName
local shiftClickTracks = true
-- The one source the player is hunting, which both stubs below answer for: the
-- mark shows on it and the shift-click offered over it is the one that stops.
local huntedSource
LuckysWardrobe.SetTracking = {
    ToggleSources = function(_, sourceIDs, setName)
        trackedSources, trackedName = sourceIDs, setName
    end,
    TogglePiece = function(_, sourceID, setName)
        toggledPiece, toggledName = sourceID, setName
    end,
    HandlesShiftClick = function(_, buttonName)
        return shiftClickTracks and shiftDown and buttonName == "LeftButton"
    end,
    AddTrackHint = function(_, target, sourceID)
        if not sourceID then return false end
        local hints = LuckysWardrobe.Strings.tracking
        target:AddLine(sourceID == huntedSource and hints.stopHint or hints.hint)
        return true
    end,
}

local markedSources = {}
local markedSetSources = {}
LuckysWardrobe.TrackedAppearances = {
    Mark = function(_, itemFrame, sourceID)
        markedSources[itemFrame] = sourceID or false
    end,
    MarkSet = function(_, itemFrame, sourceIDs)
        markedSetSources[itemFrame] = sourceIDs
    end,
    AddTooltipLine = function(_, target, sourceID)
        if sourceID ~= huntedSource then return false end
        target:AddLine("tracked")
        return true
    end,
}

local altDown = false
local linkedSource
LuckysWardrobe.WowheadLink = {
    HandlesClick = function(_, buttonName) return altDown and buttonName == "LeftButton" end,
    ShowForSource = function(_, sourceID)
        linkedSource = sourceID
        return true
    end,
}

local function visibilityFrame(shown)
    return {
        shown = shown,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        -- Unset until a test says where the client laid the frame out.
        GetLeft = function(self) return self.left end,
    }
end

-- Blizzard's own class dropdown, the one control both set pages share. It
-- behaves as the client's does: choosing a class writes the sets filter and
-- builds the menu again.
local function nativeClassDropdown()
    local dropdown = recordAnchors(visibilityFrame(true))
    function dropdown:SetupMenu(builder) self.menuBuilder = builder end
    function dropdown:SetClassFilter(classID)
        C_TransmogSets.SetTransmogSetsClassFilter(classID)
        self:Refresh()
    end
    function dropdown:Refresh()
        self:SetupMenu(function(_, root)
            for classID = 1, GetNumClasses() do
                local info = C_CreatureInfo.GetClassInfo(classID)
                root:CreateRadio(
                    info.className,
                    function(data) return C_TransmogSets.GetTransmogSetsClassFilter() == data.classID end,
                    function(data) dropdown:SetClassFilter(data.classID) end,
                    { classID = classID, className = info.className }
                )
            end
        end)
    end
    dropdown:Refresh()
    return dropdown
end

-- Blizzard's own bar, laid out for two tabs before the addon gets to it.
local NATIVE_PROGRESS_BAR_WIDTH = 196

local function nativeProgressBar()
    local bar = recordAnchors(visibilityFrame(true))
    bar.width = NATIVE_PROGRESS_BAR_WIDTH
    bar.border = newTexture()
    function bar:SetWidth(width) self.width = width end
    return bar
end

-- The journal's own two tabs, which the addon may read but never resize the
-- count of. Drawn selected or not through the same PanelTemplates calls the
-- client uses, which the stubs above record on the tab.
local function nativeTabStub()
    return { selected = false, GetWidth = function() return 60 end }
end

local wardrobe
wardrobe = {
    name = "WardrobeCollectionFrame",
    frameLevel = 20,
    numTabs = 2,
    Tabs = { nativeTabStub(), nativeTabStub() },
    selectedCollectionTab = 1,
    ItemsCollectionFrame = visibilityFrame(true),
    SetsCollectionFrame = visibilityFrame(false),
    SearchBox = visibilityFrame(true),
    FilterButton = visibilityFrame(true),
    ClassDropdown = nativeClassDropdown(),
    progressBar = nativeProgressBar(),
    ContentFrames = {},
    GetName = function(self) return self.name end,
    -- Unset until a test says the wardrobe has been laid out on screen.
    GetRight = function(self) return self.right end,
}
wardrobe.SetsCollectionFrame.searchType = 2

-- Where the client leaves the two controls that share the tab row. The Items
-- tab keeps its search box in the top right corner and parks the class dropdown
-- beside the slot column on the far left; the set pages swap them over.
local ITEMS_CLASS_DROPDOWN_LEFT = 120
local SETS_CLASS_DROPDOWN_LEFT = 700
local ITEMS_SEARCH_BOX_LEFT = 660

function wardrobe:SetTab(tabID)
    self.selectedCollectionTab = tabID
    self.ClassDropdown.left = tabID == 1 and ITEMS_CLASS_DROPDOWN_LEFT or SETS_CLASS_DROPDOWN_LEFT
    if tabID == 1 then
        self.ItemsCollectionFrame:Show()
        self.SetsCollectionFrame:Hide()
    elseif tabID == 2 then
        self.ItemsCollectionFrame:Hide()
        self.SetsCollectionFrame:Show()
    end
end

function wardrobe:ClickTab(tab)
    self:SetTab(tab:GetID())
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

local originalSetTab = wardrobe.SetTab
WardrobeCollectionFrame = wardrobe

-- The live resolver has to answer for every source the client knows, or rows
-- sit on "Loading appearance data..." forever.

local liveResolver = ExtraSets.LiveResolver()
sourceStates[7001] = { appearanceID = 9701, collected = true, sourceCollected = true }
local inWardrobe = liveResolver.sourceState(7001)
assert(inWardrobe.appearanceID == 9701 and inWardrobe.collected == true,
    "used appearance-level collected state when the client offers it")

sourceStates[7002] = { appearanceID = 9702, collected = true, sourceCollected = false, outsideWardrobe = true }
local uncollectedOutside = liveResolver.sourceState(7002)
assert(uncollectedOutside.appearanceID == 9702, "fell back to the source's own visual")
assert(uncollectedOutside.collected == false, "resolved an uncollected look outside the wardrobe context")

sourceStates[7003] = { appearanceID = 9703, collected = false, sourceCollected = true, outsideWardrobe = true }
assert(liveResolver.sourceState(7003).collected == true,
    "fell back to the source's own collected flag rather than leaving it unresolved")

assert(liveResolver.sourceState(7999) == nil, "sources the client does not know stay unavailable")

local outsideRecord = validRecord({
    setID = 70,
    pieces = pieces({ "HEAD", 7001 }, { "CHEST", 7002 }, { "LEGS", 7003 }),
})
local outsideEntry = ExtraSets.BuildEntries({ outsideRecord }, liveResolver)[1]
assert(not outsideEntry.loading, "a set of looks outside the wardrobe context still resolves")
assert(outsideEntry.collected == 2 and outsideEntry.total == 3, "counted the fallback states")

sourceStates[7001], sourceStates[7002], sourceStates[7003] = nil, nil, nil

-- Attach through Init, exactly as Core does.

ExtraSets:Init()
assert(addonLoadedCallback, "deferred attach until the collections addon loads")
addonLoadedCallback()
assert(catalogBuildStarted, "started catalogue discovery when the collections addon loaded")
assert(catalogReadyCallback, "subscribed to catalogue completion")

local page = findFrame(function(frame) return frame.name == "LuckysWardrobeExtraSetsFrame" end)
local extraTab = findFrame(function(frame) return frame.template == "PanelTopTabButtonTemplate" end)
assert(page and extraTab, "created the Extra Sets page and subtab")
assert(page.shown == false, "kept the page hidden on the native tab")
assert(extraTab.name == "LuckysWardrobeExtraSetsTab", "named the subtab as the addon's own")
assert(extraTab.text == "Extra Sets", "labelled the subtab")
-- The wardrobe's own tab state is exactly what the addon must never write: the
-- secure SetTab reads numTabs on every switch, and one addon-written field
-- taints that whole execution, down to the propagate answer the key handler
-- gives for every keypress. A tainted answer is ignored, and movement keys die
-- whenever an appearance tooltip is up.
assert(wardrobe.numTabs == 2, "left the native tab count alone")
assert(#wardrobe.ContentFrames == 0, "stayed out of the native content lifecycle")
assert(wardrobe.activeFrame == nil, "never wrote the active frame")
do
    local tabPoint, tabRelativeTo, tabRelativePoint = extraTab:GetPoint()
    assert(tabPoint == "TOPLEFT" and tabRelativeTo == wardrobe.Tabs[2] and tabRelativePoint == "TOPRIGHT",
        "hung the subtab off the end of the native strip")
end
assert(capturedView.template == "WardrobeSetsScrollFrameButtonTemplate", "reused the native sets row template")

-- The page answers collection events on the next frame, so every test that
-- fires one lets that frame end.
local function collectionUpdated()
    page.scripts.OnEvent(page, "TRANSMOG_COLLECTION_UPDATED")
    runTimers()
end

-- The third tab reaches into where Blizzard parked the progress bar, so both
-- the native bar and the addon's own copy move past the end of the tab strip.
-- Nothing has been laid out on screen yet, so there is no room to measure and
-- the bar keeps its full width.

for _, bar in ipairs({ wardrobe.progressBar, page.progressBar }) do
    assert(#bar.points == 1, "gave the progress bar a single anchor")
    local point, relativeTo, relativePoint, x = bar:GetPoint()
    assert(point == "TOPLEFT" and relativeTo == extraTab and relativePoint == "TOPRIGHT",
        "anchored the progress bar to the end of the tab strip")
    assert(x > 0, "kept the whole bar past the end of the tab strip")
    assert(bar.width < NATIVE_PROGRESS_BAR_WIDTH, "narrowed the progress bar to fit beside the tabs")
    assert(bar.border.width > bar.width, "kept the border art framing the narrowed bar")
end

local FULL_BAR_WIDTH = wardrobe.progressBar.width

-- Tab switching. Everything the bar sits between has landed on screen by the
-- time a tab is clicked, so the room can be measured from here on. The bar is
-- sized against the Items tab's search box wherever it is measured from, so the
-- wardrobe is given the right edge that puts the box where the fixture says.
local TAB_STRIP_RIGHT = 400
local ITEMS_SEARCH_BOX_INSET = 222

extraTab.right = TAB_STRIP_RIGHT
wardrobe.SearchBox.left = ITEMS_SEARCH_BOX_LEFT
wardrobe.right = ITEMS_SEARCH_BOX_LEFT + ITEMS_SEARCH_BOX_INSET

-- Where both bars ended up, which is one answer: the two are laid out by the
-- same rule and a disagreement between them is a bug in it.
local function progressBarLayout()
    local placed
    for _, bar in ipairs({ wardrobe.progressBar, page.progressBar }) do
        local point, relativeTo, relativePoint, x = bar:GetPoint()
        assert(point == "TOPLEFT" and relativeTo == extraTab and relativePoint == "TOPRIGHT",
            "anchored the bar to the end of the tab strip")
        if placed then
            assert(placed.x == x and placed.width == bar.width,
                "laid both bars out in the same place")
        end
        placed = { x = x, width = bar.width }
    end
    return placed
end

extraTab.scripts.OnClick()
assert(page.shown, "showed Extra Sets")
assert(wardrobe.selectedCollectionTab == 1, "left the native selection state alone")
assert(not wardrobe.ItemsCollectionFrame.shown and not wardrobe.SetsCollectionFrame.shown, "hid native pages")
assert(not wardrobe.SearchBox.shown and not wardrobe.FilterButton.shown, "hid native-only controls")
assert(not wardrobe.progressBar.shown, "hid the rest of the native controls")
assert(wardrobe.ClassDropdown.shown, "kept the native class dropdown, which this page shares")
assert(wardrobe.activeFrame == nil, "never wrote the active frame")
assert(extraTab.selected and not wardrobe.Tabs[1].selected and not wardrobe.Tabs[2].selected,
    "drew the strip with this tab selected")
assert(playedSound == SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "used the native tab sound")

-- Resizing the strip measured the room again. There is plenty of it here, so the
-- bar sits just past the strip at its full width.
local onExtraSets = progressBarLayout()
assert(onExtraSets.x > 0 and onExtraSets.width == FULL_BAR_WIDTH,
    "left the bar its full width where the strip leaves room for it")
assert(onExtraSets.x + onExtraSets.width < SETS_CLASS_DROPDOWN_LEFT - TAB_STRIP_RIGHT,
    "left the class dropdown clear")

-- Every SetTab call is Blizzard's side of the fence, whoever's ID it names:
-- our pages come off the screen and the chrome they hid goes back.
wardrobe:SetTab(4)
assert(not page.shown and wardrobe.SearchBox.shown, "any SetTab call puts the journal back")

extraTab.scripts.OnClick()
wardrobe:SetTab(2)
assert(not page.shown and wardrobe.SetsCollectionFrame.shown, "restored the native Sets page")
assert(wardrobe.SearchBox.shown and wardrobe.FilterButton.shown and wardrobe.ClassDropdown.shown, "restored native controls")
assert(not extraTab.selected, "drew the subtab deselected again")
assert(wardrobe.SetTab ~= originalSetTab, "hooked rather than replaced SetTab")

-- The Items tab hands the corner to its search box, which comes nearer the tab
-- strip than the class dropdown the set pages leave there. The bar is measured
-- against that one wherever it is drawn, so it holds one place and one width
-- rather than moving as the tabs change.
local onSets = progressBarLayout()
wardrobe:SetTab(1)
local onItems = progressBarLayout()
assert(onItems.x == onSets.x and onItems.width == onSets.width
    and onItems.x == onExtraSets.x and onItems.width == onExtraSets.width,
    "kept the bar in one place whichever tab is on screen")
assert(onItems.x + onItems.width < ITEMS_SEARCH_BOX_LEFT - TAB_STRIP_RIGHT,
    "left the Items tab's search box clear")

-- A strip wide enough to crowd the bar takes width off it rather than pushing it
-- under the search box, until the counts would stop fitting inside it.
extraTab.right = ITEMS_SEARCH_BOX_LEFT - 120
wardrobe:SetTab(1)
local crowded = progressBarLayout()
assert(crowded.width < onItems.width, "gave up width to a strip that crowds it")
assert(crowded.x + crowded.width <= ITEMS_SEARCH_BOX_LEFT - extraTab.right, "still cleared the search box")

extraTab.right = ITEMS_SEARCH_BOX_LEFT - 20
wardrobe:SetTab(1)
assert(progressBarLayout().width == 80, "stopped shrinking once the counts would not fit")

extraTab.right = TAB_STRIP_RIGHT
wardrobe:SetTab(1)

ExtraSets:Attach(wardrobe)
do
    local tabCount = 0
    for _, frame in ipairs(createdFrames) do
        if frame.template == "PanelTopTabButtonTemplate" then tabCount = tabCount + 1 end
    end
    assert(tabCount == 1, "attach is idempotent")
end

-- Attach callbacks arrive in no promised order, so a tab's place in the strip
-- comes from the order it asks for, not from who attached first: registered
-- backwards, the strip still reads left to right.
do
    local noop = function() end
    local lastTab = ExtraSets.AddWardrobeTab(wardrobe, "OrderLast", "Last", CreateFrame("Frame"), noop, 3)
    local middleTab = ExtraSets.AddWardrobeTab(wardrobe, "OrderMiddle", "Middle", CreateFrame("Frame"), noop, 2)
    assert(select(2, middleTab:GetPoint()) == extraTab, "the middle tab hangs off the first")
    assert(select(2, lastTab:GetPoint()) == middleTab, "and the last off the middle")
    assert(select(2, extraTab:GetPoint()) == wardrobe.Tabs[2], "with the first still on the native strip")
end

-- Catalogue lifecycle: building state first, then a repaint when the
-- catalogue lands while the page is open.

local scrollBox = findFrame(function(frame) return frame.template == "WowScrollBoxList" end)
catalogReady = false
extraTab.scripts.OnClick()
page.scripts.OnShow(page)
assert(#scrollBox.dataProvider == 0, "no rows while the catalogue is still building")

catalogReady = true
catalogRecords = { records[1], records[2] }
catalogReadyCallback()
assert(#scrollBox.dataProvider == 2, "catalogue completion repainted the open page")
assert(page.events.TRANSMOG_COLLECTION_UPDATED, "listened for the collection changing while shown")
-- Asking the client about a source is what makes it load that item's data,
-- which is what fires TRANSMOG_COLLECTION_ITEM_UPDATE. Answering that event by
-- reading every set again is a page that feeds itself.
assert(not page.events.TRANSMOG_COLLECTION_ITEM_UPDATE, "never answers the event its own reading causes")
assert(#scrollBox.dataProvider == 2, "refresh populated the list from the catalogue")

local progressBar = findFrame(function(frame) return frame.template == "CollectionsProgressBarTemplate" end)
assert(progressBar.value == 0 and progressBar.max == 2, "no set is complete yet")

sourceStates[2003].collected = true
sourceStates[2004].collected = true
collectionUpdated()
assert(progressBar.value == 1, "collection events recompute completion live")

-- A burst of events costs one pass over the catalogue, not one per event.

local builds = 0
local buildEntries = ExtraSets.BuildEntries
ExtraSets.BuildEntries = function(...)
    builds = builds + 1
    return buildEntries(...)
end
for _ = 1, 5 do page.scripts.OnEvent(page, "TRANSMOG_COLLECTION_UPDATED") end
assert(builds == 0, "nothing is rebuilt while the events are still arriving")
runTimers()
assert(builds == 1, "five events in one frame rebuilt the entries once")

-- The page measures itself, which is how a report of dropped frames gets an
-- answer rather than a guess.

local measured = table.concat(LuckysWardrobe.Perf:Report(), "\n")
assert(measured:find("page refresh: %d"), "timed its refreshes")
assert(measured:find("entries built: %d"), "timed the entry rebuilds separately from the refresh")
assert(measured:find("list filled: %d"), "timed handing the list to the scroll box")
assert(measured:find("set displayed: %d"), "timed showing the selected set")
assert(measured:find("event TRANSMOG_COLLECTION_UPDATED: %d"), "counted the events it answers")
assert(type(page.scripts.OnUpdate) == "function", "watched frames while the page is on screen")

-- The model's own script is the one thing here that runs every frame by
-- design, so it is measured rather than assumed innocent.
local dressUpModel = findFrame(function(frame) return frame.frameType == "DressUpModel" end)
dressUpModel.scripts.OnUpdate(dressUpModel, 0.016)
assert(modelUpdates == 1, "still ran Blizzard's own model script")
page.scripts.OnUpdate(page, 0.05)
measured = table.concat(LuckysWardrobe.Perf:Report(), "\n")
assert(measured:find("model updated: 1"), "timed the model script")
assert(measured:find("frames watched: 1"), "sampled the frame")

-- Searching and filtering reuse what the last rebuild produced.

local searchBox = findFrame(function(frame) return frame.template == "SearchBoxTemplate" end)
builds = 0
searchBox.text = "Loading"
searchBox.scripts.OnTextChanged()
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].key == 500, "search filtered the list")
searchBox.text = ""
searchBox.scripts.OnTextChanged()
assert(#scrollBox.dataProvider == 2, "clearing the search restores the list")
assert(builds == 0, "typing in the search box never rebuilds the entries")
ExtraSets.BuildEntries = buildEntries

-- Empty catalogue fallback.

catalogRecords = {}
collectionUpdated()
assert(#scrollBox.dataProvider == 0, "empty catalogue produces an empty list")
local emptyText
for _, frame in ipairs(createdFrames) do
    if frame.template == "InsetFrameTemplate" then emptyText = frame end
end
assert(emptyText, "left inset exists for the empty message")

page.scripts.OnHide(page)
assert(next(page.events) == nil, "unregistered every event on hide")
assert(page.scripts.OnUpdate == nil, "stopped watching frames once the page left the screen")

-- Row rendering and tracking.

catalogRecords = { records[1] }
page.scripts.OnShow(page)
local entry = scrollBox.dataProvider[1]

-- Blizzard's row template, as much of it as the initializer touches.
local function newRowButton()
    local rowButton = {
        Name = newFontString(),
        Label = newFontString(),
        IconFrame = { Icon = newTexture(), Cover = { SetShown = function() end }, Favorite = { Hide = function() end } },
        New = { Hide = function() end },
        SelectedTexture = { SetShown = function() end },
        ProgressBar = { SetShown = function() end, SetWidth = function() end },
        SetScript = function(self, script, handler)
            self.scripts = self.scripts or {}
            self.scripts[script] = handler
        end,
        CreateFontString = function() return newFontString() end,
    }
    rowButton.IconFrame.SetScript = rowButton.SetScript
    return rowButton
end

local button = newRowButton()
capturedView.initializer(button, entry)
assert(button.Name.text == "Live Name", "row shows the set name")
assert(#markedSetSources[button] == 0, "marked the row with what the set is missing")

shiftDown = true
button.scripts.OnClick(button, "LeftButton")
assert(trackedSources ~= nil and trackedName == "Live Name", "shift-click tracks the set's missing pieces")
assert(#trackedSources == 0, "only missing pieces are tracked")
shiftDown = false

sourceStates[2003].collected = false
sourceStates[2004].collected = false
collectionUpdated()
shiftDown = true
capturedView.initializer(button, scrollBox.dataProvider[1])
assert(#markedSetSources[button] == 2, "the crosshair follows what is missing as it changes")
button.scripts.OnClick(button, "LeftButton")
assert(#trackedSources == 2, "both missing sources are tracked")

-- Shift-click tracking is one setting across every page that offers it, so
-- turning it off hands the click back to selecting the set.
shiftClickTracks = false
trackedSources = nil
playedSound = nil
button.scripts.OnClick(button, "LeftButton")
assert(trackedSources == nil and playedSound, "selected the set instead when tracking is turned off")
shiftClickTracks = true
shiftDown = false

-- A row standing for several colourways. What the player wants off it is how
-- much of the whole family is left, so the line under the name counts all of
-- them and the corner says how many sets are folded behind it.

do
for id = 7200, 7208 do sourceStates[id] = { appearanceID = 8200 + id, collected = id % 3 == 0 } end

local familyRows = ExtraSets.BuildRows(ExtraSets.BuildEntries({
    validRecord({ setID = 901, name = "Nitroclad Kit", model = 42,
        pieces = pieces({ "HEAD", 7200 }, { "CHEST", 7201 }, { "LEGS", 7202 }) }),
    validRecord({ setID = 902, name = "Smoketrail Racer Suit", model = 42,
        pieces = pieces({ "HEAD", 7203 }, { "CHEST", 7204 }, { "LEGS", 7205 }) }),
    validRecord({ setID = 903, name = "Upcycled Outfit", model = 42,
        pieces = pieces({ "HEAD", 7206 }, { "CHEST", 7207 }, { "LEGS", 7208 }) }),
}, stubResolver(CLOTH_CLASS)))
assert(#familyRows == 1 and #familyRows[1].variants == 3, "the three colourways are one row")

local familyButton = newRowButton()
capturedView.initializer(familyButton, familyRows[1])
assert(familyButton.Label.text == "3/9 collected",
    "the line under the name counts every look across the colourways, not the first set's three")
assert(familyButton.luckysVariantCount.text == "x3", "and the corner says how many sets stand behind it")
assert(familyButton.Name.width == 168, "the name gives up the width the badge needs")

-- The same row template is reused as the list scrolls, so a plain set drawn
-- into a button that just held a family must not keep its badge.
capturedView.initializer(familyButton, entry)
assert(familyButton.luckysVariantCount.text == "", "a set with one colourway shows no badge")
assert(familyButton.Name.width == 190, "and takes the full width of the row back")
assert(familyButton.Label.text:find("collected"), "and counts itself the way it always did")
end

-- Preview slots. The choice is one module shared with every set pane, so
-- hiding a slot redresses the open set without its piece on the spot, and
-- showing it again puts the piece back, all without a rebuild.

assert(findFrame(function(frame) return frame.template == "SquareIconButtonTemplate" end),
    "the details pane carries the preview-slots button")

do
    local function wornSources()
        local worn = {}
        for _, sourceID in ipairs(dressUpModel.triedOn or {}) do worn[sourceID] = true end
        return worn
    end

    local fullyWorn = wornSources()
    assert(fullyWorn[2001] and fullyWorn[2003] and fullyWorn[2004],
        "the model wears the whole set while every slot is ticked")

    LuckysWardrobe.PreviewSlots:ToggleSlot("HEAD")
    local helmless = wornSources()
    assert(not helmless[2001], "hiding the head took the helm off the open set")
    assert(helmless[2003] and helmless[2004], "and left the rest of the set dressed")

    LuckysWardrobe.PreviewSlots:ToggleSlot("HEAD")
    assert(wornSources()[2001], "showing the head dressed the helm again")
end

-- Piece tooltips. The details frame has to sit above the model or the model
-- swallows the hover and no tooltip ever appears.

local pieceButtons = {}
for _, frame in ipairs(createdFrames) do
    if frame.frameType == "Button" and frame.template == nil then
        pieceButtons[#pieceButtons + 1] = frame
    end
end
assert(#pieceButtons > 0, "created piece buttons")

local detailsFrame = pieceButtons[1].parent
local modelFrame = findFrame(function(frame) return frame.frameType == "DressUpModel" end)
assert(detailsFrame and modelFrame, "found the details frame and model")
assert(detailsFrame:GetFrameLevel() > modelFrame:GetFrameLevel(),
    "details frame sits above the model so pieces stay hoverable")

local collectedPiece = pieceButtons[1]
assert(collectedPiece.piece.state == "collected", "first piece is the collected one")

-- The border art is wider than the icon it frames and sits off-centre within
-- itself, so it hangs by its right edge exactly as the Sets tab hangs it.
-- Centring it instead leaves the frame beside the icon rather than around it.
assert(#collectedPiece.border.points == 1, "gave the border a single anchor")
local borderAnchor = collectedPiece.border.points[1]
assert(borderAnchor[1] == "RIGHT" and borderAnchor[2] == collectedPiece.icon and borderAnchor[3] == "CENTER",
    "hung the border by its right edge off the icon's centre")
collectedPiece.scripts.OnEnter(collectedPiece)
assert(tooltip.owner == collectedPiece, "anchored the tooltip to the hovered piece")
assert(tooltip.appearanceData, "built a native appearance tooltip")
assert(tooltip.appearanceData.primarySourceID == collectedPiece.piece.sourceID,
    "passed the catalogued source as the primary one")
assert(#tooltip.appearanceData.sources > 0, "listed at least one source")
assert(tooltip.shown, "showed the tooltip")

local missingPiece = pieceButtons[2]
assert(missingPiece.piece.state == "missing", "second piece is missing")

-- The crosshair is put on by the same pass that lays the pieces out, so every
-- piece on show names the source its mark answers to.
assert(markedSources[missingPiece] == missingPiece.piece.sourceID,
    "handed the piece's source over to be marked when tracked")

assert(collectedPiece.border.alpha == 1 and missingPiece.border.alpha < 1,
    "faded the border with the piece it holds, rather than framing nothing brightly")
missingPiece.scripts.OnEnter(missingPiece)
assert(tooltip.appearanceData, "missing pieces still get the native tooltip")
assert(tooltip.lines[#tooltip.lines] == LuckysWardrobe.Strings.tracking.hint,
    "missing pieces mention shift-click tracking")

-- A piece already tracked says so, then the shift-click offers the way back out
-- rather than offering to track what is already tracked.
huntedSource = missingPiece.piece.sourceID
missingPiece.scripts.OnEnter(missingPiece)
assert(tooltip.lines[#tooltip.lines - 1] == "tracked", "a tracked piece says so when hovered")
assert(tooltip.lines[#tooltip.lines] == LuckysWardrobe.Strings.tracking.stopHint,
    "and offers the shift-click that stops")
huntedSource = nil

-- The tooltip offers Tab to cycle through the items sharing a look, and the
-- page's own key handler is what answers: the wardrobe's fields are the ones
-- this addon must never write, so the index lives on the page and the page
-- listens for the key itself. Sources 2003 and 2004 share one look, so this
-- piece has something to cycle to.
assert(wardrobe.tooltipCycle == nil and wardrobe.tooltipSourceIndex == nil,
    "wrote nothing on the wardrobe while a piece is hovered")
assert(page.keyboardEnabled, "listened for the key while a piece is hovered")
assert(page.tooltipCycle, "there are items to cycle through")
local firstIndex = page.tooltipSourceIndex
page.scripts.OnKeyDown(page, "TAB")
assert(page.tooltipSourceIndex == firstIndex + 1, "Tab moved on to the next item")
assert(tooltip.appearanceData.selectedIndex == firstIndex + 1, "and the tooltip was drawn again at it")
assert(page.propagateKeys == false, "kept the Tab it handled")
shiftDown = true
page.scripts.OnKeyDown(page, "TAB")
assert(tooltip.appearanceData.selectedIndex == firstIndex, "shift-Tab went back the other way")
shiftDown = false
page.scripts.OnKeyDown(page, "W")
assert(page.propagateKeys == true, "handed every other key straight back")

-- A look with a single item has nothing to cycle, and the offer is not made.
collectedPiece.scripts.OnEnter(collectedPiece)
assert(not page.tooltipCycle, "one item behind a look means nothing to cycle through")
page.scripts.OnKeyDown(page, "TAB")
assert(page.propagateKeys == true, "a Tab with nothing to cycle passes through")

-- Alt-click hands back a piece's Wowhead address, and shift-click still tracks.
toggledPiece = nil
altDown = true
missingPiece.scripts.OnClick(missingPiece, "LeftButton")
assert(linkedSource == missingPiece.piece.sourceID, "alt-click asked for the piece's address")
assert(toggledPiece == nil, "alt-click did not also track the piece")
altDown = false

-- The click is a toggle, and which way it goes is decided where tracking lives,
-- so the page only says which piece was clicked.
shiftDown = true
missingPiece.scripts.OnClick(missingPiece, "LeftButton")
assert(toggledPiece == missingPiece.piece.sourceID and toggledName == "Live Name",
    "shift-click hands a missing piece over to be tracked or untracked, named by its set")
shiftDown = false

-- Ctrl-click opens the dressing room wearing the piece, as the Sets tab does,
-- whether or not the appearance has been collected.
dressUp.held = true
collectedPiece.scripts.OnClick(collectedPiece, "LeftButton")
assert(dressUp.source == collectedPiece.piece.sourceID, "ctrl-click tried the piece on")
dressUp.source = nil
missingPiece.scripts.OnClick(missingPiece, "LeftButton")
assert(dressUp.source == missingPiece.piece.sourceID, "a piece not yet collected can still be tried on")

-- The claimed clicks come first and are not also a dressing-room click, so a
-- player who rebound the modifier onto one of them gets the one they set.
dressUp.source, toggledPiece = nil, nil
shiftDown = true
missingPiece.scripts.OnClick(missingPiece, "LeftButton")
assert(toggledPiece == missingPiece.piece.sourceID and dressUp.source == nil,
    "a shift-click that tracks does not also open the dressing room")
shiftDown = false
altDown = true
missingPiece.scripts.OnClick(missingPiece, "LeftButton")
assert(dressUp.source == nil, "an alt-click that hands back an address does not open it either")
altDown = false

-- The inspect cursor is the only sign the click is there, and it follows the
-- key rather than the hover: the modifier can go down over a still piece.
collectedPiece.scripts.OnEnter(collectedPiece)
collectedPiece.scripts.OnUpdate(collectedPiece)
assert(dressUp.cursor == "inspect", "held the inspect cursor over a hovered piece")
dressUp.held = false
collectedPiece.scripts.OnUpdate(collectedPiece)
assert(dressUp.cursor == nil, "and put it away when the key came up")

collectedPiece.scripts.OnLeave(collectedPiece)
assert(collectedPiece.scripts.OnUpdate == nil, "stopped watching the cursor once the piece was left")
assert(not tooltip.shown, "leaving a piece hides the tooltip")
assert(not page.keyboardEnabled, "let go of the keyboard once the piece was left")
assert(page.tooltipSourceIndex == nil,
    "dropped the index, so the next piece starts at its own item")

catalogRecords = { records[2] }
collectionUpdated()
local unavailablePiece
for _, frame in ipairs(pieceButtons) do
    if frame.piece and frame.piece.state == "unavailable" then unavailablePiece = frame end
end
assert(unavailablePiece, "found the unavailable piece")
unavailablePiece.scripts.OnEnter(unavailablePiece)
assert(tooltip.appearanceData == nil, "unavailable pieces skip the appearance tooltip")
assert(tooltip.lines[1] == LuckysWardrobe.Strings.extraSets.pieceUnavailable,
    "unavailable pieces say so honestly")
assert(tooltip.shown, "unavailable pieces still show a tooltip")

-- There is no look left behind an unavailable piece, so the ctrl-click has
-- nothing to try on and opens no empty dressing room.
dressUp.held = true
dressUp.source = nil
unavailablePiece.scripts.OnClick(unavailablePiece, "LeftButton")
assert(dressUp.source == nil, "left the dressing room shut for a piece the client no longer knows")
dressUp.held = false

-- Sets this character cannot wear. The client works that out from the items
-- behind the pieces, which it loads only once asked, and a piece it has not
-- loaded yet answers no. Reading a set cold therefore calls every set
-- unwearable, and the sets that arrive cold are the ones this character can
-- wear: building the list only asks the client about the pieces it declines to
-- judge. So the page says nothing until the items land, and says it then.

local noticeFont
for _, fontString in ipairs(createdFontStrings) do
    if fontString.points[1] and fontString.points[1][1] == "BOTTOM" then noticeFont = fontString end
end
assert(noticeFont, "found the notice line under the model")

sourceStates[4001] = { appearanceID = 9401, collected = true, itemID = 44001 }
sourceStates[4002] = { appearanceID = 9402, collected = true, itemID = 44002, unwearable = true }
catalogRecords = {
    validRecord({
        setID = 40,
        name = "Cold Set",
        pieces = pieces({ "HEAD", 4001, 44001 }, { "CHEST", 4002, 44002 }),
    }),
}
requestedItems = {}
collectionUpdated()
assert(not noticeFont.shown, "a set read before its items arrive is not called unwearable")
assert(#requestedItems == 2, "asked the client for the items behind the pieces")

loadedItems[44001], loadedItems[44002] = "Cold Helm", "Cold Chest"
runTimers()
assert(noticeFont.shown and noticeFont.text == LuckysWardrobe.Strings.extraSets.notUsable,
    "said so once the client could answer")

-- A set the client turns down over faction is the one a player is most likely
-- to be puzzled by, since nothing about it looks out of reach: it is the right
-- armour, it is nobody's class, and the character simply plays the other side.
sourceStates[4002].useErrorType = Enum.TransmogUseErrorType.Faction
sourceStates[4002].useError = "Requires Alliance"
collectionUpdated()
runTimers()
assert(noticeFont.text == "This set is not one your character can wear. It belongs to the Alliance.",
    "named the faction the set belongs to rather than leaving the player guessing")

sourceStates[4002].useErrorType = Enum.TransmogUseErrorType.PlayerCondition
collectionUpdated()
runTimers()
assert(noticeFont.text == "This set is not one your character can wear. Requires Alliance",
    "a refusal the page cannot name is quoted in the client's own words")

requestedItems = {}
sourceStates[4002].useErrorType, sourceStates[4002].useError = nil, nil
sourceStates[4002].unwearable = nil
collectionUpdated()
assert(not noticeFont.shown, "a set this character can wear says nothing")
assert(#requestedItems == 0, "items the client already holds are not asked for again")

sourceStates[4001], sourceStates[4002] = nil, nil
catalogRecords = { records[1] }
collectionUpdated()

-- Long set names. The Sets tab shrinks the name to keep it on one line, and
-- only wraps it, smaller again, when even that will not fit. A name left to
-- wrap by itself pushes the label and the pieces down the page.

local nameFont, longNameFont
for _, fontString in ipairs(createdFontStrings) do
    if fontString.maxLines == 1 then nameFont = fontString end
    if fontString.maxLines == 2 then longNameFont = fontString end
end
assert(nameFont and longNameFont, "built both the one-line name and the wrapped fallback")
assert(nameFont.scaled and nameFont.text == "Live Name", "scaled the name to fit the line it has")
assert(nameFont.minLineHeight == 16, "let it shrink only as far as the Sets tab does")
assert(nameFont.shown and not longNameFont.shown, "a name that fits keeps its one line")

-- The label hangs off whichever name is on screen, since the two sit at
-- different heights.
local function fontAnchoredTo(target)
    for _, fontString in ipairs(createdFontStrings) do
        local anchor = fontString.points[1]
        if anchor and anchor[2] == target then return fontString end
    end
end
assert(fontAnchoredTo(nameFont), "hung the label under the one-line name")

nameFont.truncated = true
collectionUpdated()
assert(not nameFont.shown and longNameFont.shown, "a name too long even shrunk wraps instead")
assert(longNameFont.text == "Live Name", "the wrapped name is the same name")
assert(fontAnchoredTo(longNameFont), "the label followed it")

nameFont.truncated = false
collectionUpdated()
assert(nameFont.shown and not longNameFont.shown, "and the next set that fits goes back to one line")

-- Filter menu, mirroring the Sets tab.

local filterButton = findFrame(function(frame) return frame.template == "WowStyle1FilterDropdownTemplate" end)
assert(filterButton, "created the native-style filter button")
assert(type(filterButton.menuBuilder) == "function", "attached the filter menu")
assert(filterButton.isDefaultCheck(), "filters start in the default state")

records[1].expansionID = 3
sourceStates[2003].collected = true
sourceStates[2004].collected = true
catalogRecords = { records[1], records[2] }
collectionUpdated()
assert(#scrollBox.dataProvider == 2, "both sets are on screen before filtering")
assert(scrollBox.dataProvider[1].expansionID == 3, "entries carry their expansion")

local toggles = {}
local radioSetters = {}
local expansionToggles = {}
local submenuToggles = {}
local menuActions = {}
local function submenu(label)
    return {
        CreateCheckbox = function(_, boxLabel, _isChecked, toggle)
            if label == "Expansion" then expansionToggles[boxLabel] = toggle end
            submenuToggles[label] = submenuToggles[label] or {}
            submenuToggles[label][boxLabel] = toggle
        end,
        CreateRadio = function(_, radioLabel, _isSelected, setSelected)
            radioSetters[label] = radioSetters[label] or {}
            radioSetters[label][radioLabel] = setSelected
        end,
        CreateButton = function(_, buttonLabel, callback)
            menuActions[label] = menuActions[label] or {}
            menuActions[label][buttonLabel] = callback
        end,
        CreateDivider = function() end,
    }
end
local menuRoot = {
    CreateCheckbox = function(_, label, _isChecked, toggle) toggles[label] = toggle end,
    CreateDivider = function() end,
    CreateButton = function(_, label) return submenu(label) end,
}
filterButton.menuBuilder(nil, menuRoot)
assert(toggles[COLLECTED] and toggles[NOT_COLLECTED], "offered the collected checkboxes")

toggles[NOT_COLLECTED]()
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].key == 20,
    "hiding Not Collected leaves only the complete set")
assert(progressBar.value == 1 and progressBar.max == 1, "the progress bar counts only what filters leave")
assert(not filterButton.isDefaultCheck(), "narrowed filters are no longer the default")
toggles[NOT_COLLECTED]()

toggles[COLLECTED]()
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].key == 500,
    "hiding Collected leaves only the incomplete set")
toggles[COLLECTED]()

-- The record carries expansionID 3, so it is the box labelled "Expansion 3"
-- that hides it. Keying the filter as a 1-based array put every set one
-- expansion out of step with its own checkbox.
assert(expansionToggles.Unknown, "offered an Unknown box for the sets the client will not date")
expansionToggles["Expansion 3"]()
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].key == 500,
    "unchecking a set's expansion hides it and leaves the undated set to its own box")

expansionToggles["Expansion 3"]()
expansionToggles.Unknown()
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].key == 20,
    "and unchecking Unknown hides the undated set instead, leaving the dated one")

menuActions.Expansion[UNCHECK_ALL]()
assert(#scrollBox.dataProvider == 0, "unchecking every expansion empties the list")

filterButton.defaultReset()
assert(#scrollBox.dataProvider == 2, "resetting filters restores the list")
assert(filterButton.isDefaultCheck(), "reset filters read as the default state")

-- The Source submenu, as the menu actually builds it. The page reaches the
-- filter through the same builder the client calls, so a box that is not
-- offered here is not offered in game either.
assert(submenuToggles.Source, "offered a Source submenu")
for _, sourceName in ipairs({ "Crafted", "Drop", "PvP", "Quest", "Vendor" }) do
    assert(submenuToggles.Source[sourceName], "offered a box for " .. sourceName)
end

-- Neither set in this page carries a source, so unchecking one must leave both:
-- a set no box describes is not hidden by that box.
submenuToggles.Source.Drop()
assert(#scrollBox.dataProvider == 2, "unchecking one source keeps the sets no box describes")
assert(not filterButton.isDefaultCheck(), "a narrowed source reads as narrowed")
submenuToggles.Source.Drop()

-- Unchecking every source empties the list, which is what proves the menu is
-- wired to the filter rather than merely drawn.
menuActions.Source[UNCHECK_ALL]()
assert(#scrollBox.dataProvider == 0, "unchecking every source empties the list")
menuActions.Source[CHECK_ALL]()
assert(#scrollBox.dataProvider == 2, "checking them again restores it")
assert(filterButton.isDefaultCheck(), "and reads as the default state once more")

radioSetters["Sort By"].Completion()
assert(scrollBox.dataProvider[1].key == 20, "completion sort puts the complete set first")
radioSetters["Sort Direction"].Descending()
assert(scrollBox.dataProvider[1].key == 500, "descending inverts the completion order")
radioSetters["Sort Direction"].Ascending()
radioSetters["Sort By"].Name()
assert(scrollBox.dataProvider[1].key == 20, "name sort puts Live Name before Loading Set")
radioSetters["Sort By"][DEFAULT]()

-- The class dropdown, which is what keeps this page down to a list a character
-- has some use for. It is Blizzard's own control, shared with the Sets tab, so
-- the two pages can never disagree about which class they are showing.

local classDropdown = wardrobe.ClassDropdown
-- The colourway picker inside the details pane is a dropdown too, so this asks
-- specifically that no second class dropdown was hung on the page itself.
assert(not findFrame(function(frame)
    return frame.template == "WowStyle1DropdownTemplate" and frame.parent == page
end), "built no class dropdown of its own")
assert(classDropdown.shown, "kept the native dropdown on screen for this page")
assert(#classDropdown.points == 1, "gave the dropdown a single anchor")
local classAnchor = classDropdown.points[1]
assert(classAnchor[1] == "BOTTOMRIGHT" and classAnchor[2] == page and classAnchor[3] == "TOPRIGHT",
    "hung it above the page, where the Sets tab has it, rather than inside it")

local classRadios = {}
classDropdown.menuBuilder(nil, {
    CreateRadio = function(_, label, isSelected, setSelected, data)
        classRadios[#classRadios + 1] = { label = label, isSelected = isSelected, select = setSelected, data = data }
    end,
})
assert(#classRadios == 13, "listed every class")
assert(classRadios[CLOTH_CLASS].isSelected(classRadios[CLOTH_CLASS].data),
    "opened on the class the Sets tab is showing")
assert(#scrollBox.dataProvider == 2, "both fixture sets belong to that class")

-- Class 8 is another cloth class, so it keeps the set named for nobody and
-- loses the one named for class 5.
classRadios[8].select(classRadios[8].data)
assert(C_TransmogSets.GetTransmogSetsClassFilter() == 8, "wrote the choice to the filter the Sets tab reads")
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].key == 20,
    "choosing another class drops the sets named for the old one")

-- Class 1 wears plate, so neither fixture is any use to it.
classRadios[1].select(classRadios[1].data)
assert(#scrollBox.dataProvider == 0, "a class that wears neither armour type sees neither set")

-- A class chosen on the Sets tab is the class this page opens on.
wardrobe:SetTab(2)
classDropdown:SetClassFilter(CLOTH_CLASS)
extraTab.scripts.OnClick()
page.scripts.OnShow(page)
assert(#scrollBox.dataProvider == 2, "opened on the class the Sets tab was left showing")

-- Duplicates of the Sets tab, on the page rather than in the pure rules.

records[1].officialClassMask = clothBit
collectionUpdated()
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].key == 500,
    "dropped the row the Sets tab is already showing this class")
classRadios[8].select(classRadios[8].data)
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].key == 20,
    "kept it for a class the Sets tab does not list it for")
records[1].officialClassMask = nil

-- Colourways on the page: one row per set however many tints it has, with the
-- details pane picking between them the way the Sets tab does.

catalogRecords = colourwayRecords
collectionUpdated()
assert(#scrollBox.dataProvider == 2, "the page lists one row per set, not one per listing")

local groupButton = newRowButton()
capturedView.initializer(groupButton, scrollBox.dataProvider[1])
assert(groupButton.Name.text == "Charm Vestments", "the row is named for the set, not a colourway")
assert(groupButton.Label.text == "4/6 collected",
    "and counts every look across its colourways rather than the first one's")
assert(groupButton.luckysVariantCount.text == "x2",
    "with how many colourways it holds in the corner, where it costs the counts no room")

local variantDropdown = findFrame(function(frame) return frame.template == "WowStyle1DropdownTemplate" end)
assert(variantDropdown, "built a colourway picker for the details pane")
assert(variantDropdown.shown, "a set with several colourways offers it")
assert(variantDropdown.text == "Heroic Recolor (3/3)", "opening on the first, named for what tells it apart")
assert(nameFont.text == "Charm Vestments (Heroic Recolor)", "and the pane shows that colourway")

local variantRadios = {}
variantDropdown.menuBuilder(nil, {
    CreateRadio = function(_, label, isSelected, select)
        variantRadios[#variantRadios + 1] = { label = label, isSelected = isSelected, select = select }
    end,
})
assert(#variantRadios == 2, "the picker lists every colourway")
assert(variantRadios[1].label == "Heroic Recolor (3/3)" and variantRadios[2].label == "Normal Recolor (1/3)",
    "each with what is collected of it, as the Sets tab shows its own variants")
assert(variantRadios[1].isSelected() and not variantRadios[2].isSelected(), "the one on show is the one ticked")

variantRadios[2].select()
assert(nameFont.text == "Charm Vestments (Normal Recolor)", "picking a colourway shows it")
assert(variantDropdown.text == "Normal Recolor (1/3)", "and the picker says which one that is")
assert(#scrollBox.dataProvider == 2, "picking a colourway never changes the list")

-- A set that only ever had one look has nothing to pick between.
local plainButton = newRowButton()
capturedView.initializer(plainButton, scrollBox.dataProvider[2])
plainButton.scripts.OnClick(plainButton, "LeftButton")
assert(not variantDropdown.shown, "a set with a single look offers no picker")
assert(nameFont.text == "Other Garb (Heroic Recolor)", "and shows itself")

capturedView.initializer(groupButton, scrollBox.dataProvider[1])
groupButton.scripts.OnClick(groupButton, "LeftButton")
assert(nameFont.text == "Charm Vestments (Normal Recolor)",
    "coming back to a set keeps the colourway last picked")

-- Shift-clicking a set goes after everything left in it, across every colourway,
-- which is what the row's own count promised.
shiftDown = true
groupButton.scripts.OnClick(groupButton, "LeftButton")
assert(#trackedSources == 2 and trackedName == "Charm Vestments",
    "tracked what is missing from every colourway of the set")
shiftDown = false

searchBox.text = "Normal Lookalike"
searchBox.scripts.OnTextChanged()
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].setID == 603,
    "a name folded into another row still finds that row")

searchBox.text = "Charm"
searchBox.scripts.OnTextChanged()
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].isGroup,
    "a search keeping both colourways still shows the one row for the set")
searchBox.text = ""
searchBox.scripts.OnTextChanged()

-- The progress bar counts sets to collect: three survive the folding, two of
-- them finished.
assert(progressBar.value == 2 and progressBar.max == 3, "counted the sets left after folding, not the listings")

-- The Sets tab's own looks, on the page: the catalogue names the looks the tab
-- lists the chosen class, and the listings wearing them never become rows.

catalogLooks = {
    { setID = 901, name = "Charm Vestments", appearances = { [9501] = true, [9502] = true, [9503] = true } },
}
collectionUpdated()
assert(#scrollBox.dataProvider == 2, "the tab's colourway is gone from the list")
assert(scrollBox.dataProvider[1].setID == 603 and not scrollBox.dataProvider[1].isGroup,
    "the colourway the tab does not show goes back to a plain row")
local pageFolds = ExtraSets.NativeFolds()
assert(#pageFolds == 2 and pageFolds[1].setID == 601 and pageFolds[2].setID == 602,
    "the page answers for what it folded behind the Sets tab")
assert(pageFolds[1].nativeName == "Charm Vestments", "naming the tab's set that holds the look")

searchBox.text = "Heroic Recolor"
searchBox.scripts.OnTextChanged()
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].setID == 605,
    "searching for a folded listing finds only sets still on the page")
searchBox.text = ""
searchBox.scripts.OnTextChanged()

catalogLooks = {}
collectionUpdated()
assert(#scrollBox.dataProvider == 2 and scrollBox.dataProvider[1].isGroup,
    "a tab that stops listing the look hands the row back")
assert(#ExtraSets.NativeFolds() == 0, "and nothing is folded behind it any more")

-- The looks dump, which is what says why a set did or did not fold: every
-- bundled set matching the query as the client resolves it, beside every
-- same-named set the Sets tab lists, all as plain appearance IDs.

catalogReport = { official = { [901] = "Charm Vestments", [902] = "Charm Vestments", [903] = "Elsewhere Garb" } }
setPrimaryAppearances[901] = {
    { appearanceID = 9501, collected = true },
    { appearanceID = 9502, collected = true },
    { appearanceID = 9503, collected = true },
}
local looksPrinted = {}
local realPrint = print
print = function(line) looksPrinted[#looksPrinted + 1] = line end
ExtraSets:PrintLooks("charm vestments")
print = realPrint
local looksText = table.concat(looksPrinted, "\n")
assert(looksText:find("set 601: Charm Vestments %(Heroic Recolor%): 9501,9502,9503", 1, false),
    "a bundled set's line carries the appearance IDs the client resolved for it")
assert(looksText:find("Sets tab set 901: Charm Vestments: 9501,9502,9503", 1, false),
    "a Sets tab set's line carries the appearance IDs the client counts for it")
assert(looksText:find("Sets tab set 902: Charm Vestments: nothing resolved yet", 1, false),
    "a Sets tab set the client answers no looks for says so rather than vanishing")
assert(not looksText:find("Elsewhere"), "only names matching the query are dumped")

-- The variants dump, which is what says whether a family of colourways is one
-- the client already groups or one this page would have to infer.

local variantsPrinted = {}
print = function(line) variantsPrinted[#variantsPrinted + 1] = line end
ExtraSets:PrintVariants("charm vestments")
print = realPrint
local variantsText = table.concat(variantsPrinted, "\n")
assert(variantsText:find("set 601: Charm Vestments %(Heroic Recolor%): base set 601, variants 601, 603", 1, false),
    "a set the client groups says which base it belongs to and what it groups with")
assert(variantsText:find("set 602: Charm Vestments %(Heroic Lookalike%): base set none, variants none", 1, false),
    "and one it says nothing about says nothing, which is the answer too")
assert(not variantsText:find("Distinct Regalia"), "only names matching the query are dumped")

do
local coloursPrinted, coloursText

-- The colours dump. The grouping is read off names rather than supplied by the
-- client, so being able to read every family it formed in one go is what makes
-- a family that has taken in the wrong set findable.

catalogRecords = {
    colourway(801, "Midnight Sweatsuit", { 7001, 7002 }),
    colourway(802, "Azure Sweatsuit", { 7003, 7004 }),
    colourway(803, "Standalone Cowl", { 7005 }),
}
catalogRecords[1].ensembles = { 79101 }
catalogRecords[2].ensembles = { 79102 }
catalogRecords[3].ensembles = { 79103 }
ExtraSets.InvalidateEntries()
coloursPrinted = {}
print = function(line) coloursPrinted[#coloursPrinted + 1] = line end
ExtraSets:PrintColourFamilies()
print = realPrint
coloursText = table.concat(coloursPrinted, "\n")
assert(coloursText:find("1 family", 1, true), "counted the families it formed")
assert(coloursText:find("Sweatsuit: 2 colours of 2 piece(s): Midnight, Azure", 1, true),
    "named the family, its size, and the word each colourway answers to")
assert(coloursText:find("2 set(s) folded into 1 row(s)", 1, true), "and said how much of the list it moved")
assert(not coloursText:find("Standalone"), "a set in no family is not in the dump")

catalogRecords = {}
ExtraSets.InvalidateEntries()
coloursPrinted = {}
print = function(line) coloursPrinted[#coloursPrinted + 1] = line end
ExtraSets:PrintColourFamilies()
print = realPrint
assert(table.concat(coloursPrinted, "\n"):find("No sets were grouped", 1, true),
    "a list with no family in it says so rather than printing a bare header")
end

print("Lucky's Wardrobe extra sets tests passed")
