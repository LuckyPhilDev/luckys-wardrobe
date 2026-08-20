-- luacheck: globals C_Item C_Map C_Texture C_Timer C_TransmogCollection C_TransmogSets CreateFrame EJ_GetInstanceForMap EJ_GetInstanceInfo EJ_GetInvTypeSortOrder GetBuildInfo GetInstanceInfo GetTime IsInInstance LuckyUI LuckysWardrobe PLAYER_DIFFICULTY1 PLAYER_DIFFICULTY2 PLAYER_DIFFICULTY3 PLAYER_DIFFICULTY6 UISpecialFrames UNKNOWN

-- Covers the instance scan: which sets qualify, which pieces count as dropping
-- here, and the order they come back in. The panel is not exercised; everything
-- below the UI split is.

LuckysWardrobe = { DevLog = function() end }

_G.EJ_GetInvTypeSortOrder = function() return 1 end
_G.C_Item = {
    GetItemInfoInstant = function(itemID) return itemID, nil, nil, nil, "icon" .. itemID end,
    RequestLoadItemDataByID = function() end,
}
_G.C_Texture = { GetAtlasInfo = function() return nil end }
_G.CreateFrame = function() return setmetatable({}, { __index = function() return function() end end }) end
_G.UISpecialFrames = {}
-- A 12.0.7 client, so the tier being played right now is anything from 12.0.
_G.GetBuildInfo = function() return "12.0.7", "60000", "Jan 1 2026", 120007 end
_G.GetTime = function() return 0 end
_G.UNKNOWN = "Unknown"
_G.C_Timer = { After = function() end }
_G.PLAYER_DIFFICULTY1, _G.PLAYER_DIFFICULTY2 = "Normal", "Heroic"
_G.PLAYER_DIFFICULTY3, _G.PLAYER_DIFFICULTY6 = "Raid Finder", "Mythic"
_G.LuckyUI = {
    C = setmetatable({}, { __index = function() return { 0, 0, 0 } end }),
    BODY_FONT = "font",
    CreatePanel = function() return _G.CreateFrame() end,
    CreateHeader = function() return _G.CreateFrame() end,
}

-- Two sets a boss can drop, one earned rather than dropped. Every field here is
-- one Blizzard's own TransmogSetInfo carries.
local SETS = {
    { setID = 100, name = "Nearly There", validForCharacter = true,
        description = "Heroic", patchID = 120000 },
    -- A mask names a set's classes, one bit per class ID, so this leather set is
    -- Rogue's (4) and Druid's (11).
    { setID = 101, name = "Half Done", validForCharacter = true, patchID = 110200,
        classMask = 8 + 1024 },
    { setID = 102, name = "Another Class Set", validForCharacter = false, classMask = 8 },
    { setID = 103, name = "Elsewhere", validForCharacter = true },
    { setID = 104, name = "Old Dungeon Set", validForCharacter = true },
    { setID = 105, name = "Finished", validForCharacter = true },
    { setID = 106, name = "Long Way Off", validForCharacter = true },
    -- Tier: made from a token, so no piece of it has drop data of its own. The
    -- set's source is the only thing tying it to the raid it comes from. Its patch
    -- is ahead of the client's, which is what an unreleased tier sitting in the data
    -- looks like. Not the tier being played, so never the current one.
    { setID = 107, name = "Tier This Difficulty", validForCharacter = true,
        label = "The Vault", description = "Normal", patchID = 120100 },
    { setID = 108, name = "Tier Other Difficulty", validForCharacter = true,
        label = "The Vault", description = "Mythic" },
    { setID = 109, name = "Tier Elsewhere", validForCharacter = true,
        label = "A Different Raid", description = "Normal" },
    -- A family name rather than a place. It must not match an instance, and its
    -- pieces have real drop data anyway.
    { setID = 110, name = "Family Named Set", validForCharacter = true,
        label = "Warlords Dungeon Set" },
    -- Both: the set names this raid and one piece also has drop data.
    { setID = 111, name = "Named And Dropped", validForCharacter = true,
        label = "The Vault", description = "Normal" },
    -- Shared by an armour type rather than owned by one class, so switching one of
    -- them off is not enough to take it away.
    { setID = 112, name = "Shared Leather Set", validForCharacter = false,
        classMask = 8 + 1024 },
    -- Out of reach for a reason that has nothing to do with class, which is what a
    -- race-locked heritage set looks like.
    { setID = 113, name = "Heritage Set", validForCharacter = false, classMask = 0 },
}

