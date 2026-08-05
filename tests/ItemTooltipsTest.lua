-- luacheck: globals C_TransmogCollection C_TransmogSets CreateColor CreateFrame Enum GameTooltip ItemRefTooltip LuckysWardrobe TooltipDataProcessor TooltipUtil

-- Covers what an item's tooltip says about it: which set the piece belongs to and
-- how far along that set is, how the line is coloured, what silences it, and which
-- tooltips it is put on at all.

LuckysWardrobe = {}

_G.Enum = { TooltipDataType = { Item = 10 } }

-- Colour codes are what the line carries its colours in, so the test reads them
-- back the way the client would rather than pretending they are not there.
_G.CreateColor = function(r, g, b)
    return {
        WrapTextInColorCode = function(_, text)
            return ("[%.2f,%.2f,%.2f]%s[/]"):format(r, g, b, text)
        end,
    }
end

local WHITE = "[1.00,1.00,1.00]"
local COUNT = "[0.91,0.69,0.25]"
local COMPLETE = "[0.41,0.86,0.49]"

-- Two pieces of one set, a piece of no set, a piece two sets share, and an item
-- carrying no appearance at all.
local ITEMS = {
    ["|Hitem:100|h[Helm]|h"] = { visualID = 501, sourceID = 1 },
    ["|Hitem:200|h[Gloves]|h"] = { visualID = 502, sourceID = 2 },
    ["|Hitem:300|h[Trinket]|h"] = { visualID = 503, sourceID = 3 },
    ["|Hitem:400|h[Shared Piece]|h"] = { visualID = 504, sourceID = 4 },
    ["|Hitem:900|h[Potion]|h"] = {},
    [900] = {},
}

_G.C_TransmogCollection = {
    GetItemInfo = function(itemInfo)
        local entry = ITEMS[itemInfo] or {}
        return entry.visualID, entry.sourceID
    end,
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

local settings = { tooltipSetProgress = true }
LuckysWardrobe.ItemTooltips:Init(settings)
assert(events.TRANSMOG_COLLECTION_UPDATED, "the collection was never listened to")
assert(#postCalls == 1 and postCalls[1].dataType == Enum.TooltipDataType.Item,
    "the item tooltip was never hooked")

local function lineFor(itemInfo)
    return LuckysWardrobe.ItemTooltips:Line(itemInfo)
end

-- Something in no set, or with no appearance at all, is most of what passes through
-- a bag and has nothing to do with a wardrobe.
assert(lineFor("|Hitem:900|h[Potion]|h") == nil, "an item with no appearance was talked about")
assert(lineFor("|Hitem:300|h[Trinket]|h") == nil, "a piece in no set claimed one")
assert(lineFor(nil) == nil, "a tooltip with no item at all was answered")

-- The label names the set and counts it, with the name and the count each carrying
-- their own colour and the label left in the line's own muted one.
local helm = lineFor("|Hitem:100|h[Helm]|h")
assert(helm.text == "From set: " .. WHITE .. "Glyphed Garb[/] " .. COUNT .. "7/8[/]",
    "got: " .. helm.text)
assert(helm.colour[1] == 0.54, "the label was not left in the muted colour")

-- A piece already collected reads the same: it is the set's progress, not the
-- piece's.
assert(lineFor("|Hitem:200|h[Gloves]|h").text == helm.text)

-- A piece two sets share is named by the one this character could actually wear,
-- whichever order the client lists them in.
assert(lineFor("|Hitem:400|h[Shared Piece]|h").text:find("Glyphed Garb", 1, true),
    "the unwearable set was named")

-- Set membership cannot change while a client runs, so it is asked once per piece.
local lookupsBefore = membershipLookups
lineFor("|Hitem:100|h[Helm]|h")
lineFor("|Hitem:100|h[Helm]|h")
assert(membershipLookups == lookupsBefore, "the same piece was looked up again")

-- What is collected does change, and the count is thrown away when the collection
-- says so rather than being believed for the rest of the session. A finished set
-- says so in the colour the tracker finishes one in.
setPieces[100][1].collected = true
assert(lineFor("|Hitem:100|h[Helm]|h").text:find("7/8", 1, true),
    "a stale count should stand until the collection says otherwise")
events.handler()
local finished = lineFor("|Hitem:100|h[Helm]|h")
assert(finished.text == "From set: " .. WHITE .. "Glyphed Garb[/] " .. COMPLETE .. "8/8[/]",
    "got: " .. finished.text)
setPieces[100][1].collected = false
events.handler()

-- A set this client lists no pieces for has no progress to report, and "0/0" is a
-- worse answer than saying nothing.
setsBySource[3] = { 300 }
assert(lineFor("|Hitem:300|h[Trinket]|h") == nil, "an empty set was counted")
setsBySource[3] = nil

-- Turning it off leaves the tooltip as the game drew it.
settings.tooltipSetProgress = false
assert(lineFor("|Hitem:100|h[Helm]|h") == nil, "the line survived being turned off")
settings.tooltipSetProgress = true

-- The line lands on the tooltips someone reads an item on. The shopping tooltips
-- beside them are there to be compared against what is worn.
local addLine = postCalls[1].handler
displayedLink = "|Hitem:100|h[Helm]|h"
addLine(GameTooltip)
assert(#GameTooltip.lines == 1, "the item tooltip was left alone")

addLine(ItemRefTooltip)
assert(#ItemRefTooltip.lines == 1, "a linked item said nothing")

addLine(ShoppingTooltip)
assert(#ShoppingTooltip.lines == 0, "a comparison tooltip repeated the line")

-- A tooltip with no link to offer still has the item ID the data carries.
displayedLink = nil
GameTooltip.lines = {}
addLine(GameTooltip, { id = 900 })
assert(#GameTooltip.lines == 0, "a potion was talked about by ID")

print("Lucky's Wardrobe item tooltips test passed")
