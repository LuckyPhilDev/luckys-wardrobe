-- luacheck: globals GetBuildInfo GetNumClasses GetClassInfo

-- Lucky's Wardrobe: the Extra Sets catalogue, built from the set data bundled
-- in src/Data. The client holds all of these sets in its own tables but lists
-- only a fraction of them through C_TransmogSets.GetAllSets, so the snapshot
-- supplies which items belong together and the client supplies everything the
-- collection knows about them.
--
-- Building a record means turning each item ID into the appearance source the
-- collection actually tracks. A piece this client cannot answer for is counted,
-- never guessed at, and a set with no resolvable piece at all is left out with
-- its reason kept in the session report. Nothing built here is persisted.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.ExtraSetsCatalog = {}

local Catalog = LuckysWardrobe.ExtraSetsCatalog

-- Each set asks the client about every one of its items, so the work is paced
-- to keep a frame's share of it small: the whole catalogue lands in about a
-- second, which is faster than a player can open Collections and reach the tab.
local SETS_PER_STEP = 50
local MAX_VERBOSE_LINES = 40

local ARMOUR_SLOTS = {
    INVTYPE_HEAD = "HEAD",
    INVTYPE_SHOULDER = "SHOULDER",
    INVTYPE_CLOAK = "BACK",
    INVTYPE_CHEST = "CHEST",
    INVTYPE_ROBE = "CHEST",
    INVTYPE_BODY = "BODY",
    INVTYPE_TABARD = "TABARD",
    INVTYPE_WRIST = "WRIST",
    INVTYPE_HAND = "HANDS",
    INVTYPE_WAIST = "WAIST",
    INVTYPE_LEGS = "LEGS",
    INVTYPE_FEET = "FEET",
}

-- Locale-free slot keys in display order, head to feet. Records leave here
-- already ordered, so nothing downstream has to know what a slot means.
local SLOT_ORDER = {
    "HEAD", "SHOULDER", "BACK", "CHEST", "BODY", "TABARD",
    "WRIST", "HANDS", "WAIST", "LEGS", "FEET",
}

local REJECT = {
    unresolvable = "no piece this client can resolve",
}

local stepFrame = CreateFrame("Frame")
local state
local records
local report
local readyCallbacks = {}

