-- luacheck: globals AutoScalingFontStringMixin C_TransmogCollection C_TransmogSets CreateFrame EventUtil Mixin TransmogCustomSetModelMixin TransmogSetModelMixin hooksecurefunc

-- Lucky's Wardrobe: Names on the set cards at the transmogrifier, so a wall of
-- little models says which set each one is without hovering them one by one.
-- The Sets and Custom Sets tabs are named through Blizzard's own card mixins;
-- the Extra Sets tab names its cards as it draws them.
--
-- The look is Narcissus's, which names the custom sets it lists the same way:
-- outlined text across the top of the card, tinted like the card's border so a
-- set short of complete reads as one at a glance.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.TransmogSetNames = {}

local TransmogSetNames = LuckysWardrobe.TransmogSetNames

local NAME_PADDING = 8
local NAME_LINE_SPACING = 2
-- Two lines of a card's width take almost every set name Blizzard has written.
-- A name past that shrinks to fit rather than wrapping down over the model, and
-- stops shrinking two points short of the card's own font, which is as small as
-- a name can go and still be read at a glance. The handful of names too long
-- even for that are cut off, and hovering the card still gives them in full.
local MAX_LINES = 2
local MIN_LINE_HEIGHT = 10
local COLLECTED_COLOUR = { r = 0.827, g = 0.776, b = 0.620 }
local INCOMPLETE_COLOUR = { r = 0.612, g = 0.627, b = 0.690 }
-- A near solid plate behind the name, since a card whose model is pale at the
-- shoulders leaves the outline alone to hold the letters apart.
local PLATE_PADDING = 4
local PLATE_ALPHA = 0.8
-- Above the card's own dimming and its transmogrified glow, so the name stays
-- readable whatever state the card is in.
local NAME_LEVEL_OFFSET = 5

local db
local labels = {}

local function nameLabel(card)
    if card.luckysSetName then return card.luckysSetName end

    local overlay = CreateFrame("Frame", nil, card)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(card:GetFrameLevel() + NAME_LEVEL_OFFSET)

    local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
    text:SetPoint("TOPLEFT", NAME_PADDING, -NAME_PADDING)
    text:SetPoint("TOPRIGHT", -NAME_PADDING, -NAME_PADDING)
    text:SetJustifyH("CENTER")
    text:SetSpacing(NAME_LINE_SPACING)
    text:SetMaxLines(MAX_LINES)
    -- Blizzard's own shrink to fit, which scales a string down until it sits
    -- inside the lines it is allowed rather than cutting it off.
    Mixin(text, AutoScalingFontStringMixin)
    text:SetMinLineHeight(MIN_LINE_HEIGHT)

    -- The plate takes its size from the name, so one line and a name that wraps
    -- to two both sit on a plate of their own height.
    local plate = overlay:CreateTexture(nil, "BACKGROUND")
    plate:SetColorTexture(0, 0, 0, PLATE_ALPHA)
    plate:SetPoint("TOPLEFT", text, "TOPLEFT", -PLATE_PADDING, PLATE_PADDING)
    plate:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", PLATE_PADDING, -PLATE_PADDING)

    overlay.Text = text
    card.luckysSetName = overlay
    labels[#labels + 1] = overlay
    return overlay
end

-- Names one card. The name is kept on the card even while the setting is off,
-- so turning it back on has every card on screen answer at once.
function TransmogSetNames:Apply(card, name, collected)
    local overlay = nameLabel(card)
    overlay.Text:SetText(name or "")
    local colour = collected and COLLECTED_COLOUR or INCOMPLETE_COLOUR
    overlay.Text:SetTextColor(colour.r, colour.g, colour.b)
    overlay:SetShown(db.showSetNames and (name or "") ~= "")
end

-- Answers the setting being turned off and on again.
function TransmogSetNames:Refresh()
    for _, overlay in ipairs(labels) do
        overlay:SetShown(db.showSetNames and overlay.Text:GetText() ~= "")
    end
end

local function nameNativeSet(card)
    local elementData = card.elementData
    if not elementData or not elementData.set then
        TransmogSetNames:Apply(card, nil, false)
        return
    end

    local setInfo = C_TransmogSets.GetSetInfo(elementData.set.setID)
    TransmogSetNames:Apply(card, setInfo and setInfo.name, elementData.set.collected)
end

local function nameCustomSet(card)
    local elementData = card.elementData
    if not elementData then
        TransmogSetNames:Apply(card, nil, false)
        return
    end

    TransmogSetNames:Apply(card,
        (C_TransmogCollection.GetCustomSetInfo(elementData.customSetID)), elementData.isCollected)
end

-- Cards copy their methods from the mixin when the pool creates them, so the
-- hooks must land before Blizzard_Transmog builds its first card.
local function installCardHooks()
    hooksecurefunc(TransmogSetModelMixin, "UpdateSet", nameNativeSet)
    hooksecurefunc(TransmogCustomSetModelMixin, "UpdateSet", nameCustomSet)
end

function TransmogSetNames:Init(database)
    db = database

    EventUtil.ContinueOnAddOnLoaded("Blizzard_Transmog", installCardHooks)
end
