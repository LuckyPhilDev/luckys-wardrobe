-- luacheck: globals C_TransmogCollection Enum

-- Lucky's Wardrobe: expansions typed into a set list's search box. Typing "tww"
-- into a Sets tab narrows it to The War Within instead of hunting for a set
-- whose name holds those three letters, which no set does.
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
}

-- The expansion the box currently names, nil while it names none. Shared by both
-- set lists, which are never on screen at the same time.
local typed

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

--- The expansion the search box is narrowing both set lists to, nil for none.
function SetSearch.Typed()
    return typed
end

--- Whether a set belongs in a list the search box has narrowed. A set carrying
--- no expansion is not the expansion being asked for, so it drops out with the
--- rest.
function SetSearch.Matches(expansionID)
    return typed == nil or expansionID == typed
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

    local function remember(expansionID)
        if typed == expansionID then return end
        typed = expansionID
        LuckysWardrobe.DevLog("Set search: expansion=" .. tostring(expansionID))
        redrawSetLists()
    end

    C_TransmogCollection.SetSearch = function(searchType, text)
        local expansionID = setSearches[searchType] and SetSearch.ExpansionFor(text) or nil
        remember(expansionID)
        if expansionID == nil then return setSearch(searchType, text) end

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
