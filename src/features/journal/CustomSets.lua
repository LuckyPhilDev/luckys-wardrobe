-- luacheck: globals AutoScalingFontStringMixin C_Transmog C_TransmogCollection C_TransmogSets Constants CreateDataProvider CreateScrollBoxListLinearView EventUtil GetUICameraInfo INVSLOT_BACK INVSLOT_BODY INVSLOT_CHEST INVSLOT_FEET INVSLOT_HAND INVSLOT_HEAD INVSLOT_LEGS INVSLOT_MAINHAND INVSLOT_OFFHAND INVSLOT_SHOULDER INVSLOT_TABARD INVSLOT_WAIST INVSLOT_WRIST IsUnitModelReadyForUI Mixin Model_ApplyUICamera QUESTION_MARK_ICON ScrollBoxConstants ScrollUtil WardrobeCollectionFrame WardrobeSetsDetailsModelMixin hooksecurefunc

-- Lucky's Wardrobe: Custom Sets, a fourth Appearances subtab listing the outfits
-- you have saved at the transmogrifier. The transmogrifier shows them as a wall
-- of little models and only while you are standing at one; here they read the
-- way a collected set does, as a list you can search with the outfit on your
-- character beside it and every look it is made of underneath.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.CustomSets = {}

local CustomSets = LuckysWardrobe.CustomSets

-- The smallest the Sets tab lets a set name shrink to before it gives up and
-- wraps it instead.
local NAME_MIN_LINE_HEIGHT = 16

-- The slots a saved outfit can carry a look in, in the order the transmogrifier
-- lists them, each with the global Blizzard localises its name into for the
-- tooltip's slot line. Weapons are in here where the armour sets the rest of the
-- addon deals in have none: an outfit is a whole character, weapons and all.
local SLOTS = {
    { id = INVSLOT_HEAD, name = "HEADSLOT" },
    { id = INVSLOT_SHOULDER, name = "SHOULDERSLOT" },
    { id = INVSLOT_BACK, name = "BACKSLOT" },
    { id = INVSLOT_CHEST, name = "CHESTSLOT" },
    { id = INVSLOT_BODY, name = "SHIRTSLOT" },
    { id = INVSLOT_TABARD, name = "TABARDSLOT" },
    { id = INVSLOT_WRIST, name = "WRISTSLOT" },
    { id = INVSLOT_HAND, name = "HANDSSLOT" },
    { id = INVSLOT_WAIST, name = "WAISTSLOT" },
    { id = INVSLOT_LEGS, name = "LEGSSLOT" },
    { id = INVSLOT_FEET, name = "FEETSLOT" },
    { id = INVSLOT_MAINHAND, name = "MAINHANDSLOT" },
    { id = INVSLOT_OFFHAND, name = "SECONDARYHANDSLOT" },
}

-- What the client puts in a slot an outfit says nothing about.
local NO_TRANSMOG = Constants.Transmog.NoTransmogID

local attachedWardrobe
local customPage

-- Pure catalogue logic. Everything below takes an injected resolver so the
-- rules stay testable outside the client.

--- What one saved outfit is made of: its looks in slot order, each with whether
--- it is one you own. A slot the outfit leaves alone is not a piece, and neither
--- is a deliberately hidden look like a hidden helm: neither is an appearance
--- there is anything to collect. A look the client has no answer for yet is left
--- out rather than guessed at, which is how the transmogrifier counts its own
--- custom set cards.
function CustomSets.BuildEntry(customSetID, resolver)
    local name, icon = resolver.setInfo(customSetID)
    local looks = resolver.setPieces(customSetID) or {}
    local pieces, collected = {}, 0

    local function addPiece(sourceID, slot, isSecondary)
        if not sourceID or sourceID == NO_TRANSMOG or resolver.isHiddenVisual(sourceID) then return end

        local isCollected = resolver.isCollected(sourceID)
        if isCollected == nil then return end

        pieces[#pieces + 1] = {
            slot = slot.name,
            sourceID = sourceID,
            state = isCollected and "collected" or "missing",
            isSecondary = isSecondary,
        }
        if isCollected then collected = collected + 1 end
    end

    for _, slot in ipairs(SLOTS) do
        local look = looks[slot.id]
        if look then
            addPiece(look.appearanceID, slot, false)
            -- The second look a slot can carry, which only a few slots take at
            -- all. A slot carrying the same look twice is wearing one look.
            if look.secondaryAppearanceID ~= look.appearanceID and resolver.canHaveSecondary(slot.id) then
                addPiece(look.secondaryAppearanceID, slot, true)
            end
        end
    end

    return {
        key = customSetID,
        name = name or "",
        icon = icon,
        pieces = pieces,
        -- What the client says the outfit wears, slot by slot, kept as it came
        -- so the model can be dressed in the whole of it. The pieces above are
        -- what there is to collect, which is not quite the same thing: a hidden
        -- slot is part of the look and nothing to collect, and a slot wearing
        -- two looks at once is one slot and two things to collect.
        looks = looks,
        collected = collected,
        total = #pieces,
    }
