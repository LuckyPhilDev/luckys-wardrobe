-- luacheck: globals C_TransmogCollection Enum

-- Lucky's Wardrobe: expansions and sides typed into a set list's search box.
-- Typing "tww" into a Sets tab narrows it to The War Within instead of hunting
-- for a set whose name holds those three letters, which no set does, and "tww
-- pvp" narrows it again to the ones you fought for.
--
-- The game searches set names down in C, and every set list the addon touches is
-- handed its results already narrowed, so an expansion typed into the box has to
-- be taken out of the search before the game runs it rather than added back to
-- what it returned. C_TransmogCollection.SetSearch is where the two boxes meet:
-- the Collections journal funnels its own through WardrobeCollectionFrame and
-- the transmogrifier through the box's own mixin, and both end up here.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.SetSearch = {}

local SetSearch = LuckysWardrobe.SetSearch
local Utils = LuckysWardrobe.Utils

-- The short names, in English, for the expansions whose full name is a mouthful.
-- The full names come from the client in whatever language it speaks and are
-- matched separately, so Legion and Cataclysm need nothing here: they are
-- already what the client calls them. Nothing here is a word a set is named
-- after, which is what keeps a search for a set from being answered with an
-- expansion instead.
local ALIASES = {
    vanilla = 0,
    tbc = 1,
    bc = 1,
    wotlk = 2,
    wrath = 2,
    cata = 3,
    mop = 4,
    wod = 5,
    bfa = 7,
    sl = 8,
    df = 9,
    tww = 10,
    mn = 11,
}

-- Which side of the game a set came from, as Blizzard's own two boxes split it:
-- a set is PvP or it is not, and between them they account for every set there
-- is. Nothing else here can be typed, so a set list is never narrowed to a
-- source no list could answer for.
local SIDES = { pvp = true, pve = false }

-- What the box currently narrows to, nil while it narrows nothing. Shared by
-- both set lists, which are never on screen at the same time.
local narrowing

--- The expansion a search box's whole text names, or nil where it names none.
--- Matched against the entire text rather than a fragment of it, so a set whose
--- name holds "df" is still found by typing more of it.
--- expansionNames is injected so the rules stay testable outside the client.
function SetSearch.ExpansionFor(text, expansionNames)
    if type(text) ~= "string" then return nil end
    local query = text:match("^%s*(.-)%s*$"):lower()
    if query == "" then return nil end

    local alias = ALIASES[query]
    if alias then return alias end
    for index, name in ipairs(expansionNames or Utils.EXPANSION_NAMES) do
        if name:lower() == query then return index - 1 end
    end
    return nil
end

--- Takes the side off whichever end it was typed on, so "pvp tww" and "tww pvp"
--- read the same and an expansion named in several words still has its own end
--- of the text to itself. Hands back what is left and the side that came off.
local function takeSide(query)
    local head, rest = query:match("^(%a+) (.+)$")
    if head and SIDES[head] ~= nil then return rest, SIDES[head] end

    local body, tail = query:match("^(.+) (%a+)$")
    if tail and SIDES[tail] ~= nil then return body, SIDES[tail] end

    if SIDES[query] ~= nil then return "", SIDES[query] end
    return query, nil
end

--- What a search box's whole text narrows a set list to, as
--- { expansionID = , pvp = }, either of which may be missing. nil where the text
--- narrows nothing and is the set name search it has always been.
---
--- The whole text has to be accounted for, so a set named "Gladiator's Plate" is
--- still found by typing more of it than a word this understands.
--- expansionNames is injected so the rules stay testable outside the client.
function SetSearch.Parse(text, expansionNames)
    if type(text) ~= "string" then return nil end
    local query = text:match("^%s*(.-)%s*$"):lower():gsub("%s+", " ")
    if query == "" then return nil end

    local rest, pvp = takeSide(query)
    local expansionID
    if rest ~= "" then
        expansionID = SetSearch.ExpansionFor(rest, expansionNames)
        -- Words left over that name no expansion mean the text was never about
        -- one, and a side alone is not enough to claim a search that also asked
        -- for something this cannot answer.
        if expansionID == nil then return nil end
    end

    if expansionID == nil and pvp == nil then return nil end
    return { expansionID = expansionID, pvp = pvp }
end

--- What the search box is narrowing both set lists to, nil for nothing.
function SetSearch.Narrowing()
    return narrowing
end

--- Whether a set belongs in a list narrowed to what a box was told, which is
--- Narrowing() for the game's own boxes and Parse() for the addon's own. A set
--- carrying no expansion is not the expansion being asked for, so it drops out
--- with the rest.
---
--- isPvP is the caller's own answer, because the two kinds of list reach it
--- differently: the client says nothing about a set's side, while the bundled
--- snapshot carries Wowhead's own source bits.
function SetSearch.Matches(narrowedTo, expansionID, isPvP)
    if narrowedTo == nil then return true end
    if narrowedTo.expansionID ~= nil and expansionID ~= narrowedTo.expansionID then return false end
    if narrowedTo.pvp ~= nil and isPvP ~= narrowedTo.pvp then return false end
    return true
end

-- Blizzard redraws the list itself after a search changes, but only when the
-- search it ran actually changed something, and hijacking one leaves it with
-- nothing to notice. Both lists ignore a redraw while they are hidden.
local function redrawSetLists()
    LuckysWardrobe.SetsBrowser:Refresh()
    LuckysWardrobe.TransmogSets:Refresh()
end

function SetSearch:Init()
    if SetSearch.setSearch then return end

    -- Only the two set searches. The Items tab shares this API, and there a
    -- typed word is a piece of an item name and nothing else.
    local setSearches = {
        [Enum.TransmogSearchType.BaseSets] = true,
        [Enum.TransmogSearchType.UsableSets] = true,
    }

    local setSearch = C_TransmogCollection.SetSearch
    local clearSearch = C_TransmogCollection.ClearSearch
    SetSearch.setSearch = setSearch

    local function remember(parsed)
        if narrowing == nil and parsed == nil then return end
        narrowing = parsed
        LuckysWardrobe.DevLog("Set search: expansion=" .. tostring(parsed and parsed.expansionID)
            .. " pvp=" .. tostring(parsed and parsed.pvp))
        redrawSetLists()
    end

    C_TransmogCollection.SetSearch = function(searchType, text)
        local parsed = setSearches[searchType] and SetSearch.Parse(text) or nil
        remember(parsed)
        if parsed == nil then return setSearch(searchType, text) end

        -- The text never reaches the game's own search, so whatever it was
        -- searching for before is dropped. Saying the search finished keeps the
        -- box from showing a progress bar for one that was never started.
        clearSearch(searchType)
        return true
    end

    C_TransmogCollection.ClearSearch = function(searchType)
        if setSearches[searchType] then remember(nil) end
        return clearSearch(searchType)
    end
end
