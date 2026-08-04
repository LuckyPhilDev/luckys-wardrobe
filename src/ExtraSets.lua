-- luacheck: globals CHECK_ALL COLLECTED CollectionWardrobeUtil CreateDataProvider CreateScrollBoxListLinearView DEFAULT EXPANSION_NAME0 EXPANSION_NAME1 EXPANSION_NAME2 EXPANSION_NAME3 EXPANSION_NAME4 EXPANSION_NAME5 EXPANSION_NAME6 EXPANSION_NAME7 EXPANSION_NAME8 EXPANSION_NAME9 EXPANSION_NAME10 EXPANSION_NAME11 EventUtil GetUICameraInfo IsShiftKeyDown IsUnitModelReadyForUI MenuResponse Mixin Model_ApplyUICamera NOT_COLLECTED PanelTemplates_ResizeTabsToFit PanelTemplates_SetNumTabs PanelTemplates_TabResize QUESTION_MARK_ICON ScrollBoxConstants ScrollUtil UNCHECK_ALL UnitClass WardrobeCollectionFrame WardrobeSetsDetailsModelMixin hooksecurefunc

-- Lucky's Wardrobe: Extra Sets, a third Appearances subtab listing Blizzard-defined
-- sets the runtime Sets API does not surface. Records come from the session
-- catalogue discovered by ExtraSetsCatalog.lua; everything derived (names,
-- icons, collected state) is read live from Blizzard APIs and never persisted.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.ExtraSets = {}

local ExtraSets = LuckysWardrobe.ExtraSets

local TAB_FIT_WIDTH = 275
local NATIVE_ITEMS_TAB_ID = 1
local NATIVE_SETS_TAB_ID = 2
local RECORD_TYPES = { TransmogSet = true, ItemSet = true }

-- Locale-free slot keys, in display order. The catalogue emits these same tokens.
local SLOT_ORDER = {
    "HEAD", "SHOULDER", "BACK", "CHEST", "BODY", "TABARD",
    "WRIST", "HANDS", "WAIST", "LEGS", "FEET",
}
local SLOT_INDEX = {}
for index, slot in ipairs(SLOT_ORDER) do SLOT_INDEX[slot] = index end

-- Blizzard's localized slot-name globals, for the tooltip's slot line.
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
local filters = {
    collected = true,
    uncollected = true,
    expansions = {},
    sortMode = "default",
    sortDirection = "ascending",
}

local function setAllExpansions(shown)
    for index = 1, #expansionNames do filters.expansions[index] = shown end
end

local function isNarrowed()
    if not (filters.collected and filters.uncollected) then return true end
    for index = 1, #expansionNames do
        if not filters.expansions[index] then return true end
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
    if not RECORD_TYPES[record.recordType] then return nil, "unknown recordType" end
    if type(record.recordID) ~= "number" or record.recordID <= 0 or record.recordID % 1 ~= 0 then
        return nil, "recordID must be a positive integer"
    end
    if type(record.name) ~= "string" or record.name == "" then return nil, "name is required" end
    if record.label ~= nil and type(record.label) ~= "string" then return nil, "label must be a string" end
    if record.expansionID ~= nil and type(record.expansionID) ~= "number" then
        return nil, "expansionID must be a number"
    end
    if type(record.classMask) ~= "number" or record.classMask < 0 then return nil, "classMask is required" end
    if type(record.build) ~= "string" or record.build == "" then return nil, "build is required" end
    if type(record.slotSources) ~= "table" then return nil, "slotSources are required" end

    local seenSourceIDs = {}
    local pieceCount = 0
    for slot, sourceID in pairs(record.slotSources) do
        if not SLOT_INDEX[slot] then return nil, "unknown slot: " .. tostring(slot) end
        if type(sourceID) ~= "number" or sourceID <= 0 or sourceID % 1 ~= 0 then
            return nil, "sourceID must be a positive integer"
        end
        if seenSourceIDs[sourceID] then return nil, "duplicate sourceID: " .. sourceID end
        seenSourceIDs[sourceID] = true
        pieceCount = pieceCount + 1
    end
    if pieceCount == 0 then return nil, "slotSources are empty" end
    return true
end

function ExtraSets.ClassAllowed(classMask, classID)
    if classMask == 0 or not classID then return true end
    local classBit = 2 ^ (classID - 1)
    return math.floor(classMask / classBit) % 2 == 1
end