end

--- An outfit every look of which you own. One saved from nothing but hidden
--- slots has no look to own, so it is never complete.
function CustomSets.IsComplete(entry)
    return entry.total > 0 and entry.collected == entry.total
end

--- Every outfit you have saved, in the order the transmogrifier's own Custom
--- Sets tab puts them: the ones you own every look of first, then by name.
function CustomSets.BuildEntries(customSetIDs, resolver)
    local entries = {}
    for _, customSetID in ipairs(customSetIDs) do
        entries[#entries + 1] = CustomSets.BuildEntry(customSetID, resolver)
    end

    table.sort(entries, function(left, right)
        local leftComplete, rightComplete = CustomSets.IsComplete(left), CustomSets.IsComplete(right)
        if leftComplete ~= rightComplete then return leftComplete end
        if left.name ~= right.name then return left.name < right.name end
        return left.key < right.key
    end)
    return entries
end

--- Every look an outfit needs that you do not own: what a shift-click goes after
--- and what the row's own crosshair answers for.
function CustomSets.MissingSources(entry)
    local missing = {}
    for _, piece in ipairs(entry.pieces) do
        if piece.state == "missing" then missing[#missing + 1] = piece.sourceID end
    end
    return missing
end

-- Live glue from here down: everything below talks to the client.

function CustomSets.LiveResolver()
    return {
        setInfo = function(customSetID) return C_TransmogCollection.GetCustomSetInfo(customSetID) end,
        setPieces = function(customSetID)
            return C_TransmogCollection.GetCustomSetItemTransmogInfoList(customSetID)
        end,
        -- Nothing rather than false where the client has yet to answer, so a
        -- look it knows nothing about is left off the count instead of counted
        -- as one still to find.
        isCollected = function(sourceID)
            local info = C_TransmogCollection.GetAppearanceInfoBySource(sourceID)
            return info and info.appearanceIsCollected
        end,
        isHiddenVisual = function(sourceID) return C_TransmogCollection.IsAppearanceHiddenVisual(sourceID) end,
        canHaveSecondary = function(slotID) return C_Transmog.CanHaveSecondaryAppearanceForSlotID(slotID) end,
    }
end

-- A handful of outfits at most, so they are worked out afresh whenever the
-- collection or the outfits themselves change rather than kept in step piece by
-- piece.
local cachedEntries

function CustomSets.InvalidateEntries()
    cachedEntries = nil
end

function CustomSets.Entries()
    if not cachedEntries then
        cachedEntries = CustomSets.BuildEntries(
            C_TransmogCollection.GetCustomSets() or {}, CustomSets.LiveResolver())
    end
    return cachedEntries
end

-- Page UI. The Extra Sets layout, less everything a saved outfit has no answer
-- for: no expansion, no source, no colourways, and no class, since the outfits
-- you have saved are the same ones whichever class you are browsing.

function CustomSets:CreatePage(wardrobe)
    local S = LuckysWardrobe.Strings.customSets
    local page = CreateFrame("Frame", "LuckysWardrobeCustomSetsFrame", wardrobe)
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

    -- Being shown rebuilds the player's figure from scratch, and anything put
    -- on a figure still on its way is dropped, so a dress that lands while
    -- this is up has to be asked for again once the figure arrives.
    local modelLoading

    local model = CreateFrame("DressUpModel", nil, page)
    Mixin(model, WardrobeSetsDetailsModelMixin)
    model:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 3, -3)
    model:SetPoint("BOTTOMRIGHT", rightInset, "BOTTOMRIGHT", -4, 3)
    model:SetScript("OnShow", function(self)
        modelLoading = true
        self.OnShow(self)
    end)
    model:SetScript("OnUpdate", model.OnUpdate)
    model:SetScript("OnMouseDown", model.OnMouseDown)
    model:SetScript("OnMouseUp", model.OnMouseUp)
    model:SetScript("OnMouseWheel", model.OnMouseWheel)
    -- OnModelLoaded is attached below displayEntry, which it needs in reach.
    model:OnLoad()
    model:Hide()

    local detailsFrame = CreateFrame("Frame", nil, page)
    detailsFrame:SetPoint("TOPLEFT", rightInset, "TOPLEFT", 0, -3)
    detailsFrame:SetPoint("BOTTOMRIGHT", rightInset, "BOTTOMRIGHT", -3, 2)
    -- Relative to the model, not a fixed level: the model fills the same area
    -- and takes the mouse, so anything below it stops receiving hover.
    detailsFrame:SetFrameLevel(model:GetFrameLevel() + 10)
    detailsFrame:Hide()

    -- The Sets tab shrinks a long name to keep it on one line, and only wraps
    -- it, smaller again, when even the smallest size will not fit. An outfit is
    -- named by whoever saved it, so this page meets longer names than the game's
    -- own sets ever have.
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

    local countsText = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countsText:SetWidth(380)

    local modelFade = detailsFrame:CreateTexture(nil, "BACKGROUND")
    modelFade:SetAtlas("transmog-set-model-cutoff-fade")
    modelFade:SetHeight(178)
    modelFade:SetPoint("TOPLEFT", 2, 0)
    modelFade:SetPoint("TOPRIGHT")

    -- Which slots this preview dresses, in the corner every set pane keeps the
    -- same control in. This pane has no variant dropdown to share it with.
    local previewSlotsButton = LuckysWardrobe.PreviewSlots:CreateButton(detailsFrame)
    previewSlotsButton:SetPoint("TOPRIGHT", detailsFrame, "TOPRIGHT", -10, -8)

    local detailsText = rightInset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    detailsText:SetPoint("CENTER")
    detailsText:SetWidth(340)
    detailsText:SetText(S.select)

    local itemFrames = {}
    local rowBackgrounds = {}
    local selectedEntry

    -- One strip of Blizzard's icon-row art per row of pieces, built as the rows
    -- are needed. An outfit fills a slot at most once, so it never runs past the
    -- second strip.
    local function getRowBackground(index)
        if rowBackgrounds[index] then return rowBackgrounds[index] end

        local background = detailsFrame:CreateTexture(nil, "BORDER")
        background:SetAtlas("transmog-set-iconrow-background", true)
        background:SetPoint("TOP", 0, -82 - (index - 1) * 37)
        rowBackgrounds[index] = background
        return background
    end

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

    local pieceTooltip, hidePieceTooltip = LuckysWardrobe.ExtraSets.PieceTooltips(page)
    local pieceClick =
        LuckysWardrobe.ExtraSets.PieceClicks(function() return selectedEntry and selectedEntry.name end)

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
        -- Blizzard hangs it by its right edge rather than its middle.
        itemFrame.border:SetPoint("RIGHT", itemFrame.icon, "CENTER", 20, 1)
        itemFrame:SetScript("OnEnter", pieceTooltip)
        itemFrame:SetScript("OnLeave", hidePieceTooltip)
        itemFrame:SetScript("OnClick", pieceClick)
        itemFrames[index] = itemFrame
        return itemFrame
    end

    -- A name that fits once shrunk stays on its one line; one that still will
    -- not fit wraps onto two smaller ones. Answers the line the counts hang
    -- from, since the two sit at different heights.
    local function showSetName(name)
        nameText:SetText(name)
        local wrap = nameText:IsTruncated()
        nameText:SetShown(not wrap)
        longNameText:SetShown(wrap)
        if wrap then longNameText:SetText(name) end
        return wrap and longNameText or nameText
    end

    -- Dressing the model is the most expensive thing this page does, and an
    -- outfit's looks only change when it is saved over. Only a different outfit,
    -- or a model that has been rebuilt underneath us, is worth redressing for.
    local dressedKey

    local function displayEntry(entry)
        selectedEntry = entry
        local shown = entry ~= nil
        model:SetShown(shown)
        detailsFrame:SetShown(shown)
        detailsText:SetShown(not shown)
        if not shown then
            dressedKey = nil
            return
        end

        local redress = dressedKey ~= entry.key
        dressedKey = entry.key

        countsText:ClearAllPoints()
        countsText:SetPoint("TOP", showSetName(entry.name), "BOTTOM", 0, -2)
        countsText:SetFormattedText(S.counts, entry.collected, entry.total)

        -- Dressed from what the outfit itself says rather than from the pieces
        -- below it, so the model shows the look the way the transmogrifier does:
        -- a slot deliberately left bare stays bare, and a slot wearing two looks
        -- at once wears both. Slots the previews are told not to dress stay
        -- bare too; weapons have no checkbox and always go on.
        if redress then
            model:Undress()
            for _, slot in ipairs(SLOTS) do
                local look = entry.looks[slot.id]
                if look and LuckysWardrobe.PreviewSlots:IsInvSlotShown(slot.id) then
                    model:SetItemTransmogInfo(look, slot.id)
                end
            end
        end

        for _, itemFrame in ipairs(itemFrames) do itemFrame:Hide() end
        for _, background in ipairs(rowBackgrounds) do background:Hide() end
        local places = LuckysWardrobe.ExtraSets.PieceLayout(#entry.pieces)
        local strips = #places > 0 and places[#places].row or 0
        for strip = 1, strips do getRowBackground(strip):Show() end
        for index, place in ipairs(places) do
            local piece = entry.pieces[index]
            local itemFrame = getItemFrame(index)
            local collected = piece.state == "collected"
            itemFrame.piece = piece
            itemFrame.icon:SetTexture(C_TransmogCollection.GetSourceIcon(piece.sourceID) or QUESTION_MARK_ICON)
            itemFrame.icon:SetDesaturated(not collected)
            itemFrame.icon:SetAlpha(collected and 1 or 0.3)
            itemFrame.border:SetAtlas(collected and "loottab-set-itemborder-green" or "loottab-set-itemborder-white", true)
            itemFrame.border:SetDesaturated(not collected)
            -- The Sets tab fades the frame with the icon it holds, or an
            -- uncollected piece reads as a bright frame around nothing.
            itemFrame.border:SetAlpha(collected and 1 or 0.3)
            itemFrame:ClearAllPoints()
            itemFrame:SetPoint("TOP", detailsFrame, "TOP", place.x, place.y)
            itemFrame:Show()
            LuckysWardrobe.TrackedAppearances:Mark(itemFrame, piece.sourceID)
        end

        if redress then refreshCamera() end
    end

    -- The first dress after a show goes onto a figure that is still loading,
    -- and is dropped with it, so the outfit on screen is dressed again once
    -- the figure lands. A frame later rather than here: pieces put on while
    -- the load is still settling are wiped with it, the same reason the
    -- tooltip preview waits a frame before dressing. The loads that come of
    -- dressing are left alone, or every piece going on would strip and
    -- redress in a loop.
    model:SetScript("OnModelLoaded", function(self)
        self.OnModelLoaded(self)
        if not modelLoading then return end
        modelLoading = false
        C_Timer.After(0, function()
            dressedKey = nil
            displayEntry(selectedEntry)
        end)
    end)

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
        local complete = CustomSets.IsComplete(entry)
        button.Name:SetText(entry.name)
        button.Label:SetText(S.counts:format(entry.collected, entry.total))
        if complete then
            button.Name:SetTextColor(1, 0.82, 0)
        elseif entry.collected == 0 then
            button.Name:SetTextColor(0.5, 0.5, 0.5)
        else
            button.Name:SetTextColor(0.251, 0.753, 0.251)
        end

        -- The icon the outfit was saved under, which is the one its own dropdown
        -- at the transmogrifier shows it by.
        button.IconFrame.Icon:SetTexture(entry.icon or QUESTION_MARK_ICON)
        button.IconFrame.Icon:SetDesaturated(entry.collected == 0)
        button.IconFrame.Cover:SetShown(not complete)
        button.IconFrame.Favorite:Hide()
        button.New:Hide()
        LuckysWardrobe.TrackedAppearances:MarkSet(button, CustomSets.MissingSources(entry))
        button.SelectedTexture:SetShown(selectedEntry and entry.key == selectedEntry.key)

        local showProgress = entry.collected > 0 and not complete
        button.ProgressBar:SetShown(showProgress)
        if showProgress then button.ProgressBar:SetWidth(204 * entry.collected / entry.total) end

        button:SetScript("OnClick", function(_, buttonName)
            if buttonName ~= "LeftButton" then return end
            if LuckysWardrobe.SetTracking:HandlesShiftClick(buttonName) then
                LuckysWardrobe.SetTracking:ToggleSources(CustomSets.MissingSources(entry), entry.name)
                return
            end
            selectEntry(entry)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end)
        button.IconFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(entry.name)
            GameTooltip:AddLine(S.counts:format(entry.collected, entry.total), 1, 1, 1)
            GameTooltip:Show()
        end)
        button.IconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end)
    view:SetPadding(0, 0, 44, 0, 0)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

    local function refresh()
        local allEntries = CustomSets.Entries()
        local entries = LuckysWardrobe.ExtraSets.FilterEntries(allEntries, searchBox:GetText())

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
        emptyText:SetText(#allEntries == 0 and S.empty or S.noResults)
        emptyText:SetShown(#entries == 0)
        displayEntry(selectedEntry)
    end

    -- Saving, renaming or deleting an outfit changes the list; collecting an
    -- appearance changes what the outfits on it are worth.
    local function rebuildNow()
        CustomSets.InvalidateEntries()
        refresh()
    end

    local queueRebuild = LuckysWardrobe.Utils.Debounced(LuckysWardrobe.Utils.REBUILD_DELAY_SECONDS, function()
        -- A page that has since closed rebuilds when it opens again.
        if page:IsShown() then rebuildNow() end
    end)

    -- A changed slot choice outdates whatever the model is wearing, wherever
    -- it was changed from, so the memory of what it wears goes even while the
    -- page is off screen and the outfit on screen is dressed again on the spot.
    LuckysWardrobe.PreviewSlots:OnChanged(function()
        dressedKey = nil
        if page:IsShown() then displayEntry(selectedEntry) end
    end)

    searchBox:HookScript("OnTextChanged", refresh)
    page:SetScript("OnShow", function(self)
        self:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
        self:RegisterEvent("TRANSMOG_CUSTOM_SETS_CHANGED")
        rebuildNow()
    end)
    page:SetScript("OnHide", function(self)
        self:UnregisterEvent("TRANSMOG_COLLECTION_UPDATED")
        self:UnregisterEvent("TRANSMOG_CUSTOM_SETS_CHANGED")
        -- A page that leaves the screen mid-hover would otherwise keep the
        -- tooltip, and Tab would still be cycling it from another tab.
        hidePieceTooltip()
    end)
    page:SetScript("OnEvent", queueRebuild)
    page.RefreshCameras = refreshCamera
    page.OnSearchUpdate = function() end
    -- Blizzard retries this every frame until it answers true, so it has to say
    -- no while the model is not ready rather than redressing on every frame.
    page.OnUnitModelChangedEvent = function()
        if not IsUnitModelReadyForUI("player") then return false end

        model:RefreshUnit()
        model.cameraID = nil
        model:UpdatePanAndZoomModelType()
        -- A fresh model wears nothing, whatever it was showing before.
        dressedKey = nil
        displayEntry(selectedEntry)
        return true
    end
    page:Hide()
    return page
end

function CustomSets:Attach(wardrobe)
    if attachedWardrobe or not wardrobe or not wardrobe.numTabs then return end

    attachedWardrobe = wardrobe
    customPage = self:CreatePage(wardrobe)
    -- Attached the way the Extra Sets tab is, outside Blizzard's tab state;
    -- the why lives with the registry in ExtraSets.
    LuckysWardrobe.ExtraSets.AddWardrobeTab(wardrobe, "LuckysWardrobeCustomSetsTab",
        LuckysWardrobe.Strings.customSets.tab, customPage, function()
            -- The outfits you have saved are the same ones whichever class the
            -- Sets tab is showing, so the class dropdown has nothing to say
            -- about this page.
            wardrobe.ClassDropdown:Hide()
        end, 2)
end

function CustomSets:Init()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", function()
        CustomSets:Attach(WardrobeCollectionFrame)
    end)
end
