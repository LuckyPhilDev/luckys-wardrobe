-- luacheck: globals AutoScalingFontStringMixin CHECK_ALL COLLECTED CollectionWardrobeUtil CreateDataProvider CreateScrollBoxListLinearView DEFAULT EXPANSION_NAME0 EXPANSION_NAME1 EXPANSION_NAME2 EXPANSION_NAME3 EXPANSION_NAME4 EXPANSION_NAME5 EXPANSION_NAME6 EXPANSION_NAME7 EXPANSION_NAME8 EXPANSION_NAME9 EXPANSION_NAME10 EXPANSION_NAME11 EventUtil GetUICameraInfo IsShiftKeyDown IsUnitModelReadyForUI MenuResponse Mixin Model_ApplyUICamera NOT_COLLECTED PanelTemplates_ResizeTabsToFit PanelTemplates_SetNumTabs PanelTemplates_TabResize QUESTION_MARK_ICON ScrollBoxConstants ScrollUtil UNCHECK_ALL UnitClass WardrobeCollectionFrame WardrobeSetsDetailsModelMixin hooksecurefunc

-- Lucky's Wardrobe: Extra Sets, a third Appearances subtab listing the armour
-- sets Blizzard defines, most of which its own Sets tab never shows. Records
-- come from the session catalogue ExtraSetsCatalog.lua builds out of the
-- bundled snapshot; everything derived (names, icons, collected state) is read
-- live from Blizzard APIs and never persisted.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.ExtraSets = {}

local ExtraSets = LuckysWardrobe.ExtraSets

local TAB_FIT_WIDTH = 275
local NATIVE_ITEMS_TAB_ID = 1
local NATIVE_SETS_TAB_ID = 2
-- How long a burst of collection events is allowed to gather before the page
-- reads the catalogue again. Long enough to collapse a burst, short enough
-- that collecting something still updates the list while you are looking at it.
local REBUILD_DELAY_SECONDS = 0.25
-- How long the page waits for the items behind a set's pieces to arrive before
-- reading them again. Some never arrive, so the wait is given up after a few
-- passes rather than run until it succeeds.
local ITEM_LOAD_DELAY_SECONDS = 0.5
local ITEM_LOAD_PASSES = 3

-- The smallest the Sets tab lets a set name shrink to before it gives up and
-- wraps it instead.
local NAME_MIN_LINE_HEIGHT = 16

-- The offsets Blizzard gives the class dropdown above the Sets page.
local CLASS_DROPDOWN_X = -9
local CLASS_DROPDOWN_Y = 4

-- Blizzard places the collected-sets bar for a two-tab strip, so a third tab
-- runs underneath it. It moves to the end of the strip and gives up some width
-- to stay clear of the class dropdown on the right.
local PROGRESS_BAR_WIDTH = 150
local PROGRESS_BAR_TAB_GAP = 10
local PROGRESS_BAR_TAB_DROP = -11
local PROGRESS_BAR_BORDER_MARGIN = 9

-- Blizzard's localized slot-name globals, for the tooltip's slot line. A slot
-- with no entry here is one the page could not label, so records are held to
-- the slots named below.
local SLOT_TOOLTIP_GLOBALS = {
    HEAD = "HEADSLOT",
    SHOULDER = "SHOULDERSLOT",
    BACK = "BACKSLOT",
    CHEST = "CHESTSLOT",
    BODY = "SHIRTSLOT",
    TABARD = "TABARDSLOT",
    WRIST = "WRISTSLOT",
    HANDS = "HANDSSLOT",
    WAIST = "WAISTSLOT",
    LEGS = "LEGSSLOT",
    FEET = "FEETSLOT",
}

local expansionNames = {
    EXPANSION_NAME0,
    EXPANSION_NAME1,
    EXPANSION_NAME2,
    EXPANSION_NAME3,
    EXPANSION_NAME4,
    EXPANSION_NAME5,
    EXPANSION_NAME6,
    EXPANSION_NAME7,
    EXPANSION_NAME8,
    EXPANSION_NAME9,
    EXPANSION_NAME10,
    EXPANSION_NAME11,
}

-- Session-only view state behind the filter button, matching the Sets tab menu.
-- The class is not in here: it narrows the catalogue before entries are built,
-- rather than hiding rows that have already been worked out.
local filters = {
    collected = true,
    uncollected = true,
    expansions = {},
    sortMode = "default",
    sortDirection = "ascending",
}

-- Keyed by Blizzard's expansionID, which counts from 0 for Classic. The name
-- list is a Lua array counting from 1, so every lookup here is index - 1.
local function setAllExpansions(shown)
    for index = 1, #expansionNames do filters.expansions[index - 1] = shown end
end

local function isNarrowed()
    if not (filters.collected and filters.uncollected) then return true end
    for index = 1, #expansionNames do
        if not filters.expansions[index - 1] then return true end
    end
    return false
end

setAllExpansions(true)

local attachedWardrobe
local extraPage
local extraTab
local extraTabID

-- Pure catalogue logic. Everything below takes plain tables plus injected
-- resolvers so the rules stay testable outside the client.

function ExtraSets.ValidateRecord(record)
    if type(record) ~= "table" then return nil, "record must be a table" end
    if type(record.setID) ~= "number" or record.setID <= 0 or record.setID % 1 ~= 0 then
        return nil, "setID must be a positive integer"
    end
    if type(record.name) ~= "string" or record.name == "" then return nil, "name is required" end
    if record.label ~= nil and type(record.label) ~= "string" then return nil, "label must be a string" end
    if record.expansionID ~= nil and type(record.expansionID) ~= "number" then
        return nil, "expansionID must be a number"
    end
    if type(record.armorType) ~= "number" then return nil, "armorType is required" end
    if type(record.classMask) ~= "number" or record.classMask < 0 then return nil, "classMask is required" end
    if type(record.pieces) ~= "table" or #record.pieces == 0 then return nil, "pieces are required" end

    local seenSourceIDs = {}
    for _, piece in ipairs(record.pieces) do
        if not SLOT_TOOLTIP_GLOBALS[piece.slot] then return nil, "unknown slot: " .. tostring(piece.slot) end
        if type(piece.sourceID) ~= "number" or piece.sourceID <= 0 or piece.sourceID % 1 ~= 0 then
            return nil, "sourceID must be a positive integer"
        end
        if seenSourceIDs[piece.sourceID] then return nil, "duplicate sourceID: " .. piece.sourceID end
        seenSourceIDs[piece.sourceID] = true
    end
    return true
