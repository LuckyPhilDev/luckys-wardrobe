-- luacheck: globals CreateFrame GetBuildInfo GetNumClasses GetClassInfo LuckysWardrobe C_TransmogSets C_TransmogCollection C_Item
-- luacheck: ignore 121

LuckysWardrobe = {}

local devLogs = {}
LuckysWardrobe.DevLog = function(message) devLogs[#devLogs + 1] = message end

-- Stubbed client world. Every name and ID is invented for this test; the shapes
-- mirror the documented Blizzard APIs the catalogue consumes.

local stepHandler
function CreateFrame()
    return {
        SetScript = function(_, script, handler)
            assert(script == "OnUpdate", "the build paces itself with OnUpdate")
            stepHandler = handler
        end,
    }
end

function GetBuildInfo() return "12.0.7", "68887", "Aug 4 2026", 120007 end
function GetNumClasses() return 2 end
function GetClassInfo(classID) return "Fixture Class " .. classID end

-- itemID -> equipment location. An item missing here is one this client never
-- shipped, which is how a snapshot taken from a later build reaches us.
local items = {
    [61001] = "INVTYPE_HEAD", [61002] = "INVTYPE_CHEST",
    [62001] = "INVTYPE_HEAD", [62002] = "INVTYPE_SHOULDER",
    [62003] = "INVTYPE_ROBE", [62004] = "INVTYPE_LEGS",
    [62101] = "INVTYPE_CHEST", [62102] = "INVTYPE_ROBE", [62103] = "INVTYPE_HEAD",
    [62301] = "INVTYPE_HEAD", [62302] = "INVTYPE_CHEST", [62303] = "INVTYPE_SHOULDER",
    [64001] = "INVTYPE_HEAD", [64002] = "INVTYPE_CHEST", [64003] = "INVTYPE_WEAPON",
    [64101] = "INVTYPE_HEAD", [64102] = "INVTYPE_CHEST",
    [65001] = "INVTYPE_HEAD", [65002] = "INVTYPE_CHEST", [65003] = "INVTYPE_LEGS",
    [65004] = "INVTYPE_CLOAK",
    [66001] = "INVTYPE_TABARD", [66002] = "INVTYPE_BODY",
}

-- itemID -> the armour subclass the client calls it, where it is not cloth.
-- The cloak is cloth like every other cloak, which is exactly why a set holding
-- one is not a cloth set on account of it.
local itemArmour = {
    [64001] = 4, [64002] = 4,
    [65001] = 4, [65002] = 4, [65003] = 4,
    -- Tabards and shirts are the client's miscellaneous armour: nobody's
    -- armour type in particular.
    [66001] = 0, [66002] = 0,
}

-- itemID -> { appearanceID, sourceID }. 62302 is an item this client knows but
-- holds no appearance for, which is a different failure from never shipping it.
local itemAppearances = {
    [61001] = { 91001, 1001 }, [61002] = { 91002, 1002 },
    [62001] = { 92001, 2001 }, [62002] = { 92002, 2002 },
    [62003] = { 92003, 2003 }, [62004] = { 92004, 2004 },
    [62101] = { 92101, 2101 }, [62102] = { 92102, 2102 }, [62103] = { 92103, 2103 },
    [62301] = { 92301, 2301 }, [62303] = { 92303, 2303 },
    [64001] = { 94001, 4001 }, [64002] = { 94002, 4002 }, [64003] = { 94003, 4003 },
    -- Both of these answer with the same source, which no set should list twice.
    [64101] = { 94101, 4101 }, [64102] = { 94101, 4101 },
    [65001] = { 95001, 5001 }, [65002] = { 95002, 5002 },
    [65003] = { 95003, 5003 }, [65004] = { 95004, 5004 },
    [66001] = { 96001, 6001 }, [66002] = { 96002, 6002 },
}

local transmogSetInfos = {
    [10] = { name = "Fixture Official Regalia", classMask = 0 },
    [20] = { name = "Fixture Hidden Garb", label = "Fixture Quest", classMask = 8, expansionID = 5 },
    -- The client numbers a different set 23, which is what a snapshot taken
    -- from another numbering runs into. Nothing about the answer says so: it is
    -- a well-formed set, just not this one.
    [23] = { name = "Fixture Someone Else's Set", label = "Fixture Elsewhere", classMask = 16, expansionID = 9 },
    -- The set an ensemble names, holding the very pieces the ensemble teaches.
    [30] = { name = "Fixture Client Tabards", label = "Fixture Trading Post", classMask = 0, expansionID = 3 },
}

-- setID -> the sources the client counts towards its own set of that number.
local clientSetSources = {
    [10] = { 1001, 1002 },
    -- The client counts the tier pieces; the snapshot carries the off-set
    -- pieces too, so its list is the longer of the two and still the same set.
    [20] = { 2001, 2003 },
    [23] = { 5501, 5502, 5503 },
    [30] = { 6001, 6002 },
}

-- Set 10 is one both classes' Sets tab lists, and the second class lists it
-- twice, as a client that names a set once per variant would. That tab also
-- lists the client's own 23, which is not the snapshot's 23: going by the
-- number alone would hide a set nobody can reach any other way.
local allSetsByClass = { [1] = { 10 }, [2] = { 10, 10, 23 } }

LuckysWardrobe.ExtraSetsData = {
    snapshot = "2026-08-04",
    armorTypes = {
        { key = "cloth", armorType = 1 },
        { key = "plate", armorType = 4 },
    },
    sets = {
        cloth = {
            -- Deliberately out of slot order: records leave the catalogue in
            -- display order however the snapshot listed them.
            -- The client knows this set under a different name, which is the
            -- one a player reads, in their own language.
            [20] = { name = "Fixture Hidden Garb (snapshot)", classMask = 0, pieces = { 62004, 62003, 62001, 62002 } },
            [21] = { name = "Fixture Chest And Robe", classMask = 0, pieces = { 62102, 62103, 62101 } },
            [22] = { name = "Fixture Ghost Set", classMask = 0, pieces = { 69001, 69002 } },
            [23] = { name = "Fixture Partly Missing", classMask = 128, expansionID = 2, pieces = { 62301, 62302, 69003, 62303 } },
            [10] = { name = "Fixture Official Regalia", classMask = 0, pieces = { 61001, 61002 } },
        },
        plate = {
            [40] = { name = "Fixture Armed Set", classMask = 4, pieces = { 64001, 64002, 64003 } },
            [41] = { name = "Fixture Twice Listed", classMask = 0, pieces = { 64101, 64102 } },
        },
    },
    -- The ensembles, numbered the way the client numbers its own sets rather
    -- than the way the armour lists number theirs. The cloth list uses 20 for a
    -- set of its own, and these are two different sets under one number.
    --
    -- That numbering is the client's, but the client of the build the snapshot
    -- was taken from. Set 20 has moved between that build and this one, and set
    -- 30 has not, so one of these is believed and the other is not.
    ensembles = {
        [20] = {
            name = "Fixture Ensemble Plate (snapshot)",
            classMask = 0,
            ensembles = { 70001, 70002 },
            pieces = { 65001, 65002, 65003, 65004 },
        },
        [30] = {
            name = "Fixture Ensemble Tabards",
            classMask = 0,
            ensembles = { 70003 },
            pieces = { 66001, 66002 },
        },
    },
    -- Which sets are the same armour in another colour, worked out against the
    -- snapshot above. Each listing is indexed under its own numbering, so the
    -- cloth 20 and the ensemble 20 are told apart here the way they are there.
    models = {
        snapshot = "2026-08-04",
        cloth = { [20] = 7, [21] = 7 },
        plate = { [40] = 9 },
        ensembles = { [20] = 11 },
    },
}

local classFilter = 99

-- The difficulty variants of set 10, as the client lists them: the set itself
-- among its own variants, and a variant with no name of its own.
local variantSets = {
    [10] = { { setID = 10, name = "Fixture Official Regalia" }, { setID = 11, name = "" } },
}

-- The looks the client counts towards each listed set. Set 23 answers nothing,
-- as a set with no primary appearances does.
local setPrimaryAppearances = {
    [10] = { { appearanceID = 81001, collected = true }, { appearanceID = 81002, collected = false } },
    [11] = { { appearanceID = 81003, collected = false } },
    [23] = {},
}
local primaryAppearanceAsks = 0

C_TransmogSets = {
    GetTransmogSetsClassFilter = function() return classFilter end,
    SetTransmogSetsClassFilter = function(classID) classFilter = classID end,
    GetAllSets = function()
        local sets = {}
        for _, setID in ipairs(allSetsByClass[classFilter] or {}) do
            sets[#sets + 1] = { setID = setID, name = transmogSetInfos[setID].name }
        end
        return sets
    end,
    GetSetInfo = function(setID) return transmogSetInfos[setID] end,
    GetAllSourceIDs = function(setID) return clientSetSources[setID] end,
    GetValidClassForSet = function(setID) return setID == 10 and 2 or nil end,
    GetVariantSets = function(setID) return variantSets[setID] end,
    GetSetPrimaryAppearances = function(setID)
        primaryAppearanceAsks = primaryAppearanceAsks + 1
        return setPrimaryAppearances[setID]
    end,
}

C_TransmogCollection = {
    GetItemInfo = function(itemID)
        local appearance = itemAppearances[itemID]
        if not appearance then return nil end
        return appearance[1], appearance[2]
    end,
}

Enum = { ItemClass = { Armor = 4 } }

C_Item = {
    GetItemInfoInstant = function(itemID)
        local equipLoc = items[itemID]
        if not equipLoc then return nil end
        return itemID, "Armor", "Cloth", equipLoc, 0, Enum.ItemClass.Armor, itemArmour[itemID] or 1
    end,
}

dofile("src/Strings.lua")
dofile("src/Utils.lua")
dofile("src/domain/Classes.lua")
-- The build measures how much of a frame each step takes, so the real stopwatch
-- runs here, wound by hand rather than by the clock the client would provide.
dofile("src/Perf.lua")
local clock = 0
LuckysWardrobe.Perf.Clock = function()
    clock = clock + 1
    return clock
end
dofile("src/domain/ExtraSetsCatalog.lua")
local Catalog = LuckysWardrobe.ExtraSetsCatalog

-- The report asks the page how many sets this character's class sees and how
-- many it folded away as the same look, so the page stands in for itself here.
-- One of the two rows below speaks for a set listed again under another name,
-- and one bundled set sits folded behind a look the Sets tab already shows.
local shownEntries = { {}, { alternateNames = { "Live Name (Recolor)" } } }
local nativeFolds = {
    { setID = 21, name = "Fixture Chest And Robe", nativeName = "Fixture Official Regalia" },
}
LuckysWardrobe.ExtraSets = {
    Entries = function() return shownEntries end,
    FoldedCount = function(entries)
        local folded = 0
        for _, entry in ipairs(entries) do folded = folded + #(entry.alternateNames or {}) end
        return folded
    end,
    NativeFolds = function() return nativeFolds end,
}

local function runBuild()
    for _ = 1, 100 do
        if Catalog:IsReady() then return end
        assert(stepHandler, "the build never scheduled any work")
        stepHandler()
    end
    error("the build never finished")
end

local function recordFor(setID)
    for _, record in ipairs(Catalog:GetRecords()) do
        if record.setID == setID and not record.ensembles then return record end
    end
end

local function ensembleRecordFor(setID)
    for _, record in ipairs(Catalog:GetRecords()) do
        if record.setID == setID and record.ensembles then return record end
    end
end

local function pieceKeys(record)
    local parts = {}
    for index, piece in ipairs(record.pieces) do
        parts[index] = piece.slot .. "=" .. piece.sourceID .. "@" .. piece.itemID
    end
    return table.concat(parts, ",")
end

local function rejectionFor(setID)
    for _, rejection in ipairs(Catalog:GetReport().rejections) do
        if rejection.setID == setID then return rejection end
    end
end

local function fingerprint()
    local parts = {}
    for _, record in ipairs(Catalog:GetRecords()) do
        parts[#parts + 1] = table.concat({
            record.setID, record.name, record.label or "", record.classMask,
            record.armorType, record.expansionID or "", record.unresolvedPieces,
            record.officialClassMask or "", table.concat(record.ensembles or {}, "+"),
            pieceKeys(record),
        }, "|")
    end
    return table.concat(parts, "\n")
end

-- Nothing is available until the build finishes.

local readyFired = false
Catalog:OnReady(function() readyFired = true end)
Catalog:StartBuild()
assert(not Catalog:IsReady() and #Catalog:GetRecords() == 0, "no records before the build finishes")
assert(not readyFired, "readiness is not announced early")

runBuild()
assert(Catalog:IsReady(), "the build finished")
assert(readyFired, "callbacks waiting on the catalogue fired")
assert(classFilter == 99, "restored the class filter the player had set")

local immediate = false
Catalog:OnReady(function() immediate = true end)
assert(immediate, "a callback added after the build runs at once")

-- Records: what the client can resolve, in display order.

assert(#Catalog:GetRecords() == 7, "listed every set with more than one resolvable piece")

local garb = recordFor(20)
assert(garb, "listed a set the client never shows in the Sets tab")
assert(garb.armorType == 1, "took the armour type from the file the set came from")
assert(pieceKeys(garb) == "HEAD=2001@62001,SHOULDER=2002@62002,CHEST=2003@62003,LEGS=2004@62004",
    "ordered the pieces head to feet whatever order the snapshot listed them in")
assert(garb.unresolvedPieces == 0, "a fully resolved set has nothing missing")

-- The model index rides onto the record, read under the numbering of the
-- listing the set came from.
assert(garb.model == 7 and recordFor(21).model == 7,
    "two sets built on one model carry the same number out of the catalogue")
assert(recordFor(22) == nil and recordFor(23).model == nil,
    "and a set the index says nothing about carries none")
assert(ensembleRecordFor(20).model == 11,
    "the ensemble 20 took its own listing's model, not the cloth 20's")

-- Where the client knows a set it is the authority; the snapshot fills the rest.
assert(garb.name == "Fixture Hidden Garb", "took the name from the client, not the snapshot")
assert(garb.classMask == 8 and garb.expansionID == 5 and garb.label == "Fixture Quest",
    "took the class mask, expansion, and label from the client")
-- The client knows a set 23, but not this one: it shares no source with the
-- pieces the snapshot lists. Believing it would rename the set, refile it under
-- another class, and date it to another expansion.
local partly = recordFor(23)
assert(partly.name == "Fixture Partly Missing", "kept the bundled name where the client means another set")
assert(partly.classMask == 128 and partly.label == nil,
    "took nothing from a client set that is not this set")
-- The client dated its own set 23 to expansion 9, and that set is not this one.
assert(partly.expansionID == 2, "dated the set from the snapshot, not from the client's other set")
assert(Catalog:GetReport().identityMismatches == 2,
    "counted the sets the snapshot and this client number differently, in either listing")

assert(Catalog.SameSet({ { sourceID = 1 }, { sourceID = 2 } }, { 1, 2 }), "the same sources are the same set")
assert(Catalog.SameSet({ { sourceID = 1 }, { sourceID = 2 }, { sourceID = 3 } }, { 1, 2 }),
    "a snapshot carrying off-set pieces the client does not count is still the same set")
assert(not Catalog.SameSet({ { sourceID = 1 }, { sourceID = 2 } }, { 8, 9, 1 }),
    "one shared piece among strangers is not identity")
assert(not Catalog.SameSet({ { sourceID = 1 } }, {}), "a client that lists no sources settles nothing")
assert(not Catalog.SameSet({ { sourceID = 1 } }, nil), "nor does one that answers nothing at all")

local chestAndRobe = recordFor(21)
assert(pieceKeys(chestAndRobe) == "HEAD=2103@62103,CHEST=2102@62102,CHEST=2101@62101",
    "kept both chest pieces, in the order the snapshot listed them")

local armed = recordFor(40)
assert(armed.armorType == 4 and pieceKeys(armed) == "HEAD=4001@64001,CHEST=4002@64002",
    "left the weapon out of an armour set")
assert(armed.unresolvedPieces == 0, "a weapon is not a piece this client failed to resolve")

-- Deduplicating sources can leave a set down to one piece, which is left out
-- the same way a set with nothing resolvable at all is.
assert(not recordFor(41), "left out a set a source dedupe reduces to a single piece")
local twiceListed = rejectionFor(41)
assert(twiceListed and twiceListed.name == "Fixture Twice Listed", "named the set it left out")
assert(twiceListed.category == "only one piece this client can resolve", "said why")

-- The ensembles. Their numbering is the client's own, so the set the client
-- holds under the number is the set the ensemble teaches, and nothing about it
-- has to be checked first.

local ensemblePlate = ensembleRecordFor(20)
assert(ensemblePlate and garb ~= ensemblePlate,
    "two listings using one number keep a record each rather than one shutting the other out")
assert(ensemblePlate.ensembles[1] == 70001 and ensemblePlate.ensembles[2] == 70002,
    "kept the ensembles that teach the set, so the page can say where to buy it")
assert(ensemblePlate.armorType == 4,
    "read the armour off the pieces for the list that does not say, the cloak among them left out")
-- The snapshot's numbering is the client's, but of another build. This client
-- holds a set 20 that shares no piece with what the ensemble teaches, so its
-- name, class, and expansion are about some other set and none are taken.
assert(ensemblePlate.name == "Fixture Ensemble Plate (snapshot)" and ensemblePlate.classMask == 0
    and ensemblePlate.expansionID == nil and ensemblePlate.label == nil,
    "an ensemble is checked against the client like any other listing")

local tabards = ensembleRecordFor(30)
assert(tabards.name == "Fixture Client Tabards" and tabards.label == "Fixture Trading Post"
    and tabards.expansionID == 3,
    "and where the client holds the very set the ensemble teaches, the client names it")
assert(tabards.armorType == 0, "a set of tabards and shirts is nobody's armour in particular")
assert(Catalog:GetReport().identityMismatches == 2, "both numberings that disagree are counted")
assert(Catalog:GetReport().fromEnsembles == 2, "counted the sets that came from an ensemble")

-- Pieces this client cannot answer for are counted, never guessed at.

assert(partly.unresolvedPieces == 2, "counted the piece with no appearance and the one that never shipped")
assert(pieceKeys(partly) == "HEAD=2301@62301,SHOULDER=2303@62303", "kept the pieces that did resolve")
assert(Catalog:GetReport().unresolvedPieces == 2, "the report totals unresolved pieces across the catalogue")

assert(not recordFor(22), "left out a set with nothing this client can resolve")
local ghost = rejectionFor(22)
assert(ghost and ghost.name == "Fixture Ghost Set", "named the set it left out")
assert(ghost.category == "no piece this client can resolve", "said why")

-- Overlap with Blizzard's own Sets tab. The catalogue keeps the set and says
-- which classes' Sets tab lists it; the page is what drops the duplicate row.

local official = recordFor(10)
assert(official, "kept a set Blizzard already lists")
assert(official.officialClassMask == 3, "named every class whose Sets tab lists it, each counted once")
assert(garb.officialClassMask == nil, "a set no Sets tab lists belongs to no class there")
-- The Sets tab lists a 10 and a 23. Only the 10 is the set the snapshot means,
-- so only the 10 is a duplicate: the page keeps the 23 for every class.
assert(partly.officialClassMask == nil, "a set that only shares a number is nobody's duplicate")
assert(Catalog:GetReport().alsoOfficial == 1,
    "counted the set the Sets tab really holds, not the one that shares its number")

-- The looks the Sets tab already shows each class, difficulty variants
-- included: what the page folds look-duplicates against.

local classOneLooks = Catalog:OfficialLooks(1)
assert(#classOneLooks == 2, "class 1 gets the set its tab lists and that set's variant, each once")
assert(classOneLooks[1].setID == 10 and classOneLooks[1].name == "Fixture Official Regalia",
    "a look carries the name the tab shows for it")
assert(classOneLooks[1].appearances[81001] and classOneLooks[1].appearances[81002],
    "and the appearances the client counts towards the set")
assert(classOneLooks[2].setID == 11 and classOneLooks[2].name == "Fixture Official Regalia",
    "a variant with no name of its own borrows its set's")

-- Class 2's tab also lists its own 23, but the client answers no looks for it,
-- so there is nothing of it to fold against.
assert(#Catalog:OfficialLooks(2) == 2, "a set the client answers no looks for is left out")
assert(#Catalog:OfficialLooks(nil) == 2, "no class chosen means every listed set's looks")

local asksBefore = primaryAppearanceAsks
assert(Catalog:OfficialLooks(1) == classOneLooks, "a class asked twice is answered from the session")
assert(primaryAppearanceAsks == asksBefore, "without asking the client again")

-- Same client, same catalogue.

local first = fingerprint()
Catalog:Rebuild()
runBuild()
assert(fingerprint() == first, "a rebuild on the same client produces the same catalogue")
assert(Catalog:OfficialLooks(1) ~= classOneLooks, "a rebuild reads the Sets tab's looks afresh")

-- A model index built against another snapshot describes another numbering, so
-- the sets it names are not the sets it means. Folding the wrong armour together
-- is worse than folding none, so the whole file is refused rather than trusted
-- in part.

do
local index = LuckysWardrobe.ExtraSetsData.models
LuckysWardrobe.ExtraSetsData.models = {
    snapshot = "2026-01-01",
    cloth = { [20] = 7, [21] = 7 },
    plate = {}, ensembles = {},
}
Catalog:Rebuild()
runBuild()
assert(recordFor(20).model == nil and recordFor(21).model == nil,
    "an index for another snapshot groups nothing at all")
local said = false
for _, message in ipairs(devLogs) do said = said or message:find("another snapshot") ~= nil end
assert(said, "and says so, since the tab quietly stopping grouping needs a reason")

LuckysWardrobe.ExtraSetsData.models = nil
Catalog:Rebuild()
runBuild()
assert(recordFor(20).model == nil, "no index at all is no grouping either")

LuckysWardrobe.ExtraSetsData.models = index
Catalog:Rebuild()
runBuild()
assert(recordFor(20).model == 7, "and the matching index groups again")
end

-- Rejection grouping.

local summary = Catalog:SummarizeRejections()
assert(#summary == 2, "grouped the left-out sets by reason")
assert(summary[1].count == 1 and summary[2].count == 1, "each reason left out one set")
assert(summary[1].category == "no piece this client can resolve", "a tie between counts breaks alphabetically")
assert(summary[2].category == "only one piece this client can resolve", "a tie between counts breaks alphabetically")

-- Looking a set up by name reaches all three places it can be.

local listed, dropped, native, folded = Catalog:FindCandidates("fixture")
assert(#listed == 5 and #dropped == 2, "found both listed and left-out sets")
-- Both sets the Sets tab lists are found by name, the collision among them:
-- this list is the client's own, so it answers for the client's numbering.
assert(#native == 2 and native[1].setID == 10 and native[2].setID == 23,
    "found the sets Blizzard lists natively, in set order")
for _, record in ipairs(listed) do
    assert(record.setID ~= 10, "a set the page drops as a duplicate is not reported as listed")
    assert(record.setID ~= 21, "nor is one folded behind a look the Sets tab shows")
end
assert(#folded == 1 and folded[1].setID == 21 and folded[1].nativeName == "Fixture Official Regalia",
    "a folded set is reported behind the tab's set that holds its look")
local none, alsoNone, stillNone, noneFolded = Catalog:FindCandidates("nothing named this")
assert(#none == 0 and #alsoNone == 0 and #stillNone == 0 and #noneFolded == 0,
    "an unknown name matches nothing")

-- The report, as a player reads it in chat.

local printed = {}
local realPrint = print
print = function(line) printed[#printed + 1] = line end
Catalog:PrintReport(false)
print = realPrint

local reportText = table.concat(printed, "\n")
assert(reportText:find("2026%-08%-04"), "named the snapshot the sets came from")
assert(reportText:find("7 of 9 set%(s%) listed"), "counted what was listed against what was bundled")
assert(reportText:find("an ensemble teaches: 2"), "counted the sets that reached the list as ensembles")
assert(reportText:find("shown for this character's class: 2"), "counted the sets this character's class sees")
assert(reportText:find("folded into another row as the same look: 1"),
    "accounted for the sets the page folded away, so the count is not short with nothing to say why")
assert(reportText:find("hidden as looks the Sets tab already shows this class: 1"),
    "counted the sets folded behind the tab's own looks")
assert(reportText:find("hidden as Blizzard's own Sets tab lists them: 1"), "counted the overlap it hides")
assert(reportText:find("no appearance for: 2"), "counted the pieces this client could not resolve")

print("Lucky's Wardrobe extra sets catalogue tests passed")