-- sourceID -> collected
local APPEARANCES = {
    [100] = { [1] = true, [2] = true, [3] = true, [4] = false },
    [101] = { [5] = true, [6] = false, [7] = false, [8] = false },
    [102] = { [9] = false },
    [103] = { [10] = true, [11] = false },
    [104] = { [12] = false, [13] = false },
    [105] = { [14] = true, [15] = true },
    [106] = { [16] = false, [17] = false, [18] = false, [19] = false, [20] = false },
    [107] = { [21] = true, [22] = false, [23] = false },
    [108] = { [24] = true, [25] = false },
    [109] = { [26] = true, [27] = false },
    [110] = { [28] = true, [29] = false },
    [111] = { [30] = true, [31] = false, [32] = false },
    [112] = { [33] = true, [34] = false },
    [113] = { [35] = true, [36] = false },
}

local DROPS = {
    [4]  = { { instance = "The Vault", encounter = "The Warden", difficulties = {} } },
    [6]  = { { instance = "The Vault", encounter = "The Warden", difficulties = { "Heroic" } } },
    [7]  = { { instance = "The Vault", encounter = "The Gatekeeper", difficulties = {} } },
    [8]  = { { instance = "Somewhere Else", encounter = "A Boss", difficulties = {} } },
    [9]  = { { instance = "The Vault", encounter = "The Warden", difficulties = {} } },
    [11] = { { instance = "Somewhere Else", encounter = "A Boss", difficulties = {} } },
    -- Named as the Encounter Journal has it, not as the map is called.
    [12] = { { instance = "The Vault of Old", encounter = "The Warden", difficulties = {} } },
    [13] = { { instance = "The Vault of Old", encounter = "The Gatekeeper", difficulties = {} } },
    [16] = { { instance = "The Vault", encounter = "The Warden", difficulties = {} } },
    [17] = { { instance = "The Vault", encounter = "The Gatekeeper", difficulties = {} } },
    [29] = { { instance = "Upper Blackrock Spire", encounter = "Kyrak", difficulties = {} } },
    [31] = { { instance = "The Vault", encounter = "The Warden", difficulties = {} } },
    [34] = { { instance = "The Vault", encounter = "The Warden", difficulties = {} } },
    [36] = { { instance = "The Vault", encounter = "The Warden", difficulties = {} } },
}

-- Appearances the player owns right now, layered over the set data above so a
-- piece looted mid-run can be marked collected.
local COLLECTED_NOW = {}

local dropLookups, lookedUp = 0, {}

_G.C_TransmogSets = {
    GetAllSets = function() return SETS end,
    GetSetPrimaryAppearances = function(setID)
        local sources = APPEARANCES[setID]
        if not sources then return nil end

        local appearances = {}
        for sourceID, collected in pairs(sources) do
            appearances[#appearances + 1] = {
                appearanceID = sourceID,
                collected = collected or COLLECTED_NOW[sourceID] or false,
            }
        end
        table.sort(appearances, function(a, b) return a.appearanceID < b.appearanceID end)
        return appearances
    end,
}

_G.C_TransmogCollection = {
    GetAppearanceSourceDrops = function(sourceID)
        dropLookups = dropLookups + 1
        lookedUp[sourceID] = true
        return DROPS[sourceID]
    end,
    GetSourceInfo = function(sourceID)
        return {
            name = "Piece " .. sourceID,
            itemID = 1000 + sourceID,
            invType = "INVTYPE_CHEST",
            isCollected = COLLECTED_NOW[sourceID] or false,
        }
    end,
}