end

function ExtraSets.ClassAllowed(classMask, classID)
    if classMask == 0 or not classID then return true end
    local classBit = 2 ^ (classID - 1)
    return math.floor(classMask / classBit) % 2 == 1
end

-- What one class has any use for: the sets named for it, plus the sets named
-- for nobody in the armour that class wears. A set belonging to another class,
-- or to nobody in armour this class cannot transmogrify, is not a set this
-- character will ever wear, so it never becomes a row.
function ExtraSets.MatchesClass(record, classID)
    if not classID then return true end
    if record.classMask ~= 0 then return ExtraSets.ClassAllowed(record.classMask, classID) end

    local armourType = LuckysWardrobe.Classes:ArmourType(classID)
    return armourType == nil or record.armorType == armourType
end

function ExtraSets.RecordsForClass(records, classID)
    if not classID then return records end

    local matching = {}
    for _, record in ipairs(records) do
        if ExtraSets.MatchesClass(record, classID) then matching[#matching + 1] = record end
    end
    return matching
end

-- resolver.sourceState(sourceID) returns nil when the source does not exist on
-- this client, or { appearanceID, collected } where collected == nil means the
-- appearance data has not loaded yet.
function ExtraSets.BuildEntries(records, resolver)
    local entries = {}
    local seenSetIDs = {}

    for _, record in ipairs(records) do
        local valid, problem = ExtraSets.ValidateRecord(record)
        if not valid then
            LuckysWardrobe.DevLog("Extra Sets record rejected: " .. tostring(problem))
        elseif seenSetIDs[record.setID] then
            LuckysWardrobe.DevLog("Extra Sets record rejected: duplicate set " .. record.setID)
        else
            seenSetIDs[record.setID] = true
            entries[#entries + 1] = ExtraSets.BuildEntry(record, resolver)
        end
    end

    return entries
end

function ExtraSets.BuildEntry(record, resolver)
    local pieces = {}
    for index, piece in ipairs(record.pieces) do
        pieces[index] = { slot = piece.slot, sourceID = piece.sourceID, itemID = piece.itemID }
    end

    -- Pieces the catalogue could not resolve at all never became sources, so
    -- they are counted here rather than shown as rows the tooltip cannot fill.
    local collected, total = 0, 0
    local unavailable = record.unresolvedPieces or 0
    local loading = false
    local seenAppearanceIDs = {}
    for _, piece in ipairs(pieces) do
        local state = resolver.sourceState(piece.sourceID)
        if not state then
            piece.state = "unavailable"
            unavailable = unavailable + 1
        elseif state.collected == nil or state.appearanceID == nil then
            piece.state = "loading"
            loading = true
            total = total + 1
        else
            -- Sources sharing an appearance count once, matching how Blizzard
            -- counts official set completion.
            piece.state = state.collected and "collected" or "missing"
            if not seenAppearanceIDs[state.appearanceID] then
                seenAppearanceIDs[state.appearanceID] = true
                total = total + 1
                if state.collected then collected = collected + 1 end
            end
        end
    end

    return {
        key = record.setID,
        setID = record.setID,
        name = record.name,
        label = record.label or "",
        expansionID = record.expansionID,
        armorType = record.armorType,
        classMask = record.classMask,
        pieces = pieces,
        collected = collected,
        total = total,
        missing = total - collected,
        unavailable = unavailable,
        loading = loading,
    }
end

-- Why this character could not wear the set, or nil when they could, which is
-- what the details panel says when they could not. Armour type is what keeps
-- most sets off a character and the class mask does not encode it, so the
-- refusal comes from the sources themselves and only then is it worth asking
-- what the character wears. Anything the client turns down for a reason of its
-- own, a race or faction lock among them, answers "other": there is nothing
-- more to tell the player than that it turned it down. Worked out for the set
-- on screen rather than for every set in the list, because only the one on
-- screen ever says so.
function ExtraSets.UnwearableReason(entry, classID, sourceValidity)
    if not ExtraSets.ClassAllowed(entry.classMask or 0, classID) then return "class" end

    local judged, valid = 0, 0
    for _, piece in ipairs(entry.pieces) do
        local isValid = sourceValidity(piece.sourceID)
        if isValid ~= nil then
            judged = judged + 1
            if isValid then valid = valid + 1 end
        end
    end
    if judged == 0 or valid == judged then return nil end

    local wornArmour = LuckysWardrobe.Classes:ArmourType(classID)
    if wornArmour and entry.armorType and entry.armorType ~= wornArmour then return "armour" end
    return "other"
end

-- The line the details panel shows for a set out of reach, naming the reason
-- where there is one to name. A set whose mask holds no class this client has,
-- or an armour type it has no name for, falls back to saying only that the set
-- is out of reach rather than to a sentence with a hole in it.
function ExtraSets.UnwearableNotice(entry, reason, classID)
    local S = LuckysWardrobe.Strings.extraSets
    if reason == "class" then
        local classes = LuckysWardrobe.Classes:FromMask(entry.classMask)
        if #classes > 0 then return S.notUsableClass:format(LuckysWardrobe.Classes:Names(classes)) end
    elseif reason == "armour" then
        local setArmour = S.armourTypes[entry.armorType]
        local wornArmour = S.armourTypes[LuckysWardrobe.Classes:ArmourType(classID)]
        if setArmour and wornArmour then return S.notUsableArmour:format(setArmour, wornArmour) end
    end
    return S.notUsable
end

function ExtraSets.IsComplete(entry)
    return not entry.loading and entry.total > 0 and entry.collected == entry.total
end

-- Collected/Not Collected and expansion narrowing, mirroring the Sets tab
-- filter menu. Only sets the client itself knows carry an expansion, so the
-- rest stay visible while any expansion is still checked rather than vanishing
-- behind a box that does not describe them.
function ExtraSets.ApplyFilters(entries, filterState)
    local anyExpansion = false
    for _, shown in pairs(filterState.expansions) do
        if shown then
            anyExpansion = true
            break
        end
    end

    local result = {}
    for _, entry in ipairs(entries) do
        local shown
        if ExtraSets.IsComplete(entry) then
            shown = filterState.collected
        else
            shown = filterState.uncollected
        end
        if shown then
            if entry.expansionID ~= nil and filterState.expansions[entry.expansionID] ~= nil then
                shown = filterState.expansions[entry.expansionID]
            else
                shown = anyExpansion
            end
        end
        if shown then result[#result + 1] = entry end
    end
    return result
end

function ExtraSets.FilterEntries(entries, query)
    local normalized = (query or ""):match("^%s*(.-)%s*$"):gsub("%s+", " "):lower()
    if normalized == "" then return entries end

    local filtered = {}
    for _, entry in ipairs(entries) do
        local text = (entry.name .. " " .. entry.label):lower()
        if text:find(normalized, 1, true) then filtered[#filtered + 1] = entry end
    end
    return filtered
end

-- "default" keeps catalogue order: armour type, then set ID, which puts a set's
-- recolours next to each other. "name" is alphabetical. "completion" puts the
-- fewest missing pieces first; sets with nothing resolvable sort last because
-- there is nothing left to finish there. Descending inverts any of them.
function ExtraSets.SortEntries(entries, mode, direction)
    local descending = direction == "descending"
    if mode ~= "completion" and mode ~= "name" then
        if not descending then return entries end
        local reversed = {}
        for index = #entries, 1, -1 do reversed[#reversed + 1] = entries[index] end
        return reversed
    end

    local decorated = {}
    for index, entry in ipairs(entries) do
        decorated[index] = { entry = entry, order = index }
    end
    table.sort(decorated, function(left, right)
        local before
        if mode == "name" then
            if left.entry.name ~= right.entry.name then
                before = left.entry.name < right.entry.name
            else
                before = left.order < right.order
            end
        else
            local leftMissing = left.entry.total > 0 and left.entry.missing or math.huge
            local rightMissing = right.entry.total > 0 and right.entry.missing or math.huge
            if leftMissing ~= rightMissing then
                before = leftMissing < rightMissing
            elseif left.entry.total ~= right.entry.total then
                before = left.entry.total > right.entry.total
            else
                before = left.order < right.order
            end
        end
        if descending then return not before end
        return before
    end)

    local sorted = {}
    for index, item in ipairs(decorated) do sorted[index] = item.entry end
    return sorted
end

-- Live resolvers, split out so tests can replace them wholesale.

function ExtraSets.LiveResolver()
    return {
        -- Asked of every piece of every set on this page, so it asks the client
        -- once where it can. Appearance info counts any source of the same look
        -- as collected, which is what the Sets tab shows, and answering means
        -- the source exists. The client declines for looks outside the player's
        -- wardrobe context, such as another armour type, and only then is the
        -- source itself worth the second question.
        sourceState = function(sourceID)
            local appearance = C_TransmogCollection.GetAppearanceInfoBySource(sourceID)
            if appearance then
                return {
                    appearanceID = appearance.appearanceID,
                    collected = appearance.appearanceIsCollected and true or false,
                }
            end

            local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
            if not sourceInfo then return nil end
            return {
                appearanceID = sourceInfo.visualID,
                collected = sourceInfo.isCollected and true or false,
            }
        end,
        -- Whether this character could wear a piece at all, which is armour
        -- type more often than class. Asked only of the set on screen: it costs
        -- a table for every piece, and nothing in the list is built from it.
        --
        -- The client works the answer out from the item's own data, and a piece
        -- it has not loaded yet says no rather than declining. Cold is not the
        -- same as no, so an unloaded piece goes unjudged and the set waits for
        -- a real answer instead of being called unwearable on first sight.
        sourceValidity = function(sourceID)
            local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
            if not sourceInfo then return nil end
            if not sourceInfo.itemID or not C_Item.GetItemInfo(sourceInfo.itemID) then return nil end
            return sourceInfo.isValidSourceForPlayer and true or false
        end,
        playerClassID = function()
            local _, _, classID = UnitClass("player")
            return classID
        end,
    }
end

function ExtraSets.Records()
    return LuckysWardrobe.ExtraSetsCatalog:GetRecords()
end

-- Thousands of sets, each asking the client about every one of its pieces, is
-- far too much work to redo for a keystroke in the search box. Entries are
-- built once for the chosen class and kept until something the client owns
-- actually changes.
local cachedEntries
local selectedClassID

function ExtraSets.InvalidateEntries()
    cachedEntries = nil
end

--- Takes the class the Sets tab is showing, so the one dropdown Blizzard draws
--- above both pages means the same thing on either. Answers whether the page
--- now has a different class to list.
function ExtraSets.SyncClassFilter()
    local classID = C_TransmogSets.GetTransmogSetsClassFilter()
    if not classID or classID == selectedClassID then return false end

    selectedClassID = classID
    ExtraSets.InvalidateEntries()
    return true
end

function ExtraSets.Entries()
    if not cachedEntries then
        LuckysWardrobe.Perf:Begin("entries built")
        cachedEntries = ExtraSets.BuildEntries(
            ExtraSets.RecordsForClass(ExtraSets.Records(), selectedClassID),
            ExtraSets.LiveResolver()
        )
        LuckysWardrobe.Perf:End("entries built")
    end
    return cachedEntries
end

-- Page UI. Mirrors the native Sets layout: list on the left, dressing-room
-- model on the right, with search and a session-only sort choice.

function ExtraSets:CreatePage(wardrobe)
    local S = LuckysWardrobe.Strings.extraSets
    local page = CreateFrame("Frame", "LuckysWardrobeExtraSetsFrame", wardrobe)
    page:SetPoint("TOPLEFT", 4, -60)
    page:SetPoint("BOTTOMRIGHT", -6, 5)

    local leftInset = CreateFrame("Frame", nil, page, "InsetFrameTemplate")
    leftInset:SetWidth(260)
    leftInset:SetPoint("TOPLEFT")
    leftInset:SetPoint("BOTTOMLEFT")

    local rightInset = CreateFrame("Frame", nil, page, "CollectionsBackgroundTemplate")
    rightInset:SetPoint("TOPLEFT", leftInset, "TOPRIGHT", 22, 0)
    rightInset:SetPoint("BOTTOMRIGHT")
    rightInset.BGCornerTopLeft:Hide()
    rightInset.BGCornerTopRight:Hide()

    local searchBox = CreateFrame("EditBox", nil, page, "SearchBoxTemplate")
    searchBox:SetSize(145, 20)
    searchBox:SetPoint("TOPLEFT", 15, -9)

    local filterButton = CreateFrame("DropdownButton", nil, page, "WowStyle1FilterDropdownTemplate")
    filterButton:SetSize(93, 22)
    filterButton:SetPoint("TOPLEFT", 166, -8)

    local progressBar = CreateFrame("StatusBar", nil, page, "CollectionsProgressBarTemplate")
    page.progressBar = progressBar

    local listContainer = CreateFrame("Frame", nil, page)
    listContainer:SetSize(255, 499)
    listContainer:SetPoint("TOPLEFT", 3, -36)
    listContainer:SetFrameStrata("HIGH")

    local scrollBox = CreateFrame("Frame", nil, listContainer, "WowScrollBoxList")
    scrollBox:SetAllPoints()

    local scrollBar = CreateFrame("EventFrame", nil, listContainer, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 8, 31)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 8, -1)

    local emptyText = leftInset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("CENTER")
    emptyText:SetWidth(220)
    emptyText:SetText(S.empty)

    local model = CreateFrame("DressUpModel", nil, page)
    Mixin(model, WardrobeSetsDetailsModelMixin)
    model:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 3, -3)
    model:SetPoint("BOTTOMRIGHT", rightInset, "BOTTOMRIGHT", -4, 3)
    model:SetScript("OnShow", model.OnShow)
    -- Blizzard's own model script, run through the stopwatch: it is the only
    -- thing on this page that runs every frame by design, so it has to be
    -- ruled in or out before anything else is blamed.
    model:SetScript("OnUpdate", function(self, elapsed)
        LuckysWardrobe.Perf:Begin("model updated")
        self.OnUpdate(self, elapsed)
        LuckysWardrobe.Perf:End("model updated")
    end)
    model:SetScript("OnMouseDown", model.OnMouseDown)
    model:SetScript("OnMouseUp", model.OnMouseUp)
    model:SetScript("OnMouseWheel", model.OnMouseWheel)
    model:SetScript("OnModelLoaded", model.OnModelLoaded)
    model:OnLoad()
    model:Hide()

    local detailsFrame = CreateFrame("Frame", nil, page)
    detailsFrame:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 0, -3)
    detailsFrame:SetPoint("BOTTOMRIGHT", rightInset, "BOTTOMRIGHT", -3, 2)
    -- Relative to the model, not a fixed level: the model fills the same area
    -- and takes the mouse, so anything below it stops receiving hover.
    detailsFrame:SetFrameLevel(model:GetFrameLevel() + 10)
    detailsFrame:Hide()

    -- The Sets tab shrinks a long set name to keep it on one line, and only
    -- wraps it, smaller again, when even the smallest size will not fit.
    local nameText = detailsFrame:CreateFontString(nil, "OVERLAY", "Fancy24Font")
    nameText:SetPoint("TOP", 0, -37)
    nameText:SetWidth(380)
    nameText:SetTextColor(1, 0.82, 0)
    Mixin(nameText, AutoScalingFontStringMixin)
    nameText:SetMaxLines(1)
    nameText:SetMinLineHeight(NAME_MIN_LINE_HEIGHT)

    local longNameText = detailsFrame:CreateFontString(nil, "OVERLAY", "Fancy16Font")
    longNameText:SetPoint("TOP", 0, -30)
    longNameText:SetWidth(380)
    longNameText:SetTextColor(1, 0.82, 0)
    longNameText:SetMaxLines(2)
    longNameText:Hide()

    local labelText = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelText:SetPoint("TOP", nameText, "BOTTOM", 0, -2)
    labelText:SetWidth(380)

    local countsText = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countsText:SetPoint("TOP", labelText, "BOTTOM", 0, -2)
    countsText:SetWidth(380)

    local iconRowBackground = detailsFrame:CreateTexture(nil, "BORDER")
    iconRowBackground:SetAtlas("transmog-set-iconrow-background", true)
    iconRowBackground:SetPoint("TOP", 0, -82)

    local modelFade = detailsFrame:CreateTexture(nil, "BACKGROUND")
    modelFade:SetAtlas("transmog-set-model-cutoff-fade")
    modelFade:SetHeight(178)
    modelFade:SetPoint("TOPLEFT", 2, 0)
    modelFade:SetPoint("TOPRIGHT")

    local noticeText = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    noticeText:SetPoint("BOTTOM", 0, 12)
    noticeText:SetWidth(380)

    local detailsText = rightInset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    detailsText:SetPoint("CENTER")
    detailsText:SetWidth(340)
    detailsText:SetText(S.select)

    local itemFrames = {}
    local selectedEntry

    local function refreshCamera()
        local detailsCameraID = C_TransmogSets.GetCameraIDs()
        if not detailsCameraID then return end

        model:RefreshCamera()
        Model_ApplyUICamera(model, detailsCameraID)
        if model.cameraID ~= detailsCameraID then
            model.cameraID = detailsCameraID
            model.defaultPosX, model.defaultPosY, model.defaultPosZ, model.yaw = GetUICameraInfo(detailsCameraID)
        end
    end

    -- Every source sharing this piece's look, so the tooltip can list where the
    -- appearance comes from the way the native Sets tab does.
    local function pieceSources(piece)
        local sourceInfo = C_TransmogCollection.GetSourceInfo(piece.sourceID)
        if not sourceInfo then return nil end

        local sources = {}
        for _, sourceID in ipairs(C_TransmogCollection.GetAllAppearanceSources(sourceInfo.visualID) or {}) do
            local info = C_TransmogCollection.GetSourceInfo(sourceID)
            if info then sources[#sources + 1] = info end
        end
        if #sources == 0 then sources[1] = sourceInfo end

        CollectionWardrobeUtil.SortSources(sources, sourceInfo.visualID, piece.sourceID)
        return sources
    end

    -- The tooltip offers Tab to cycle through the items sharing a look, and it
    -- is the wardrobe's own key handler that does the cycling: it moves the
    -- source index and asks whichever frame owns the tooltip to draw it again.
    -- A page that draws its tooltips behind the wardrobe's back never gets
    -- asked, which is why the offer went unanswered here.
    local hoveredPiece

    local function drawPieceTooltip()
        local piece = hoveredPiece
        local sources = piece.state ~= "unavailable" and pieceSources(piece) or nil
        if not sources then
            GameTooltip:SetText(S.pieceUnavailable, 1, 0.25, 0.25, 1, true)
            GameTooltip:Show()
            return
        end

        wardrobe.tooltipContentFrame = page
        wardrobe.tooltipSourceIndex, wardrobe.tooltipCycle =
            CollectionWardrobeUtil.SetAppearanceTooltip(GameTooltip, {
                sources = sources,
                primarySourceID = piece.sourceID,
                selectedIndex = wardrobe.tooltipSourceIndex,
                showUseError = true,
                showTrackingInfo = false,
                slotType = _G[SLOT_TOOLTIP_GLOBALS[piece.slot]],
            })
        if piece.state == "missing" then
            GameTooltip:AddLine(S.trackHint, 0.5, 0.8, 1)
        end
        GameTooltip:Show()
    end

    local function pieceTooltip(itemFrame)
        hoveredPiece = itemFrame.piece
        GameTooltip:SetOwner(itemFrame, "ANCHOR_RIGHT")
        drawPieceTooltip()
    end

    -- Handing the tooltip back matters as much as claiming it: the index Tab
    -- walks belongs to the piece that was hovered, and the next piece starts
    -- again from its own item.
    local function hidePieceTooltip()
        hoveredPiece = nil
        wardrobe:HideAppearanceTooltip()
    end

    local function getItemFrame(index)
        if itemFrames[index] then return itemFrames[index] end

        local itemFrame = CreateFrame("Button", nil, detailsFrame)
        itemFrame:SetSize(32, 32)
        itemFrame:RegisterForClicks("LeftButtonUp")
        itemFrame.icon = itemFrame:CreateTexture(nil, "BORDER")
        itemFrame.icon:SetSize(28, 28)
        itemFrame.icon:SetPoint("CENTER")
        itemFrame.border = itemFrame:CreateTexture(nil, "OVERLAY")
        -- The border art is wider than the icon and off-centre within itself, so
        -- Blizzard hangs it by its right edge rather than its middle. Centring it
        -- instead leaves the frame sitting beside the icon it frames.
        itemFrame.border:SetPoint("RIGHT", itemFrame.icon, "CENTER", 20, 1)
        itemFrame:SetScript("OnEnter", pieceTooltip)
        itemFrame:SetScript("OnLeave", hidePieceTooltip)
        itemFrame:SetScript("OnClick", function(self, buttonName)
            if LuckysWardrobe.WowheadLink:HandlesClick(buttonName)
                and LuckysWardrobe.WowheadLink:ShowForSource(self.piece.sourceID) then
                return
            end
            if IsShiftKeyDown() and self.piece.state == "missing" then
                LuckysWardrobe.SetTracking:TrackSources({ self.piece.sourceID }, selectedEntry and selectedEntry.name)
            end
        end)
        itemFrames[index] = itemFrame
        return itemFrame
    end

    -- A name that fits once shrunk stays on its one line; one that still will
    -- not fit wraps onto two smaller ones. Answers the line the rest of the
    -- details hang from, since the two sit at different heights.
    local function showSetName(name)
        nameText:SetText(name)
        local wrap = nameText:IsTruncated()
        nameText:SetShown(not wrap)
        longNameText:SetShown(wrap)
        if wrap then longNameText:SetText(name) end
        return wrap and longNameText or nameText
    end

    local function showNotice(entry)
        local resolver = ExtraSets.LiveResolver()
        local classID = resolver.playerClassID()
        local unwearable = ExtraSets.UnwearableReason(entry, classID, resolver.sourceValidity)
        if entry.unavailable > 0 then
            noticeText:SetFormattedText(S.unavailableNotice, entry.unavailable)
        elseif unwearable then
            noticeText:SetText(ExtraSets.UnwearableNotice(entry, unwearable, classID))
        end
        noticeText:SetShown(entry.unavailable > 0 or unwearable ~= nil)
    end

    -- Asking for a set's items is what starts them loading, and the answers
    -- land frames later. Sets this character can wear are the ones that arrive
    -- cold, since building the list only asks the client about pieces it will
    -- not judge, so without this pass the notice would be wrong exactly where
    -- it matters and right only after leaving the set and coming back.
    local function loadPieceItems(entry, pass)
        local waiting = false
        for _, piece in ipairs(entry.pieces) do
            if piece.itemID and not C_Item.GetItemInfo(piece.itemID) then
                C_Item.RequestLoadItemDataByID(piece.itemID)
                waiting = true
            end
        end
        if not waiting or pass >= ITEM_LOAD_PASSES then return end

        C_Timer.After(ITEM_LOAD_DELAY_SECONDS, function()
            -- The set on screen may have moved on while the client answered.
            if not selectedEntry or selectedEntry.key ~= entry.key then return end
            showNotice(entry)
            loadPieceItems(entry, pass + 1)
        end)
    end

    -- Dressing the model is the most expensive thing this page does, and the
    -- pieces of a set never change while a session runs. Only a different set,
    -- or a model that has been rebuilt underneath us, is worth redressing for.
    local dressedKey

    local function displayEntry(entry)
        LuckysWardrobe.Perf:Begin("set displayed")
        selectedEntry = entry
        local shown = entry ~= nil
        model:SetShown(shown)
        detailsFrame:SetShown(shown)
        detailsText:SetShown(not shown)
        if not shown then
            dressedKey = nil
            LuckysWardrobe.Perf:End("set displayed")
            return
        end

        local redress = dressedKey ~= entry.key
        dressedKey = entry.key
        if redress then LuckysWardrobe.Perf:Count("model dressed") end

        labelText:ClearAllPoints()
        labelText:SetPoint("TOP", showSetName(entry.name), "BOTTOM", 0, -2)
        labelText:SetText(entry.label)
        countsText:SetFormattedText(S.counts, entry.collected, entry.total)
        showNotice(entry)
        loadPieceItems(entry, 1)
        if redress then model:Undress() end

        for _, itemFrame in ipairs(itemFrames) do itemFrame:Hide() end
        local spacing = 37
        local xOffset = -math.floor((#entry.pieces - 1) * spacing / 2)
        for index, piece in ipairs(entry.pieces) do
            local itemFrame = getItemFrame(index)
            local collected = piece.state == "collected"
            itemFrame.piece = piece
            itemFrame.icon:SetTexture(
                piece.state ~= "unavailable" and C_TransmogCollection.GetSourceIcon(piece.sourceID)
                or QUESTION_MARK_ICON
            )
            itemFrame.icon:SetDesaturated(not collected)
            itemFrame.icon:SetAlpha(collected and 1 or 0.3)
            itemFrame.border:SetAtlas(collected and "loottab-set-itemborder-green" or "loottab-set-itemborder-white", true)
            itemFrame.border:SetDesaturated(not collected)
            -- The Sets tab fades the frame with the icon it holds, or an
            -- uncollected piece reads as a bright frame around nothing.
            itemFrame.border:SetAlpha(collected and 1 or 0.3)
            itemFrame:ClearAllPoints()
            itemFrame:SetPoint("TOP", detailsFrame, "TOP", xOffset + (index - 1) * spacing, -98)
            itemFrame:Show()

            if redress and piece.state ~= "unavailable" and C_TransmogCollection.GetSourceInfo(piece.sourceID) then
                model:TryOn(piece.sourceID)
            end
        end

        if redress then refreshCamera() end
        LuckysWardrobe.Perf:End("set displayed")
    end

    local function refreshVisibleSelection()
        scrollBox:ForEachFrame(function(button)
            local entry = button:GetElementData()
            button.SelectedTexture:SetShown(selectedEntry and entry.key == selectedEntry.key)
        end)
    end

    local function selectEntry(entry)
        displayEntry(entry)
        refreshVisibleSelection()
    end

    local view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("WardrobeSetsScrollFrameButtonTemplate", function(button, entry)
        local complete = ExtraSets.IsComplete(entry)
        button.Name:SetText(entry.name)
        -- Counts beat a loading notice as soon as anything resolves, so a set
        -- with one slow piece still says something useful.
        if entry.total > 0 then
            button.Label:SetText(entry.label ~= "" and entry.label or S.counts:format(entry.collected, entry.total))
        elseif entry.loading then
            button.Label:SetText(S.loading)
        else
            button.Label:SetText(S.pieceUnavailableShort)
        end
        if complete then
            button.Name:SetTextColor(1, 0.82, 0)
        elseif entry.collected == 0 then
            button.Name:SetTextColor(0.5, 0.5, 0.5)
        else
            button.Name:SetTextColor(0.251, 0.753, 0.251)
        end

        local firstPiece = entry.pieces[1]
        button.IconFrame.Icon:SetTexture(
            firstPiece and firstPiece.state ~= "unavailable"
                and C_TransmogCollection.GetSourceIcon(firstPiece.sourceID)
            or QUESTION_MARK_ICON
        )
        button.IconFrame.Icon:SetDesaturated(entry.collected == 0)
        button.IconFrame.Cover:SetShown(not complete)
        button.IconFrame.Favorite:Hide()
        button.New:Hide()
        button.SelectedTexture:SetShown(selectedEntry and entry.key == selectedEntry.key)

        local showProgress = not entry.loading and entry.collected > 0 and not complete
        button.ProgressBar:SetShown(showProgress)
        if showProgress then button.ProgressBar:SetWidth(204 * entry.collected / entry.total) end

        button:SetScript("OnClick", function(_, buttonName)
            if buttonName ~= "LeftButton" then return end
            if IsShiftKeyDown() then
                ExtraSets:TrackMissing(entry)
                return
            end
            selectEntry(entry)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end)
        button.IconFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(entry.name)
            if entry.label ~= "" then GameTooltip:AddLine(entry.label, 1, 1, 1) end
            GameTooltip:AddLine(S.counts:format(entry.collected, entry.total), 1, 1, 1)
            GameTooltip:Show()
        end)
        button.IconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end)
    view:SetPadding(0, 0, 44, 0, 0)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

    local function refresh()
        LuckysWardrobe.Perf:Begin("page refresh")
        local allEntries = ExtraSets.Entries()
        local narrowed = ExtraSets.ApplyFilters(allEntries, filters)
        local entries = ExtraSets.SortEntries(
            ExtraSets.FilterEntries(narrowed, searchBox:GetText()),
            filters.sortMode,
            filters.sortDirection
        )

        if selectedEntry then
            local selectedKey = selectedEntry.key
            selectedEntry = nil
            for _, entry in ipairs(entries) do
                if entry.key == selectedKey then
                    selectedEntry = entry
                    break
                end
            end
        end
        selectedEntry = selectedEntry or entries[1]

        LuckysWardrobe.Perf:Begin("list filled")
        scrollBox:SetDataProvider(CreateDataProvider(entries), ScrollBoxConstants.RetainScrollPosition)
        LuckysWardrobe.Perf:End("list filled")

        if not LuckysWardrobe.ExtraSetsCatalog:IsReady() then
            emptyText:SetText(S.building)
        elseif #allEntries == 0 then
            emptyText:SetText(S.empty)
        else
            emptyText:SetText(S.noResults)
        end
        emptyText:SetShown(#entries == 0)

        -- Like the Sets tab, the progress bar counts what the filters leave
        -- on screen, not the whole catalogue.
        progressBar:SetMinMaxValues(0, math.max(#narrowed, 1))
        local completed = 0
        for _, entry in ipairs(narrowed) do
            if ExtraSets.IsComplete(entry) then completed = completed + 1 end
        end
        progressBar:SetValue(completed)
        progressBar.text:SetFormattedText(S.progress, completed, #narrowed)
        displayEntry(selectedEntry)
        LuckysWardrobe.Perf:End("page refresh")
    end

    filterButton:SetIsDefaultCallback(function()
        return not isNarrowed()
    end)

    filterButton:SetDefaultCallback(function()
        filters.collected = true
        filters.uncollected = true
        setAllExpansions(true)
        refresh()
    end)

    filterButton:SetupMenu(function(_, root)
        root:CreateCheckbox(COLLECTED, function() return filters.collected end, function()
            filters.collected = not filters.collected
            refresh()
        end)
        root:CreateCheckbox(NOT_COLLECTED, function() return filters.uncollected end, function()
            filters.uncollected = not filters.uncollected
            refresh()
        end)
        root:CreateDivider()

        local sort = root:CreateButton("Sort By")
        for _, option in ipairs({
            { key = "default", label = DEFAULT },
            { key = "name", label = "Name" },
            { key = "completion", label = "Completion" },
        }) do
            local mode = option
            sort:CreateRadio(mode.label, function() return filters.sortMode == mode.key end, function()
                filters.sortMode = mode.key
                refresh()
            end)
        end

        local direction = root:CreateButton("Sort Direction")
        for _, option in ipairs({ { key = "ascending", label = "Ascending" }, { key = "descending", label = "Descending" } }) do
            local sortDirection = option
            direction:CreateRadio(sortDirection.label, function() return filters.sortDirection == sortDirection.key end, function()
                filters.sortDirection = sortDirection.key
                refresh()
            end)
        end

        local expansions = root:CreateButton("Expansion")
        expansions:CreateButton(CHECK_ALL, function()
            setAllExpansions(true)
            refresh()
            return MenuResponse.Refresh
        end)
        expansions:CreateButton(UNCHECK_ALL, function()
            setAllExpansions(false)
            refresh()
            return MenuResponse.Refresh
        end)
        expansions:CreateDivider()
        for index, name in ipairs(expansionNames) do
            local expansionID = index - 1
            expansions:CreateCheckbox(name, function() return filters.expansions[expansionID] end, function()
                filters.expansions[expansionID] = not filters.expansions[expansionID]
                refresh()
            end)
        end
    end)

    -- Collecting an appearance changes what these sets have collected, so the
    -- cached entries go and the page builds them again. Searching and filtering
    -- reuse what is already there.
    local function rebuildNow()
        ExtraSets.InvalidateEntries()
        refresh()
    end

    -- Learning one appearance fires the collection event several times over,
    -- and reading every set again costs far more than a frame, so a burst
    -- collapses into a single pass a moment later. The delay is not felt:
    -- nothing on screen changes until the pass runs either way.
    local rebuildQueued = false
    local function queueRebuild()
        if rebuildQueued then return end

        rebuildQueued = true
        C_Timer.After(REBUILD_DELAY_SECONDS, function()
            rebuildQueued = false
            -- A page that has since closed rebuilds when it opens again.
            if page:IsShown() then rebuildNow() end
        end)
    end

    searchBox:HookScript("OnTextChanged", refresh)
    page:SetScript("OnShow", function(self)
        -- TRANSMOG_COLLECTION_UPDATED is the one that means the collection
        -- changed. TRANSMOG_COLLECTION_ITEM_UPDATE means the client finished
        -- loading an item's data, which asking about a source is what causes:
        -- answering it here made the page feed itself, hundreds of times over.
        self:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
        -- Watching frames only matters while the page is the thing on screen,
        -- and this is the only work it does every frame: a counter and a
        -- comparison, so that measuring a slow page cannot be what slows it.
        self:SetScript("OnUpdate", function(_, elapsed) LuckysWardrobe.Perf:Frame(elapsed) end)
        ExtraSets.SyncClassFilter()
        rebuildNow()
    end)
    page:SetScript("OnHide", function(self)
        self:UnregisterEvent("TRANSMOG_COLLECTION_UPDATED")
        self:SetScript("OnUpdate", nil)
        -- A page that leaves the screen mid-hover would otherwise keep the
        -- tooltip, and Tab would still be cycling it from another tab.
        hidePieceTooltip()
    end)
    page:SetScript("OnEvent", function(_, event)
        LuckysWardrobe.Perf:Count("event " .. event)
        queueRebuild()
    end)
    page.Refresh = rebuildNow
    page.RefreshCameras = refreshCamera
    page.OnSearchUpdate = function() end
    -- What the wardrobe calls on the frame that owns the tooltip once Tab has
    -- moved the index along.
    page.RefreshAppearanceTooltip = function()
        if hoveredPiece then drawPieceTooltip() end
    end
    -- Blizzard retries this every frame until it answers true, so a version of
    -- it that never does, or that makes the client change the model again,
    -- would cost a full redress on every frame. The counter says which.
    page.OnUnitModelChangedEvent = function()
        LuckysWardrobe.Perf:Count("model change handled")
        if not IsUnitModelReadyForUI("player") then
            LuckysWardrobe.Perf:Count("model change deferred")
            return false
        end

        model:RefreshUnit()
        model.cameraID = nil
        model:UpdatePanAndZoomModelType()
        -- A fresh model wears nothing, whatever it was showing before.
        dressedKey = nil
        displayEntry(selectedEntry)
        return true
    end
    page:Hide()
    LuckysWardrobe.DevLog("Extra Sets page built; model level=" .. model:GetFrameLevel()
        .. " details level=" .. detailsFrame:GetFrameLevel())
    return page
end

function ExtraSets:TrackMissing(entry)
    local missing = {}
    for _, piece in ipairs(entry.pieces) do
        if piece.state == "missing" then missing[#missing + 1] = piece.sourceID end
    end
    LuckysWardrobe.SetTracking:TrackSources(missing, entry.name)
end

-- Blizzard hangs the class dropdown above the Sets page rather than inside it,
-- and SetTab re-anchors it to whichever native page it just chose. This page
-- occupies the same corner, so the same offsets leave the dropdown exactly
-- where the Sets tab has it.
local function layOutClassDropdown(dropdown)
    dropdown:ClearAllPoints()
    dropdown:SetPoint("BOTTOMRIGHT", extraPage, "TOPRIGHT", CLASS_DROPDOWN_X, CLASS_DROPDOWN_Y)
end

local function updateSelectedTab(wardrobe, selectedTabID)
    local selected = selectedTabID == extraTabID
    extraPage:SetShown(selected)

    if selected then
        wardrobe.ItemsCollectionFrame:Hide()
        wardrobe.SetsCollectionFrame:Hide()
        wardrobe.SearchBox:Hide()
        wardrobe.FilterButton:Hide()
        wardrobe.progressBar:Hide()
        wardrobe.activeFrame = extraPage
        layOutClassDropdown(wardrobe.ClassDropdown)
        wardrobe.ClassDropdown:Show()
        -- Blizzard refreshes the dropdown from the active page's filter while
        -- the active page is still the one being left, so it reads the name on
        -- the button again now that this page is the active one.
        wardrobe.ClassDropdown:Refresh()
    elseif selectedTabID == NATIVE_ITEMS_TAB_ID or selectedTabID == NATIVE_SETS_TAB_ID then
        wardrobe.SearchBox:Show()
        wardrobe.FilterButton:Show()
        wardrobe.ClassDropdown:Show()
    end
end

-- Anchoring to the last tab keeps the bar clear of the strip as tab widths
-- change with the selection. The border art is a fixed texture, so it has to be
-- narrowed alongside the bar it frames.
local function layOutProgressBar(progressBar)
    progressBar:ClearAllPoints()
    progressBar:SetPoint("TOPLEFT", extraTab, "TOPRIGHT", PROGRESS_BAR_TAB_GAP, PROGRESS_BAR_TAB_DROP)
    progressBar:SetWidth(PROGRESS_BAR_WIDTH)
    progressBar.border:SetWidth(PROGRESS_BAR_WIDTH + PROGRESS_BAR_BORDER_MARGIN)
end

function ExtraSets:Attach(wardrobe)
    if attachedWardrobe or not wardrobe or not wardrobe.numTabs then return end

    attachedWardrobe = wardrobe
    extraTabID = wardrobe.numTabs + 1
    extraPage = self:CreatePage(wardrobe)
    extraPage.searchType = wardrobe.SetsCollectionFrame.searchType
    table.insert(wardrobe.ContentFrames, extraPage)

    extraTab = CreateFrame(
        "Button",
        wardrobe:GetName() .. "Tab" .. extraTabID,
        wardrobe,
        "PanelTopTabButtonTemplate"
    )
    extraTab:SetID(extraTabID)
    extraTab:SetText(LuckysWardrobe.Strings.extraSets.tab)
    extraTab.minWidth = 75
    PanelTemplates_TabResize(extraTab, 0)
    extraTab:SetScript("OnClick", function()
        wardrobe:ClickTab(extraTab)
    end)

    hooksecurefunc(wardrobe, "SetTab", updateSelectedTab)
    hooksecurefunc(wardrobe, "ClickTab", function(self)
        PanelTemplates_ResizeTabsToFit(self, TAB_FIT_WIDTH)
    end)

    -- One class for both pages: the Sets tab's dropdown is the only class
    -- control there is, so a choice made in it is a choice made here.
    hooksecurefunc(wardrobe.ClassDropdown, "SetClassFilter", function()
        if ExtraSets.SyncClassFilter() and extraPage:IsShown() then extraPage.Refresh() end
    end)

    -- The catalogue may still be building when the page first shows; repaint the
    -- moment it lands.
    LuckysWardrobe.ExtraSetsCatalog:OnReady(function()
        ExtraSets.InvalidateEntries()
        if extraPage:IsShown() then extraPage.Refresh() end
    end)

    PanelTemplates_SetNumTabs(wardrobe, extraTabID)
    PanelTemplates_ResizeTabsToFit(wardrobe, TAB_FIT_WIDTH)
    layOutProgressBar(wardrobe.progressBar)
    layOutProgressBar(extraPage.progressBar)
    updateSelectedTab(wardrobe, wardrobe.selectedCollectionTab)
end

function ExtraSets:Init()
    filters.collected = true
    filters.uncollected = true
    filters.sortMode = "default"
    filters.sortDirection = "ascending"
    setAllExpansions(true)
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", function()
        LuckysWardrobe.ExtraSetsCatalog:StartBuild()
        ExtraSets:Attach(WardrobeCollectionFrame)
    end)
end
