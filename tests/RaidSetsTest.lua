-- luacheck: globals C_ClassColor C_CreatureInfo C_Item C_TransmogCollection C_TransmogSets EJ_GetInvTypeSortOrder Enum GetNumClasses LuckysWardrobe

-- Covers finding a raid's class sets across every class, and which difficulty
-- the journal's own wording picks.

LuckysWardrobe = { DevLog = function() end }

_G.Enum = { InventoryType = {
    IndexHeadType = 1, IndexShoulderType = 3, IndexChestType = 5, IndexRobeType = 20,
    IndexHandType = 10, IndexLegsType = 7, IndexWristType = 9,
} }
_G.GetNumClasses = function() return 2 end
_G.C_CreatureInfo = {
    GetClassInfo = function(classID)
        return ({ { className = "Warrior", classFile = "WARRIOR" }, { className = "Paladin", classFile = "PALADIN" } })[classID]
    end,
}

local ABERRUS = "Aberrus, the Shadowed Crucible"
local SETS = {
    [1] = {
        { setID = 10, label = ABERRUS, description = "Normal", classMask = 1 },
        { setID = 11, label = ABERRUS, description = "Mythic", classMask = 1 },
        { setID = 99, label = "Honor", description = "", classMask = 0 },
    },
    [2] = {
        { setID = 20, label = ABERRUS, description = "Heroic", classMask = 2 },
    },
}

-- Sepulcher's other difficulties are variants of its Normal set, carrying no label.
local VARIANTS = { [20] = { { setID = 22, label = "", description = "Raid Finder", classMask = 2 } } }
local filter = 7
_G.C_TransmogSets = {
    GetTransmogSetsClassFilter = function() return filter end,
    SetTransmogSetsClassFilter = function(classID) filter = classID end,
    GetAllSets = function() return SETS[filter] or {} end,
    GetVariantSets = function(setID) return VARIANTS[setID] or {} end,
    GetSetPrimaryAppearances = function()
        return { { appearanceID = 501, collected = false }, { appearanceID = 502, collected = false } }
    end,
}
_G.C_TransmogCollection = {
    GetSourceInfo = function(sourceID)
        return ({
            [501] = { itemID = 1, invType = 9, visualID = 71 },
            [502] = { itemID = 2, invType = 2, visualID = 72 },
            [503] = { itemID = 3, invType = 9, visualID = 71, isCollected = true },
        })[sourceID]
    end,
    GetAllAppearanceSources = function(visualID) return visualID == 71 and { 501, 503 } or { 502 } end,
}
_G.C_Item = { GetItemInventoryTypeByID = function(itemID) return itemID == 2 and 1 or 9 end }
_G.EJ_GetInvTypeSortOrder = function(invType) return invType end

dofile("src/domain/Classes.lua")
dofile("src/domain/RaidSets.lua")

local RaidSets = LuckysWardrobe.RaidSets

local raid = RaidSets:ForInstance(ABERRUS)
assert(filter == 7, "the player's own class filter was not put back")
assert(raid.classes[1].Normal == 10 and raid.classes[1].Mythic == 11)
assert(raid.classes[2].Heroic == 20, "another class's set was missed")
assert(raid.classes[2]["Raid Finder"] == 22, "a variant with no label of its own was missed")
assert(table.concat(raid.difficulties, ",") == "Raid Finder,Normal,Heroic,Mythic", "difficulties came back out of order")
assert(RaidSets:ForInstance("Ragefire Chasm") == nil, "a raid with no class sets found some")
assert(RaidSets:ForInstance("Honor") == nil, "a set every class can wear was taken for a class set")

assert(RaidSets.MatchDifficulty(raid.difficulties, "Heroic") == "Heroic")
assert(RaidSets.MatchDifficulty(raid.difficulties, "25 Player (Heroic)") == "Heroic", "legacy wording did not match")
assert(RaidSets.MatchDifficulty(raid.difficulties, "Timewalking") == "Raid Finder", "no match did not fall back to the first")
assert(RaidSets.MatchDifficulty({ "" }, "Normal") == "", "a set with no difficulty was not chosen")

local pieces = RaidSets:Pieces(10)
assert(pieces[1].sourceID == 502 and pieces[2].sourceID == 501, "pieces were not in slot order")
assert(pieces[1].token and not pieces[2].token, "the token slot was not marked")
assert(pieces[2].collected, "a look known through another item was not counted")
assert(not pieces[1].collected, "a look known through no item was counted")
