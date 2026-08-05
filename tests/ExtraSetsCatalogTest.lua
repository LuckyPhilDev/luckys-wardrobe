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
    [62301] = "INVTYPE_HEAD", [62302] = "INVTYPE_CHEST",
    [64001] = "INVTYPE_HEAD", [64002] = "INVTYPE_CHEST", [64003] = "INVTYPE_WEAPON",
    [64101] = "INVTYPE_HEAD", [64102] = "INVTYPE_CHEST",
}

-- itemID -> { appearanceID, sourceID }. 62302 is an item this client knows but
-- holds no appearance for, which is a different failure from never shipping it.
local itemAppearances = {
    [61001] = { 91001, 1001 }, [61002] = { 91002, 1002 },
    [62001] = { 92001, 2001 }, [62002] = { 92002, 2002 },
    [62003] = { 92003, 2003 }, [62004] = { 92004, 2004 },
    [62101] = { 92101, 2101 }, [62102] = { 92102, 2102 }, [62103] = { 92103, 2103 },
    [62301] = { 92301, 2301 },
    [64001] = { 94001, 4001 }, [64002] = { 94002, 4002 }, [64003] = { 94003, 4003 },
    -- Both of these answer with the same source, which no set should list twice.
    [64101] = { 94101, 4101 }, [64102] = { 94101, 4101 },
}

local transmogSetInfos = {
    [10] = { name = "Fixture Official Regalia", classMask = 0 },
    [20] = { name = "Fixture Hidden Garb", label = "Fixture Quest", classMask = 8, expansionID = 5 },
    -- The client numbers a different set 23, which is what a snapshot taken
    -- from another numbering runs into. Nothing about the answer says so: it is
    -- a well-formed set, just not this one.
    [23] = { name = "Fixture Someone Else's Set", label = "Fixture Elsewhere", classMask = 16, expansionID = 9 },
}

-- setID -> the sources the client counts towards its own set of that number.
local clientSetSources = {
    [10] = { 1001, 1002 },
    -- The client counts the tier pieces; the snapshot carries the off-set
    -- pieces too, so its list is the longer of the two and still the same set.
    [20] = { 2001, 2003 },
    [23] = { 5501, 5502, 5503 },
}

-- The client's Sets tab lists its own 23, which is not the snapshot's 23. A
-- count of overlap that goes by the number alone counts it as one the player
-- can already see.
local allSetsByClass = { [1] = { 10 }, [2] = { 23 } }

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
            [23] = { name = "Fixture Partly Missing", classMask = 128, pieces = { 62301, 62302, 69003 } },
            [10] = { name = "Fixture Official Regalia", classMask = 0, pieces = { 61001, 61002 } },
        },
        plate = {
            [40] = { name = "Fixture Armed Ensemble", classMask = 4, pieces = { 64001, 64002, 64003 } },
            [41] = { name = "Fixture Twice Listed", classMask = 0, pieces = { 64101, 64102 } },
        },
    },
}

local classFilter = 99

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
}

C_TransmogCollection = {
    GetItemInfo = function(itemID)
        local appearance = itemAppearances[itemID]
        if not appearance then return nil end
        return appearance[1], appearance[2]
    end,
}

C_Item = {
    GetItemInfoInstant = function(itemID)
        local equipLoc = items[itemID]
        if not equipLoc then return nil end
        return itemID, "Armor", "Cloth", equipLoc, 0, 4, 1
    end,
}

dofile("src/Strings.lua")
-- The build measures how much of a frame each step takes, so the real stopwatch
-- runs here, wound by hand rather than by the clock the client would provide.
dofile("src/Perf.lua")
local clock = 0
LuckysWardrobe.Perf.Clock = function()
    clock = clock + 1
    return clock
end
dofile("src/ExtraSetsCatalog.lua")
local Catalog = LuckysWardrobe.ExtraSetsCatalog

-- The report asks the page how many sets this character's class sees, so the
-- page stands in for itself here.
local shownEntries = { {}, {} }
LuckysWardrobe.ExtraSets = { Entries = function() return shownEntries end }

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
        if record.setID == setID then return record end
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

