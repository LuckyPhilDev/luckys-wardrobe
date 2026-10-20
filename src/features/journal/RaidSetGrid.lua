-- luacheck: globals EncounterJournal EJ_GetDifficulty GetDifficultyInfo DressUpTransmogSet HandleModifiedItemClick GameTooltip_Hide GameTooltip_SuppressAutomaticCompareItem

-- Lucky's Wardrobe: Every class's set from a raid side by side, opened from the
-- Adventure Guide, so a token can go to the alt that still needs its piece.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.RaidSetGrid = {}

local RaidSetGrid = LuckysWardrobe.RaidSetGrid

local COLUMNS = 7
local CARD_WIDTH, CARD_HEIGHT = 150, 300
local CARD_HEADER_HEIGHT = 32
local GAP, PADDING = 6, 12
local ICON_SIZE, ICON_STEP, ICONS_PER_ROW, ICON_ROWS = 24, 28, 5, 2
local MAX_ALTS = 3
local TOOLBAR_HEIGHT = 30

local db
local journalButton
local window
local dropdown
local cards = {}
local shown = { raidName = nil, raid = nil, difficulty = nil }

local function S() return LuckysWardrobe.Strings.raidSets end

local function altsLine(alts)
    if #alts == 0 then return "|cff808080" .. S().noAlts .. "|r" end

    local names = {}
    for index = 1, math.min(#alts, MAX_ALTS) do
        names[index] = LuckyRoster:FormatName(alts[index].key)
    end
    local line = table.concat(names, ", ")
    if #alts > MAX_ALTS then line = line .. " " .. S().moreAlts:format(#alts - MAX_ALTS) end
    return line
end

local function showPieceTooltip(icon)
    local piece = icon.piece
    GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
    -- Comparing against your own gear is noise for another class's piece.
    GameTooltip_SuppressAutomaticCompareItem(GameTooltip)
    GameTooltip:SetItemByID(piece.itemID)
    GameTooltip:AddLine(" ")
    if piece.collected then
        GameTooltip:AddLine(S().collected, 0.3, 0.9, 0.3)
    else
        GameTooltip:AddLine(S().notCollected, 0.9, 0.3, 0.3)
    end
    if piece.token then GameTooltip:AddLine(S().tokenSlot, 0.7, 0.7, 0.7) end
    GameTooltip:Show()
end

local function clickPiece(icon)
    local info = C_TransmogCollection.GetAppearanceSourceInfo(icon.piece.sourceID)
    if info and info.itemLink then HandleModifiedItemClick(info.itemLink) end
end

local function getIcon(card, index)
    local icon = card.icons[index]
    if icon then return icon end

    icon = CreateFrame("Button", nil, card)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon.edge = icon:CreateTexture(nil, "BACKGROUND")
    icon.edge:SetPoint("TOPLEFT", -1, 1)
    icon.edge:SetPoint("BOTTOMRIGHT", 1, -1)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.tokenPip = icon:CreateTexture(nil, "OVERLAY")
    icon.tokenPip:SetSize(4, 4)
    icon.tokenPip:SetPoint("TOPRIGHT", -1, -1)
    icon.tokenPip:SetColorTexture(LuckyUI.C.goldAccent[1], LuckyUI.C.goldAccent[2], LuckyUI.C.goldAccent[3], 0.9)
    icon:SetScript("OnEnter", showPieceTooltip)
    icon:SetScript("OnLeave", GameTooltip_Hide)
    icon:SetScript("OnClick", clickPiece)

    local row, column = math.floor((index - 1) / ICONS_PER_ROW), (index - 1) % ICONS_PER_ROW
    local rowWidth = ICONS_PER_ROW * ICON_STEP - (ICON_STEP - ICON_SIZE)
    icon:SetPoint("BOTTOMLEFT", (CARD_WIDTH - rowWidth) / 2 + column * ICON_STEP,
        6 + (ICON_ROWS - 1 - row) * ICON_STEP)
    card.icons[index] = icon
    return icon
end

local function styleIcon(icon, piece)
    icon.piece = piece
    icon.texture:SetTexture(C_TransmogCollection.GetSourceIcon(piece.sourceID))
    icon.texture:SetDesaturated(not piece.collected)
    icon.texture:SetAlpha(piece.collected and 1 or 0.35)
    if piece.collected then
        icon.edge:SetColorTexture(0.3, 0.85, 0.3, 0.9)
    else
        icon.edge:SetColorTexture(0, 0, 0, 0.6)
    end
    icon.tokenPip:SetShown(piece.token)
    icon:Show()
end

-- A figure still loading drops anything put on it, so the pieces go on once it
-- lands, a frame later, the same as the Extra Sets preview.
local function dressModel(card)
    if card.modelLoading then return end
    card.model:Undress()
    for _, piece in ipairs(card.pieces) do card.model:TryOn(piece.sourceID) end
end

local function showCardTooltip(card)
    GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
    GameTooltip:AddLine(LuckysWardrobe.Classes:Colour(card.class, card.class.name))
    for _, alt in ipairs(card.alts) do
        GameTooltip:AddLine(LuckyRoster:FormatName(alt.key))
    end
    if #card.alts == 0 then GameTooltip:AddLine(S().noAlts, 0.5, 0.5, 0.5) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(S().cardHint, 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local function createCard(parent)
    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetSize(CARD_WIDTH, CARD_HEIGHT)
    card:SetBackdrop(LuckyUI.Backdrop)
    card:SetBackdropColor(LuckyUI.C.bgPanel[1], LuckyUI.C.bgPanel[2], LuckyUI.C.bgPanel[3], 0.9)
    card:SetBackdropBorderColor(LuckyUI.C.borderDark[1], LuckyUI.C.borderDark[2], LuckyUI.C.borderDark[3])
    card.icons = {}
    card.pieces = {}

    card.name = card:CreateFontString(nil, "OVERLAY")
    card.name:SetFont(LuckyUI.BODY_FONT, 13)
    card.name:SetPoint("TOPLEFT", 6, -5)

    card.count = card:CreateFontString(nil, "OVERLAY")
    card.count:SetFont(LuckyUI.BODY_FONT, 12)
    card.count:SetPoint("TOPRIGHT", -6, -5)

    card.altsText = card:CreateFontString(nil, "OVERLAY")
    card.altsText:SetFont(LuckyUI.BODY_FONT, 10)
    card.altsText:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -2)
    card.altsText:SetPoint("RIGHT", -6, 0)
    card.altsText:SetJustifyH("LEFT")
    card.altsText:SetWordWrap(false)

    local model = CreateFrame("DressUpModel", nil, card)
    model:SetPoint("TOPLEFT", 4, -CARD_HEADER_HEIGHT)
    model:SetPoint("BOTTOMRIGHT", -4, 10 + ICON_ROWS * ICON_STEP)
    model:SetKeepModelOnHide(true)
    model:SetScript("OnModelLoaded", function()
        if not card.modelLoading then return end
        card.modelLoading = false
        C_Timer.After(0, function() dressModel(card) end)
    end)
    card.model = model

    card:SetScript("OnClick", function(self)
        local sourceIDs = {}
        for index, piece in ipairs(self.pieces) do sourceIDs[index] = piece.sourceID end
        DressUpTransmogSet(sourceIDs)
    end)
    card:SetScript("OnEnter", showCardTooltip)
    card:SetScript("OnLeave", GameTooltip_Hide)
    return card
