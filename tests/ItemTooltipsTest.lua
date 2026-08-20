-- luacheck: globals C_TransmogCollection C_TransmogSets CreateColor CreateFrame Enum GameTooltip ItemRefTooltip LuckysWardrobe TooltipDataProcessor TooltipUtil

-- Covers what an item's tooltip says about it: which set the piece belongs to,
-- whether Blizzard lists that set or only the Extra Sets catalogue does, how far
-- along it is, how the line is coloured, what silences it, and which tooltips it is
-- put on at all.

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

-- Two pieces of one set, a piece of no set, a piece two sets share, a piece only the
-- Extra Sets catalogue knows a set for, and an item carrying no appearance at all.
local ITEMS = {
    ["|Hitem:100|h[Helm]|h"] = { visualID = 501, sourceID = 1 },
    ["|Hitem:200|h[Gloves]|h"] = { visualID = 502, sourceID = 2 },
    ["|Hitem:300|h[Trinket]|h"] = { visualID = 503, sourceID = 3 },
    ["|Hitem:400|h[Shared Piece]|h"] = { visualID = 504, sourceID = 4 },
    ["|Hitem:500|h[Eyepatch]|h"] = { visualID = 505, sourceID = 5 },
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

-- The catalogue behind the Extra Sets tab, which numbers its sets the way Wowhead
-- does: set 100 here is a different set from Blizzard's 100, which is why the two
-- are counted apart. It is not ready until the build that runs on entering the
-- world has finished.
local catalogueReady = false
local extraEntries = 0

LuckysWardrobe.ExtraSetsCatalog = {
    IsReady = function() return catalogueReady end,
    GetRecords = function()
        return { { setID = 100, name = "Glyphed Garb (Recolor)", pieces = { { sourceID = 5 }, { sourceID = 6 } } } }
    end,
}

LuckysWardrobe.ExtraSets = {
    RecordKey = function(record)
        if record.ensembles then return "ensemble:" .. record.setID end
        return record.setID
    end,
    LiveResolver = function() return "resolver" end,
    BuildEntry = function(record, resolver)
        assert(resolver == "resolver", "the live resolver should be the one asked")
        extraEntries = extraEntries + 1
        return { name = record.name, collected = 3, total = 8 }
    end,
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

-- Tooltips keep their lines and hand them out again for the next thing hovered, so
-- the font a line is left in is the font the next tooltip to use it draws with.
_G.GameTooltipText = "normal"
_G.GameTooltipTextSmall = "small"

local function FontString()
    local fontString = { font = _G.GameTooltipText }
    function fontString:SetFontObject(font) self.font = font end
    return fontString
end

local function Tooltip(name)
    local tooltip = { lines = {}, scripts = {} }
    function tooltip:GetName() return name end
    function tooltip:NumLines() return #self.lines end
    function tooltip:HookScript(script, handler) self.scripts[script] = handler end
    function tooltip:AddLine(text, r, g, b)
        self.lines[#self.lines + 1] = { text = text, colour = { r, g, b } }
        local lineName = name .. "TextLeft" .. #self.lines
        _G[lineName] = _G[lineName] or FontString()
    end
    function tooltip:Clear()
        self.lines = {}
        if self.scripts.OnTooltipCleared then self.scripts.OnTooltipCleared(self) end
    end
    return tooltip
end

_G.GameTooltip = Tooltip("GameTooltip")
_G.ItemRefTooltip = Tooltip("ItemRefTooltip")
local ShoppingTooltip = Tooltip("ShoppingTooltip1")

local displayedLink
_G.TooltipUtil = {
    GetDisplayedItem = function() return "Item", displayedLink end,
}

LuckyStrings = { New = function(_, tbl) return tbl end }
dofile("src/Strings.lua")
dofile("src/features/tooltips/ItemTooltips.lua")

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

-- Blizzard lists a fraction of the sets the client holds. A piece it says belongs to
-- nothing is put to the Extra Sets catalogue, which has nothing to say until the
-- build that runs on entering the world has finished.
assert(lineFor("|Hitem:500|h[Eyepatch]|h") == nil, "the catalogue answered before it was built")

catalogueReady = true
local eyepatch = lineFor("|Hitem:500|h[Eyepatch]|h")
assert(eyepatch.text == "From set: " .. WHITE .. "Glyphed Garb (Recolor)[/] " .. COUNT .. "3/8[/]",
    "got: " .. tostring(eyepatch and eyepatch.text))

-- Counting an extra set costs a walk through its pieces, so the answer is kept
-- until the collection changes.
local countedBefore = extraEntries
lineFor("|Hitem:500|h[Eyepatch]|h")
assert(extraEntries == countedBefore, "the same extra set was counted again")
events.handler()
lineFor("|Hitem:500|h[Eyepatch]|h")
assert(extraEntries == countedBefore + 1, "the extra set's count survived the collection changing")

-- The two lists number their sets differently, so a piece Blizzard does list is
-- never answered with the catalogue's set of the same number.
assert(lineFor("|Hitem:100|h[Helm]|h").text:find("7/8", 1, true),
    "a Blizzard set was answered with the catalogue's count")

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

-- The line is a footnote, so it is drawn in the small tooltip font, and the line is
-- handed back in the font it was found in: the next tooltip to use it is not ours to
-- shrink.
assert(_G.GameTooltipTextLeft1.font == "small", "the line was left at the item's own text size")
GameTooltip:Clear()
assert(_G.GameTooltipTextLeft1.font == "normal", "a shrunk line was left shrunk for the next tooltip")

GameTooltip:Clear()
assert(_G.GameTooltipTextLeft1.font == "normal", "clearing twice should leave the line alone")

-- A tooltip with no link to offer still has the item ID the data carries.
displayedLink = nil
GameTooltip.lines = {}
addLine(GameTooltip, { id = 900 })
assert(#GameTooltip.lines == 0, "a potion was talked about by ID")

print("Lucky's Wardrobe item tooltips test passed")
