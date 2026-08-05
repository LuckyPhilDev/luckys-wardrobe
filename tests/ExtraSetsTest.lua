-- luacheck: globals AutoScalingFontStringMixin CHECK_ALL COLLECTED CollectionWardrobeUtil CreateFrame CreateDataProvider CreateScrollBoxListLinearView DEFAULT EventUtil GameTooltip GetUICameraInfo IsShiftKeyDown IsUnitModelReadyForUI LuckysWardrobe MenuResponse Mixin Model_ApplyUICamera NOT_COLLECTED PanelTemplates_ResizeTabsToFit PanelTemplates_SetNumTabs PanelTemplates_TabResize PlaySound QUESTION_MARK_ICON SOUNDKIT ScrollBoxConstants ScrollUtil UNCHECK_ALL UnitClass WardrobeCollectionFrame WardrobeSetsDetailsModelMixin hooksecurefunc GetNumClasses C_ClassColor C_CreatureInfo C_TransmogSets C_TransmogCollection C_Item C_Timer

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
dofile("src/Data/ExtraSetsData.lua")
dofile("src/Classes.lua")
-- The page measures its own work, so the real stopwatch runs here too, wound
-- by hand rather than by the clock the client would provide.
dofile("src/Perf.lua")
local clock = 0
LuckysWardrobe.Perf.Clock = function()
    clock = clock + 1
    return clock
end
dofile("src/ExtraSets.lua")

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

-- Search.

