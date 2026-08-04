-- luacheck: globals C_LootJournal GetBuildInfo GetNumClasses GetClassInfo

-- Lucky's Wardrobe: runtime discovery of Blizzard-defined sets the Sets API
-- does not list. The catalogue is derived once per session from documented
-- client APIs, in ID order with fixed rules, so the same client build always
-- produces the same records. Nothing discovered is persisted.
--
-- Inclusion rules:
-- - TransmogSet records qualify only when C_TransmogSets.GetAllSets (across
--   every class filter) did not list them. Membership comes from the set's
--   primary appearances when it has any, otherwise its whole source list.
-- - ItemSet records qualify only when every armour piece maps to exactly one
--   appearance source whose owning item round-trips to the same item. Anything
--   ambiguous is rejected with a reason, never guessed.
-- - Records need at least MIN_ARMOUR_SLOTS armour slots; weapons and
--   jewellery never count.
-- - Records whose sources sit inside an official set, or repeat an earlier
--   record's membership, are rejected as duplicates.
-- Rejections are kept in a session report so nothing disappears silently.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.ExtraSetsCatalog = {}

local Catalog = LuckysWardrobe.ExtraSetsCatalog

local MAX_TRANSMOG_SET_ID = 10000
local MAX_ITEM_SET_ID = 5000
-- The diagnostic sweep deliberately reaches past discovery's ceilings, so a set
-- sitting above them shows up as such instead of looking like it does not exist.
local SWEEP_TRANSMOG_CEILING = 60000
local SWEEP_ITEM_CEILING = 20000
local IDS_PER_STEP = 200
local MIN_ARMOUR_SLOTS = 3
local ITEM_CLASS_ARMOR = 4

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

local NON_ARMOUR_SLOTS = {
    INVTYPE_NECK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true,
    INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true,
    INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true,
    INVTYPE_AMMO = true, INVTYPE_RELIC = true, INVTYPE_BAG = true,
    INVTYPE_QUIVER = true, [""] = true,
}

local stepFrame = CreateFrame("Frame")
local state
local records
local report
local readyCallbacks = {}

-- Stable rejection categories, so the session report can group candidates by
-- why they were left out instead of by their one-off details.
local REJECT = {
    noName = "no resolvable name",
    noSources = "no appearance sources",
    noItemData = "source has no item data",
    unknownSlot = "unknown inventory type",
    ambiguous = "ambiguous mapping",
    tooFewSlots = "fewer than " .. MIN_ARMOUR_SLOTS .. " wearable armour slots",
    official = "covered by an official set",
    duplicate = "duplicate source membership",
}

-- Returns the slot token for an armour piece, nil for pieces that never count
-- (weapons, jewellery, unequippable), or nil plus a detail for tokens this
-- version does not recognise.
local function slotFor(equipLoc)
    if equipLoc == nil or NON_ARMOUR_SLOTS[equipLoc] then return nil end
    local slot = ARMOUR_SLOTS[equipLoc]
    if not slot then return nil, tostring(equipLoc) end
    return slot
end

-- The name is what makes a rejection recognisable in the report; it is nil only
-- when the candidate had no resolvable name to begin with.
local function reject(key, name, category, detail)
    report.rejections[#report.rejections + 1] = {
        key = key,
        name = name,
        category = category,
        reason = detail and (category .. ": " .. detail) or category,
    }
end

-- The class filter narrows GetAllSets, so the official snapshot has to union
-- every class. The mutation is save, loop, restore inside one call, which the
-- UI never observes between frames. Names are kept so a set Blizzard already
-- lists can be told apart from one nothing on the client knows about.
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

