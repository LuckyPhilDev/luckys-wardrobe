-- luacheck: globals PLAYER_DIFFICULTY1 PLAYER_DIFFICULTY2 PLAYER_DIFFICULTY3 PLAYER_DIFFICULTY6

-- Lucky's Wardrobe: The class sets a raid drops, for every class at once.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.RaidSets = {}

local RaidSets = LuckysWardrobe.RaidSets

-- What a tier token turns into: the five slots the catalyst and the tokens cover.
local TOKEN_SLOTS = {
    [Enum.InventoryType.IndexHeadType] = true,
    [Enum.InventoryType.IndexShoulderType] = true,
    [Enum.InventoryType.IndexChestType] = true,
    [Enum.InventoryType.IndexRobeType] = true,
    [Enum.InventoryType.IndexHandType] = true,
    [Enum.InventoryType.IndexLegsType] = true,
}

local DIFFICULTY_ORDER = {
    [PLAYER_DIFFICULTY3 or "Raid Finder"] = 1,
    [PLAYER_DIFFICULTY1 or "Normal"] = 2,
    [PLAYER_DIFFICULTY2 or "Heroic"] = 3,
    [PLAYER_DIFFICULTY6 or "Mythic"] = 4,
}

-- Raid tier sets carry the raid's name as their label, which is the only link the
-- client offers between a set and where it drops. Keyed label, class, difficulty.
local byLabel
-- Sets that lost their place in the index to another of the same class and
-- difficulty, kept for /lw token: [kept setID] = { other setIDs }.
local shadowed

-- The class filter narrows GetAllSets, so every class is read in turn and the
-- player's own filter put back, the same as the Extra Sets catalogue does.
local function addToIndex(label, classID, set)
    local raid = byLabel[label] or {}
    byLabel[label] = raid
    local sets = raid[classID] or {}
    raid[classID] = sets
    local difficulty = set.description or ""
    local kept = sets[difficulty]
    if not kept then
        sets[difficulty] = set.setID
    elseif kept ~= set.setID then
        shadowed[kept] = shadowed[kept] or {}
        table.insert(shadowed[kept], set.setID)
    end
end

-- The class filter narrows GetAllSets, so every class is read in turn and the
-- player's own filter put back, the same as the Extra Sets catalogue does. Only
-- a base set carries the raid's name; its other difficulties are variants with
-- no label of their own, so they are filed under the base set's.
local function buildIndex()
    byLabel, shadowed = {}, {}
    local Classes = LuckysWardrobe.Classes
    local savedFilter = C_TransmogSets.GetTransmogSetsClassFilter()
    for classID = 1, GetNumClasses() do
        C_TransmogSets.SetTransmogSetsClassFilter(classID)
        for _, set in ipairs(C_TransmogSets.GetAllSets() or {}) do
            if set.label and set.label ~= "" and Classes:MaskHas(set.classMask or 0, classID) then
                addToIndex(set.label, classID, set)
                for _, variant in ipairs(C_TransmogSets.GetVariantSets(set.setID) or {}) do
                    addToIndex(set.label, classID, variant)
                end
            end
        end
    end
    C_TransmogSets.SetTransmogSetsClassFilter(savedFilter)
end

local function byDifficulty(a, b)
    local rankA, rankB = DIFFICULTY_ORDER[a] or 99, DIFFICULTY_ORDER[b] or 99
    if rankA ~= rankB then return rankA < rankB end
    return a < b
end

--- The class sets labelled with this raid's name, or nil for a raid with none:
--- { classes = { [classID] = { [difficulty] = setID } }, difficulties = { ... } }.
function RaidSets:ForInstance(raidName)
    if not raidName then return nil end
    if not byLabel then buildIndex() end

    local classes = byLabel[raidName]
    if not classes then
        LuckysWardrobe.DevLog("Raid sets: no class sets are labelled " .. raidName .. ".")
        return nil
    end

    local seen, difficulties = {}, {}
    for _, sets in pairs(classes) do
        for difficulty in pairs(sets) do
            if not seen[difficulty] then
                seen[difficulty] = true
                difficulties[#difficulties + 1] = difficulty
            end
        end
    end
    table.sort(difficulties, byDifficulty)

    return { classes = classes, difficulties = difficulties }
end

--- The difficulty of a raid's sets that the journal's own difficulty names. The
--- two disagree on wording ("10 Player (Heroic)" against "Heroic"), so either
--- containing the other counts. Falls back to the first.
function RaidSets.MatchDifficulty(difficulties, journalDifficulty)
    if journalDifficulty then
        for _, difficulty in ipairs(difficulties) do
            if difficulty ~= "" and (journalDifficulty:find(difficulty, 1, true)
                or difficulty:find(journalDifficulty, 1, true)) then
                return difficulty
            end
        end
    end
    return difficulties[1]
end

-- The set's flag covers only its own item. The look counts as collected from any
-- item that carries it, which is how Transmog Upgrade Master reads it too.
local function appearanceCollected(appearance, info)
    if appearance.collected or info.isCollected then return true end
    for _, otherID in ipairs(C_TransmogCollection.GetAllAppearanceSources(info.visualID) or {}) do
        local other = C_TransmogCollection.GetSourceInfo(otherID)
        if other and other.isCollected then return true end
    end
    return false
end

-- Read on every tooltip refresh, so kept until the collection changes.
local piecesBySet = {}

local function readPieces(setID)
    local pieces = {}
    for _, appearance in ipairs(C_TransmogSets.GetSetPrimaryAppearances(setID) or {}) do
        -- Named appearanceID, holds a sourceID. Blizzard's field, left as it comes.
        local sourceID = appearance.appearanceID
        local info = C_TransmogCollection.GetSourceInfo(sourceID)
        if info then
            local invType = C_Item.GetItemInventoryTypeByID(info.itemID)
            pieces[#pieces + 1] = {
                sourceID = sourceID,
                itemID = info.itemID,
                invType = invType,
                collected = appearanceCollected(appearance, info),
                setSaysCollected = appearance.collected,
                token = TOKEN_SLOTS[invType] or false,
                sortOrder = EJ_GetInvTypeSortOrder(info.invType) or 99,
            }
        end
    end
    table.sort(pieces, function(a, b) return a.sortOrder < b.sortOrder end)
    return pieces
end

--- A set's pieces in journal slot order: { sourceID, itemID, invType, collected, token }.
function RaidSets:Pieces(setID)
    local pieces = piecesBySet[setID]
    if not pieces then
        pieces = readPieces(setID)
        piecesBySet[setID] = pieces
    end
    return pieces
end

--- Other sets with the same raid, class and difficulty as this one, which the
--- index passed over in its favour.
function RaidSets:ShadowedBy(setID)
    return shadowed and shadowed[setID] or {}
end

function RaidSets:ForgetCollected()
    piecesBySet = {}
end

function RaidSets:Init()
    local events = CreateFrame("Frame")
    events:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
    events:SetScript("OnEvent", function() RaidSets:ForgetCollected() end)
end
