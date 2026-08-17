-- luacheck: globals C_TransmogCollection Enum LuckysWardrobe

-- Covers what a search box's text names: which words are read as an expansion
-- or a side, which sets the pair of them keeps, and what the game's own set
-- search is told once the text has been claimed.

LuckysWardrobe = {}
LuckysWardrobe.DevLog = function() end

-- The client's own expansion names, in the order it hands them over. A
-- localised client would name them in its own language, which is exactly why
-- these are matched rather than hard-coded.
local EXPANSION_NAMES = {
    "Classic", "The Burning Crusade", "Wrath of the Lich King", "Cataclysm",
    "Mists of Pandaria", "Warlords of Draenor", "Legion", "Battle for Azeroth",
    "Shadowlands", "Dragonflight", "The War Within", "Midnight",
}
LuckysWardrobe.Utils = { EXPANSION_NAMES = EXPANSION_NAMES }

dofile("src/domain/SetSearch.lua")
local SetSearch = LuckysWardrobe.SetSearch

local function expansionFor(text)
    return SetSearch.ExpansionFor(text, EXPANSION_NAMES)
end

assert(expansionFor("tww") == 10, "the short name for The War Within")
assert(expansionFor("TWW") == 10, "typed in any case")
assert(expansionFor("  tww  ") == 10, "surrounded by whatever spaces were typed")
assert(expansionFor("The War Within") == 10, "the client's own name for it")
assert(expansionFor("classic") == 0, "the first expansion is 0, not nothing")
assert(expansionFor("vanilla") == 0, "and answers to what players call it")
assert(expansionFor("legion") == 6, "a name needing no short form of its own")
assert(expansionFor("mn") == 11 and expansionFor("midnight") == 11, "the newest expansion, either way")

assert(expansionFor("tw") == nil, "part of a short name is not the short name")
assert(expansionFor("twwx") == nil, "nor is more than one")
assert(expansionFor("war") == nil, "a word out of an expansion's name is a name search")
assert(expansionFor("") == nil, "an empty box narrows nothing")
assert(expansionFor(nil) == nil, "and neither does no box at all")

local function parse(text)
    return SetSearch.Parse(text, EXPANSION_NAMES)
end

local function describe(text)
    local parsed = parse(text)
    if not parsed then return "none" end
    return tostring(parsed.expansionID) .. "/" .. tostring(parsed.kind)
end

assert(describe("tww") == "10/nil", "an expansion alone leaves the kind open")
assert(describe("pvp") == "nil/pvp", "a kind alone leaves the expansion open")
assert(describe("pve") == "nil/pve", "and its opposite is a kind of its own")
assert(describe("raid") == "nil/raid", "so is raid tier")
assert(describe("tww pvp") == "10/pvp", "an expansion and a kind together")
assert(describe("pvp tww") == "10/pvp", "typed in either order")
assert(describe("mn raid") == "11/raid", "the pair Rubyurek asked for")
assert(describe("the war within raid") == "10/raid", "an expansion of several words keeps them")
assert(describe("PvE  TWW") == "10/pve", "in any case, however it was spaced")
assert(describe("classic pvp") == "0/pvp", "the first expansion is 0, not nothing")

assert(parse("tww tabard") == nil, "a word naming neither is the name search it always was")
assert(parse("gladiator") == nil, "and so is a set name that merely sounds like one")
assert(parse("pvp raid") == nil, "two kinds name no set list worth showing")

-- The game's own search, and the two lists that redraw once it has been answered.
local searched, cleared, redrawn = {}, {}, 0
_G.Enum = { TransmogSearchType = { Items = 1, BaseSets = 2, UsableSets = 3 } }
_G.C_TransmogCollection = {
    SetSearch = function(searchType, text)
        searched[#searched + 1] = searchType .. ":" .. text
        return false
    end,
    ClearSearch = function(searchType)
        cleared[#cleared + 1] = searchType
    end,
}
LuckysWardrobe.SetsBrowser = { Refresh = function() redrawn = redrawn + 1 end }
LuckysWardrobe.TransmogSets = { Refresh = function() end }

SetSearch:Init()
local BASE_SETS, ITEMS = Enum.TransmogSearchType.BaseSets, Enum.TransmogSearchType.Items

assert(C_TransmogCollection.SetSearch(BASE_SETS, "tww pvp") == true,
    "a search this understands is answered here rather than started in the game")
assert(#cleared == 1 and cleared[1] == BASE_SETS, "clearing whatever the game was searching for before")
assert(#searched == 0, "the text never reaches the game's own search")
assert(redrawn == 1, "the list redraws for a search the game saw nothing change in")

-- Both halves have to hold, which is the whole point of typing them together.
local narrowedTo = SetSearch.Narrowing()
assert(SetSearch.Matches(narrowedTo, 10, true, false), "a PvP set from that expansion belongs in the list")
assert(not SetSearch.Matches(narrowedTo, 10, false, true), "a raid set from the same expansion does not")
assert(not SetSearch.Matches(narrowedTo, 9, true, false), "nor a PvP set from another expansion")
assert(not SetSearch.Matches(narrowedTo, nil, true, false), "and neither does one nothing could date")
assert(SetSearch.Matches(nil, nil, false, false), "with nothing typed, every set belongs")

-- An expansion on its own says nothing about the kind, and vice versa.
assert(SetSearch.Matches(parse("tww"), 10, false, false), "an expansion alone keeps every kind")
assert(SetSearch.Matches(parse("pvp"), 3, true, false), "a kind alone keeps every expansion")
assert(SetSearch.Matches(parse("raid"), 3, false, true), "raid tier answers to raid")
assert(not SetSearch.Matches(parse("raid"), 3, true, false), "and a PvP set does not")

-- PvE is everything that is not PvP, which is where raid tier sits.
assert(SetSearch.Matches(parse("pve"), 3, false, true), "a raid set is PvE")
assert(SetSearch.Matches(parse("pve"), 3, false, false), "and so is everything else that is not PvP")
assert(not SetSearch.Matches(parse("pve"), 3, true, false), "PvP is the one thing it leaves out")

-- The pair from the request: one expansion, one kind, both have to hold.
assert(SetSearch.Matches(parse("mn raid"), 11, false, true), "a Midnight raid set")
assert(not SetSearch.Matches(parse("mn raid"), 10, false, true), "not a raid set from before it")

C_TransmogCollection.SetSearch(BASE_SETS, "tabard")
assert(SetSearch.Narrowing() == nil and searched[1] == BASE_SETS .. ":tabard",
    "anything else is the set name search it always was")

-- The Items tab shares the API, and there "tww" is three letters of an item name.
C_TransmogCollection.SetSearch(ITEMS, "tww")
assert(SetSearch.Narrowing() == nil and searched[2] == ITEMS .. ":tww",
    "the items search is left alone")

C_TransmogCollection.SetSearch(BASE_SETS, "df")
assert(SetSearch.Narrowing().expansionID == 9, "narrowed again")
C_TransmogCollection.ClearSearch(BASE_SETS)
assert(SetSearch.Narrowing() == nil, "an emptied box puts the whole list back")

print("SetSearchTest passed")