local function reject(setID, name, category)
    report.rejections[#report.rejections + 1] = { setID = setID, name = name, category = category }
end

-- The class filter narrows GetAllSets, so the official snapshot has to union
-- every class. The mutation is save, loop, restore inside one call, which the
-- UI never observes between frames. Names are kept so a set Blizzard already
-- lists can be told apart from one only the bundled data names.
local function snapshotOfficialSets()
    local official = {}
    local savedFilter = C_TransmogSets.GetTransmogSetsClassFilter()
    for classID = 1, GetNumClasses() do
        C_TransmogSets.SetTransmogSetsClassFilter(classID)
        for _, set in ipairs(C_TransmogSets.GetAllSets() or {}) do
            official[set.setID] = set.name or ""
        end
    end
    C_TransmogSets.SetTransmogSetsClassFilter(savedFilter)
    return official
end

-- The collection tracks appearance sources, not items, so an item ID is only
-- useful once the client has named the source behind it. A piece the client
-- answers for but the page never shows, a weapon or a ring, comes back empty; a
-- piece this client holds no data for at all comes back empty and flagged, so a
-- set can say how much of itself this build is missing.
local function resolveItem(itemID)
    local equipLoc = select(4, C_Item.GetItemInfoInstant(itemID))
    if not equipLoc then return nil, nil, true end

    local slot = ARMOUR_SLOTS[equipLoc]
    if not slot then return nil end

    local _, sourceID = C_TransmogCollection.GetItemInfo(itemID)
    if not sourceID then return nil, nil, true end
    return slot, sourceID
end

-- Pieces come out in slot order, keeping the snapshot's order within a slot so
-- a set carrying both a chest and a robe shows them the way Wowhead lists them.
local function buildPieces(itemIDs)
    local bySlot, unresolved, seenSources = {}, 0, {}
    for _, itemID in ipairs(itemIDs) do
        local slot, sourceID, unknown = resolveItem(itemID)
        if unknown then
            unresolved = unresolved + 1
        elseif slot and not seenSources[sourceID] then
            seenSources[sourceID] = true
            bySlot[slot] = bySlot[slot] or {}
            table.insert(bySlot[slot], { slot = slot, sourceID = sourceID, itemID = itemID })
        end
    end

    local pieces = {}
    for _, slot in ipairs(SLOT_ORDER) do
        for _, piece in ipairs(bySlot[slot] or {}) do
            pieces[#pieces + 1] = piece
        end
    end
    return pieces, unresolved
end

local function buildRecord(setID, set, armorType)
    local pieces, unresolved = buildPieces(set.pieces)
    if #pieces == 0 then
        return reject(setID, set.name, REJECT.unresolvable)
    end

    report.unresolvedPieces = report.unresolvedPieces + unresolved
    -- Where the client knows the set it is the authority on who may wear it and
    -- which expansion it belongs to; the snapshot only fills the gaps.
    local info = C_TransmogSets.GetSetInfo(setID)
    records[#records + 1] = {
        setID = setID,
        name = set.name,
        armorType = armorType,
        classMask = info and info.classMask or set.classMask,
        expansionID = info and info.expansionID,
        label = info and info.label,
        pieces = pieces,
        unresolvedPieces = unresolved,
    }
end

-- Set IDs are the keys of a hash table, so the work list fixes an order once
-- and the stepper walks it across frames from there.
local function workList()
    local work = {}
    for _, armour in ipairs(LuckysWardrobe.ExtraSetsData.armorTypes) do
        local setIDs = {}
        for setID in pairs(LuckysWardrobe.ExtraSetsData.sets[armour.key] or {}) do
            setIDs[#setIDs + 1] = setID
        end
        table.sort(setIDs)
        work[#work + 1] = { key = armour.key, armorType = armour.armorType, setIDs = setIDs }
    end
    return work
end

local function finalize()
    for _, record in ipairs(records) do
        if report.official[record.setID] then
            report.alsoOfficial = report.alsoOfficial + 1
        end
    end

    state = nil
    stepFrame:SetScript("OnUpdate", nil)

    LuckysWardrobe.DevLog("Extra Sets catalogue built: " .. #records .. " set(s), "
        .. #report.rejections .. " left out.")
    for _, callback in ipairs(readyCallbacks) do callback() end
    readyCallbacks = {}
end

local function step()
    for _ = 1, SETS_PER_STEP do
        local group = state.work[state.groupIndex]
        if not group then return finalize() end

        state.cursor = state.cursor + 1
        local setID = group.setIDs[state.cursor]
        if not setID then
            state.groupIndex = state.groupIndex + 1
            state.cursor = 0
        else
            buildRecord(setID, LuckysWardrobe.ExtraSetsData.sets[group.key][setID], group.armorType)
        end
    end
end

function Catalog:StartBuild()
    if records or state then return end

    local version, buildNumber = GetBuildInfo()
    records = {}
    report = {
        snapshot = LuckysWardrobe.ExtraSetsData.snapshot,
        build = version .. "." .. buildNumber,
        alsoOfficial = 0,
        unresolvedPieces = 0,
        rejections = {},
        official = snapshotOfficialSets(),
    }
    state = { work = workList(), groupIndex = 1, cursor = 0 }
    stepFrame:SetScript("OnUpdate", step)
end

-- Discards the session catalogue and builds it again. Dev and test hook.
function Catalog:Rebuild()
    records = nil
    if state then
        state = nil
        stepFrame:SetScript("OnUpdate", nil)
    end
    self:StartBuild()
end

function Catalog:IsReady()
    return records ~= nil and state == nil
end

function Catalog:GetRecords()
    if not self:IsReady() then return {} end
    return records
end

function Catalog:GetReport()
    return report
end

-- Groups this session's left-out sets by reason, most common first, with a
-- stable order for equal counts.
function Catalog:SummarizeRejections()
    local counts, categories = {}, {}
    for _, rejection in ipairs(report and report.rejections or {}) do
        if counts[rejection.category] == nil then
            counts[rejection.category] = 0
            categories[#categories + 1] = rejection.category
        end
        counts[rejection.category] = counts[rejection.category] + 1
    end

    table.sort(categories, function(left, right)
        if counts[left] ~= counts[right] then return counts[left] > counts[right] end
        return left < right
    end)

    local summary = {}
    for index, category in ipairs(categories) do
        summary[index] = { category = category, count = counts[category] }
    end
    return summary
end

function Catalog:PrintReport(verbose)
    local S = LuckysWardrobe.Strings.extraSets.report
    local function say(line) print(LuckysWardrobe.Strings.addon.prefix .. " " .. line) end

    if not report then
        say(S.notStarted)
        return
    end
    if not self:IsReady() then
        say(S.building)
        return
    end

    local total = #records + #report.rejections
    say(S.header:format(report.snapshot, report.build, #records, total))

    -- The catalogue spans every class and armour type, so a per-character number
    -- is the one to compare against any list built for the logged-in character.
    -- Counting the page's own entries keeps the report and the page from ever
    -- disagreeing.
    local usable = 0
    for _, entry in ipairs(LuckysWardrobe.ExtraSets.Entries()) do
        if entry.usable then usable = usable + 1 end
    end
    say(S.usableLine:format(usable))
    say(S.officialLine:format(report.alsoOfficial))
    if report.unresolvedPieces > 0 then
        say(S.unresolvedLine:format(report.unresolvedPieces))
    end
    for _, group in ipairs(self:SummarizeRejections()) do
        say(S.groupLine:format(group.category, group.count))
    end

    if not verbose then
        say(S.hint)
        return
    end

    say(S.includedHeader:format(#records))
    for index, record in ipairs(records) do
        if index > MAX_VERBOSE_LINES then
            say(S.andMore:format(#records - MAX_VERBOSE_LINES))
            break
        end
        say(S.recordLine:format(record.setID, record.name, #record.pieces))
    end
    say(S.rejectedHeader:format(#report.rejections))
    for index, rejection in ipairs(report.rejections) do
        if index > MAX_VERBOSE_LINES then
            say(S.andMore:format(#report.rejections - MAX_VERBOSE_LINES))
            break
        end
        say(S.rejectionLine:format(rejection.setID, rejection.name, rejection.category))
    end
end

-- Every set whose name contains the query: listed, left out by a rule, or one
-- Blizzard lists natively. A set can appear in more than one list, which is the
-- point: the overlap between the bundled data and the Sets tab is exactly what
-- a duplicate looks like.
function Catalog:FindCandidates(query)
    local normalized = (query or ""):lower()
    local listed, dropped, native = {}, {}, {}
    for _, record in ipairs(records or {}) do
        if record.name:lower():find(normalized, 1, true) then listed[#listed + 1] = record end
    end
    for _, rejection in ipairs(report and report.rejections or {}) do
        if rejection.name and rejection.name:lower():find(normalized, 1, true) then
            dropped[#dropped + 1] = rejection
        end
    end
    for setID, name in pairs(report and report.official or {}) do
        if name ~= "" and name:lower():find(normalized, 1, true) then
            native[#native + 1] = { setID = setID, name = name }
        end
    end
    table.sort(native, function(left, right) return left.setID < right.setID end)
    return listed, dropped, native
end

function Catalog:PrintMatches(query)
    local S = LuckysWardrobe.Strings.extraSets.report
    local function say(line) print(LuckysWardrobe.Strings.addon.prefix .. " " .. line) end

    if not report then
        say(S.notStarted)
        return
    end
    if not self:IsReady() then
        say(S.building)
        return
    end

    local listed, dropped, native = self:FindCandidates(query)
    if #listed == 0 and #dropped == 0 and #native == 0 then
        say(S.findNone:format(query))
        return
    end

    say(S.findHeader:format(query))
    for _, record in ipairs(listed) do
        say(S.foundListed:format(record.setID, record.name, #record.pieces))
    end
    for _, rejection in ipairs(dropped) do
        say(S.foundDropped:format(rejection.setID, rejection.name, rejection.category))
    end
    -- The Sets tab filters to one class at a time and opens on the player's own,
    -- so saying a set is listed there is misleading on a character that cannot
    -- see it. Name the class filter it sits behind instead.
    for _, set in ipairs(native) do
        local classID = C_TransmogSets.GetValidClassForSet(set.setID)
        local className = classID and GetClassInfo(classID)
        if className then
            say(S.foundNativeClass:format(className, set.setID, set.name))
        else
            say(S.foundNative:format(set.setID, set.name))
        end
    end
end

-- Runs the callback once the catalogue exists, immediately when it already does.
function Catalog:OnReady(callback)
    if self:IsReady() then
        callback()
    else
        readyCallbacks[#readyCallbacks + 1] = callback
    end
end
