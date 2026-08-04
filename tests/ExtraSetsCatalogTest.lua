-- luacheck: globals CreateFrame GetBuildInfo GetNumClasses GetClassInfo LuckysWardrobe C_TransmogSets C_TransmogCollection C_Item C_LootJournal
-- luacheck: ignore 121

LuckysWardrobe = {}

local devLogs = {}
LuckysWardrobe.DevLog = function(message) devLogs[#devLogs + 1] = message end

-- Stubbed client world. Every name and ID is invented for this test; the
-- shapes mirror the documented Blizzard APIs the catalogue consumes.

local stepHandler
function CreateFrame()
    return {
        SetScript = function(_, script, handler)
            assert(script == "OnUpdate", "discovery paces itself with OnUpdate")
            stepHandler = handler
        end,
    }
end

function GetBuildInfo() return "12.0.7", "68887", "Aug 4 2026", 120007 end
function GetNumClasses() return 2 end
function GetClassInfo(classID) return "Fixture Class " .. classID end

-- Official sets are split across class filters to prove the snapshot unions them.
local allSetsByClass = { [1] = { 10, 12 }, [2] = { 11 } }

local transmogSetInfos = {
    [10] = { name = "Fixture Official Regalia", classMask = 0 },
    [11] = { name = "Fixture Official Vestments", classMask = 0 },
    [12] = { name = "Fixture Official Repeats", classMask = 0 },
    [20] = { name = "Fixture Hidden Garb", label = "Fixture Quest", classMask = 0, expansionID = 5 },
    [21] = { name = "Fixture Sparse Pair", classMask = 0 },
    [22] = { name = "Fixture Twin Chests", classMask = 0 },
    [23] = { name = "Fixture Official Echo", classMask = 0 },
    [24] = { name = "Fixture Armed Ensemble", classMask = 4 },
    [25] = { name = "", classMask = 0 },
    [26] = { name = "Fixture Ghost Piece", classMask = 0 },
    [27] = { name = "Fixture Hidden Garb Copy", classMask = 0 },
    [28] = { name = "Fixture Mystery Slot", classMask = 0 },
    [29] = { name = "Fixture Ensemble Bundle", classMask = 0 },
    [30] = { name = "Fixture Empty Bundle", classMask = 0 },
    [31] = { name = "Fixture Partial Overlap", classMask = 0 },
}

-- 29 stands for a set Blizzard never lists in the journal: whole-set membership
-- but no primary-flagged appearances. 30 has neither.
-- 12 lists 1201 twice, which is what makes a naive occurrence tally reach a
-- candidate's source total without owning every one of its sources.
local transmogSetSources = {
    [10] = { 1001, 1002, 1003, 1004, 1005 },
    [11] = { 1101, 1102, 1103 },
    [12] = { 1201, 1201, 1202 },
    [29] = { 2901, 2902, 2903 },
}

local primarySources = {
    [20] = { 2001, 2002, 2003, 2004, 2005 },
    [21] = { 2101, 2102 },
    [22] = { 2201, 2202, 2203, 2204 },
    [23] = { 1001, 1002, 1003 },
    [24] = { 2401, 2402, 2403, 2404 },
    [25] = { 2501 },
    [26] = { 2601, 2602, 2603 },
    [27] = { 2001, 2002, 2003, 2004, 2005 },
    [28] = { 2801, 2802, 2803 },
    -- 1201 and 1202 belong to official set 12; 1101 belongs to official set 11.
    [31] = { 1201, 1202, 1101 },
}

-- sourceID -> itemID; 2602 has no item on purpose.
local sourceItems = {
    [1001] = 61001, [1002] = 61002, [1003] = 61003,
    [1101] = 71101, [1102] = 71102, [1103] = 71103,
    [2001] = 62001, [2002] = 62002, [2003] = 62003, [2004] = 62004, [2005] = 62005,
    [2101] = 62101, [2102] = 62102,
    [2201] = 62201, [2202] = 62202, [2203] = 62203, [2204] = 62204,
    [2401] = 62401, [2402] = 62402, [2403] = 62403, [2404] = 62404,
    [2601] = 62601, [2603] = 62603,
    [2801] = 62801, [2802] = 62802, [2803] = 62803,
    [2901] = 62901, [2902] = 62902, [2903] = 62903,
    [1201] = 71201, [1202] = 71202,
    [5001] = 70001, [5002] = 70002, [5003] = 70003, [5004] = 70004, [5005] = 70005,
    [5101] = 70101, [5102] = 79999, [5103] = 70103,
    [5301] = 70301, [5302] = 70302,
    [5401] = 70401,
    [5501] = 70501, [5502] = 70502, [5503] = 70503,
}

-- itemID -> { equipLoc, classID, subClassID }
local items = {
    [61001] = { "INVTYPE_HEAD", 4, 1 }, [61002] = { "INVTYPE_CHEST", 4, 1 }, [61003] = { "INVTYPE_LEGS", 4, 1 },
    [71101] = { "INVTYPE_HEAD", 4, 3 }, [71102] = { "INVTYPE_CHEST", 4, 3 }, [71103] = { "INVTYPE_LEGS", 4, 3 },
    [62001] = { "INVTYPE_HEAD", 4, 1 }, [62002] = { "INVTYPE_SHOULDER", 4, 1 },
    [62003] = { "INVTYPE_ROBE", 4, 1 }, [62004] = { "INVTYPE_LEGS", 4, 1 }, [62005] = { "INVTYPE_FEET", 4, 1 },
    [62101] = { "INVTYPE_HEAD", 4, 1 }, [62102] = { "INVTYPE_HAND", 4, 1 },
    [62201] = { "INVTYPE_HEAD", 4, 1 }, [62202] = { "INVTYPE_CHEST", 4, 1 },
    [62203] = { "INVTYPE_ROBE", 4, 1 }, [62204] = { "INVTYPE_LEGS", 4, 1 },
    [62401] = { "INVTYPE_HEAD", 4, 4 }, [62402] = { "INVTYPE_CHEST", 4, 4 },
    [62403] = { "INVTYPE_LEGS", 4, 4 }, [62404] = { "INVTYPE_WEAPON", 2, 7 },
    [62601] = { "INVTYPE_HEAD", 4, 1 }, [62603] = { "INVTYPE_LEGS", 4, 1 },
    [62801] = { "INVTYPE_HEAD", 4, 1 }, [62802] = { "INVTYPE_MYSTERY", 4, 1 }, [62803] = { "INVTYPE_LEGS", 4, 1 },
    [62901] = { "INVTYPE_HEAD", 4, 1 }, [62902] = { "INVTYPE_CHEST", 4, 1 }, [62903] = { "INVTYPE_LEGS", 4, 1 },
    [71201] = { "INVTYPE_CHEST", 4, 3 }, [71202] = { "INVTYPE_LEGS", 4, 3 },
    [70001] = { "INVTYPE_HEAD", 4, 1 }, [70002] = { "INVTYPE_SHOULDER", 4, 1 },
    [70003] = { "INVTYPE_ROBE", 4, 1 }, [70004] = { "INVTYPE_LEGS", 4, 1 }, [70005] = { "INVTYPE_FEET", 4, 1 },
    [70101] = { "INVTYPE_HEAD", 4, 2 }, [70102] = { "INVTYPE_CHEST", 4, 2 }, [70103] = { "INVTYPE_LEGS", 4, 2 },
    [70301] = { "INVTYPE_HEAD", 4, 1 }, [70302] = { "INVTYPE_CHEST", 4, 1 },
    [70303] = { "INVTYPE_FINGER", 4, 0 }, [70304] = { "INVTYPE_TRINKET", 4, 0 },
    [70401] = { "INVTYPE_HEAD", 4, 1 },
    [70501] = { "INVTYPE_HEAD", 4, 1 }, [70502] = { "INVTYPE_CHEST", 4, 2 }, [70503] = { "INVTYPE_LEGS", 4, 1 },
}

-- itemID -> { visualID, sourceID } for item-set pieces.
local itemAppearances = {
    [70001] = { 95001, 5001 }, [70002] = { 95002, 5002 }, [70003] = { 95003, 5003 },
    [70004] = { 95004, 5004 }, [70005] = { 95005, 5005 },
    [70101] = { 95101, 5101 }, [70102] = { 95102, 5102 }, [70103] = { 95103, 5103 },
    [71101] = { 96101, 1101 }, [71102] = { 96102, 1102 }, [71103] = { 96103, 1103 },
    [70301] = { 95301, 5301 }, [70302] = { 95302, 5302 },
    [70401] = { 95401, 5401 },
    [70501] = { 95501, 5501 }, [70502] = { 95502, 5502 }, [70503] = { 95503, 5503 },
}

local itemSetNames = {
    [500] = "Fixture Woven Set",
    [501] = "Fixture Borrowed Look",
    [502] = "Fixture Official Subset",
    [503] = "Fixture Trinket Pile",
    [505] = "Fixture Patchwork Set",
}

local itemSetItems = {
    [500] = { 70001, 70002, 70003, 70004, 70005 },
    [501] = { 70101, 70102, 70103 },
    [502] = { 71101, 71102, 71103 },
    [503] = { 70301, 70302, 70303, 70304 },
    [504] = { 70401 },
    [505] = { 70501, 70502, 70503 },
}

local classFilter = 99

C_TransmogSets = {
    GetTransmogSetsClassFilter = function() return classFilter end,
    SetTransmogSetsClassFilter = function(classID) classFilter = classID end,
    GetAllSets = function()
        local sets = {}
        for _, setID in ipairs(allSetsByClass[classFilter] or {}) do
            local info = transmogSetInfos[setID]
            sets[#sets + 1] = { setID = setID, name = info and info.name }
        end
        return sets
    end,
    GetSetInfo = function(setID) return transmogSetInfos[setID] end,
    GetAllSourceIDs = function(setID) return transmogSetSources[setID] end,
    GetValidClassForSet = function(setID) return setID == 11 and 2 or nil end,
    GetSetPrimaryAppearances = function(setID)
        local sources = primarySources[setID]
        if not sources then return nil end
        local appearances = {}
        for index, sourceID in ipairs(sources) do
            appearances[index] = { appearanceID = sourceID }
        end
        return appearances
    end,
}

C_TransmogCollection = {
    GetSourceItemID = function(sourceID) return sourceItems[sourceID] end,
    GetItemInfo = function(itemID)
        local appearance = itemAppearances[itemID]
        if not appearance then return nil end
        return appearance[1], appearance[2]
    end,
}

C_Item = {
    GetItemInfoInstant = function(itemID)
        local item = items[itemID]
        assert(item, "unexpected item lookup: " .. tostring(itemID))
        return itemID, "Armor", "Cloth", item[1], 0, item[2], item[3]
    end,
    GetItemSetInfo = function(setID) return itemSetNames[setID] end,
}

C_LootJournal = {
    GetItemSetItems = function(setID)
        local list = itemSetItems[setID]
        if not list then return nil end
        local result = {}
        for index, itemID in ipairs(list) do
            result[index] = { itemID = itemID }
        end
        return result
    end,
}

dofile("src/ExtraSetsCatalog.lua")
local Catalog = LuckysWardrobe.ExtraSetsCatalog

local function runDiscovery()
    for _ = 1, 500 do
        if not stepHandler then return end
        stepHandler()
    end
    error("discovery never finished")
end

local function recordKeys()
    local keys = {}
    for index, record in ipairs(Catalog:GetRecords()) do
        keys[index] = record.recordType .. ":" .. record.recordID
    end
    return table.concat(keys, ", ")
end

local function rejectionReason(key)
    for _, rejection in ipairs(Catalog:GetReport().rejections) do
        if rejection.key == key then return rejection.reason end
    end
end

local function fingerprint()
    local parts = {}
    for _, record in ipairs(Catalog:GetRecords()) do
        local slots = {}
        for slot, sourceID in pairs(record.slotSources) do
            slots[#slots + 1] = slot .. "=" .. sourceID
        end
        table.sort(slots)
        parts[#parts + 1] = table.concat({
            record.recordType, record.recordID, record.name, record.label or "",
            record.classMask, record.armorType or "", record.expansionID or "",
            record.build, table.concat(slots, ","),
        }, "|")
    end
    return table.concat(parts, "\n")
end

-- Build and drive to completion.

Catalog:StartBuild()
assert(classFilter == 99, "restored the class filter after the official snapshot")
assert(not Catalog:IsReady(), "catalogue is not ready while discovery runs")
assert(#Catalog:GetRecords() == 0, "no records before discovery finishes")

local readyFired = false
Catalog:OnReady(function() readyFired = true end)

runDiscovery()
assert(Catalog:IsReady(), "discovery completed")
assert(readyFired, "completion notified subscribers")
assert(#devLogs > 0 and devLogs[#devLogs]:find("catalogue built"), "logged a discovery summary")

local lateFired = false
Catalog:OnReady(function() lateFired = true end)
assert(lateFired, "late subscribers run immediately")

-- Inclusion and exclusion rules.

assert(recordKeys() == "TransmogSet:20, TransmogSet:24, TransmogSet:29, TransmogSet:31, ItemSet:500, ItemSet:505",
    "emitted exactly the defensible records, got: " .. recordKeys())

assert(rejectionReason("TransmogSet:31") == nil,
    "a candidate straddling two official sets is not covered by either")

local bundle = Catalog:GetRecords()[3]
assert(bundle.name == "Fixture Ensemble Bundle", "a set with no primary appearances still qualifies")
assert(bundle.slotSources.HEAD == 2901 and bundle.slotSources.CHEST == 2902
    and bundle.slotSources.LEGS == 2903, "membership fell back to the whole source list")

local hiddenGarb = Catalog:GetRecords()[1]
assert(hiddenGarb.name == "Fixture Hidden Garb" and hiddenGarb.label == "Fixture Quest", "kept live name and label")
assert(hiddenGarb.expansionID == 5, "kept the expansion for filtering")
assert(hiddenGarb.build == "12.0.7.68887", "stamped the client build")
assert(hiddenGarb.slotSources.CHEST == 2003, "robe pieces map onto the chest slot")

local armed = Catalog:GetRecords()[2]
assert(armed.classMask == 4, "kept the explicit class restriction")
assert(armed.slotSources.HEAD and armed.slotSources.CHEST and armed.slotSources.LEGS, "kept the armour pieces")
local armedCount = 0
for _ in pairs(armed.slotSources) do armedCount = armedCount + 1 end
assert(armedCount == 3, "weapon pieces are never emitted")

assert(Catalog:GetRecords()[5].armorType == 1, "uniform armour subclass becomes the armour restriction")
assert(Catalog:GetRecords()[6].armorType == nil, "mixed armour subclasses carry no armour restriction")

assert(rejectionReason("TransmogSet:21"):find("fewer than 3"), "rejected the set with too few armour slots")
assert(rejectionReason("TransmogSet:22"):find("two sources for slot CHEST"), "rejected the slot collision")
assert(rejectionReason("TransmogSet:30") == "no appearance sources",
    "a set with neither primary appearances nor a source list is rejected, not guessed at")
assert(rejectionReason("TransmogSet:23") == "covered by an official set: 10", "rejected the official subset")
assert(rejectionReason("TransmogSet:25") == "no resolvable name", "rejected the nameless set")
assert(rejectionReason("TransmogSet:26"):find("no item data"), "rejected the source without an item")
assert(rejectionReason("TransmogSet:27") == "duplicate source membership: TransmogSet:20",
    "rejected the repeated membership")
assert(rejectionReason("TransmogSet:28") == "unknown inventory type: INVTYPE_MYSTERY",
    "unknown inventory tokens reject the record instead of guessing")
assert(rejectionReason("ItemSet:501"):find("does not round%-trip"), "rejected the item mapped to another item's source")
assert(rejectionReason("ItemSet:502") == "covered by an official set: 11", "rejected the item-set official overlap")
assert(rejectionReason("ItemSet:503"):find("fewer than 3"), "jewellery did not count toward the slot minimum")
assert(rejectionReason("ItemSet:504") == "no resolvable name", "rejected the nameless item set")

-- Session report: what was listed, and why every other candidate was left out.

local summary = Catalog:SummarizeRejections()
local summaryTotal = 0
for index, group in ipairs(summary) do
    summaryTotal = summaryTotal + group.count
    if index > 1 then
        assert(summary[index - 1].count >= group.count, "grouped rejections run most common first")
    end
end
local rejectionCount = #Catalog:GetReport().rejections
assert(summaryTotal == rejectionCount, "every rejection lands in exactly one group")
assert(#summary == 8, "grouped the eight distinct reasons, got " .. #summary)
assert(summary[1].category == "ambiguous mapping" and summary[1].count == 2,
    "equal counts fall back to alphabetical order")

-- The report counts the page's own entries; entry building is covered in
-- ExtraSetsTest, so here it only has to report usability.
LuckysWardrobe.ExtraSets = {
    LiveResolver = function() return "live-resolver" end,
    BuildEntries = function(builtRecords, resolver)
        assert(resolver == "live-resolver", "report counted entries from live client data")
        local entries = {}
        for index, record in ipairs(builtRecords) do
            entries[index] = { usable = record.recordID ~= 24 }
        end
        return entries
    end,
}

LuckysWardrobe.Strings = {
    addon = { prefix = "Wardrobe:" },
    extraSets = {
        report = {
            notStarted = "not started",
            building = "building",
            header = "client %s: %d listed, %d left out",
            usableLine = "  usable here: %d",
            groupLine = "  %s: %d",
            hint = "hint",
            findHeader = "matching %s:",
            findNone = "never saw %s",
            foundListed = "  listed: %s %d: %s (%d pieces)",
            foundDropped = "  left out: %s %s: %s",
            foundNative = "  native: TransmogSet %d: %s",
            foundNativeClass = "  native under %s: TransmogSet %d: %s",
            sweepHeader = "swept %s:",
            sweepHit = "  %s %d: %s%s",
            sweepBeyond = " (beyond)",
            sweepNone = "no %s below %d / %d",
            includedHeader = "listed (%d):",
            recordLine = "  %s %d: %s (%d pieces)",
            rejectedHeader = "left out (%d):",
            rejectionLine = "  %s %s: %s",
            unnamed = "(no name)",
        },
    },
}

local printed = {}
local realPrint = print
print = function(line) printed[#printed + 1] = line end

Catalog:PrintReport()
print = realPrint
assert(printed[1] == "Wardrobe: client 12.0.7.68887: 6 listed, " .. rejectionCount .. " left out",
    "reported the build and totals")
-- Five of the six records carry no class mask; the sixth is another class.
assert(printed[2] == "Wardrobe:   usable here: 5", "reported the per-character count for like-for-like comparison")
assert(printed[3]:find("ambiguous mapping: 2", 1, true), "listed the grouped reasons")
assert(printed[#printed] == "Wardrobe: hint", "pointed at the full listing")
assert(#printed == 3 + #summary, "summary stays short by default")

printed = {}
print = function(line) printed[#printed + 1] = line end
Catalog:PrintReport(true)
print = realPrint
local joined = table.concat(printed, "\n")
assert(joined:find("TransmogSet 20: Fixture Hidden Garb (5 pieces)", 1, true), "listed each set with its piece count")
assert(joined:find("TransmogSet:21 Fixture Sparse Pair: fewer than 3 wearable armour slots", 1, true),
    "named each rejected candidate alongside its reason")
assert(joined:find("ItemSet:501 Fixture Borrowed Look: ambiguous mapping: item 70102 does not round-trip", 1, true),
    "kept the specific detail alongside the category")
assert(joined:find("TransmogSet:25 (no name): no resolvable name", 1, true),
    "candidates with no name say so rather than printing a gap")

-- Looking one candidate up by name, listed or left out.

local listed, dropped = Catalog:FindCandidates("hidden garb")
assert(#listed == 1 and listed[1].recordID == 20, "found the listed set by name")
assert(#dropped == 1 and dropped[1].key == "TransmogSet:27", "found the rejected candidate of the same name")

assert(select(2, Catalog:FindCandidates("SPARSE")) [1].key == "TransmogSet:21", "name matching ignores case")
assert(#Catalog:FindCandidates("nothing here") == 0, "an unscanned name matches nothing")

local _, _, native = Catalog:FindCandidates("official")
assert(#native == 3 and native[1].setID == 10 and native[3].setID == 12,
    "sets Blizzard lists natively are findable too, in set ID order")

printed = {}
print = function(line) printed[#printed + 1] = line end
Catalog:PrintMatches("hidden garb")
Catalog:PrintMatches("shimmering nonexistence")
print = realPrint
assert(printed[1] == "Wardrobe: matching hidden garb:", "headed the matches with the query")
assert(printed[2] == "Wardrobe:   listed: TransmogSet 20: Fixture Hidden Garb (5 pieces)", "showed the listed match")
assert(printed[3] == "Wardrobe:   left out: TransmogSet:27 Fixture Hidden Garb Copy: "
    .. "duplicate source membership: TransmogSet:20", "showed the rejected match and its reason")
assert(printed[4] == "Wardrobe: never saw shimmering nonexistence",
    "a name the scan never saw is reported as such, not as an empty result")

printed = {}
print = function(line) printed[#printed + 1] = line end
Catalog:PrintMatches("Official Vestments")
print = realPrint
assert(printed[2] == "Wardrobe:   native under Fixture Class 2: TransmogSet 11: Fixture Official Vestments",
    "a class-restricted set names the filter it sits behind, not just the tab")

-- Raw sweep: finds sets by name with no inclusion rules, official or not.

-- 10, 11 and 12 are official, 23 and 502 were rejected as covered by one; the
-- sweep is blind to all of that and reports every name that matches.
local swept = Catalog.SweepForName("fixture official", 40, 600)
assert(#swept == 5 and swept[1].recordID == 10 and swept[4].recordID == 23,
    "swept transmog sets by name regardless of the inclusion rules")
assert(swept[5].recordType == "ItemSet" and swept[5].recordID == 502,
    "transmog sets sweep before item sets, each in ID order")
assert(Catalog.SweepForName("woven", 40, 600)[1].recordType == "ItemSet", "swept item sets too")
assert(#Catalog.SweepForName("sparse", 20, 0) == 0, "a set above the swept ceiling is not reported")
assert(#Catalog.SweepForName("sparse", 40, 0) == 1, "raising the ceiling reaches it")
assert(#Catalog.SweepForName("nothing here", 40, 600) == 0, "an absent name sweeps up nothing")

-- Determinism: a rebuild over the same world produces identical records.

local firstBuild = fingerprint()
Catalog:Rebuild()
runDiscovery()
assert(fingerprint() == firstBuild, "rediscovery is deterministic for the same client")

-- Empty world: discovery still completes and reports an empty catalogue.

transmogSetInfos = {}
primarySources = {}
itemSetItems = {}
C_TransmogSets.GetSetInfo = function() return nil end
C_TransmogSets.GetSetPrimaryAppearances = function() return nil end
C_LootJournal.GetItemSetItems = function() return nil end
allSetsByClass = { [1] = {}, [2] = {} }
C_TransmogSets.GetAllSets = function() return {} end

Catalog:Rebuild()
runDiscovery()
assert(Catalog:IsReady() and #Catalog:GetRecords() == 0, "an empty world yields an empty, ready catalogue")

print("Lucky's Wardrobe extra sets catalogue tests passed")
