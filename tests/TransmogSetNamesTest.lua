-- luacheck: globals AutoScalingFontStringMixin C_TransmogCollection C_TransmogSets CreateFrame EventUtil LuckysWardrobe Mixin TransmogCustomSetModelMixin TransmogSetModelMixin hooksecurefunc

LuckysWardrobe = {}

LuckyStrings = { New = function(_, tbl) return tbl end }
dofile("src/Strings.lua")

function Mixin(object, ...)
    for _, mixin in ipairs({ ... }) do
        for key, value in pairs(mixin) do object[key] = value end
    end
    return object
end

-- Blizzard's shrink to fit, which takes over SetText so that every new string
-- is scaled down to the lines it is allowed. The stub keeps that shape, so a
-- name set here is a name the real one would have scaled.
AutoScalingFontStringMixin = {}
function AutoScalingFontStringMixin:SetText(value)
    self.text = value or ""
    self.scalings = (self.scalings or 0) + 1
end
function AutoScalingFontStringMixin:SetMinLineHeight(height)
    self.minLineHeight = height
end
function AutoScalingFontStringMixin:ScaleTextToFit()
    self.scalings = (self.scalings or 0) + 1
end

local function newRegion(kind)
    local region = { kind = kind, points = {}, shown = true, text = "" }
    function region:SetPoint(point, ...) self.points[point] = { ... } end
    function region:SetAllPoints() self.allPoints = true end
    function region:SetJustifyH(justify) self.justifyH = justify end
    function region:SetSpacing(spacing) self.spacing = spacing end
    function region:SetMaxLines(lines) self.maxLines = lines end
    function region:SetTextColor(r, g, b) self.colour = { r, g, b } end
    function region:SetText(value) self.text = value or "" end
    function region:GetText() return self.text end
    function region:SetShown(shown) self.shown = shown and true or false end
    function region:IsShown() return self.shown end
    function region:GetNumLines() return self.lines or 1 end
    function region:SetFrameLevel(level) self.level = level end
    function region:GetFrameLevel() return self.level or 1 end
    function region:SetColorTexture(r, g, b, a) self.colour = { r, g, b, a } end
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
    -- The template's favourite star, a frame of its own over the card, whose
    -- icon shows only for a set the player has favourited.
    card.Favorite = newRegion("frame")
    card.Favorite.level = CARD_LEVEL + 1
    card.Favorite.Icon = newRegion("texture")
    card.Favorite.Icon:SetShown(false)
    return card
end

function CreateFrame(_, _, parent)
    local frame = newRegion("frame")
    frame.parent = parent
    return frame
end

EventUtil = { ContinueOnAddOnLoaded = function(_, callback) callback() end }

