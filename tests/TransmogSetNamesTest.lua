-- luacheck: globals C_TransmogCollection C_TransmogSets CreateFrame EventUtil LuckysWardrobe TransmogCustomSetModelMixin TransmogSetModelMixin hooksecurefunc

LuckysWardrobe = {}

local function newRegion(kind)
    local region = { kind = kind, points = {}, shown = true, text = "" }
    function region:SetPoint(point, ...) self.points[point] = { ... } end
    function region:SetAllPoints() self.allPoints = true end
    function region:SetJustifyH(justify) self.justifyH = justify end
    function region:SetSpacing(spacing) self.spacing = spacing end
    function region:SetTextColor(r, g, b) self.colour = { r, g, b } end
    function region:SetText(value) self.text = value or "" end
    function region:GetText() return self.text end
    function region:SetShown(shown) self.shown = shown and true or false end
    function region:SetFrameLevel(level) self.level = level end
    function region:GetFrameLevel() return self.level or 1 end
    function region:CreateFontString(_, layer, template)
        local fontString = newRegion("fontstring")
        fontString.layer = layer
        fontString.template = template
        self.fontString = fontString
        return fontString
    end
    return region
end

local CARD_LEVEL = 3

local function newCard(elementData)
    local card = newRegion("card")
    card.level = CARD_LEVEL
    card.elementData = elementData
    return card
end

function CreateFrame(_, _, parent)
    local frame = newRegion("frame")
    frame.parent = parent
    return frame
end

EventUtil = { ContinueOnAddOnLoaded = function(_, callback) callback() end }

function hooksecurefunc(target, method, callback)
    local original = target[method]
    target[method] = function(...)
        original(...)
        callback(...)
    end
end

-- Narcissus's own colours, which this borrows so the two read as one idea.
local COLLECTED_COLOUR = { 0.827, 0.776, 0.620 }
local INCOMPLETE_COLOUR = { 0.612, 0.627, 0.690 }

local function isColour(region, colour)
    return region.colour[1] == colour[1] and region.colour[2] == colour[2] and region.colour[3] == colour[3]
end

local setNames = { [7] = "Judgement Armor" }
C_TransmogSets = {
    GetSetInfo = function(setID)
        local name = setNames[setID]
        return name and { setID = setID, name = name }
    end,
}

local customSetNames = { [3] = "Raid Night Best" }
C_TransmogCollection = {
    GetCustomSetInfo = function(customSetID)
        return customSetNames[customSetID], "icon"
    end,
}

-- Blizzard's own card mixins, which do the dressing and the state art. The
-- names hang off these, so the originals must still run.
local nativeUpdates, customUpdates = 0, 0
TransmogSetModelMixin = {}
function TransmogSetModelMixin:UpdateSet() nativeUpdates = nativeUpdates + 1 end
TransmogCustomSetModelMixin = {}
function TransmogCustomSetModelMixin:UpdateSet() customUpdates = customUpdates + 1 end

dofile("src/TransmogSetNames.lua")

local db = { showSetNames = true }
LuckysWardrobe.TransmogSetNames:Init(db)

-- Blizzard's Sets tab.

local setCard = newCard({ set = { setID = 7, collected = true } })
TransmogSetModelMixin.UpdateSet(setCard)

assert(nativeUpdates == 1, "left Blizzard's own card update running")

local overlay = setCard.luckysSetName
assert(overlay, "named the set card")
assert(overlay.parent == setCard, "put the name on the card itself")
assert(overlay.allPoints, "covered the card, so the name is placed against its edges")
assert(overlay.level > CARD_LEVEL, "put the name above the card's own art")

local text = overlay.fontString
assert(text.text == "Judgement Armor", "read the name from the set")
assert(overlay.shown, "showed the name")
assert(text.layer == "OVERLAY", "drew the name over the card")
assert(text.template == "GameFontNormalOutline", "outlined the name, so it reads over the model behind it")
assert(text.justifyH == "CENTER", "centred the name")
assert(text.spacing == 2, "spaced the lines of a name that wraps")
assert(isColour(text, COLLECTED_COLOUR), "tinted a complete set's name like its border")

local left, right, bottom = text.points.TOPLEFT, text.points.TOPRIGHT, text.points.BOTTOM
assert(left and right and not bottom, "sat the name across the top of the card")
assert(left[1] > 0 and left[2] < 0, "inset the name from the card's top left corner")
assert(right[1] < 0 and right[2] < 0, "inset the name from the card's top right corner")

-- Blizzard's Custom Sets tab.

local customCard = newCard({ customSetID = 3, isCollected = false })
TransmogCustomSetModelMixin.UpdateSet(customCard)

assert(customUpdates == 1, "left Blizzard's own custom card update running")
assert(customCard.luckysSetName.fontString.text == "Raid Night Best", "read the name the player gave the custom set")
assert(customCard.luckysSetName.shown, "showed the custom set's name")
assert(isColour(customCard.luckysSetName.fontString, INCOMPLETE_COLOUR),
    "tinted a set short of complete like its own border")

-- The Extra Sets tab, which names its cards as it draws them.

local extraCard = newCard()
LuckysWardrobe.TransmogSetNames:Apply(extraCard, "Ironfeather Battlesuit", true)
assert(extraCard.luckysSetName.fontString.text == "Ironfeather Battlesuit", "named the extra set's card")
assert(extraCard.luckysSetName.shown, "showed the extra set's name")
assert(isColour(extraCard.luckysSetName.fontString, COLLECTED_COLOUR), "tinted the extra set's name too")

-- A set this client cannot name is left as Blizzard drew it.

local namelessCard = newCard({ set = { setID = 404 } })
TransmogSetModelMixin.UpdateSet(namelessCard)
assert(not namelessCard.luckysSetName.shown, "showed nothing for a set the client has no name for")

-- The setting.

db.showSetNames = false
LuckysWardrobe.TransmogSetNames:Refresh()
assert(not setCard.luckysSetName.shown and not customCard.luckysSetName.shown,
    "hid the names already on screen when the setting went off")

db.showSetNames = true
LuckysWardrobe.TransmogSetNames:Refresh()
assert(setCard.luckysSetName.shown and customCard.luckysSetName.shown and extraCard.luckysSetName.shown,
    "brought the names back when the setting went on again")
assert(not namelessCard.luckysSetName.shown, "left the nameless card alone through both")

local latecomer = newCard({ set = { setID = 7 } })
db.showSetNames = false
TransmogSetModelMixin.UpdateSet(latecomer)
assert(not latecomer.luckysSetName.shown, "drew a new card unnamed while the setting was off")
db.showSetNames = true
LuckysWardrobe.TransmogSetNames:Refresh()
assert(latecomer.luckysSetName.shown, "named that card the moment the setting came back")

print("Lucky's Wardrobe transmog set names test passed")
