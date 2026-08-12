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

dofile("src/SetSearch.lua")
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
    return tostring(parsed.expansionID) .. "/" .. tostring(parsed.pvp)
end

assert(describe("tww") == "10/nil", "an expansion alone leaves the side open")
assert(describe("pvp") == "nil/true", "a side alone leaves the expansion open")
assert(describe("pve") == "nil/false", "and the other side is everything that is not PvP")
assert(describe("tww pvp") == "10/true", "an expansion and a side together")
assert(describe("pvp tww") == "10/true", "typed in either order")
assert(describe("the war within pvp") == "10/true", "an expansion of several words keeps them")
assert(describe("PvE  TWW") == "10/false", "in any case, however it was spaced")
assert(describe("classic pvp") == "0/true", "the first expansion is 0, not nothing")

assert(parse("tww tabard") == nil, "a word naming neither is the name search it always was")
assert(parse("gladiator") == nil, "and so is a set name that merely sounds like one")
assert(parse("pvp pve") == nil, "two sides name no set list worth showing")

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
assert(SetSearch.Matches(narrowedTo, 10, true), "a PvP set from that expansion belongs in the list")
assert(not SetSearch.Matches(narrowedTo, 10, false), "one from the expansion that is not PvP does not")
assert(not SetSearch.Matches(narrowedTo, 9, true), "nor a PvP set from another expansion")
assert(not SetSearch.Matches(narrowedTo, nil, true), "and neither does one nothing could date")
assert(SetSearch.Matches(nil, nil, false), "with nothing typed, every set belongs")

-- An expansion on its own says nothing about the side, and vice versa.
assert(SetSearch.Matches(parse("tww"), 10, false), "an expansion alone keeps both sides")
assert(SetSearch.Matches(parse("pvp"), 3, true), "a side alone keeps every expansion")
assert(not SetSearch.Matches(parse("pve"), 3, true), "the other side still leaves PvP out")

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
