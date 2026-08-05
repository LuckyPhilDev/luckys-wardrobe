-- luacheck: globals C_TransmogCollection C_TransmogSets CreateFrame Enum GameTooltip ItemRefTooltip LuckysWardrobe TooltipDataProcessor TooltipUtil TRANSMOGRIFY_TOOLTIP_APPEARANCE_KNOWN TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN

-- Covers what an item's tooltip says about it: whether the look is already yours,
-- which set it belongs to and how far along that set is, which settings silence
-- each half, and which tooltips the lines are put on at all.

LuckysWardrobe = {}

_G.TRANSMOGRIFY_TOOLTIP_APPEARANCE_KNOWN = "You've collected this appearance"
_G.TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN = "You haven't collected this appearance"

_G.Enum = { TooltipDataType = { Item = 10 } }

-- Two pieces of one set, a piece of no set whose look another item taught, and an
-- item carrying no appearance at all.
local ITEMS = {
    ["|Hitem:100|h[Helm]|h"] = { visualID = 501, sourceID = 1 },
    ["|Hitem:200|h[Gloves]|h"] = { visualID = 502, sourceID = 2 },
    ["|Hitem:300|h[Lookalike]|h"] = { visualID = 503, sourceID = 3 },
    ["|Hitem:400|h[Shared Piece]|h"] = { visualID = 504, sourceID = 4 },
    ["|Hitem:900|h[Potion]|h"] = {},
    [900] = {},
}

-- Source 33 teaches the same look as source 3, and is the one actually collected.
local collectedSources = { [2] = true, [33] = true }
local appearanceSources = { [503] = { 3, 33 } }

_G.C_TransmogCollection = {
    GetItemInfo = function(itemInfo)
        local entry = ITEMS[itemInfo] or {}
        return entry.visualID, entry.sourceID
    end,
    PlayerHasTransmogItemModifiedAppearance = function(sourceID)
        return collectedSources[sourceID] == true
    end,
    GetAllAppearanceSources = function(visualID) return appearanceSources[visualID] end,
}

-- The set is missing only its helm. The other-class set shares the fourth piece,
-- and is listed first so the pick has to be made on more than order.
local sets = {
    [100] = { setID = 100, name = "Glyphed Garb", validForCharacter = true },
    [200] = { setID = 200, name = "Other Class Set", validForCharacter = false },
    [300] = { setID = 300, name = "Set This Client Has No Pieces For", validForCharacter = true },
}

local setPieces = {
    [100] = { { collected = false }, { collected = true }, { collected = true }, { collected = true },
        { collected = true }, { collected = true }, { collected = true }, { collected = true } },
    [200] = { { collected = false }, { collected = false } },
    [300] = {},
}

local setsBySource = { [1] = { 100 }, [2] = { 100 }, [4] = { 200, 100 } }
local membershipLookups = 0

_G.C_TransmogSets = {
    GetSetsContainingSourceID = function(sourceID)
        membershipLookups = membershipLookups + 1
        return setsBySource[sourceID]
    end,
    GetSetInfo = function(setID) return sets[setID] end,
    GetSetPrimaryAppearances = function(setID) return setPieces[setID] end,
}

local events = {}
_G.CreateFrame = function()
    return {
        RegisterEvent = function(_, event) events[event] = true end,
        SetScript = function(_, _, handler) events.handler = handler end,
    }
end

