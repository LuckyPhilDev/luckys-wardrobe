-- luacheck: globals C_TransmogCollection C_TransmogSets CreateFrame EventUtil TransmogCustomSetModelMixin TransmogSetModelMixin hooksecurefunc

-- Lucky's Wardrobe: Names on the set cards at the transmogrifier, so a wall of
-- little models says which set each one is without hovering them one by one.
-- The Sets and Custom Sets tabs are named through Blizzard's own card mixins;
-- the Extra Sets tab names its cards as it draws them.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.TransmogSetNames = {}

local TransmogSetNames = LuckysWardrobe.TransmogSetNames

-- The plate keeps clear of the card's edge, where the border art sits.
local PLATE_INSET = 6
local TEXT_PADDING = 4
-- A long set name reads fine over two lines. A third would climb up the model.
local MAX_LINES = 2
local PLATE_ALPHA = 0.6
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

    local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local textInset = PLATE_INSET + TEXT_PADDING
    text:SetPoint("BOTTOMLEFT", textInset, textInset)
    text:SetPoint("BOTTOMRIGHT", -textInset, textInset)
    text:SetJustifyH("CENTER")
    text:SetMaxLines(MAX_LINES)

    -- The plate takes its size from the text, so a name that wraps sits on a
    -- taller plate rather than spilling off a fixed one.
    local plate = overlay:CreateTexture(nil, "BACKGROUND")
    plate:SetColorTexture(0, 0, 0, PLATE_ALPHA)
    plate:SetPoint("TOPLEFT", text, "TOPLEFT", -TEXT_PADDING, TEXT_PADDING)
    plate:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", TEXT_PADDING, -TEXT_PADDING)

    overlay.Text = text
    card.luckysSetName = overlay
    labels[#labels + 1] = overlay
    return overlay
end

-- Names one card. The name is kept on the card even while the setting is off,
-- so turning it back on has every card on screen answer at once.
function TransmogSetNames:Apply(card, name)
    local overlay = nameLabel(card)
    overlay.Text:SetText(name or "")
    overlay:SetShown(db.showSetNames and (name or "") ~= "")
end

-- Answers the setting being turned off and on again.
function TransmogSetNames:Refresh()
    for _, overlay in ipairs(labels) do
        overlay:SetShown(db.showSetNames and overlay.Text:GetText() ~= "")
    end
end

local function nativeSetName(card)
    local elementData = card.elementData
    if not elementData or not elementData.set then return nil end

    local setInfo = C_TransmogSets.GetSetInfo(elementData.set.setID)
    return setInfo and setInfo.name
end

local function customSetName(card)
    local elementData = card.elementData
    if not elementData then return nil end

    return (C_TransmogCollection.GetCustomSetInfo(elementData.customSetID))
end

-- Cards copy their methods from the mixin when the pool creates them, so the
-- hooks must land before Blizzard_Transmog builds its first card.
local function installCardHooks()
    hooksecurefunc(TransmogSetModelMixin, "UpdateSet", function(card)
        TransmogSetNames:Apply(card, nativeSetName(card))
    end)
    hooksecurefunc(TransmogCustomSetModelMixin, "UpdateSet", function(card)
        TransmogSetNames:Apply(card, customSetName(card))
    end)
end

function TransmogSetNames:Init(database)
    db = database

    EventUtil.ContinueOnAddOnLoaded("Blizzard_Transmog", installCardHooks)
end
