-- luacheck: globals C_ClassColor C_CreatureInfo C_Item C_TransmogCollection C_TransmogSets EJ_GetInstanceInfo EJ_GetInvTypeSortOrder Enum GetNumClasses LuckysWardrobe

-- Covers which classes a tier token still serves: the slot it makes, the
-- difficulty its tooltip names, and saying nothing where no set can be found.

LuckysWardrobe = { DevLog = function() end }

local HEAD, HAND, CHEST, ROBE = 1, 10, 5, 20
_G.Enum = { InventoryType = {
    IndexHeadType = HEAD, IndexShoulderType = 3, IndexChestType = CHEST, IndexRobeType = ROBE,
    IndexHandType = HAND, IndexLegsType = 7,
} }
_G.GetNumClasses = function() return 2 end
_G.C_CreatureInfo = {
    GetClassInfo = function(classID)
        return ({ { className = "Warrior", classFile = "WARRIOR" }, { className = "Rogue", classFile = "ROGUE" } })[classID]
    end,
}
_G.EJ_GetInstanceInfo = function(instanceID) return ({ [1208] = "Aberrus" })[instanceID] end
_G.EJ_GetInvTypeSortOrder = function(invType) return invType end

-- Warrior has every Mythic piece but misses Normal hands; Rogue misses Mythic hands
-- and wears a robe on Normal.
local SETS = {
    [1] = { { setID = 10, label = "Aberrus", description = "Normal", classMask = 1 },
            { setID = 11, label = "Aberrus", description = "Mythic", classMask = 1 } },
    [2] = { { setID = 20, label = "Aberrus", description = "Normal", classMask = 2 },
            { setID = 21, label = "Aberrus", description = "Mythic", classMask = 2 } },
}
local PIECES = {
    [10] = { { 101, HAND, false }, { 102, HEAD, true } },
    [11] = { { 111, HAND, true }, { 112, HEAD, true } },
    [20] = { { 201, HAND, true }, { 202, ROBE, false } },
    [21] = { { 211, HAND, false }, { 212, HEAD, true } },
}
local invTypeOfItem = {}

local VARIANTS = {}
local filter = 0
_G.C_TransmogSets = {
    GetTransmogSetsClassFilter = function() return filter end,
    SetTransmogSetsClassFilter = function(classID) filter = classID end,
    GetAllSets = function() return SETS[filter] or {} end,
    GetVariantSets = function(setID) return VARIANTS[setID] or {} end,
    GetSetPrimaryAppearances = function(setID)
        local list = {}
        for index, piece in ipairs(PIECES[setID]) do
            list[index] = { appearanceID = piece[1], collected = piece[3] }
            invTypeOfItem[piece[1]] = piece[2]
        end
        return list
    end,
}
_G.C_TransmogCollection = {
    GetSourceInfo = function(sourceID) return { itemID = sourceID, invType = invTypeOfItem[sourceID], visualID = sourceID } end,
    GetAllAppearanceSources = function(visualID) return { visualID } end,
}
_G.C_Item = { GetItemInventoryTypeByID = function(itemID) return invTypeOfItem[itemID] end }

dofile("src/domain/Classes.lua")
dofile("src/domain/RaidSets.lua")
dofile("src/domain/TierTokens.lua")

LuckysWardrobe.TierTokensData = {
    [500] = { slot = HAND, classMask = 3, instances = { 1208 } },
    [501] = { slot = CHEST, classMask = 3, instances = { 1208 } },
    [502] = { slot = HAND, classMask = 3, instances = { 9999 } },
    [503] = { slot = 0, classMask = 1, instances = { 1208 } },
}

local TierTokens = LuckysWardrobe.TierTokens

local function names(classes)
    local list = {}
    for index, class in ipairs(classes) do list[index] = class.name end
    return table.concat(list, ",")
end

assert(TierTokens:ClassesNeeding(1, {}) == nil, "an item that is no token got an answer")
assert(names(TierTokens:ClassesNeeding(500, { "Zenith Mixing Fluid", "Mythic" })) == "Rogue",
    "the difficulty the token names was not the one checked")
assert(names(TierTokens:ClassesNeeding(500, { "Zenith Mixing Fluid", "|cff1eff00Mythic|r " })) == "Rogue",
    "a difficulty line carrying its colour was not read")
assert(names(TierTokens:ClassesNeeding(500, { "Zenith Mixing Fluid", "|cnGREEN_FONT_COLOR:Mythic|r" })) == "Rogue",
    "a difficulty line with a named colour was not read")
assert(names(TierTokens:ClassesNeeding(500, { "Zenith Mixing Fluid", "|cffa335eeMythic|r" })) == "Rogue",
    "a colour ending in a letter hid the difficulty")
assert(names(TierTokens:ClassesNeeding(500, { "Zenith Mixing Fluid", "Unmythic" })) == "Warrior",
    "a word merely ending in a difficulty was read as one")
assert(names(TierTokens:ClassesNeeding(500, { "Zenith Mixing Fluid" })) == "Warrior",
    "a token naming no difficulty was not read as Normal")
assert(names(TierTokens:ClassesNeeding(501, {})) == "Rogue", "a chest token did not count a robe")
assert(TierTokens:ClassesNeeding(502, {}) == nil, "a token whose raid has no sets claimed every class done")
assert(names(TierTokens:ClassesNeeding(503, {})) == "Warrior", "an any-slot token missed a token slot")
assert(#TierTokens:ClassesNeeding(503, { "Mythic" }) == 0, "a class with every piece was still listed")