-- Primary appearances are the Sets journal's presentation data, so sets Blizzard
-- never lists there routinely have none. Blizzard's own dress-up, account store,
-- and covenant previews read whole-set membership from GetAllSourceIDs, which is
-- the surface that answers for exactly those sets.
local function memberSourceIDs(setID)
    local sources = {}
    for _, appearance in ipairs(C_TransmogSets.GetSetPrimaryAppearances(setID) or {}) do
        -- Blizzard names this field appearanceID but it holds a source ID.
        sources[#sources + 1] = appearance.appearanceID
    end
    if #sources > 0 then return sources end
    return C_TransmogSets.GetAllSourceIDs(setID) or {}
end

local function scanTransmogSet(setID)
    local info = C_TransmogSets.GetSetInfo(setID)
    if not info then return end

    if state.officialLookup[setID] then
        local sourceIDs = C_TransmogSets.GetAllSourceIDs(setID)
        if sourceIDs and #sourceIDs > 0 then
            state.officialMembership[setID] = sourceIDs
        end
        return
    end

    local key = "TransmogSet:" .. setID
    if not info.name or info.name == "" then
        return reject(key, nil, REJECT.noName)
    end
    local sources = memberSourceIDs(setID)
    if #sources == 0 then
        return reject(key, info.name, REJECT.noSources)
    end

    local slotSources = {}
    local slotCount = 0
    for _, sourceID in ipairs(sources) do
        local itemID = C_TransmogCollection.GetSourceItemID(sourceID)
        if not itemID then
            return reject(key, info.name, REJECT.noItemData)
        end
        local equipLoc = select(4, C_Item.GetItemInfoInstant(itemID))
        local slot, problem = slotFor(equipLoc)
        if problem then
            return reject(key, info.name, REJECT.unknownSlot, problem)
        end
        if slot then
            if slotSources[slot] and slotSources[slot] ~= sourceID then
                return reject(key, info.name, REJECT.ambiguous, "two sources for slot " .. slot)
            end
            if not slotSources[slot] then slotCount = slotCount + 1 end
            slotSources[slot] = sourceID
        end
    end
    if slotCount < MIN_ARMOUR_SLOTS then
        return reject(key, info.name, REJECT.tooFewSlots)
    end

    state.candidates[#state.candidates + 1] = {
        recordType = "TransmogSet",
        recordID = setID,
        name = info.name,
        label = info.label,
        classMask = info.classMask or 0,
        expansionID = info.expansionID,
        build = state.build,
        slotSources = slotSources,
    }
end

local function scanItemSet(setID)
    local items = C_LootJournal.GetItemSetItems(setID)
    if not items or #items == 0 then return end

    local key = "ItemSet:" .. setID
    local name = C_Item.GetItemSetInfo(setID)
    if not name or name == "" then
        return reject(key, nil, REJECT.noName)
    end

    local slotSources = {}
    local slotCount = 0
    local armorType
    local mixedArmor = false
    for _, item in ipairs(items) do
        local _, _, _, equipLoc, _, itemClassID, itemSubClassID = C_Item.GetItemInfoInstant(item.itemID)
        local slot, problem = slotFor(equipLoc)
        if problem then
            return reject(key, name, REJECT.unknownSlot, problem)
        end
        if slot then
            local visualID, sourceID = C_TransmogCollection.GetItemInfo(item.itemID)
            if not visualID or not sourceID then
                return reject(key, name, REJECT.ambiguous, "item " .. item.itemID .. " has no appearance source")
            end
            if C_TransmogCollection.GetSourceItemID(sourceID) ~= item.itemID then
                return reject(key, name, REJECT.ambiguous, "item " .. item.itemID .. " does not round-trip to its source")
            end
            if slotSources[slot] and slotSources[slot] ~= sourceID then
                return reject(key, name, REJECT.ambiguous, "two sources for slot " .. slot)
            end
            if not slotSources[slot] then slotCount = slotCount + 1 end
            slotSources[slot] = sourceID
            if itemClassID == ITEM_CLASS_ARMOR then
                if armorType == nil then
                    armorType = itemSubClassID
                elseif armorType ~= itemSubClassID then
                    mixedArmor = true
                end
            end
        end
    end
    if slotCount < MIN_ARMOUR_SLOTS then
        return reject(key, name, REJECT.tooFewSlots)
    end

    state.candidates[#state.candidates + 1] = {
        recordType = "ItemSet",
        recordID = setID,
        name = name,
        classMask = 0,
        armorType = not mixedArmor and armorType or nil,
        build = state.build,
        slotSources = slotSources,
    }
end

local function sortedSources(slotSources)
    local sources = {}
    for _, sourceID in pairs(slotSources) do sources[#sources + 1] = sourceID end
    table.sort(sources)
    return sources
end

-- Lowest official set whose membership contains every candidate source, if any.
-- Owners are counted once per source: a set that lists the same source twice
-- would otherwise reach the total without owning every source.
local function findCoveringOfficialSet(sources, sourceOwners)
    local counts = {}
    for _, sourceID in ipairs(sources) do
        local owners = sourceOwners[sourceID]
        if not owners then return nil end
        for setID in pairs(owners) do
            counts[setID] = (counts[setID] or 0) + 1
        end
    end
    local best
    for setID, count in pairs(counts) do
        if count == #sources and (not best or setID < best) then best = setID end
    end
    return best
end

local function finalize()
    local sourceOwners = {}
    for setID, sources in pairs(state.officialMembership) do
        for _, sourceID in ipairs(sources) do
            sourceOwners[sourceID] = sourceOwners[sourceID] or {}
            sourceOwners[sourceID][setID] = true
        end
    end

    records = {}
    local seenMemberships = {}
    for _, candidate in ipairs(state.candidates) do
        local key = candidate.recordType .. ":" .. candidate.recordID
        local sources = sortedSources(candidate.slotSources)
        local membershipKey = table.concat(sources, ":")
        local coveringSetID = findCoveringOfficialSet(sources, sourceOwners)
        if coveringSetID then
            reject(key, candidate.name, REJECT.official, tostring(coveringSetID))
        elseif seenMemberships[membershipKey] then
            reject(key, candidate.name, REJECT.duplicate, seenMemberships[membershipKey])
        else
            seenMemberships[membershipKey] = key
            records[#records + 1] = candidate
        end
    end

    report.included = #records
    state = nil
    stepFrame:SetScript("OnUpdate", nil)

    LuckysWardrobe.DevLog("Extra Sets catalogue built: " .. #records .. " record(s), "
        .. #report.rejections .. " rejection(s).")
    for _, callback in ipairs(readyCallbacks) do callback() end
    readyCallbacks = {}
end

local function step()
    for _ = 1, IDS_PER_STEP do
        state.cursor = state.cursor + 1
        if state.phase == "transmogSets" then
            if state.cursor > MAX_TRANSMOG_SET_ID then
                state.phase = "itemSets"
                state.cursor = 0
            else
                scanTransmogSet(state.cursor)
            end
        elseif state.phase == "itemSets" then
            if state.cursor > MAX_ITEM_SET_ID then
                finalize()
                return
            end
            scanItemSet(state.cursor)
        end
    end
end

function Catalog:StartBuild()
    if records or state then return end

    local version, buildNumber = GetBuildInfo()
    local official = snapshotOfficialSets()
    report = { build = version .. "." .. buildNumber, included = 0, rejections = {}, official = official }
    state = {
        phase = "transmogSets",
        cursor = 0,
        build = version .. "." .. buildNumber,
        officialLookup = official,
        officialMembership = {},
        candidates = {},
    }
    stepFrame:SetScript("OnUpdate", step)
end

-- Discards the session catalogue and discovers again. Dev and test hook.
function Catalog:Rebuild()
    records = nil
    if state then
        state = nil
        stepFrame:SetScript("OnUpdate", nil)
    end
    self:StartBuild()
end

function Catalog:IsReady()
    return records ~= nil
end

function Catalog:GetRecords()
    return records or {}
end

function Catalog:GetReport()
    return report
end

-- Groups this session's rejected candidates by why they were left out, most
-- common first, with a stable order for equal counts.
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

local function countPieces(record)
    local pieces = 0
    for _ in pairs(record.slotSources) do pieces = pieces + 1 end
    return pieces
end

function Catalog:PrintReport(verbose)
    local S = LuckysWardrobe.Strings.extraSets.report
    local function say(line) print(LuckysWardrobe.Strings.addon.prefix .. " " .. line) end

    if not report then
        say(S.notStarted)
        return
    end
    if not records then
        say(S.building)
        return
    end

    say(S.header:format(report.build, #records, #report.rejections))

    -- The catalogue spans every class, so a per-character number is the one to
    -- compare against any list built for the logged-in character. Counting the
    -- page's own entries keeps the report and the page from ever disagreeing.
    local ExtraSets = LuckysWardrobe.ExtraSets
    local usable = 0
    for _, entry in ipairs(ExtraSets.BuildEntries(records, ExtraSets.LiveResolver())) do
        if entry.usable then usable = usable + 1 end
    end
    say(S.usableLine:format(usable))

    for _, group in ipairs(self:SummarizeRejections()) do
        say(S.groupLine:format(group.category, group.count))
    end

    if not verbose then
        say(S.hint)
        return
    end

    say(S.includedHeader:format(#records))
    for _, record in ipairs(records) do
        say(S.recordLine:format(record.recordType, record.recordID, record.name, countPieces(record)))
    end
    say(S.rejectedHeader:format(#report.rejections))
    for _, rejection in ipairs(report.rejections) do
        say(S.rejectionLine:format(rejection.key, rejection.name or S.unnamed, rejection.reason))
    end
end

-- Every set whose name contains the query: listed, dropped by a rule, or one
-- Blizzard already lists natively. Missing from all three means nothing on this
-- client answers to the name, which is a different problem from a rule dropping it.
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

-- Raw name sweep over a wider ID range than discovery uses, with no inclusion
-- rules applied. This answers a question the session report cannot: whether the
-- client holds a set by this name at all, and at what ID. A hit above
-- MAX_TRANSMOG_SET_ID or MAX_ITEM_SET_ID means discovery's ceiling is too low;
-- no hit anywhere means nothing on this client answers to the name.
function Catalog.SweepForName(query, transmogCeiling, itemCeiling)
    local normalized = (query or ""):lower()
    local hits = {}
    for setID = 1, transmogCeiling do
        local info = C_TransmogSets.GetSetInfo(setID)
        local name = info and info.name
        if name and name ~= "" and name:lower():find(normalized, 1, true) then
            hits[#hits + 1] = { recordType = "TransmogSet", recordID = setID, name = name }
        end
    end
    for setID = 1, itemCeiling do
        local name = C_Item.GetItemSetInfo(setID)
        if name and name ~= "" and name:lower():find(normalized, 1, true) then
            hits[#hits + 1] = { recordType = "ItemSet", recordID = setID, name = name }
        end
    end
    return hits
end

function Catalog:PrintSweep(query)
    local S = LuckysWardrobe.Strings.extraSets.report
    local function say(line) print(LuckysWardrobe.Strings.addon.prefix .. " " .. line) end

    local hits = Catalog.SweepForName(query, SWEEP_TRANSMOG_CEILING, SWEEP_ITEM_CEILING)
    if #hits == 0 then
        say(S.sweepNone:format(query, SWEEP_TRANSMOG_CEILING, SWEEP_ITEM_CEILING))
        return
    end

    say(S.sweepHeader:format(query))
    for _, hit in ipairs(hits) do
        local beyond = (hit.recordType == "TransmogSet" and hit.recordID > MAX_TRANSMOG_SET_ID)
            or (hit.recordType == "ItemSet" and hit.recordID > MAX_ITEM_SET_ID)
        say(S.sweepHit:format(hit.recordType, hit.recordID, hit.name, beyond and S.sweepBeyond or ""))
    end
end

function Catalog:PrintMatches(query)
    local S = LuckysWardrobe.Strings.extraSets.report
    local function say(line) print(LuckysWardrobe.Strings.addon.prefix .. " " .. line) end

    if not report then
        say(S.notStarted)
        return
    end
    if not records then
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
        say(S.foundListed:format(record.recordType, record.recordID, record.name, countPieces(record)))
    end
    for _, rejection in ipairs(dropped) do
        say(S.foundDropped:format(rejection.key, rejection.name, rejection.reason))
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
    if records then
        callback()
    else
        readyCallbacks[#readyCallbacks + 1] = callback
    end
end