end

local function getCard(index)
    local card = cards[index]
    if not card then
        card = createCard(window)
        local row, column = math.floor((index - 1) / COLUMNS), (index - 1) % COLUMNS
        card:SetPoint("TOPLEFT", PADDING + column * (CARD_WIDTH + GAP),
            -(LuckyUI.HEADER_HEIGHT + TOOLBAR_HEIGHT + PADDING + row * (CARD_HEIGHT + GAP)))
        cards[index] = card
    end
    return card
end

local function fillCard(card, class, setID)
    card.class = class
    card.pieces = LuckysWardrobe.RaidSets:Pieces(setID)
    local collected = 0
    for index, piece in ipairs(card.pieces) do
        if piece.collected then collected = collected + 1 end
        styleIcon(getIcon(card, index), piece)
    end
    for index = #card.pieces + 1, #card.icons do card.icons[index]:Hide() end

    card.name:SetText(LuckysWardrobe.Classes:Colour(class, class.name))
    local complete = collected == #card.pieces
    card.count:SetText(("%d/%d"):format(collected, #card.pieces))
    card.count:SetTextColor(complete and 0.3 or 0.91, complete and 0.9 or 0.86, complete and 0.3 or 0.78)
    card.alts = LuckysWardrobe.Classes:Alts(class.file)
    card.altsText:SetText(altsLine(card.alts))

    if card.modelSet then
        dressModel(card)
    else
        card.modelSet = true
        card.modelLoading = true
        card.model:SetUnit("player")
        card.model:SetUseTransmogSkin(true)
    end
    card:Show()
end

local function redraw()
    local raid = shown.raid
    local used = 0
    for _, class in ipairs(LuckysWardrobe.Classes:All()) do
        local sets = raid.classes[class.classID]
        local setID = sets and sets[shown.difficulty]
        if setID then
            used = used + 1
            fillCard(getCard(used), class, setID)
        end
    end
    for index = used + 1, #cards do cards[index]:Hide() end

    local rows = math.max(1, math.ceil(used / COLUMNS))
    local columns = math.min(math.max(used, 1), COLUMNS)
    window:SetSize(PADDING * 2 + columns * CARD_WIDTH + (columns - 1) * GAP,
        LuckyUI.HEADER_HEIGHT + TOOLBAR_HEIGHT + PADDING * 2 + rows * CARD_HEIGHT + (rows - 1) * GAP)
    dropdown:SetShown(#raid.difficulties > 1)
    dropdown:GenerateMenu()
end

local function createWindow()
    window = LuckyUI.CreateWindow("LuckysWardrobeRaidSetGrid", 400, 400, "",
        { db = db, key = "raidSetGridPosition" })

    dropdown = CreateFrame("DropdownButton", nil, window, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(150)
    dropdown:SetPoint("TOPRIGHT", -PADDING, -(LuckyUI.HEADER_HEIGHT + 6))
    dropdown:SetupMenu(function(_, root)
        for _, difficulty in ipairs(shown.raid and shown.raid.difficulties or {}) do
            root:CreateRadio(difficulty,
                function() return shown.difficulty == difficulty end,
                function()
                    shown.difficulty = difficulty
                    redraw()
                end)
        end
    end)

    -- Collecting a piece while the window is up ticks it off there and then.
    window:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
    window:SetScript("OnEvent", function(self)
        if not (self:IsShown() and shown.raid) then return end
        LuckysWardrobe.RaidSets:ForgetCollected()
        redraw()
    end)
end

local function journalDifficultyName()
    local difficultyID = EJ_GetDifficulty()
    return difficultyID and GetDifficultyInfo(difficultyID)
end

function RaidSetGrid:Show(raidName)
    local raid = LuckysWardrobe.RaidSets:ForInstance(raidName)
    if not raid then return end
    if not window then createWindow() end

    shown.raidName, shown.raid = raidName, raid
    shown.difficulty = LuckysWardrobe.RaidSets.MatchDifficulty(raid.difficulties, journalDifficultyName())
    window.titleText:SetText(S().title:format(raidName))
    window:Show()
    redraw()
end

local function journalRaidName()
    local instanceID = EncounterJournal.instanceID
    if not instanceID then return nil end
    local name = EJ_GetInstanceInfo(instanceID)
    local isRaid = select(12, EJ_GetInstanceInfo(instanceID))
    return isRaid and name or nil
end

-- The journal redraws the instance for a difficulty change too, which is left
-- alone so the window keeps the difficulty picked in it.
local function onInstanceDisplayed()
    local raidName = db.raidSetGrid and journalRaidName()
    local hasSets = raidName ~= nil and LuckysWardrobe.RaidSets:ForInstance(raidName) ~= nil
    journalButton:SetShown(hasSets)
    if hasSets and raidName ~= shown.raidName and window and window:IsShown() then
        RaidSetGrid:Show(raidName)
    end
end

-- Sits under the journal's own side tabs, looking like one, but is not one:
-- Blizzard's tab template would hand the click to its own tab switching.
local function createJournalButton()
    local info = EncounterJournal.encounter.info
    journalButton = CreateFrame("Button", nil, info)
    journalButton:SetSize(63, 57)
    journalButton:SetFrameLevel(info.modelTab:GetFrameLevel())
    journalButton:SetPoint("TOP", info.modelTab, "BOTTOM", 0, 2)
    journalButton:SetNormalTexture(journalButton:CreateTexture(nil, "BACKGROUND", "UI-EJ-Tab-UnSelected"))
    journalButton:SetPushedTexture(journalButton:CreateTexture(nil, "BACKGROUND", "UI-EJ-Tab-Selected"))
    local highlight = journalButton:CreateTexture(nil, "HIGHLIGHT", "UI-EJ-Tab-Highlight")
    highlight:SetBlendMode("ADD")
    journalButton:SetHighlightTexture(highlight)

    local icon = journalButton:CreateTexture(nil, "OVERLAY")
    icon:SetSize(30, 30)
    icon:SetPoint("RIGHT", -12, 0)
    icon:SetTexture("Interface\\AddOns\\Luckys_Wardrobe\\Images\\icon")

    journalButton:SetScript("OnClick", function()
        local raidName = journalRaidName()
        if window and window:IsShown() and shown.raidName == raidName then
            window:Hide()
        else
            RaidSetGrid:Show(raidName)
        end
    end)
    journalButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
        GameTooltip:AddLine(S().button, 1, 1, 1)
        GameTooltip:AddLine(S().buttonDesc, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    journalButton:SetScript("OnLeave", GameTooltip_Hide)
    journalButton:Hide()

    hooksecurefunc("EncounterJournal_DisplayInstance", onInstanceDisplayed)
    EncounterJournal:HookScript("OnHide", function()
        if window then window:Hide() end
    end)
end

function RaidSetGrid:Refresh()
    if journalButton then onInstanceDisplayed() end
    if window and not db.raidSetGrid then window:Hide() end
end

function RaidSetGrid:Init(database)
    db = database
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EncounterJournal", createJournalButton)
end