local playerDifficulty = "Normal"
local inInstance, instanceType = true, "raid"
_G.IsInInstance = function() return inInstance, instanceType end
_G.GetInstanceInfo = function() return "The Vault", "raid", 0, playerDifficulty end
_G.C_Map = { GetBestMapForUnit = function() return 42 end }
_G.EJ_GetInstanceForMap = function() return 7 end
_G.EJ_GetInstanceInfo = function() return "The Vault of Old" end

-- Rogue and Druid are all the classes this needs: one to own a set on its own, and
-- a second to share one with.
_G.GetNumClasses = function() return 13 end
_G.C_CreatureInfo = {
    GetClassInfo = function(classID)
        if classID == 4 then return { className = "Rogue", classFile = "ROGUE" } end
        if classID == 11 then return { className = "Druid", classFile = "DRUID" } end
        return nil
    end,
}
_G.C_ClassColor = {
    GetClassColor = function() return { WrapTextInColorCode = function(_, text) return text end } end,
}

LuckyStrings = { New = function(_, tbl) return tbl end }
dofile("src/Strings.lua")
dofile("src/Utils.lua")
dofile("src/domain/Classes.lua")
dofile("src/domain/SetSources.lua")
dofile("src/features/completion/SetCompletion.lua")

local SetCompletion = LuckysWardrobe.SetCompletion
-- Everything below the tier block wants to see every set that qualifies, including
-- the current tier's, which is left out by default.
SetCompletion:Init({ instanceSetsMaxMissing = 3, includeCurrentTier = true })

-- The instance is only reported inside a dungeon or raid.
local instance = SetCompletion:GetCurrentInstance()
assert(instance.name == "The Vault")
assert(instance.journalName == "The Vault of Old")
assert(instance.difficulty == "Normal")

inInstance, instanceType = false, "none"
assert(SetCompletion:GetCurrentInstance() == nil)
inInstance, instanceType = true, "party"
assert(SetCompletion:GetCurrentInstance() ~= nil, "dungeons count as well as raids")
inInstance, instanceType = true, "pvp"
assert(SetCompletion:GetCurrentInstance() == nil, "battlegrounds are not instances for this")
inInstance, instanceType = true, "raid"

local matches = SetCompletion:Scan(instance)

local byName = {}
for _, match in ipairs(matches) do byName[match.name] = match end

-- A set whose last piece drops here comes back, and knows it is finished by it.
assert(byName["Nearly There"], "the set one piece short of done is missing")
assert(byName["Nearly There"].remaining == 0)
assert(byName["Nearly There"].collected == 3 and byName["Nearly There"].total == 4)

