-- luacheck: globals C_LootJournal GetBuildInfo GetNumClasses

-- Lucky's Wardrobe: runtime discovery of Blizzard-defined sets the Sets API
-- does not list. The catalogue is derived once per session from documented
-- client APIs, in ID order with fixed rules, so the same client build always
-- produces the same records. Nothing discovered is persisted.
--
-- Inclusion rules:
-- - TransmogSet records qualify only when C_TransmogSets.GetAllSets (across
--   every class filter) did not list them.
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

-- Returns the slot token for an armour piece, nil for pieces that never count
-- (weapons, jewellery, unequippable), or nil plus a reason for tokens this
-- version does not recognise.
local function slotFor(equipLoc)
    if equipLoc == nil or NON_ARMOUR_SLOTS[equipLoc] then return nil end
    local slot = ARMOUR_SLOTS[equipLoc]
    if not slot then return nil, "unknown inventory type " .. tostring(equipLoc) end
    return slot
end

local function reject(key, reason)
    report.rejections[#report.rejections + 1] = { key = key, reason = reason }
end

-- The class filter narrows GetAllSets, so the official snapshot has to union
-- every class. The mutation is save, loop, restore inside one call, which the
-- UI never observes between frames.
local function snapshotOfficialSetIDs()
    local official = {}
    local savedFilter = C_TransmogSets.GetTransmogSetsClassFilter()
    for classID = 1, GetNumClasses() do
        C_TransmogSets.SetTransmogSetsClassFilter(classID)
        for _, set in ipairs(C_TransmogSets.GetAllSets() or {}) do
            official[set.setID] = true
        end
    end
    C_TransmogSets.SetTransmogSetsClassFilter(savedFilter)
    return official
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
        return reject(key, "no resolvable name")
    end
    local primary = C_TransmogSets.GetSetPrimaryAppearances(setID)
    if not primary or #primary == 0 then
        return reject(key, "no primary appearances")
    end

    local slotSources = {}
    local slotCount = 0
    for _, appearance in ipairs(primary) do
        -- Blizzard names this field appearanceID but it holds a source ID.
        local sourceID = appearance.appearanceID
        local itemID = C_TransmogCollection.GetSourceItemID(sourceID)
        if not itemID then
            return reject(key, "primary source has no item data")
        end
        local equipLoc = select(4, C_Item.GetItemInfoInstant(itemID))
        local slot, problem = slotFor(equipLoc)
        if problem then
            return reject(key, problem)
        end
        if slot then
            if slotSources[slot] and slotSources[slot] ~= sourceID then
                return reject(key, "ambiguous mapping: two primary sources for slot " .. slot)
            end
            if not slotSources[slot] then slotCount = slotCount + 1 end
            slotSources[slot] = sourceID
        end
    end
    if slotCount < MIN_ARMOUR_SLOTS then
        return reject(key, "fewer than " .. MIN_ARMOUR_SLOTS .. " wearable armour slots")
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
        return reject(key, "no resolvable name")
    end

    local slotSources = {}
    local slotCount = 0
    local armorType
    local mixedArmor = false
    for _, item in ipairs(items) do
        local _, _, _, equipLoc, _, itemClassID, itemSubClassID = C_Item.GetItemInfoInstant(item.itemID)
        local slot, problem = slotFor(equipLoc)
        if problem then
            return reject(key, problem)
        end
        if slot then
            local visualID, sourceID = C_TransmogCollection.GetItemInfo(item.itemID)
            if not visualID or not sourceID then
                return reject(key, "ambiguous mapping: item " .. item.itemID .. " has no appearance source")
            end
            if C_TransmogCollection.GetSourceItemID(sourceID) ~= item.itemID then
                return reject(key, "ambiguous mapping: item " .. item.itemID .. " does not round-trip to its source")
            end
            if slotSources[slot] and slotSources[slot] ~= sourceID then
                return reject(key, "ambiguous mapping: two sources for slot " .. slot)
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
        return reject(key, "fewer than " .. MIN_ARMOUR_SLOTS .. " wearable armour slots")
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
local function findCoveringOfficialSet(sources, sourceOwners)
    local counts = {}
    for _, sourceID in ipairs(sources) do
        local owners = sourceOwners[sourceID]
        if not owners then return nil end
        for _, setID in ipairs(owners) do
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
            table.insert(sourceOwners[sourceID], setID)
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
            reject(key, "covered by official set " .. coveringSetID)
        elseif seenMemberships[membershipKey] then
            reject(key, "duplicate source membership of " .. seenMemberships[membershipKey])
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
    report = { included = 0, rejections = {} }
    state = {
        phase = "transmogSets",
        cursor = 0,
        build = version .. "." .. buildNumber,
        officialLookup = snapshotOfficialSetIDs(),
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

-- Runs the callback once the catalogue exists, immediately when it already does.
function Catalog:OnReady(callback)
    if records then
        callback()
    else
        readyCallbacks[#readyCallbacks + 1] = callback
    end
end