local postCalls = {}
_G.TooltipDataProcessor = {
    AddTooltipPostCall = function(dataType, handler)
        postCalls[#postCalls + 1] = { dataType = dataType, handler = handler }
    end,
}

local function Tooltip()
    local tooltip = { lines = {} }
    function tooltip:AddLine(text, r, g, b)
        self.lines[#self.lines + 1] = { text = text, colour = { r, g, b } }
    end
    return tooltip
end

_G.GameTooltip = Tooltip()
_G.ItemRefTooltip = Tooltip()
local ShoppingTooltip = Tooltip()

local displayedLink
_G.TooltipUtil = {
    GetDisplayedItem = function() return "Item", displayedLink end,
}

dofile("src/Strings.lua")
dofile("src/ItemTooltips.lua")

local settings = { tooltipAppearanceCollected = true, tooltipSetProgress = true }
LuckysWardrobe.ItemTooltips:Init(settings)
assert(events.TRANSMOG_COLLECTION_UPDATED, "the collection was never listened to")
assert(#postCalls == 1 and postCalls[1].dataType == Enum.TooltipDataType.Item,
    "the item tooltip was never hooked")

local function linesFor(itemInfo)
    return LuckysWardrobe.ItemTooltips:Lines(itemInfo) or {}
end

local function texts(lines)
    local said = {}
    for index, line in ipairs(lines) do said[index] = line.text end
    return table.concat(said, " | ")
end

-- Something with no appearance is most of what passes through a bag, and has
-- nothing to do with a wardrobe.
assert(#linesFor("|Hitem:900|h[Potion]|h") == 0, "an item with no appearance was talked about")
assert(#linesFor(nil) == 0, "a tooltip with no item at all was answered")

-- A piece still to collect says so, and names the set it would go towards.
local helm = linesFor("|Hitem:100|h[Helm]|h")
assert(#helm == 2, "the helm should say both things, got: " .. texts(helm))
assert(helm[1].text == TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN)
assert(helm[2].text == "Glyphed Garb 7/8", "got: " .. helm[2].text)
assert(helm[1].colour[1] == 1 and helm[2].colour[1] == 0.91, "an uncollected piece read as collected")

-- A piece already collected says so in the collected colour, and the set line is
-- the same either way: it is the set's progress, not the piece's.
local gloves = linesFor("|Hitem:200|h[Gloves]|h")
assert(gloves[1].text == TRANSMOGRIFY_TOOLTIP_APPEARANCE_KNOWN)
assert(gloves[1].colour[1] == 0.41, "a collected piece was not coloured as one")
assert(gloves[2].text == "Glyphed Garb 7/8")

-- A look is yours whichever item taught it, so an item you have never owned still
-- says you have the appearance. Belonging to no set leaves it at that one line.
local lookalike = linesFor("|Hitem:300|h[Lookalike]|h")
assert(#lookalike == 1, "a piece in no set claimed one, got: " .. texts(lookalike))
assert(lookalike[1].text == TRANSMOGRIFY_TOOLTIP_APPEARANCE_KNOWN,
    "a look collected from another item read as missing")

-- A piece two sets share is named by the one this character could actually wear,
-- whichever order the client lists them in.
local shared = linesFor("|Hitem:400|h[Shared Piece]|h")
assert(shared[2].text == "Glyphed Garb 7/8", "the unwearable set was named, got: " .. shared[2].text)

-- Set membership cannot change while a client runs, so it is asked once per piece.
local lookupsBefore = membershipLookups
linesFor("|Hitem:100|h[Helm]|h")
linesFor("|Hitem:100|h[Helm]|h")
assert(membershipLookups == lookupsBefore, "the same piece was looked up again")

-- What is collected does change, and the answer is thrown away when the collection
-- says so rather than being believed for the rest of the session.
collectedSources[1] = true
setPieces[100][1].collected = true
assert(linesFor("|Hitem:100|h[Helm]|h")[1].text == TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN,
    "a stale answer should stand until the collection says otherwise")
events.handler()
local finished = linesFor("|Hitem:100|h[Helm]|h")
assert(finished[1].text == TRANSMOGRIFY_TOOLTIP_APPEARANCE_KNOWN, "the new appearance was not noticed")
assert(finished[2].text == "Glyphed Garb 8/8", "the set count did not move")
assert(finished[2].colour[1] == 0.41, "a finished set was not coloured as done")
collectedSources[1] = nil
setPieces[100][1].collected = false
events.handler()

-- A set this client lists no pieces for has no progress to report, and "0/0" is a
-- worse answer than saying nothing.
setsBySource[3] = { 300 }
assert(#linesFor("|Hitem:300|h[Lookalike]|h") == 1, "an empty set was counted")
setsBySource[3] = nil

-- Each half is a setting of its own, and turning both off leaves the tooltip as the
-- game drew it.
settings.tooltipSetProgress = false
assert(#linesFor("|Hitem:100|h[Helm]|h") == 1, "the set line survived being turned off")
settings.tooltipSetProgress = true

settings.tooltipAppearanceCollected = false
local setOnly = linesFor("|Hitem:100|h[Helm]|h")
assert(#setOnly == 1 and setOnly[1].text == "Glyphed Garb 7/8", "the collected line survived being turned off")
settings.tooltipAppearanceCollected = true

settings.tooltipAppearanceCollected, settings.tooltipSetProgress = false, false
assert(#linesFor("|Hitem:100|h[Helm]|h") == 0, "both lines off should say nothing at all")
settings.tooltipAppearanceCollected, settings.tooltipSetProgress = true, true

-- The lines land on the tooltips someone reads an item on. The shopping tooltips
-- beside them are there to be compared against what is worn.
local addLines = postCalls[1].handler
displayedLink = "|Hitem:100|h[Helm]|h"
addLines(GameTooltip)
assert(#GameTooltip.lines == 2, "the item tooltip was left alone")

addLines(ItemRefTooltip)
assert(#ItemRefTooltip.lines == 2, "a linked item said nothing")

addLines(ShoppingTooltip)
assert(#ShoppingTooltip.lines == 0, "a comparison tooltip repeated the lines")

-- A tooltip with no link to offer still has the item ID the data carries.
displayedLink = nil
GameTooltip.lines = {}
addLines(GameTooltip, { id = 900 })
assert(#GameTooltip.lines == 0, "a potion was talked about by ID")

print("Lucky's Wardrobe item tooltips test passed")
