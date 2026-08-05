-- luacheck: globals C_TransmogCollection C_Item CreateFrame GetTime

-- Lucky's Wardrobe: recolor grouping. Armour appearances that share a model and
-- differ only in texture carry no Blizzard record: no set ID, no membership
-- list, and no name. Membership here is therefore inferred, which the Extra Sets
-- catalogue never does. `.docs/recolor-grouping-spec.md` records that departure.
--
-- A family forms only where two independent signals agree: the leading words its
-- members' item names share, and how close together those members sit in
-- Blizzard's own wardrobe ordering. `uiOrder` is a global sort key rather than a
-- per-category rank, and Blizzard gives one set's pieces near-consecutive
-- values, so a wide spread is strong evidence that a name prefix has swept up
-- unrelated items. Names alone are too eager to be trusted on their own.
--
-- One name usually covers several colourways, so ordering does the second job of
-- saying where one ends and the next begins. See RecolorGroups.Group.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.RecolorGroups = {}

local RecolorGroups = LuckysWardrobe.RecolorGroups

local MIN_ARMOUR_SLOTS = 3
-- Leading words this short ("The", "Sun") would seed a family out of unrelated
-- items that merely start alike.
local MIN_PREFIX_LENGTH = 5
-- Calibrated against families observed on retail 12.0.7.68974, whose members
-- spanned 200 to 900 of ordering, with headroom for larger sets and for gaps
-- where a set's pieces are not perfectly consecutive.
local MAX_UI_ORDER_SPAN = 5000

-- Collection type IDs 1 to 11 are exactly the armour slots, so a member's slot
-- is read from Blizzard's own category rather than derived from inventory type.
local SLOT_BY_CATEGORY = {
    [1] = "HEAD", [2] = "SHOULDER", [3] = "BACK", [4] = "CHEST", [5] = "BODY",
    [6] = "TABARD", [7] = "WRIST", [8] = "HANDS", [9] = "WAIST", [10] = "LEGS",
    [11] = "FEET",
}

local SLOT_ORDER = {
    "HEAD", "SHOULDER", "BACK", "CHEST", "BODY", "TABARD",
    "WRIST", "HANDS", "WAIST", "LEGS", "FEET",
}
local SLOT_INDEX = {}
for index, slot in ipairs(SLOT_ORDER) do SLOT_INDEX[slot] = index end

local REJECT = {
    shortPrefix = "shared name too short to identify a family",
    tooFewSlots = "fewer than " .. MIN_ARMOUR_SLOTS .. " armour slots",
    spread = "members too far apart in wardrobe order",
}