-- A stand-in for the menu being built, which records what was added to it.
local function newMenuDescription()
    local description = { entries = {} }
    function description:CreateDivider()
        self.entries[#self.entries + 1] = { divider = true }
    end
    function description:CreateCheckbox(label, isSelected, setSelected)
        self.entries[#self.entries + 1] =
            { label = label, isSelected = isSelected, setSelected = setSelected }
    end
    return description
end

local function findCheckbox(description, label)
    for _, entry in ipairs(description.entries) do
        if entry.label == label then return entry end
    end
end

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

dofile("src/features/transmogrifier/TransmogSetNames.lua")

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
assert(text.maxLines == 2, "held the name to two lines")
assert(text.scalings == 1, "shrank the name to fit those two lines")
assert(text.minLineHeight and text.minLineHeight > 0, "gave the shrinking a floor to stop at")
assert(isColour(text, COLLECTED_COLOUR), "tinted a complete set's name like its border")

local left, right, bottom = text.points.TOPLEFT, text.points.TOPRIGHT, text.points.BOTTOM
assert(left and right and not bottom, "sat the name across the top of the card")
assert(left[1] > 0 and left[2] < 0, "inset the name from the card's top left corner")
assert(right[1] < 0 and right[2] < 0, "inset the name from the card's top right corner")

local plate = overlay.texture
assert(plate, "gave the name a plate to sit on")
assert(plate.layer == "BACKGROUND", "drew the plate behind the name")
assert(plate.colour[1] == 0 and plate.colour[2] == 0 and plate.colour[3] == 0, "made the plate black")
assert(plate.colour[4] > 0 and plate.colour[4] < 1, "left the plate translucent")
assert(#plate.points.TOPLEFT == 0 and #plate.points.TOPRIGHT == 0,
    "ran the plate into the card's own top corners rather than stopping short of them")
assert(plate.points.BOTTOM[1] == text, "took the plate's depth from the name, so a name that wraps still sits on it")
assert(setCard.Favorite.level > overlay.level, "kept the favourite star over the plate")

-- A name that wraps starts higher up the card.

local wrappingCard = newCard({ set = { setID = 7, collected = true } })
TransmogSetModelMixin.UpdateSet(wrappingCard)
local wrappingText = wrappingCard.luckysSetName.fontString
local oneLineTop = wrappingText.points.TOPLEFT[2]

wrappingText.lines = 2
TransmogSetModelMixin.UpdateSet(wrappingCard)
assert(wrappingText.points.TOPLEFT[2] > oneLineTop, "lifted a name that wraps to two lines")
assert(wrappingText.points.TOPRIGHT[2] == wrappingText.points.TOPLEFT[2], "lifted both of its edges together")

wrappingText.lines = 1
TransmogSetModelMixin.UpdateSet(wrappingCard)
assert(wrappingText.points.TOPLEFT[2] == oneLineTop, "put a name back down when the card next held one line")

-- A favourited set wears a star in the corner the name starts from.

local favouriteCard = newCard({ set = { setID = 7, collected = true } })
favouriteCard.Favorite.Icon:SetShown(true)
TransmogSetModelMixin.UpdateSet(favouriteCard)

local favouriteText = favouriteCard.luckysSetName.fontString
assert(favouriteText.points.TOPLEFT[1] > left[1], "gave the name room to clear the star")
assert(favouriteText.points.TOPRIGHT[1] == -favouriteText.points.TOPLEFT[1],
    "pulled both edges in by the same amount, so the name stays centred on the card")

-- A name that wraps fills its line whatever the padding, so on a favourited
-- card it takes the room it needs on the star's side alone.
local centredLeft = favouriteText.points.TOPLEFT[1]
favouriteText.lines = 2
local scalings = favouriteText.scalings
TransmogSetModelMixin.UpdateSet(favouriteCard)
assert(favouriteText.points.TOPLEFT[1] > centredLeft, "started a wrapped name clear of the star outright")
assert(favouriteText.points.TOPRIGHT[1] == -centredLeft, "left its other edge where the centring put it")
assert(favouriteText.scalings > scalings + 1,
    "measured the name again against the narrower line it was given")

favouriteText.lines = 1
TransmogSetModelMixin.UpdateSet(favouriteCard)
assert(favouriteText.points.TOPLEFT[1] == centredLeft, "put a one line name back where the centring wants it")

-- Cards are pooled, so the one that carried a favourite carries an ordinary set
-- a page later.
favouriteCard.Favorite.Icon:SetShown(false)
TransmogSetModelMixin.UpdateSet(favouriteCard)
assert(favouriteText.points.TOPLEFT[1] == left[1] and favouriteText.points.TOPRIGHT[1] == right[1],
    "took the name back to the card's own edges once the star went")

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

-- Cards are pooled, so a card carries a different set's name a page later.
LuckysWardrobe.TransmogSetNames:Apply(extraCard, "Runebound Gladiator's Chain Battlegear", false)
assert(extraCard.luckysSetName.fontString.scalings == 2, "shrank the next name the same card was given")
assert(isColour(extraCard.luckysSetName.fontString, INCOMPLETE_COLOUR), "retinted it for the set it now shows")

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

-- The same setting as an option in a filter menu. The page that owns the menu
-- places it, so what arrives here is the box alone.

local menu = newMenuDescription()
LuckysWardrobe.TransmogSetNames:AddFilterOption(menu)

local option = findCheckbox(menu, LuckysWardrobe.Strings.setNames.filter)
assert(option, "offered the names as a filter option")
assert(#menu.entries == 1, "added the box alone, leaving the page to keep it apart from its own entries")
assert(option.isSelected(), "showed the option ticked while the names are on")

option.setSelected()
assert(db.showSetNames == false, "turning the option off turned the setting off")
assert(not setCard.luckysSetName.shown, "and took the names off the cards on screen")
assert(not option.isSelected(), "and unticked itself")

option.setSelected()
assert(db.showSetNames == true and setCard.luckysSetName.shown, "turning it back on brought the names back")

print("Lucky's Wardrobe transmog set names test passed")
