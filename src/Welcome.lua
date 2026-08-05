-- luacheck: globals CreateFrame EventUtil UIParent UISpecialFrames

-- Lucky's Wardrobe: A note the first time the addon runs, saying it is newly
-- written rather than an older one carried forward, and handing over the Discord
-- address for the functionality that is not here yet.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.Welcome = {}

local Welcome = LuckysWardrobe.Welcome
local S = LuckysWardrobe.Strings.welcome

-- Matches the conflict dialog, which the same login can put on screen.
local PANEL_WIDTH = 460
local PADDING = 16
local TEXT_WIDTH = PANEL_WIDTH - PADDING * 2
local TEXT_TOP = 45
local LINE_GAP = 10
local LINK_HEIGHT = 22
local LINK_LABEL_GAP = 6
local HINT_GAP = 10
local HINT_HEIGHT = 14
local BUTTON_GAP = 14
local BUTTON_HEIGHT = 26
local BOTTOM_PADDING = 12

local db
local dialog

local function addLine(frame, previous, size, color)
    local line = frame:CreateFontString(nil, "OVERLAY")
    line:SetFont(LuckyUI.BODY_FONT, size)
    line:SetWidth(TEXT_WIDTH)
    line:SetJustifyH("LEFT")
    line:SetWordWrap(true)
    line:SetSpacing(3)
    line:SetTextColor(color[1], color[2], color[3])
    if previous then
        line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -LINE_GAP)
    else
        line:SetPoint("TOPLEFT", PADDING, -TEXT_TOP)
    end
    return line
end

-- The game has no clipboard API, so the address arrives in a box that can be
-- selected rather than as text on the panel.
local function addLink(frame, label)
    local c = LuckyUI.C

    local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    box:SetBackdrop(LuckyUI.Backdrop)
    box:SetBackdropColor(c.bgInput[1], c.bgInput[2], c.bgInput[3], c.bgInput[4])
    box:SetBackdropBorderColor(c.borderDark[1], c.borderDark[2], c.borderDark[3])
    box:SetSize(TEXT_WIDTH, LINK_HEIGHT)
    box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -LINK_LABEL_GAP)

    local link = CreateFrame("EditBox", nil, box)
    link:SetPoint("TOPLEFT", 6, -3)
    link:SetPoint("BOTTOMRIGHT", -6, 3)
    link:SetAutoFocus(false)
    link:SetFont(LuckyUI.BODY_FONT, 12, "")
    link:SetTextColor(c.textLight[1], c.textLight[2], c.textLight[3])
    link:SetText(S.discordURL)
    link:SetScript("OnEscapePressed", function() frame:Hide() end)
    link:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    -- The address never changes, so typing in it can only lose it.
    link:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(S.discordURL) end
    end)
    link:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    frame.link = link
    return box
end

local function build()
    local frame = LuckyUI.CreatePanel("LuckysWardrobeWelcome", UIParent, PANEL_WIDTH, 200)
    frame:SetPoint("CENTER", 0, 120)
    frame:SetFrameStrata("DIALOG")
    table.insert(UISpecialFrames, frame:GetName())
    LuckyUI.CreateHeader(frame, S.title)

    local headline = addLine(frame, nil, 14, LuckyUI.C.textLight)
    headline:SetText(S.headline)
    local body = addLine(frame, headline, 12, LuckyUI.C.textMuted)
    body:SetText(S.body)
    local ask = addLine(frame, body, 12, LuckyUI.C.textMuted)
    ask:SetText(S.ask)

    local linkLabel = addLine(frame, ask, 12, LuckyUI.C.goldAccent)
    linkLabel:SetText(S.linkLabel)
    local linkBox = addLink(frame, linkLabel)

    local hint = frame:CreateFontString(nil, "OVERLAY")
    hint:SetFont(LuckyUI.BODY_FONT, 10)
    hint:SetPoint("TOPLEFT", linkBox, "BOTTOMLEFT", 0, -HINT_GAP)
    hint:SetTextColor(LuckyUI.C.goldMuted[1], LuckyUI.C.goldMuted[2], LuckyUI.C.goldMuted[3])
    hint:SetText(S.copyHint)

    local close = LuckyUI.CreateButton(frame, S.close, 90, BUTTON_HEIGHT, "primary")
    close:SetPoint("BOTTOMRIGHT", -PADDING, BOTTOM_PADDING)
    close:SetScript("OnClick", function() frame:Hide() end)
    frame.close = close

    -- Wrapped text is only as tall as the font makes it, so the panel is sized
    -- from what the lines measure once they hold their text.
    local text = 0
    for _, line in ipairs({ headline, body, ask, linkLabel }) do
        text = text + line:GetStringHeight() + LINE_GAP
    end
    frame:SetHeight(TEXT_TOP + text - LINE_GAP
        + LINK_LABEL_GAP + LINK_HEIGHT
        + HINT_GAP + HINT_HEIGHT
        + BUTTON_GAP + BUTTON_HEIGHT + BOTTOM_PADDING)

    return frame
end

function Welcome:Show()
    dialog = dialog or build()
    dialog:Show()
end

function Welcome:Init(database)
    db = database
    EventUtil.ContinueOnPlayerLogin(function()
        if db.welcomeShown then return end
        -- A conflict warning is the more pressing of the two and answering it
        -- reloads either way, so the welcome keeps out of its way and waits for
        -- a login that has the screen to itself.
        if #LuckysWardrobe.AddonConflicts:Find() > 0 then return end
        db.welcomeShown = true
        self:Show()
    end)
end