-- Names split on whitespace. Locales that do not space their words yield a
-- single token, so families there can only form from identical names, which in
-- practice means no grouping at all. That is the intended fallback: no groups
-- beats wrong groups in a locale the rule was never checked against.
local function words(name)
    local result = {}
    for word in name:gmatch("%S+") do result[#result + 1] = word end
    return result
end

local function sharedLeadingWords(members)
    local shared = {}
    for index = 1, #members[1].words do
        local word = members[1].words[index]
        for memberIndex = 2, #members do
            if members[memberIndex].words[index] ~= word then return shared end
        end
        shared[#shared + 1] = word
    end
    return shared
end

-- Groups appearances into candidate families, in a fixed order for a fixed
-- input. Returns the families and every cluster left out with its reason.
function RecolorGroups.Group(appearances)
    local buckets, keys = {}, {}
    for _, appearance in ipairs(appearances) do
        local slot = SLOT_BY_CATEGORY[appearance.categoryID]
        local nameWords = appearance.name and words(appearance.name) or {}
        if slot and nameWords[1] then
            local key = nameWords[1]:lower()
            if not buckets[key] then
                buckets[key] = {}
                keys[#keys + 1] = key
            end
            local bucket = buckets[key]
            bucket[#bucket + 1] = {
                name = appearance.name,
                words = nameWords,
                slot = slot,
                sourceID = appearance.sourceID,
                visualID = appearance.visualID,
                uiOrder = appearance.uiOrder,
                collected = appearance.collected,
            }
        end
    end
    table.sort(keys)

    local families, rejections = {}, {}
    local function reject(key, name, reason)
        rejections[#rejections + 1] = { key = key, name = name, reason = reason }
    end

    for _, key in ipairs(keys) do
        local members = buckets[key]
        local name = table.concat(sharedLeadingWords(members), " ")
        if #name < MIN_PREFIX_LENGTH then
            reject(key, name, REJECT.shortPrefix)
        else
            -- One name covers every colourway of a model, and tier sets ship the
            -- same piece names at several difficulties as separate appearances.
            -- A slot coming round again is therefore where one colourway ends,
            -- not an ambiguity: walking in wardrobe order and closing the run at
            -- each repeat splits them without a threshold deciding where.
            table.sort(members, function(left, right)
                return (left.uiOrder or 0) < (right.uiOrder or 0)
            end)

            local runs, current, seen = {}, {}, {}
            for _, member in ipairs(members) do
                if seen[member.slot] then
                    runs[#runs + 1] = current
                    current, seen = {}, {}
                end
                seen[member.slot] = true
                current[#current + 1] = member
            end
            runs[#runs + 1] = current

            for index, run in ipairs(runs) do
                local runKey = #runs > 1 and (key .. "#" .. index) or key
                local span = (run[#run].uiOrder or 0) - (run[1].uiOrder or 0)
                if #run < MIN_ARMOUR_SLOTS then
                    reject(runKey, name, REJECT.tooFewSlots)
                elseif span > MAX_UI_ORDER_SPAN then
                    reject(runKey, name, REJECT.spread .. ": " .. span)
                else
                    table.sort(run, function(left, right)
                        return SLOT_INDEX[left.slot] < SLOT_INDEX[right.slot]
                    end)
                    families[#families + 1] = {
                        key = runKey, name = name, span = span, members = run,
                    }
                end
            end
        end
    end

    return families, rejections
end

-- Every armour appearance the client will enumerate, with the name of a
-- representative source, plus what that enumeration covers.
--
-- GetCategoryAppearances answers through the player's wardrobe filters, so the
-- result is only as complete as the Items tab is unfiltered. Collected and
-- uncollected visibility are opened and restored around the sweep. Filters that
-- cannot be restored exactly are left alone; instead the client's own filtered
-- and unfiltered totals come back alongside, so a short enumeration is reported
-- rather than quietly producing fewer families.
function RecolorGroups.LiveAppearances()
    local shownCollected = C_TransmogCollection.GetCollectedShown()
    local shownUncollected = C_TransmogCollection.GetUncollectedShown()
    C_TransmogCollection.SetCollectedShown(true)
    C_TransmogCollection.SetUncollectedShown(true)

    local appearances = {}
    local coverage = { enumerated = 0, filtered = 0, total = 0, items = {} }
    for categoryID = 1, #SLOT_ORDER do
        coverage.total = coverage.total + (C_TransmogCollection.GetCategoryTotal(categoryID) or 0)
        coverage.filtered = coverage.filtered + (C_TransmogCollection.GetFilteredCategoryTotal(categoryID) or 0)
        for _, info in ipairs(C_TransmogCollection.GetCategoryAppearances(categoryID) or {}) do
            coverage.enumerated = coverage.enumerated + 1
            -- One appearance has many sources and they cache independently, so
            -- the first is often nameless while a later one already resolves.
            -- Every source is offered up for warming either way.
            local name, sourceID
            for _, candidate in ipairs(C_TransmogCollection.GetAllAppearanceSources(info.visualID) or {}) do
                local sourceInfo = C_TransmogCollection.GetSourceInfo(candidate)
                if sourceInfo then
                    if sourceInfo.itemID then
                        coverage.items[#coverage.items + 1] = sourceInfo.itemID
                    end
                    local candidateName = sourceInfo.name
                    if (not candidateName or candidateName == "") and sourceInfo.itemID then
                        candidateName = C_Item.GetItemInfo(sourceInfo.itemID)
                    end
                    if not name and candidateName and candidateName ~= "" then
                        name, sourceID = candidateName, candidate
                    end
                end
            end
            if name then
                appearances[#appearances + 1] = {
                    name = name,
                    categoryID = categoryID,
                    visualID = info.visualID,
                    sourceID = sourceID,
                    uiOrder = info.uiOrder,
                    collected = info.isCollected,
                }
            end
        end
    end

    C_TransmogCollection.SetCollectedShown(shownCollected)
    C_TransmogCollection.SetUncollectedShown(shownUncollected)
    return appearances, coverage
end

-- An appearance's item name is nil until the client holds that item's data, and
-- most of a full collection is cold, so a sweep run without warming names only a
-- fraction and quietly drops the rest of every family.
--
-- Placing the requests is not the same as holding the answers: they arrive later
-- as GET_ITEM_INFO_RECEIVED. Warming therefore waits until the client has gone
-- quiet for a few seconds and only then reports done. Some items never resolve,
-- so quiet is the finish line rather than a complete count.
local ITEMS_PER_STEP = 500
local QUIET_SECONDS = 3
local warmFrame = CreateFrame("Frame")

function RecolorGroups:WarmItemNames(itemIDs, onDone)
    local cursor, lastReply = 0, GetTime()
    local function finish()
        warmFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        warmFrame:SetScript("OnEvent", nil)
        warmFrame:SetScript("OnUpdate", nil)
        onDone()
    end

    warmFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    warmFrame:SetScript("OnEvent", function() lastReply = GetTime() end)
    warmFrame:SetScript("OnUpdate", function()
        for _ = 1, ITEMS_PER_STEP do
            if cursor >= #itemIDs then break end
            cursor = cursor + 1
            C_Item.RequestLoadItemDataByID(itemIDs[cursor])
            lastReply = GetTime()
        end
        if cursor >= #itemIDs and GetTime() - lastReply > QUIET_SECONDS then finish() end
    end)
end

-- Parks the whole report in saved variables. A full run is thousands of lines
-- and the chat frame keeps only its last few hundred, so chat can report totals
-- while the detail goes somewhere it can be read in full after a reload.
function RecolorGroups:DumpReport(database)
    local appearances, coverage = RecolorGroups.LiveAppearances()
    local families, rejections = RecolorGroups.Group(appearances)

    local dump = {
        appearances = #appearances,
        coverage = { enumerated = coverage.enumerated, filtered = coverage.filtered, total = coverage.total },
        families = {},
        rejections = {},
    }
    for index, family in ipairs(families) do
        local pieces = {}
        for pieceIndex, member in ipairs(family.members) do
            pieces[pieceIndex] = member.slot .. "|" .. member.name .. "|" .. (member.uiOrder or -1)
        end
        dump.families[index] = { name = family.name, span = family.span, pieces = pieces }
    end
    for index, rejection in ipairs(rejections) do
        dump.rejections[index] = rejection.key .. "|" .. rejection.name .. "|" .. rejection.reason
    end

    database.recolorDump = dump
    return #families, #rejections
end

-- Where name resolution falls down, counted step by step for one slot. The
-- report's totals say how many appearances ended up named but not which call
-- stopped answering, and those need different fixes.
function RecolorGroups.ResolutionFunnel(categoryID)
    local counts = { appearances = 0, sources = 0, items = 0, sourceNames = 0, itemNames = 0 }
    for _, info in ipairs(C_TransmogCollection.GetCategoryAppearances(categoryID) or {}) do
        counts.appearances = counts.appearances + 1
        local sources = C_TransmogCollection.GetAllAppearanceSources(info.visualID)
        if sources and sources[1] then
            counts.sources = counts.sources + 1
            local sourceInfo = C_TransmogCollection.GetSourceInfo(sources[1])
            if sourceInfo then
                if sourceInfo.itemID then counts.items = counts.items + 1 end
                if sourceInfo.name and sourceInfo.name ~= "" then
                    counts.sourceNames = counts.sourceNames + 1
                end
                if sourceInfo.itemID and C_Item.GetItemInfo(sourceInfo.itemID) then
                    counts.itemNames = counts.itemNames + 1
                end
            end
        end
    end
    return counts
end

function RecolorGroups:PrintFunnel()
    local S = LuckysWardrobe.Strings.recolorGroups
    for categoryID = 1, #SLOT_ORDER do
        local counts = RecolorGroups.ResolutionFunnel(categoryID)
        print(LuckysWardrobe.Strings.addon.prefix .. " " .. S.funnelLine:format(
            SLOT_ORDER[categoryID], counts.appearances, counts.sources,
            counts.items, counts.sourceNames, counts.itemNames))
    end
end

function RecolorGroups:PrintReport(verbose)
    local S = LuckysWardrobe.Strings.recolorGroups
    local function say(line) print(LuckysWardrobe.Strings.addon.prefix .. " " .. line) end

    local appearances, coverage = RecolorGroups.LiveAppearances()
    local families, rejections = RecolorGroups.Group(appearances)
    say(S.header:format(#appearances, #families, #rejections))
    if coverage.enumerated < coverage.total then
        say(S.shortCoverage:format(coverage.enumerated, coverage.total, coverage.filtered))
    end

    if not verbose then
        say(S.hint)
        return
    end

    for _, family in ipairs(families) do
        say(S.familyLine:format(family.name, #family.members, family.span))
        for _, member in ipairs(family.members) do
            say(S.memberLine:format(member.slot, member.name, member.uiOrder or -1))
        end
    end
    say(S.rejectedHeader:format(#rejections))
    for _, rejection in ipairs(rejections) do
        say(S.rejectionLine:format(rejection.key, rejection.reason))
    end
end
