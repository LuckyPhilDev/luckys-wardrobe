-- luacheck: globals C_TransmogCollection C_TransmogSets CreateFrame EventUtil LuckysWardrobe TransmogCustomSetModelMixin TransmogSetModelMixin hooksecurefunc

LuckysWardrobe = {}

local function newRegion(kind)
    local region = { kind = kind, points = {}, shown = true, text = "" }
    function region:SetPoint(point, ...) self.points[point] = { ... } end
    function region:SetAllPoints() self.allPoints = true end
    function region:SetJustifyH(justify) self.justifyH = justify end
    function region:SetMaxLines(lines) self.maxLines = lines end
    function region:SetColorTexture(r, g, b, a) self.colour = { r, g, b, a } end
    function region:SetText(value) self.text = value or "" end
    function region:GetText() return self.text end
    function region:SetShown(shown) self.shown = shown and true or false end
    function region:SetFrameLevel(level) self.level = level end
    function region:GetFrameLevel() return self.level or 1 end
    function region:CreateTexture(_, layer)
        local texture = newRegion("texture")
        texture.layer = layer
        self.texture = texture
        return texture
    end
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

local setCard = newCard({ set = { setID = 7 } })
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
assert(text.justifyH == "CENTER", "centred the name")
assert(text.maxLines == 2, "held the name to two lines")

local left, right, top = text.points.BOTTOMLEFT, text.points.BOTTOMRIGHT, text.points.TOP
assert(left and right and not top, "sat the name against the bottom of the card")
assert(left[1] > 0 and left[2] > 0, "inset the name from the card's bottom left corner")
assert(right[1] < 0 and right[2] > 0, "inset the name from the card's bottom right corner")

local plate = overlay.texture
assert(plate, "gave the name a plate to sit on")
assert(plate.layer == "BACKGROUND" and text.layer == "OVERLAY", "drew the plate behind the name")
assert(plate.colour[4] > 0 and plate.colour[4] < 1, "made the plate translucent")
assert(plate.points.TOPLEFT[1] == text and plate.points.BOTTOMRIGHT[1] == text,
    "sized the plate from the name, so a name that wraps still sits on it")

-- Blizzard's Custom Sets tab.

local customCard = newCard({ customSetID = 3 })
TransmogCustomSetModelMixin.UpdateSet(customCard)

assert(customUpdates == 1, "left Blizzard's own custom card update running")
assert(customCard.luckysSetName.fontString.text == "Raid Night Best", "read the name the player gave the custom set")
assert(customCard.luckysSetName.shown, "showed the custom set's name")

-- The Extra Sets tab, which names its cards as it draws them.

local extraCard = newCard()
LuckysWardrobe.TransmogSetNames:Apply(extraCard, "Ironfeather Battlesuit")
assert(extraCard.luckysSetName.fontString.text == "Ironfeather Battlesuit", "named the extra set's card")
assert(extraCard.luckysSetName.shown, "showed the extra set's name")

-- A set this client cannot name is left as Blizzard drew it rather than given
-- an empty plate.

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