assert(#ExtraSets.FilterEntries(entries, "") == 3, "blank query keeps everything")
assert(#ExtraSets.FilterEntries(entries, "  live  ") == 1, "matched trimmed case-insensitive names")
assert(#ExtraSets.FilterEntries(entries, "FIXTURE") == 1, "matched labels")
assert(#ExtraSets.FilterEntries(entries, "nothing") == 0, "unmatched query empties the list")

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

-- Collected, armour type, and expansion filters.

assert(ExtraSets.IsComplete({ loading = false, total = 2, collected = 2 }), "a full set counts as complete")
assert(not ExtraSets.IsComplete({ loading = true, total = 2, collected = 2 }), "loading sets are not complete yet")
assert(not ExtraSets.IsComplete({ loading = false, total = 0, collected = 0 }), "empty sets are never complete")

local completeEntry = { loading = false, total = 2, collected = 2, expansionID = 2, armorType = CLOTH }
local partialEntry = { loading = false, total = 2, collected = 1, expansionID = 2, armorType = CLOTH }
local unknownEntry = { loading = false, total = 3, collected = 0, armorType = LEATHER }
local filterEntries = { completeEntry, partialEntry, unknownEntry }
local filterState = { collected = true, uncollected = true, expansions = { true, true } }

assert(#ExtraSets.ApplyFilters(filterEntries, filterState) == 3, "default filters keep everything")
filterState.collected = false
local uncollectedOnly = ExtraSets.ApplyFilters(filterEntries, filterState)
assert(#uncollectedOnly == 2 and uncollectedOnly[1] == partialEntry, "unchecking Collected hides complete sets")
filterState.collected = true
filterState.uncollected = false
local collectedOnly = ExtraSets.ApplyFilters(filterEntries, filterState)
assert(#collectedOnly == 1 and collectedOnly[1] == completeEntry, "unchecking Not Collected hides incomplete sets")
filterState.uncollected = true
filterState.expansions = { true, false }
local narrowedExpansions = ExtraSets.ApplyFilters(filterEntries, filterState)
assert(#narrowedExpansions == 1 and narrowedExpansions[1] == unknownEntry,
    "expansion narrowing hides matching sets but keeps unclassifiable ones")
filterState.expansions = { false, false }
assert(#ExtraSets.ApplyFilters(filterEntries, filterState) == 0, "unchecking every expansion empties the list")
filterState.expansions = { true, true }

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
    function fontString:SetWidth() end
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
    function texture:Hide() self.shown = false end
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
    function frame:SetFrameStrata() end
    function frame:SetFrameLevel(level) self.frameLevel = level end
    function frame:GetFrameLevel() return self.frameLevel end
    function frame:EnableMouse() end
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
function IsUnitModelReadyForUI() return true end
function UnitClass() return "Class 5", "CLASS5", CLOTH_CLASS end
function Model_ApplyUICamera() end
function GetUICameraInfo() return 0, 0, 0, 0 end
function PanelTemplates_SetNumTabs(frame, count) frame.numTabs = count end
function PanelTemplates_TabResize() end
local resizeWidth
function PanelTemplates_ResizeTabsToFit(_, width) resizeWidth = width end

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
C_TransmogSets = {
    GetCameraIDs = function() return nil end,
    GetSetInfo = function(setID) return setID == 20 and { name = "Live Name" } or nil end,
    GetTransmogSetsClassFilter = function() return setsClassFilter end,
    SetTransmogSetsClassFilter = function(classID) setsClassFilter = classID end,
    GetSetPrimaryAppearances = function(setID) return setPrimaryAppearances[setID] end,
}
-- Item data arrives from the server, so the client holds it only once asked.
local loadedItems = {}
local requestedItems = {}

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
LuckysWardrobe.SetTracking = {
    TrackSources = function(_, sourceIDs, setName)
        trackedSources, trackedName = sourceIDs, setName
    end,
}

local ctrlDown = false
local linkedSource
LuckysWardrobe.WowheadLink = {
    HandlesClick = function(_, buttonName) return ctrlDown and buttonName == "LeftButton" end,
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

local wardrobe
wardrobe = {
    name = "WardrobeCollectionFrame",
    frameLevel = 20,
    numTabs = 2,
    selectedCollectionTab = 1,
    ItemsCollectionFrame = visibilityFrame(true),
    SetsCollectionFrame = visibilityFrame(false),
    SearchBox = visibilityFrame(true),
    FilterButton = visibilityFrame(true),
    ClassDropdown = nativeClassDropdown(),
    progressBar = nativeProgressBar(),
    ContentFrames = {},
    GetName = function(self) return self.name end,
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

function wardrobe:HideAppearanceTooltip()
    self.tooltipContentFrame = nil
    self.tooltipCycle = nil
    self.tooltipSourceIndex = nil
    GameTooltip:Hide()
end

-- Blizzard's own key handler, the one thing that makes Tab cycle a tooltip: it
-- walks the source index and asks the frame that owns the tooltip to draw
-- itself again.
function wardrobe:OnKeyDown(key)
    if not (self.tooltipCycle and key == "TAB") then return end

    self.tooltipSourceIndex = self.tooltipSourceIndex + (IsShiftKeyDown() and -1 or 1)
    self.tooltipContentFrame:RefreshAppearanceTooltip()
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
assert(extraTab.name == "WardrobeCollectionFrameTab3" and extraTab.id == 3, "followed native tab naming and IDs")
assert(extraTab.text == "Extra Sets", "labelled the subtab")
assert(wardrobe.numTabs == 3, "registered exactly one extra subtab")
assert(wardrobe.ContentFrames[1] == page, "joined the native content lifecycle")
assert(page.searchType == wardrobe.SetsCollectionFrame.searchType, "kept the native search-event contract")
assert(resizeWidth ~= nil, "made room for the third tab")
assert(capturedView.template == "WardrobeSetsScrollFrameButtonTemplate", "reused the native sets row template")

-- The page answers collection events on the next frame, so every test that
-- fires one lets that frame end.
local function collectionUpdated()
    page.scripts.OnEvent(page, "TRANSMOG_COLLECTION_UPDATED")
    runTimers()
end

-- The third tab reaches into where Blizzard parked the progress bar, so both
-- the native bar and the addon's own copy move past the end of the tab strip.
-- Nothing has been laid out on screen yet, so there is no gap to measure.

for _, bar in ipairs({ wardrobe.progressBar, page.progressBar }) do
    assert(#bar.points == 1, "gave the progress bar a single anchor")
    local point, relativeTo, relativePoint, x = bar:GetPoint()
    assert(point == "TOP" and relativeTo == extraTab and relativePoint == "TOPRIGHT",
        "anchored the progress bar to the end of the tab strip")
    assert(x - bar.width / 2 > 0, "kept the whole bar past the end of the tab strip")
    assert(bar.width < NATIVE_PROGRESS_BAR_WIDTH, "narrowed the progress bar to clear the class dropdown")
    assert(bar.border.width > bar.width, "kept the border art framing the narrowed bar")
end

-- Tab switching. Everything the bar sits between has landed on screen by the
-- time a tab is clicked, so the gap can be measured from here on.

local TAB_STRIP_RIGHT = 400
extraTab.right = TAB_STRIP_RIGHT
wardrobe.SearchBox.left = ITEMS_SEARCH_BOX_LEFT

extraTab.scripts.OnClick()
assert(wardrobe.selectedCollectionTab == 3 and page.shown, "selected and showed Extra Sets")
assert(not wardrobe.ItemsCollectionFrame.shown and not wardrobe.SetsCollectionFrame.shown, "hid native pages")
assert(not wardrobe.SearchBox.shown and not wardrobe.FilterButton.shown, "hid native-only controls")
assert(not wardrobe.progressBar.shown, "hid the rest of the native controls")
assert(wardrobe.ClassDropdown.shown, "kept the native class dropdown, which this page shares")
assert(wardrobe.activeFrame == page, "became the active Appearances page")
assert(playedSound == SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "used the native tab sound")

-- Resizing the strip measured the gap again, and this time the bar could centre
-- itself in it rather than hug the end of the strip.
for _, bar in ipairs({ wardrobe.progressBar, page.progressBar }) do
    local _, _, _, x = bar:GetPoint()
    assert(x == (SETS_CLASS_DROPDOWN_LEFT - TAB_STRIP_RIGHT) / 2,
        "centred the bar in the gap between the tab strip and the class dropdown")
    assert(x + bar.width / 2 < SETS_CLASS_DROPDOWN_LEFT - TAB_STRIP_RIGHT, "left the class dropdown clear")
end

wardrobe:SetTab(4)
assert(not page.shown and not wardrobe.SearchBox.shown, "left unknown third-party tabs alone")

wardrobe:SetTab(2)
assert(not page.shown and wardrobe.SetsCollectionFrame.shown, "restored the native Sets page")
assert(wardrobe.SearchBox.shown and wardrobe.FilterButton.shown and wardrobe.ClassDropdown.shown, "restored native controls")
assert(wardrobe.SetTab ~= originalSetTab, "hooked rather than replaced SetTab")

-- The Items tab hands the corner to its search box and sends the class dropdown
-- to the far left, where measuring it would put the bar under the tab strip.
wardrobe:SetTab(1)
for _, bar in ipairs({ wardrobe.progressBar, page.progressBar }) do
    local _, _, _, x = bar:GetPoint()
    assert(x == (ITEMS_SEARCH_BOX_LEFT - TAB_STRIP_RIGHT) / 2,
        "centred the bar against whichever control shares its row")
    assert(x - bar.width / 2 > 0, "kept the whole bar past the end of the tab strip")
end

ExtraSets:Attach(wardrobe)
assert(wardrobe.numTabs == 3, "attach is idempotent")

-- Catalogue lifecycle: building state first, then a repaint when the
-- catalogue lands while the page is open.

local scrollBox = findFrame(function(frame) return frame.template == "WowScrollBoxList" end)
catalogReady = false
wardrobe:SetTab(3)
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
    }
    rowButton.IconFrame.SetScript = rowButton.SetScript
    return rowButton
end

local button = newRowButton()
capturedView.initializer(button, entry)
assert(button.Name.text == "Live Name", "row shows the set name")

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
button.scripts.OnClick(button, "LeftButton")
assert(#trackedSources == 2, "both missing sources are tracked")
shiftDown = false

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
assert(collectedPiece.border.alpha == 1 and missingPiece.border.alpha < 1,
    "faded the border with the piece it holds, rather than framing nothing brightly")
missingPiece.scripts.OnEnter(missingPiece)
assert(tooltip.appearanceData, "missing pieces still get the native tooltip")
assert(tooltip.lines[#tooltip.lines] == LuckysWardrobe.Strings.extraSets.trackHint,
    "missing pieces mention shift-click tracking")

-- The tooltip offers Tab to cycle through the items sharing a look, and the
-- wardrobe's key handler is what answers: it moves the index and asks the frame
-- that owns the tooltip to draw it again. Sources 2003 and 2004 share one look,
-- so this piece has something to cycle to.
assert(wardrobe.tooltipContentFrame == page, "claimed the tooltip while a piece is hovered")
assert(wardrobe.tooltipCycle, "told the wardrobe there are items to cycle through")
local firstIndex = wardrobe.tooltipSourceIndex
wardrobe:OnKeyDown("TAB")
assert(wardrobe.tooltipSourceIndex == firstIndex + 1, "Tab moved on to the next item")
assert(tooltip.appearanceData.selectedIndex == firstIndex + 1, "and the tooltip was drawn again at it")
shiftDown = true
wardrobe:OnKeyDown("TAB")
assert(tooltip.appearanceData.selectedIndex == firstIndex, "shift-Tab went back the other way")
shiftDown = false

-- A look with a single item has nothing to cycle, and the offer is not made.
collectedPiece.scripts.OnEnter(collectedPiece)
assert(not wardrobe.tooltipCycle, "one item behind a look means nothing to cycle through")

-- Ctrl-click hands back a piece's Wowhead address, and shift-click still tracks.
trackedSources = nil
ctrlDown = true
missingPiece.scripts.OnClick(missingPiece, "LeftButton")
assert(linkedSource == missingPiece.piece.sourceID, "ctrl-click asked for the piece's address")
assert(trackedSources == nil, "ctrl-click did not also track the piece")
ctrlDown = false

shiftDown = true
missingPiece.scripts.OnClick(missingPiece, "LeftButton")
assert(trackedSources and trackedSources[1] == missingPiece.piece.sourceID,
    "shift-click still tracks a missing piece")
shiftDown = false

collectedPiece.scripts.OnLeave(collectedPiece)
assert(not tooltip.shown, "leaving a piece hides the tooltip")
assert(wardrobe.tooltipContentFrame == nil and wardrobe.tooltipSourceIndex == nil,
    "handed the tooltip back, so the next piece starts at its own item")

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

requestedItems = {}
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
local menuActions = {}
local function submenu(label)
    return {
        CreateCheckbox = function(_, boxLabel, _isChecked, toggle)
            if label == "Expansion" then expansionToggles[boxLabel] = toggle end
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
expansionToggles["Expansion 3"]()
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].key == 500,
    "unchecking a set's expansion hides it but keeps unclassifiable sets")
menuActions.Expansion[UNCHECK_ALL]()
assert(#scrollBox.dataProvider == 0, "unchecking every expansion empties the list")

filterButton.defaultReset()
assert(#scrollBox.dataProvider == 2, "resetting filters restores the list")
assert(filterButton.isDefaultCheck(), "reset filters read as the default state")

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
wardrobe:SetTab(3)
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
assert(groupButton.Label.text == "2 colours", "and says how many colourways it holds without being opened")

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

print("Lucky's Wardrobe extra sets tests passed")