assert(#Catalog:GetRecords() == 6, "listed every set with at least one resolvable piece")

local garb = recordFor(20)
assert(garb, "listed a set the client never shows in the Sets tab")
assert(garb.armorType == 1, "took the armour type from the file the set came from")
assert(pieceKeys(garb) == "HEAD=2001@62001,SHOULDER=2002@62002,CHEST=2003@62003,LEGS=2004@62004",
    "ordered the pieces head to feet whatever order the snapshot listed them in")
assert(garb.unresolvedPieces == 0, "a fully resolved set has nothing missing")

-- Where the client knows a set it is the authority; the snapshot fills the rest.
assert(garb.name == "Fixture Hidden Garb", "took the name from the client, not the snapshot")
assert(garb.classMask == 8 and garb.expansionID == 5 and garb.label == "Fixture Quest",
    "took the class mask, expansion, and label from the client")
-- The client knows a set 23, but not this one: it shares no source with the
-- pieces the snapshot lists. Believing it would rename the set, refile it under
-- another class, and date it to another expansion.
local partly = recordFor(23)
assert(partly.name == "Fixture Partly Missing", "kept the bundled name where the client means another set")
assert(partly.classMask == 128 and partly.expansionID == nil and partly.label == nil,
    "took nothing from a client set that is not this set")
assert(Catalog:GetReport().identityMismatches == 1, "counted the set the two numberings disagree about")

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

local twiceListed = recordFor(41)
assert(#twiceListed.pieces == 1, "counted a source listed twice as one piece")

-- Pieces this client cannot answer for are counted, never guessed at.

assert(partly.unresolvedPieces == 2, "counted the piece with no appearance and the one that never shipped")
assert(pieceKeys(partly) == "HEAD=2301@62301", "kept the piece that did resolve")
assert(Catalog:GetReport().unresolvedPieces == 2, "the report totals unresolved pieces across the catalogue")

assert(not recordFor(22), "left out a set with nothing this client can resolve")
local ghost = rejectionFor(22)
assert(ghost and ghost.name == "Fixture Ghost Set", "named the set it left out")
assert(ghost.category == "no piece this client can resolve", "said why")

-- Overlap with Blizzard's own Sets tab is counted rather than hidden: it is
-- exactly what a later pass would de-duplicate.

assert(recordFor(10), "a set Blizzard already lists is still listed here")
-- The Sets tab lists a 10 and a 23. Only the 10 is the set the snapshot means,
-- so only the 10 is a set the player can already see without this page.
assert(Catalog:GetReport().alsoOfficial == 1,
    "counted the set the Sets tab really holds, not the one that shares its number")

-- Same client, same catalogue.

local first = fingerprint()
Catalog:Rebuild()
runBuild()
assert(fingerprint() == first, "a rebuild on the same client produces the same catalogue")

-- Rejection grouping.

local summary = Catalog:SummarizeRejections()
assert(#summary == 1 and summary[1].count == 1, "grouped the left-out sets by reason")

-- Looking a set up by name reaches all three places it can be.

local listed, dropped, native = Catalog:FindCandidates("fixture")
assert(#listed == 6 and #dropped == 1, "found both listed and left-out sets")
-- Both sets the Sets tab lists are found by name, the collision among them:
-- this list is the client's own, so it answers for the client's numbering.
assert(#native == 2 and native[1].setID == 10 and native[2].setID == 23,
    "found the sets Blizzard lists natively, in set order")
local none, alsoNone, stillNone = Catalog:FindCandidates("nothing named this")
assert(#none == 0 and #alsoNone == 0 and #stillNone == 0, "an unknown name matches nothing")

-- The report, as a player reads it in chat.

local printed = {}
local realPrint = print
print = function(line) printed[#printed + 1] = line end
Catalog:PrintReport(false)
print = realPrint

local reportText = table.concat(printed, "\n")
assert(reportText:find("2026%-08%-04"), "named the snapshot the sets came from")
assert(reportText:find("6 of 7 set%(s%) listed"), "counted what was listed against what was bundled")
assert(reportText:find("shown for this character's class: 2"), "counted the sets this character's class sees")
assert(reportText:find("also in Blizzard's own Sets tab: 1"), "counted the overlap")
assert(reportText:find("no appearance for: 2"), "counted the pieces this client could not resolve")

print("Lucky's Wardrobe extra sets catalogue tests passed")