-- Three of four pieces missing, two of them here, so one is left over.
assert(byName["Half Done"], "a set within the missing-piece limit is missing")
assert(#byName["Half Done"].here == 2)
assert(byName["Half Done"].remaining == 1)

-- Whose set it is rides along with the match, for the row to colour and the tooltip
-- to name.
assert(byName["Half Done"].classMask == 8 + 1024, "the class mask did not survive the scan")

-- The Encounter Journal's name for the instance matches as well as the map's.
assert(byName["Old Dungeon Set"], "a set named by its journal instance did not match")
assert(byName["Old Dungeon Set"].remaining == 0)

-- A set this character cannot wear is skipped before the lookups, even though its
-- piece has drop data that would have matched.
assert(not byName["Another Class Set"], "a set for another class was listed")
assert(DROPS[9][1].instance == "The Vault")
assert(not lookedUp[9], "a set for another class cost a drop lookup")

-- Sets past the missing-piece limit are skipped before the lookups too.
assert(not byName["Long Way Off"], "a set past the limit was listed")
assert(not lookedUp[16], "a set past the limit cost a drop lookup")

-- Nothing to show for a set that drops nowhere near here, or one already done.
assert(not byName["Elsewhere"], "a set with no pieces here was listed")
assert(not byName["Finished"], "a completed set was listed")
assert(#matches == 5)

-- Closest to done first, and a set that finishes here beats one that does not.
assert(matches[1].remaining == 0)
assert(matches[#matches].name == "Half Done")

-- A piece behind a difficulty this run isn't on still counts, and says so.
local notes = {}
for _, piece in ipairs(byName["Half Done"].here) do notes[piece.name] = piece.difficultyNote end
assert(notes["Piece 6"] == "Heroic", "a piece needing another difficulty said nothing")
assert(notes["Piece 7"] == nil, "a piece with no difficulty restriction was flagged")

playerDifficulty = "Heroic"
for _, match in ipairs(SetCompletion:Scan(SetCompletion:GetCurrentInstance())) do
    if match.name == "Half Done" then
        for _, piece in ipairs(match.here) do
            assert(piece.difficultyNote == nil, "a Heroic piece was flagged while on Heroic")
        end
    end
end
playerDifficulty = "Normal"

-- The limit is what keeps the scan cheap, so it has to bite before the lookups.
dropLookups = 0
-- One piece short: only the boss drop. The three sets that are equally close all
-- belong to another raid, another difficulty, or another place entirely.
local tight = SetCompletion:Scan(instance, 1)
assert(#tight == 1 and tight[1].name == "Nearly There")
assert(dropLookups == 0, "results are cached, so a rescan re-reads nothing")

-- Tier has no drop data at all, so the set naming this raid is what puts it on the
-- list, with every missing piece counted as here and no boss to name.
local tier = byName["Tier This Difficulty"]
assert(tier, "a set whose source names this instance was missing")
assert(#tier.here == 2 and tier.remaining == 0)
for _, piece in ipairs(tier.here) do
    assert(piece.encounter == nil, "a piece with no drop data claimed a boss")
    assert(piece.difficultyNote == nil, "the difficulty matched and was flagged anyway")
end

-- The same set exists once per difficulty and only this run's version can be
-- finished here, so the others are left off rather than listed with a caveat.
assert(not byName["Tier Other Difficulty"], "a set for another difficulty was listed")

-- A set naming a different raid stays off the list.
assert(not byName["Tier Elsewhere"], "a set naming another raid was listed")

-- A label that names a family rather than a place must not match an instance, and
-- this one's piece drops somewhere else entirely.
assert(not byName["Family Named Set"], "a set named after a family matched an instance")

-- Drop data wins where it exists, because only it can name the boss. The rest of
-- the set still comes along on the strength of the set's source.
local both = byName["Named And Dropped"]
assert(both and #both.here == 2 and both.remaining == 0)
local named, unnamed = 0, 0
for _, piece in ipairs(both.here) do
    if piece.encounter == "The Warden" then named = named + 1 else unnamed = unnamed + 1 end
end
assert(named == 1 and unnamed == 1, "the piece with drop data should have kept its boss")

-- The icon row shows the whole set, not just what is missing, so every piece is
-- listed with what it needs to be drawn and which of the three states it is in.
local iconRow = byName["Half Done"]
assert(#iconRow.pieces == 4, "the row should cover the whole set, collected included")
local collected, availableHere, elsewhere = 0, 0, 0
for _, piece in ipairs(iconRow.pieces) do
    assert(piece.icon, "a piece has no icon to draw")
    assert(piece.itemID, "a piece has no item to read an icon from")
    if piece.collected then collected = collected + 1
    elseif piece.availableHere then availableHere = availableHere + 1
    else elsewhere = elsewhere + 1 end
end
assert(collected == 1 and availableHere == 2 and elsewhere == 1)

-- A piece still to find carries everywhere it drops, so hovering it can name the
-- bosses. A piece already collected carries none, because there is nothing to ask.
for _, piece in ipairs(iconRow.pieces) do
    if piece.collected then
        assert(piece.drops == nil, "a collected piece was given drop locations")
    else
        assert(piece.drops, "a missing piece has nowhere to come from")
    end
end

-- A piece the player is already carrying the makings of is stamped, and carries the
-- item it would be made from so the hover can name it. Source 5 is already collected
-- and source 7 is not, so only one of the two is news.
LuckysWardrobe.Catalyst = {
    GetHeldTargets = function()
        return { bySource = { [5] = "|Hitem:9|h[Spare]|h", [7] = "|Hitem:9|h[Spare]|h" }, bySet = {}, items = 1 }
    end,
}
SetCompletion:Init({ instanceSetsMaxMissing = 3, includeCurrentTier = true, markCatalysablePieces = true })

local function halfDonePieces()
    local found = {}
    for _, match in ipairs(SetCompletion:Scan(instance)) do
        if match.name == "Half Done" then
            for _, piece in ipairs(match.pieces) do found[piece.sourceID] = piece end
            found.match = match
        end
    end
    return found
end

local stamped = halfDonePieces()
assert(stamped[7].catalysable == "|Hitem:9|h[Spare]|h", "a missing piece held the makings of was not stamped")
assert(stamped[5].catalysable == nil, "a piece already collected was stamped as catalysable")
assert(stamped[6].catalysable == nil, "a piece nothing held would make was stamped")
assert(stamped.match.catalysable == 1, "the row should count one stamped piece")

-- Turning it off stops the panel asking at all, which is what a player without the
-- catalyst addon, or without the patience for another mark, gets.
SetCompletion:Init({ instanceSetsMaxMissing = 3, includeCurrentTier = true, markCatalysablePieces = false })
LuckysWardrobe.Catalyst.GetHeldTargets = function() error("the panel asked while the setting was off") end
local unstamped = halfDonePieces()
assert(unstamped[7].catalysable == nil, "a stamp survived the setting being turned off")
assert(unstamped.match.catalysable == 0)
SetCompletion:Init({ instanceSetsMaxMissing = 3, includeCurrentTier = true })

-- This instance's bosses come first, so the useful line is the one at the top.
local elsewherePiece
for _, piece in ipairs(iconRow.pieces) do
    if not piece.collected and not piece.availableHere then elsewherePiece = piece end
end
assert(elsewherePiece and elsewherePiece.drops[1].instance == "Somewhere Else")
assert(elsewherePiece.drops[1].isHere == false)

local herePiece
for _, piece in ipairs(iconRow.pieces) do
    if piece.availableHere and piece.drops then herePiece = piece end
end
assert(herePiece and herePiece.drops[1].isHere, "the boss in this instance should sort first")
assert(herePiece.drops[1].encounter)

-- Tier has no drop data, so its missing pieces have an empty list rather than a
-- wrong one, and the tooltip falls back to naming the instance.
local tierPiece
for _, piece in ipairs(byName["Tier This Difficulty"].pieces) do
    if not piece.collected then tierPiece = piece end
end
assert(tierPiece and #tierPiece.drops == 0 and tierPiece.availableHere)

-- Raising the limit brings in the set that was too far off before.
local generous = SetCompletion:Scan(instance, 8)
assert(#generous == 6)
assert(generous[#generous].name == "Long Way Off")

-- A piece looted during the run counts as collected on the next scan, so the count
-- climbs without walking back out.
COLLECTED_NOW[12] = true
local oldDungeonSet
for _, match in ipairs(SetCompletion:Scan(instance)) do
    if match.name == "Old Dungeon Set" then oldDungeonSet = match end
end
assert(oldDungeonSet, "the set should still have a piece to find here")
assert(oldDungeonSet.collected == 1 and oldDungeonSet.total == 2)
assert(#oldDungeonSet.here == 1)

-- Once the last piece is in, the set drops off the list entirely.
COLLECTED_NOW[13] = true
for _, match in ipairs(SetCompletion:Scan(instance)) do
    assert(match.name ~= "Old Dungeon Set", "a finished set was still listed")
end
COLLECTED_NOW[12], COLLECTED_NOW[13] = nil, nil

-- Difficulty names don't match across the two sides, so neither spelling of the
-- same difficulty should be reported as out of reach.
playerDifficulty = "Mythic Keystone"
local keystoneNote
for _, match in ipairs(SetCompletion:Scan(SetCompletion:GetCurrentInstance(), 3)) do
    if match.name == "Half Done" then
        for _, piece in ipairs(match.here) do
            if piece.name == "Piece 6" then keystoneNote = piece.difficultyNote end
        end
    end
end
assert(keystoneNote == "Heroic", "a Heroic piece should be flagged on a Mythic key")

playerDifficulty = "25 Player (Heroic)"
for _, match in ipairs(SetCompletion:Scan(SetCompletion:GetCurrentInstance(), 3)) do
    if match.name == "Half Done" then
        for _, piece in ipairs(match.here) do
            assert(piece.difficultyNote == nil,
                "a Heroic piece was flagged while in a 25 Player (Heroic) raid")
        end
    end
end
playerDifficulty = "Normal"

-- A set from the tier being raided now gets finished by turning up, so it is left
-- off unless asked for. Only that tier goes: an older set is still worth a trip
-- back, and a set whose patch has not shipped is not the tier anyone is playing.
SetCompletion:Init({ instanceSetsMaxMissing = 3, includeCurrentTier = false })
local ignoringTier = {}
local found, tierStats = SetCompletion:Scan(instance)
for _, match in ipairs(found) do ignoringTier[match.name] = true end

assert(not ignoringTier["Nearly There"], "a set from the current tier was listed")
assert(tierStats.skippedCurrentTier == 1, "the scan should report what the tier filter took")
assert(ignoringTier["Half Done"], "a set from an older patch should survive the tier filter")
assert(ignoringTier["Tier This Difficulty"], "a set from an unreleased patch is not this tier")
assert(ignoringTier["Old Dungeon Set"], "a set carrying no patch at all should survive")

-- Nothing but the setting decides this, so asking for the tier brings it back.
SetCompletion:Init({ instanceSetsMaxMissing = 3, includeCurrentTier = true })
assert(#SetCompletion:Scan(instance) == 5, "asking for the current tier should bring it back")

-- Someone collecting across an account can ask for the sets this character cannot
-- wear, to learn whether a raid is worth a trip on an alt. The set then earns its
-- place on the same terms as any other, drop lookups included.
SetCompletion:Init({ instanceSetsMaxMissing = 3, includeCurrentTier = true,
    includeOtherClassSets = true, hiddenSetClasses = {} })
local withOtherClasses, otherClassStats = SetCompletion:Scan(instance)
local otherClassNames = {}
for _, match in ipairs(withOtherClasses) do otherClassNames[match.name] = true end

assert(otherClassNames["Another Class Set"], "asking for other classes' sets should bring them back")
assert(otherClassStats.skippedClass == 0, "nothing should be skipped for class once they are asked for")
assert(#withOtherClasses == 8, "the sets for other classes should be the only additions")

-- The setting decides only whether they are considered, not whether they qualify:
-- one that drops nowhere near here stays off the list either way.
assert(not otherClassNames["Elsewhere"], "a set with no pieces here was listed")

-- The class list narrows that down to the alts actually being collected for, so
-- switching a class off takes its sets back off the list.
local function scanWithout(hidden)
    SetCompletion:Init({ instanceSetsMaxMissing = 3, includeCurrentTier = true,
        includeOtherClassSets = true, hiddenSetClasses = hidden })
    local names = {}
    for _, match in ipairs(SetCompletion:Scan(instance)) do names[match.name] = true end
    return names
end

local withoutRogues = scanWithout({ ROGUE = true })
assert(not withoutRogues["Another Class Set"], "a set for a class switched off was listed")
assert(withoutRogues["Half Done"], "a set this character can wear answers to the toggle, not the list")

-- A set an armour type's worth of classes share is still one of them's until every
-- class on it has been switched off.
assert(withoutRogues["Shared Leather Set"], "a set another listed class shares was dropped")
assert(not scanWithout({ ROGUE = true, DRUID = true })["Shared Leather Set"])

-- Class has nothing to say about a set held back by race, so the class list leaves
-- it where the toggle put it.
assert(scanWithout({ ROGUE = true, DRUID = true })["Heritage Set"],
    "a set belonging to no class was hidden by a choice about classes")

print("Lucky's Wardrobe set completion test passed")