-- resolver.sourceState(sourceID) returns nil when the source does not exist on
-- this client, or { appearanceID, collected } where collected == nil means the
-- appearance data has not loaded yet.
-- resolver.setName(record) may return a live name for the Blizzard record.
-- resolver.playerClassID() returns the current class ID, or nil outside the client.
function ExtraSets.BuildEntries(records, resolver)
    local entries = {}
    local seenKeys = {}

    for _, record in ipairs(records) do
        local valid, problem = ExtraSets.ValidateRecord(record)
        if not valid then
            LuckysWardrobe.DevLog("Extra Sets record rejected: " .. tostring(problem))
        else
            local key = record.recordType .. ":" .. record.recordID
            if seenKeys[key] then
                LuckysWardrobe.DevLog("Extra Sets record rejected: duplicate " .. key)
            else
                seenKeys[key] = true
                entries[#entries + 1] = ExtraSets.BuildEntry(record, key, resolver)
            end
        end
    end

    return entries
end

function ExtraSets.BuildEntry(record, key, resolver)
    local pieces = {}
    for slot, sourceID in pairs(record.slotSources) do
        pieces[#pieces + 1] = { slot = slot, sourceID = sourceID }
    end
    table.sort(pieces, function(left, right)
        return SLOT_INDEX[left.slot] < SLOT_INDEX[right.slot]
    end)

    local collected, total, unavailable = 0, 0, 0
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
        key = key,
        recordType = record.recordType,
        recordID = record.recordID,
        name = resolver.setName(record) or record.name,
        label = record.label or "",
        expansionID = record.expansionID,
        pieces = pieces,
        collected = collected,
        total = total,
        missing = total - collected,
        unavailable = unavailable,
        loading = loading,
        usable = ExtraSets.ClassAllowed(record.classMask, resolver.playerClassID()),
    }
end

function ExtraSets.IsComplete(entry)
    return not entry.loading and entry.total > 0 and entry.collected == entry.total
end

-- Collected/Not Collected and expansion narrowing, mirroring the Sets tab
-- filter menu. Entries without expansion data (ItemSet records) cannot be
-- classified, so they stay visible while any expansion is still checked
-- rather than vanishing behind a box that does not describe them.
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

-- "default" keeps catalogue order. "completion" puts the fewest missing pieces
-- first; sets with nothing resolvable sort last because there is nothing left
-- to finish there. Descending inverts either order.
function ExtraSets.SortEntries(entries, mode, direction)
    local descending = direction == "descending"
    if mode ~= "completion" then
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
        local leftMissing = left.entry.total > 0 and left.entry.missing or math.huge
        local rightMissing = right.entry.total > 0 and right.entry.missing or math.huge
        if leftMissing ~= rightMissing then
            before = leftMissing < rightMissing
        elseif left.entry.total ~= right.entry.total then
            before = left.entry.total > right.entry.total
        else
            before = left.order < right.order
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
        sourceState = function(sourceID)
            local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
            if not sourceInfo then return nil end

            -- Appearance info counts any source of the same look as collected,
            -- which is what the Sets tab shows, but the client declines to
            -- answer for looks outside the player's wardrobe context such as
            -- another armour type or class. The source carries its own
            -- collected flag in every case, so fall back to that rather than
            -- leaving the piece unresolved.
            local appearance = C_TransmogCollection.GetAppearanceInfoBySource(sourceID)
            local collected
            if appearance then
                collected = appearance.appearanceIsCollected
            else
                collected = sourceInfo.isCollected
            end

            return {
                appearanceID = (appearance and appearance.appearanceID) or sourceInfo.visualID,
                collected = collected and true or false,
            }
        end,
        setName = function(record)
            if record.recordType == "TransmogSet" then
                local setInfo = C_TransmogSets.GetSetInfo(record.recordID)
                return setInfo and setInfo.name
            end
            local name = C_Item.GetItemSetInfo(record.recordID)
            if name and name ~= "" then return name end
            return nil
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
    progressBar:SetPoint("TOPLEFT", 249, 21)

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
    model:SetScript("OnUpdate", model.OnUpdate)
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

    local nameText = detailsFrame:CreateFontString(nil, "OVERLAY", "Fancy24Font")
    nameText:SetPoint("TOP", 0, -37)
    nameText:SetWidth(380)
    nameText:SetTextColor(1, 0.82, 0)

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

    local function pieceTooltip(itemFrame)
        local piece = itemFrame.piece
        GameTooltip:SetOwner(itemFrame, "ANCHOR_RIGHT")

        local sources = piece.state ~= "unavailable" and pieceSources(piece) or nil
        if not sources then
            GameTooltip:SetText(S.pieceUnavailable, 1, 0.25, 0.25, 1, true)
        else
            CollectionWardrobeUtil.SetAppearanceTooltip(GameTooltip, {
                sources = sources,
                primarySourceID = piece.sourceID,
                showUseError = true,
                showTrackingInfo = false,
                slotType = _G[SLOT_TOOLTIP_GLOBALS[piece.slot]],
            })
            if piece.state == "missing" then
                GameTooltip:AddLine(S.trackHint, 0.5, 0.8, 1)
            end
        end
        GameTooltip:Show()
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
        itemFrame.border:SetPoint("CENTER", itemFrame.icon, "CENTER", 4, 1)
        itemFrame:SetScript("OnEnter", pieceTooltip)
        itemFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        itemFrame:SetScript("OnClick", function(self)
            if IsShiftKeyDown() and self.piece.state == "missing" then
                LuckysWardrobe.SetTracking:TrackSources({ self.piece.sourceID }, selectedEntry and selectedEntry.name)
            end
        end)
        itemFrames[index] = itemFrame
        return itemFrame
    end

    local function displayEntry(entry)
        selectedEntry = entry
        local shown = entry ~= nil
        model:SetShown(shown)
        detailsFrame:SetShown(shown)
        detailsText:SetShown(not shown)
        if not shown then return end

        nameText:SetText(entry.name)
        labelText:SetText(entry.label)
        countsText:SetFormattedText(S.counts, entry.collected, entry.total)
        if entry.unavailable > 0 then
            noticeText:SetFormattedText(S.unavailableNotice, entry.unavailable)
        elseif not entry.usable then
            noticeText:SetText(S.notUsable)
        end
        noticeText:SetShown(entry.unavailable > 0 or not entry.usable)
        model:Undress()

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
            itemFrame.icon:SetAlpha(collected and 1 or 0.35)
            itemFrame.border:SetAtlas(collected and "loottab-set-itemborder-green" or "loottab-set-itemborder-white", true)
            itemFrame.border:SetDesaturated(not collected)
            itemFrame:ClearAllPoints()
            itemFrame:SetPoint("TOP", detailsFrame, "TOP", xOffset + (index - 1) * spacing, -98)
            itemFrame:Show()

            if piece.state ~= "unavailable" and C_TransmogCollection.GetSourceInfo(piece.sourceID) then
                model:TryOn(piece.sourceID)
            end
        end

        refreshCamera()
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
        local allEntries = ExtraSets.BuildEntries(ExtraSets.Records(), ExtraSets.LiveResolver())
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

        scrollBox:SetDataProvider(CreateDataProvider(entries), ScrollBoxConstants.RetainScrollPosition)
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
        for _, option in ipairs({ { key = "default", label = DEFAULT }, { key = "completion", label = "Completion" } }) do
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
            local expansionIndex = index
            expansions:CreateCheckbox(name, function() return filters.expansions[expansionIndex] end, function()
                filters.expansions[expansionIndex] = not filters.expansions[expansionIndex]
                refresh()
            end)
        end
    end)

    searchBox:HookScript("OnTextChanged", refresh)
    page:SetScript("OnShow", function(self)
        self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        self:RegisterEvent("ITEM_DATA_LOAD_RESULT")
        self:RegisterEvent("TRANSMOG_COLLECTION_ITEM_UPDATE")
        self:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
        refresh()
    end)
    page:SetScript("OnHide", function(self)
        self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        self:UnregisterEvent("ITEM_DATA_LOAD_RESULT")
        self:UnregisterEvent("TRANSMOG_COLLECTION_ITEM_UPDATE")
        self:UnregisterEvent("TRANSMOG_COLLECTION_UPDATED")
        GameTooltip:Hide()
    end)
    page:SetScript("OnEvent", refresh)
    page.Refresh = refresh
    page.RefreshCameras = refreshCamera
    page.OnSearchUpdate = function() end
    page.OnUnitModelChangedEvent = function()
        if not IsUnitModelReadyForUI("player") then return false end

        model:RefreshUnit()
        model.cameraID = nil
        model:UpdatePanAndZoomModelType()
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

local function updateSelectedTab(wardrobe, selectedTabID)
    local selected = selectedTabID == extraTabID
    extraPage:SetShown(selected)

    if selected then
        wardrobe.ItemsCollectionFrame:Hide()
        wardrobe.SetsCollectionFrame:Hide()
        wardrobe.SearchBox:Hide()
        wardrobe.FilterButton:Hide()
        wardrobe.ClassDropdown:Hide()
        wardrobe.progressBar:Hide()
        wardrobe.activeFrame = extraPage
    elseif selectedTabID == NATIVE_ITEMS_TAB_ID or selectedTabID == NATIVE_SETS_TAB_ID then
        wardrobe.SearchBox:Show()
        wardrobe.FilterButton:Show()
        wardrobe.ClassDropdown:Show()
    end
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

    -- Discovery may still be running when the page first shows; repaint the
    -- moment the catalogue lands.
    LuckysWardrobe.ExtraSetsCatalog:OnReady(function()
        if extraPage:IsShown() then extraPage.Refresh() end
    end)

    PanelTemplates_SetNumTabs(wardrobe, extraTabID)
    PanelTemplates_ResizeTabsToFit(wardrobe, TAB_FIT_WIDTH)
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
