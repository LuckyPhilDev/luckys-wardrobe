-- luacheck: globals C_TransmogCollection Enum LuckysWardrobe

-- Covers what a search box's text names: which words are read as an expansion,
-- and what the game's own set search is told once one has been.

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

assert(expansionFor("tw") == nil, "part of a short name is not the short name")
assert(expansionFor("twwx") == nil, "nor is more than one")
assert(expansionFor("war") == nil, "a word out of an expansion's name is a name search")
assert(expansionFor("") == nil, "an empty box narrows nothing")
assert(expansionFor(nil) == nil, "and neither does no box at all")

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

assert(C_TransmogCollection.SetSearch(BASE_SETS, "tww") == true,
    "an expansion answers the search itself rather than starting one")
assert(SetSearch.Typed() == 10, "and narrows both set lists to it")
assert(#cleared == 1 and cleared[1] == BASE_SETS, "clearing whatever the game was searching for before")
assert(#searched == 0, "the text never reaches the game's own search")
assert(redrawn == 1, "the list redraws for a search the game saw nothing change in")

assert(SetSearch.Matches(10), "a set from that expansion belongs in the list")
assert(not SetSearch.Matches(9), "one from another does not")
assert(not SetSearch.Matches(nil), "and neither does one nothing could date")

C_TransmogCollection.SetSearch(BASE_SETS, "tabard")
assert(SetSearch.Typed() == nil and searched[1] == BASE_SETS .. ":tabard",
    "anything else is the set name search it always was")

-- The Items tab shares the API, and there "tww" is three letters of an item name.
C_TransmogCollection.SetSearch(ITEMS, "tww")
assert(SetSearch.Typed() == nil and searched[2] == ITEMS .. ":tww",
    "the items search is left alone")

C_TransmogCollection.SetSearch(BASE_SETS, "df")
assert(SetSearch.Typed() == 9, "narrowed again")
C_TransmogCollection.ClearSearch(BASE_SETS)
assert(SetSearch.Typed() == nil, "an emptied box puts the whole list back")

print("SetSearchTest passed")
