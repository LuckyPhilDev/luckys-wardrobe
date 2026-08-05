-- luacheck: globals C_Item C_PlayerInfo C_Timer C_TransmogCollection C_TransmogOutfitInfo COLLECTED ColorManager Constants CreateDataProvider CreateFrame Enum EventUtil GameTooltip GameTooltip_AddColoredLine GameTooltip_AddDisabledLine GameTooltip_AddHighlightLine GetTime GREEN_FONT_COLOR IsShiftKeyDown IsUnitModelReadyForUI LIGHTYELLOW_FONT_COLOR MenuUtil NORMAL_FONT_COLOR NOT_COLLECTED PlaySound Pool_HideAndClearAnchors RED_FONT_COLOR RETRIEVING_ITEM_INFO Round SOUNDKIT TextureKitConstants TransmogFrame UIErrorsFrame WrapTextInColor hooksecurefunc

-- Lucky's Wardrobe: the Extra Sets tab at the transmogrifier, beside Blizzard's
-- own Sets tab and built from the same card grid, so the two read as one UI.
-- Cards come from the session catalogue the Collections page already uses,
-- narrowed to the class being played: the transmogrifier dresses one character,
-- so there is no class to choose. Clicking a card applies every piece of the
-- set the player has collected, through the same pending-transmog calls the
-- native tabs make.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.TransmogExtraSets = {}

local TransmogExtraSets = LuckysWardrobe.TransmogExtraSets

-- How long a burst of collection events is allowed to gather before the page
-- reads the catalogue again, matching the Collections page.
local REBUILD_DELAY_SECONDS = 0.25

-- How long the page waits for the items behind its sets to arrive before it
-- judges them again, and how many times it is willing to wait. Some items never
-- arrive, so the waiting ends rather than running until it succeeds.
local ITEM_LOAD_DELAY_SECONDS = 0.5
local ITEM_LOAD_PASSES = 3
-- How many items one pass will ask for. This page lists hundreds of sets, and
-- asking about every one of them at once is a burst the client answers no
-- faster for.
local ITEM_LOAD_BUDGET = 200

-- The grid spacing Blizzard gives the native Sets tab's card grid.
local CARD_GRID_X_PADDING = 27
local CARD_GRID_Y_PADDING = 19

-- The record slots, head to feet, in the order the viewed outfit is read.
local SLOT_KEYS = {
    "HEAD", "SHOULDER", "BACK", "CHEST", "BODY", "TABARD",
    "WRIST", "HANDS", "WAIST", "LEGS", "FEET",
}

-- Session-only state behind the filter button, mirroring the native Sets tab
-- menu: fully collected sets and everything short of that.
local filters = {
    collected = true,
    uncollected = true,
}

local attachedWardrobe
local extraTabID

-- Pure catalogue logic. Everything below takes plain tables plus injected
-- resolvers so the rules stay testable outside the client.

-- The filter button's two checkboxes, with the Sets tab's meaning: "collected"
-- is a set with every look owned, and everything short of that, half done or
-- untouched, sits behind "not collected".
function TransmogExtraSets.FilterByCollected(entries, showCollected, showUncollected)
    local result = {}
    for _, entry in ipairs(entries) do
        if LuckysWardrobe.ExtraSets.IsComplete(entry) then
            if showCollected then result[#result + 1] = entry end
        elseif showUncollected then
            result[#result + 1] = entry
        end
    end
    return result
end

-- Where this tab belongs in the strip: directly after the Sets tab, as a number
-- midway between Sets and whichever tab currently follows it. Everything else
-- keeps the place it holds, because the strip is shared. Another addon's tab
-- may be in here, and where it put itself is its business.
--
-- The answer is a midpoint rather than a fixed number because tab numbering is
-- not stable. An addon inserting a tab renumbers the ones behind it, so a
-- position worked out once at load goes stale the moment that happens: W2
-- Transmog Studio renumbers Items, Studio, Sets, Custom Sets, Situations to 1
-- through 5, which turned the 2.5 this tab was given, back when Sets was 2,
-- into a seat in front of the tab it was aimed at.
--
-- Taking the nearest index above Sets keeps the midpoint clear of every other
-- tab, so no two tabs can end up asking for the same seat, and asking twice
-- against an unchanged strip gives the same answer both times.
function TransmogExtraSets.LayoutIndexAfter(setsIndex, otherIndexes)
    local nextIndex
    for _, index in ipairs(otherIndexes) do
        if index > setsIndex and (not nextIndex or index < nextIndex) then nextIndex = index end
    end
    if not nextIndex then return setsIndex + 1 end
    return (setsIndex + nextIndex) / 2
end

-- The sets this character can actually put on. A set the client refuses, over
-- a faction lock most often, can never be applied at the transmogrifier, so it
-- is not offered here: Blizzard's own Sets tab lists only the sets the player
-- can use, for the same reason. The Collections page still lists them, because
-- browsing a set is not wearing it.
--
-- A set the client has said nothing about stays. Its verdict comes from item
-- data the client loads only once asked, and a cold cache is not a refusal:
-- hiding on one would empty the page every time it opened.
function TransmogExtraSets.WearableEntries(entries, classID, sourceValidity)
    local wearable = {}
    for _, entry in ipairs(entries) do
        if not LuckysWardrobe.ExtraSets.UnwearableReason(entry, classID, sourceValidity) then
            wearable[#wearable + 1] = entry
        end
    end
    return wearable
end

-- The cards in the order the page shows them: nearest to finished first, so
-- everything wearable sits on the early pages and the untouched tail keeps to
-- the back of the book.
function TransmogExtraSets.VisibleEntries(entries, filterState, query)
    local ExtraSets = LuckysWardrobe.ExtraSets
    local narrowed = TransmogExtraSets.FilterByCollected(
        entries, filterState.collected, filterState.uncollected)
    return ExtraSets.SortEntries(ExtraSets.FilterEntries(narrowed, query), "completion", "ascending")
end

-- Whether the outfit on show is wearing this set: every slot the set covers is
-- showing one of the set's own looks for that slot. Slots the set says nothing
-- about are not asked, which is how the native Sets tab judges its own cards,
-- and a set with no resolvable look at all can never be what an outfit wears.
--
-- viewed maps record slots to { appearanceID, hasPending } for what the outfit
-- carries there, and a set counts as pending while any matched slot is.
function TransmogExtraSets.MatchesViewedOutfit(entry, viewed)
    local looksBySlot = {}
    for _, piece in ipairs(entry.pieces) do
        if piece.appearanceID then
            looksBySlot[piece.slot] = looksBySlot[piece.slot] or {}
            looksBySlot[piece.slot][piece.appearanceID] = true
        end
    end

    local judged = false
    local hasPending = false
    for slot, looks in pairs(looksBySlot) do
        local worn = viewed[slot]
        if not worn or not looks[worn.appearanceID] then return false end
        judged = true
        hasPending = hasPending or worn.hasPending
    end
    if not judged then return false end
    return true, hasPending
end

-- The first listed set the outfit on show is wearing, which is the card the
-- page lights up the way the Sets tab marks the set a player has applied.
-- Wearing a look means owning it, so a set with nothing collected is not asked.
function TransmogExtraSets.AppliedEntry(entries, viewed)
    for _, entry in ipairs(entries) do
        if entry.collected > 0 then
            local matched, hasPending = TransmogExtraSets.MatchesViewedOutfit(entry, viewed)
            if matched then return entry, hasPending end
        end
    end
    return nil
end

-- The pending changes one click makes. A slot is decided by its first piece,
-- the one the card's model wears, and resolveSource answers with the source of
-- that look the outfit should carry, or nothing when the look is uncollected.
-- A slot with nothing to apply is left out rather than emptied: applying a set
-- you half own dresses what you have and keeps the outfit's answer elsewhere.
function TransmogExtraSets.ApplyList(entry, resolveSource)
    local taken, applications = {}, {}
    for _, piece in ipairs(entry.pieces) do
        if piece.state ~= "unavailable" and not taken[piece.slot] then
            taken[piece.slot] = true
            local sourceID = resolveSource(piece.sourceID)
            if sourceID then
                applications[#applications + 1] = { slot = piece.slot, sourceID = sourceID }
            end
        end
    end
    return applications
end

-- Live glue from here down: everything below talks to the client.

-- Entries for the character being played, built once and kept until the
-- collection changes. The page has no class dropdown: whoever is standing at
-- the transmogrifier is the class every answer is about.
--
-- The rows and the verdict on them are kept apart because they go stale for
-- different reasons: the rows change when the collection does, while the
-- verdict changes as the item data behind a set arrives, which happens far more
-- often and costs nothing like as much to work out again.
local cachedRows
local cachedEntries

function TransmogExtraSets.InvalidateEntries()
    cachedRows = nil
    cachedEntries = nil
end

-- Judges the rows again without building them again, which is what item data
-- landing calls for: the sets have not changed, only what the client will say
-- about them.
function TransmogExtraSets.RejudgeEntries()
    cachedEntries = nil
end

function TransmogExtraSets.Entries()
    if not cachedEntries then
        LuckysWardrobe.Perf:Begin("transmog entries built")
        local ExtraSets = LuckysWardrobe.ExtraSets
        local resolver = ExtraSets.LiveResolver()
        if not cachedRows then
            -- The Sets tab sits beside this one here as it does in Collections,
            -- so a look it already shows folds away on both pages or the two
            -- disagree about which sets exist.
            local classID = resolver.playerClassID()
            cachedRows = ExtraSets.CollapseDuplicates(
                ExtraSets.BuildEntries(ExtraSets.RecordsForClass(ExtraSets.Records(), classID), resolver),
                ExtraSets.NativeLooks(classID)
            )
        end
        cachedEntries = TransmogExtraSets.WearableEntries(
            cachedRows, resolver.playerClassID(), resolver.sourceValidity)
        LuckysWardrobe.Perf:End("transmog entries built")
    end
    return cachedEntries
end

-- Items already asked for this session, so a pass moves on to the sets nothing
-- has been asked about rather than asking again for answers still in flight.
local requestedItems = {}

-- Asks the client for the item behind one piece of every set it has not judged
-- yet, which is what makes it judge them. One piece is enough to place a set:
-- a lock that keeps a character out of one covers every piece of it, so its
-- first piece answers for the rest. Says whether anything was asked for, which
-- is the only reason to look again.
local function requestUnjudgedItems(entries)
    local asked = 0
    for _, entry in ipairs(entries) do
        if asked >= ITEM_LOAD_BUDGET then break end
        for _, piece in ipairs(entry.pieces) do
            if piece.state ~= "unavailable" and piece.itemID then
                if not requestedItems[piece.itemID] and not C_Item.GetItemInfo(piece.itemID) then
                    requestedItems[piece.itemID] = true
                    C_Item.RequestLoadItemDataByID(piece.itemID)
                    asked = asked + 1
                end
                break
            end
        end
    end
    return asked > 0
end

-- Locale-free record slots to the outfit slots the transmogrifier's API
-- speaks. Shoulders assign the right side, the primary: the left follows it
-- unless the player has split them, which is what the Items tab does too.
local outfitSlots
local function outfitSlotFor(slotKey)
    if not outfitSlots then
        local slots = Enum.TransmogOutfitSlot
        outfitSlots = {
            HEAD = slots.Head,
            SHOULDER = slots.ShoulderRight,
            BACK = slots.Back,
            CHEST = slots.Chest,
            BODY = slots.Body,
            TABARD = slots.Tabard,
            WRIST = slots.Wrist,
            HANDS = slots.Hand,
            WAIST = slots.Waist,
            LEGS = slots.Legs,
            FEET = slots.Feet,
        }
    end
    return outfitSlots[slotKey]
end

-- What the outfit on show wears in each armour slot, as looks rather than
-- sources: a slot is wearing a set's piece whichever item taught the look.
local function viewedOutfitBySlot()
    local appearanceType = Enum.TransmogType.Appearance
    local noOption = Enum.TransmogOutfitSlotOption.None
    local viewed = {}
    for _, slotKey in ipairs(SLOT_KEYS) do
        local slotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(
            outfitSlotFor(slotKey), appearanceType, noOption)
        local transmogID = slotInfo and slotInfo.transmogID
        if transmogID and transmogID ~= Constants.Transmog.NoTransmogID then
            local sourceInfo = C_TransmogCollection.GetSourceInfo(transmogID)
            if sourceInfo and sourceInfo.visualID then
                viewed[slotKey] = {
                    appearanceID = sourceInfo.visualID,
                    hasPending = slotInfo.hasPending and true or false,
                }
            end
        end
    end
    return viewed
end

-- The source the outfit should carry for this piece's look: one the player has
-- collected, preferring one the client will let this character wear. The
-- record's own source may be the uncollected copy while the same look arrived
-- from another item, so every source of the look is considered.
local function applicableSource(sourceID)
    local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
    if not sourceInfo then return nil end

    local fallback
    for _, candidateID in ipairs(C_TransmogCollection.GetAllAppearanceSources(sourceInfo.visualID) or {}) do
        local candidate = C_TransmogCollection.GetSourceInfo(candidateID)
        if candidate and candidate.isCollected then
            if candidate.isValidSourceForPlayer then return candidateID end
            fallback = fallback or candidateID
        end
    end
    return fallback
end

local function applyEntry(entry)
    local applications = TransmogExtraSets.ApplyList(entry, applicableSource)
    if #applications == 0 then
        UIErrorsFrame:AddMessage(LuckysWardrobe.Strings.extraSets.nothingToApply, RED_FONT_COLOR:GetRGB())
        return
    end

    local appearanceType = Enum.TransmogType.Appearance
    local noOption = Enum.TransmogOutfitSlotOption.None
    local applied = 0
    for _, application in ipairs(applications) do
        local slot = outfitSlotFor(application.slot)
        local slotInfo = slot and C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(slot, appearanceType, noOption)
        if slotInfo and slotInfo.canTransmogrify then
            C_TransmogOutfitInfo.SetPendingTransmog(slot, appearanceType, noOption,
                application.sourceID, Enum.TransmogOutfitDisplayType.Assigned)
            applied = applied + 1
        end
    end

    -- A set every slot turns down leaves the outfit exactly as it was, and a
    -- click that changes nothing has to say why rather than look broken.
    if applied == 0 then
        UIErrorsFrame:AddMessage(LuckysWardrobe.Strings.extraSets.nothingApplied, RED_FONT_COLOR:GetRGB())
        return
    end
    PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
end

-- Card behaviour, installed over Blizzard's own set-card template so every
-- texture, animation and hover state is the native one. The template calls
-- these by name on the frame, which is how its own mixins override each other.

-- Dresses the model in the set and paints the same states the native cards
-- carry: the incomplete border and dimming, the applied-and-pending glow, and
-- the save flash. One piece per slot, the first listed, since a model cannot
-- wear a chest and its robe twin at once.
local function updateCard(card)
    if not card.elementData then return end
    local entry = card.elementData.entry
    local page = card.elementData.page

    local dressed = {}
    for _, piece in ipairs(entry.pieces) do
        if piece.state ~= "unavailable" and not dressed[piece.slot] then
            dressed[piece.slot] = true
            card:TryOn(piece.sourceID)
        end
    end

    local complete = LuckysWardrobe.ExtraSets.IsComplete(entry)
    local borderAtlas = complete and "transmog-setcard-default" or "transmog-setcard-incomplete"
    card.Border:SetAtlas(borderAtlas)
    card.Highlight:SetAtlas(borderAtlas)
    card.IncompleteOverlay:SetShown(not complete)

    local appliedEntry, hasPending = page.AppliedState()
    if appliedEntry and appliedEntry.key == entry.key then
        card.TransmogStateTexture:SetAtlas(
            hasPending and "transmog-setcard-transmogrified-pending" or "transmog-setcard-transmogrified",
            TextureKitConstants.IgnoreAtlasSize
        )
        card.TransmogStateTexture:Show()
        if hasPending then
            card.PendingFrame:Show()
            card.PendingFrame.Anim:Restart()
        else
            card.PendingFrame.Anim:Stop()
            card.PendingFrame:Hide()
        end
        if page.GetOutfitSlotSavedState() then
            card.SavedFrame:Show()
            card.SavedFrame.Anim:Restart()
            page.SetOutfitSlotSavedState(false)
        end
    else
        card.TransmogStateTexture:Hide()
        card.PendingFrame.Anim:Stop()
        card.PendingFrame:Hide()
    end

    -- Favourites are Blizzard's own bookkeeping and these sets are not in it.
    card.Favorite.Icon:Hide()

    LuckysWardrobe.TransmogSetNames:Apply(card, entry.name, complete)
end

-- The native card tooltip, told from the entry: name coloured by the pieces'
-- average quality, the label with how much is collected, then every piece in
-- its collected or missing colour. A piece the client has not named yet marks
-- the tooltip to redraw when the item data lands, as the native cards do.
local function cardTooltip(card)
    if not card.elementData then return end
    local S = LuckysWardrobe.Strings.extraSets
    local entry = card.elementData.entry

    local totalQuality, qualityCount, waitingOnQuality = 0, 0, false
    for _, piece in ipairs(entry.pieces) do
        if piece.state ~= "unavailable" then
            local sourceInfo = C_TransmogCollection.GetSourceInfo(piece.sourceID)
            if sourceInfo and sourceInfo.quality then
                totalQuality = totalQuality + sourceInfo.quality
                qualityCount = qualityCount + 1
            else
                waitingOnQuality = true
            end
        end
    end

    GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
    if waitingOnQuality then
        card.waitingOnData = true
        GameTooltip:SetText(RETRIEVING_ITEM_INFO, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
    else
        local quality = qualityCount > 0 and Round(totalQuality / qualityCount) or Enum.ItemQuality.Common
        local colorData = ColorManager.GetColorDataForItemQuality(quality)
        if colorData then
            GameTooltip:SetText(entry.name, colorData.r, colorData.g, colorData.b)
        else
            GameTooltip:SetText(entry.name)
        end

        local countsColor = entry.collected == entry.total and NORMAL_FONT_COLOR or GREEN_FONT_COLOR
        local counts = WrapTextInColor(S.counts:format(entry.collected, entry.total), countsColor)
        if entry.label ~= "" then
            GameTooltip_AddHighlightLine(GameTooltip, entry.label .. " " .. counts)
        else
            GameTooltip_AddHighlightLine(GameTooltip, counts)
        end
    end

    local wrap = false
    local leftOffset = 8
    for _, piece in ipairs(entry.pieces) do
        if piece.state ~= "unavailable" then
            local sourceInfo = C_TransmogCollection.GetSourceInfo(piece.sourceID)
            local name = sourceInfo and sourceInfo.name
            if not name or name == "" then
                card.waitingOnData = true
            elseif piece.state == "collected" then
                GameTooltip_AddColoredLine(GameTooltip, name, LIGHTYELLOW_FONT_COLOR, wrap, leftOffset)
            else
                GameTooltip_AddDisabledLine(GameTooltip, name, wrap, leftOffset)
            end
        end
    end
    if entry.unavailable > 0 then
        GameTooltip_AddDisabledLine(GameTooltip, S.unavailableNotice:format(entry.unavailable))
    end
    -- A card that folded other names in says so, or the set the player was
    -- searching for reads as missing from the page.
    for _, alternateName in ipairs(entry.alternateNames or {}) do
        GameTooltip_AddDisabledLine(GameTooltip, S.alsoListed:format(alternateName))
    end
    GameTooltip:Show()
end

local function cardMouseDown(card, buttonName)
    if not card.elementData or buttonName ~= "LeftButton" then return end
    local entry = card.elementData.entry

    -- The same shift-click the Collections page answers, down to the setting
    -- that turns it off: track everything the set is still missing.
    if LuckysWardrobe.SetTracking:HandlesShiftClick(buttonName) then
        LuckysWardrobe.ExtraSets:TrackMissing(entry)
        return
    end
    applyEntry(entry)
end

local function cardMouseUp(card, buttonName)
    if not card.elementData or buttonName ~= "RightButton" then return end
    local entry = card.elementData.entry

    MenuUtil.CreateContextMenu(card, function(_owner, rootDescription)
        rootDescription:CreateButton(LuckysWardrobe.Strings.extraSets.wowheadMenu, function()
            LuckysWardrobe.WowheadLink:ShowForTransmogSet(entry.setID)
        end)
    end)
end

-- Runs once per pooled card. UpdateSet and RefreshTooltip are plain methods
-- the template's handlers reach through the frame, so instance fields replace
-- them; the mouse handlers are script bindings, so they are rebound outright
-- rather than trusting the template to look the method up again.
local function initCard(card, elementData)
    if not card.luckysExtraSetCard then
        card.luckysExtraSetCard = true
        card.UpdateSet = updateCard
        card.RefreshTooltip = cardTooltip
        card:SetScript("OnMouseDown", cardMouseDown)
        card:SetScript("OnMouseUp", cardMouseUp)
    end
    card.elementData = elementData
    card:RefreshSetCamera()
end

local function resetCard(framePool, card)
    Pool_HideAndClearAnchors(framePool, card)
    card.elementData = nil
end

-- Page UI. The layout copies the native Sets tab piece for piece: filter and
-- search in the top corner, a paged grid of set cards below.

function TransmogExtraSets:CreatePage(wardrobe)
    local S = LuckysWardrobe.Strings.extraSets
    local page = CreateFrame("Frame", "LuckysWardrobeTransmogExtraSetsFrame", wardrobe.TabContent)
    page:SetAllPoints()
    page:Hide()

    local filterButton = CreateFrame("DropdownButton", nil, page, "WowStyle1FilterDropdownTemplate")
    filterButton.resizeToText = false
    filterButton:SetPoint("TOPRIGHT", -29, -24)

    -- The native search template, minus the server search type: filtering
    -- happens here against names the catalogue already knows.
    local searchBox = CreateFrame("EditBox", nil, page, "TransmogSearchBoxTemplate")
    searchBox:SetPoint("TOPRIGHT", filterButton, "TOPLEFT", -10, 1)

    local pagedContent = CreateFrame("Frame", nil, page, "PagedNaturalSizeGridContentFrameTemplate")
    pagedContent.xPadding = CARD_GRID_X_PADDING
    pagedContent.yPadding = CARD_GRID_Y_PADDING
    pagedContent:SetPoint("TOPLEFT", 26, -72)
    pagedContent:SetPoint("BOTTOMRIGHT", -26, 10)

    local view = CreateFrame("Frame", nil, pagedContent)
    view:SetAllPoints()
    pagedContent.ViewFrames = { view }

    local pagingControls = CreateFrame("Frame", nil, pagedContent, "PagingControlsHorizontalTemplate")
    pagingControls.bottomPadding = 3
    pagingControls.prevPageSound = SOUNDKIT.UI_TRANSMOG_PAGE_TURN
    pagingControls.nextPageSound = SOUNDKIT.UI_TRANSMOG_PAGE_TURN
    pagingControls:SetPoint("BOTTOM", 0, 5)
    pagedContent.PagingControls = pagingControls

    local noEntriesText = pagedContent:CreateFontString(nil, "OVERLAY", "GameFontNormalMed2")
    noEntriesText:SetWidth(590)
    noEntriesText:SetPoint("CENTER", -3, 31)
    noEntriesText:Hide()

    pagedContent:SetElementTemplateData({
        EXTRA_SET = { template = "TransmogSetModelTemplate", initFunc = initCard, resetFunc = resetCard },
    })

    -- Which card the outfit on show is wearing, asked once per frame however
    -- many cards ask: every card on a page asks during the same refresh.
    local appliedComputedAt, appliedEntry, appliedPending
    local function appliedState()
        if appliedComputedAt ~= GetTime() then
            appliedComputedAt = GetTime()
            appliedEntry, appliedPending =
                TransmogExtraSets.AppliedEntry(TransmogExtraSets.Entries(), viewedOutfitBySlot())
        end
        return appliedEntry, appliedPending
    end

    local outfitSlotSaved = false
    page.AppliedState = appliedState
    page.GetOutfitSlotSavedState = function() return outfitSlotSaved end
    page.SetOutfitSlotSavedState = function(saved) outfitSlotSaved = saved end

    local function refresh()
        LuckysWardrobe.Perf:Begin("transmog page refresh")
        local entries = TransmogExtraSets.Entries()
        local visible = TransmogExtraSets.VisibleEntries(entries, filters, searchBox:GetText())

        local elements = {}
        for _, entry in ipairs(visible) do
            elements[#elements + 1] = { templateKey = "EXTRA_SET", entry = entry, page = page }
        end
        local retainCurrentPage = true
        pagedContent:SetDataProvider(CreateDataProvider({ { elements = elements } }), retainCurrentPage)

        if not LuckysWardrobe.ExtraSetsCatalog:IsReady() then
            noEntriesText:SetText(S.building)
        elseif #entries == 0 then
            noEntriesText:SetText(S.empty)
        else
            noEntriesText:SetText(S.noResults)
        end
        noEntriesText:SetShown(#elements == 0)
        LuckysWardrobe.Perf:End("transmog page refresh")
    end

    -- A set is only kept off the page once the client has refused it, and the
    -- client will not judge a set whose items it has not loaded. So each rebuild
    -- asks for what it is missing and reads the answers a moment later, which is
    -- what settles the page onto the sets this character can really wear.
    local warmRun = 0
    local function warmVerdicts(run, pass)
        if not requestUnjudgedItems(TransmogExtraSets.Entries()) then return end

        C_Timer.After(ITEM_LOAD_DELAY_SECONDS, function()
            -- A rebuild since this pass started has a warm-up of its own.
            if run ~= warmRun or not page:IsShown() then return end
            TransmogExtraSets.RejudgeEntries()
            refresh()
            if pass < ITEM_LOAD_PASSES then warmVerdicts(run, pass + 1) end
        end)
    end

    local function rebuildNow()
        TransmogExtraSets.InvalidateEntries()
        refresh()
        warmRun = warmRun + 1
        warmVerdicts(warmRun, 1)
    end

    -- Learning one appearance fires the collection event several times over,
    -- so a burst collapses into a single pass a moment later.
    local rebuildQueued = false
    local function queueRebuild()
        if rebuildQueued then return end

        rebuildQueued = true
        C_Timer.After(REBUILD_DELAY_SECONDS, function()
            rebuildQueued = false
            if page:IsShown() then rebuildNow() end
        end)
    end

    filterButton:SetIsDefaultCallback(function()
        return filters.collected and filters.uncollected
    end)

    filterButton:SetDefaultCallback(function()
        filters.collected = true
        filters.uncollected = true
        refresh()
    end)

    filterButton:SetupMenu(function(_dropdown, rootDescription)
        rootDescription:CreateCheckbox(COLLECTED, function() return filters.collected end, function()
            filters.collected = not filters.collected
            refresh()
        end)
        rootDescription:CreateCheckbox(NOT_COLLECTED, function() return filters.uncollected end, function()
            filters.uncollected = not filters.uncollected
            refresh()
        end)
        -- Behind a divider because it decides how the cards are drawn rather
        -- than which of them are here, and the Default button leaves it alone
        -- for the same reason: it is a setting, not a filter.
        rootDescription:CreateDivider()
        LuckysWardrobe.TransmogSetNames:AddFilterOption(rootDescription)
    end)

    searchBox:HookScript("OnTextChanged", function()
        -- The template clears its own text on hide, which is not a search.
        if page:IsShown() then refresh() end
    end)

    page:SetScript("OnShow", function(self)
        self:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
        self:RegisterEvent("VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS")
        self:RegisterEvent("UI_SCALE_CHANGED")
        self:RegisterEvent("DISPLAY_SIZE_CHANGED")
        local hasAlternateForm, inAlternateForm = C_PlayerInfo.GetAlternateFormInfo()
        if hasAlternateForm then
            self:RegisterUnitEvent("UNIT_FORM_CHANGED", "player")
            self.inAlternateForm = inAlternateForm
        end
        -- The collection can change while the page is off screen and its
        -- events are unregistered, so coming back always reads it fresh.
        rebuildNow()
    end)

    page:SetScript("OnHide", function(self)
        self:UnregisterEvent("TRANSMOG_COLLECTION_UPDATED")
        self:UnregisterEvent("VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS")
        self:UnregisterEvent("UI_SCALE_CHANGED")
        self:UnregisterEvent("DISPLAY_SIZE_CHANGED")
        self:UnregisterEvent("UNIT_FORM_CHANGED")
    end)

    page:SetScript("OnEvent", function(self, event)
        LuckysWardrobe.Perf:Count("event " .. event)
        if event == "TRANSMOG_COLLECTION_UPDATED" then
            queueRebuild()
        elseif event == "VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS" then
            -- Saving marks the applied card with the native flash. Already set
            -- means a multi-slot save is mid-burst, and is left alone.
            if not outfitSlotSaved then
                outfitSlotSaved = appliedState() ~= nil
            end
        elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
            pagedContent:ForEachFrame(function(card) card:RefreshSetCamera() end)
        elseif event == "UNIT_FORM_CHANGED" then
            -- Form swaps rebuild the little models, so the cards dress again
            -- once the client says the new form is ready to draw.
            if IsUnitModelReadyForUI("player") then
                local _hasAlternateForm, inAlternateForm = C_PlayerInfo.GetAlternateFormInfo()
                if self.inAlternateForm ~= inAlternateForm then
                    self.inAlternateForm = inAlternateForm
                    refresh()
                end
            end
        end
    end)

    page.Refresh = rebuildNow
    LuckysWardrobe.DevLog("Transmog Extra Sets page built.")
    return page
end

-- Puts this tab back in its seat against the strip as it stands right now,
-- rather than as it stood when the tab was added.
local function placeTabAfterSets()
    local wardrobe = attachedWardrobe
    local headers = wardrobe and wardrobe.TabHeaders
    if not headers or not extraTabID then return end

    local tabButton = headers:GetTabButton(extraTabID)
    local setsButton = wardrobe.setsTabID and headers:GetTabButton(wardrobe.setsTabID)
    if not tabButton or not setsButton or not setsButton.layoutIndex then return end

    local otherIndexes = {}
    for _, tab in ipairs(headers.tabs or {}) do
        if tab ~= tabButton and tab.layoutIndex then
            otherIndexes[#otherIndexes + 1] = tab.layoutIndex
        end
    end
    tabButton.layoutIndex = TransmogExtraSets.LayoutIndexAfter(setsButton.layoutIndex, otherIndexes)
end

function TransmogExtraSets:Attach(transmogFrame)
    if attachedWardrobe then return end
    local wardrobe = transmogFrame and transmogFrame.WardrobeCollection
    if not wardrobe or not wardrobe.TabContent or not wardrobe.TabHeaders
        or type(wardrobe.AddNamedTab) ~= "function" then
        LuckysWardrobe.DevLog("Transmog Extra Sets: wardrobe collection missing; tab not added.")
        return
    end

    attachedWardrobe = wardrobe
    local page = self:CreatePage(wardrobe)
    extraTabID = wardrobe:AddNamedTab(LuckysWardrobe.Strings.extraSets.tab, page)

    -- New tabs land at the end of the strip, after Situations, so this one has
    -- to take its seat beside Sets and then keep taking it: another addon can
    -- renumber the strip at any point in the session, and one of them does.
    --
    -- Laying the strip out is deferred to the frame after it is marked dirty,
    -- and marking it dirty is what anything moving a tab has to do for the move
    -- to show. So the seat is claimed from there, after whatever renumbering
    -- prompted it and before the layout it will be read by. Claiming it changes
    -- an index and nothing else, leaving the frame as dirty as it already was,
    -- so this cannot mark its way into a loop.
    placeTabAfterSets()
    if type(wardrobe.TabHeaders.MarkDirty) == "function" then
        hooksecurefunc(wardrobe.TabHeaders, "MarkDirty", placeTabAfterSets)
    end
    wardrobe.TabHeaders:MarkDirty()

    -- The catalogue may still be building when the page first shows; repaint
    -- the moment it lands.
    LuckysWardrobe.ExtraSetsCatalog:OnReady(function()
        TransmogExtraSets.InvalidateEntries()
        if page:IsShown() then page.Refresh() end
    end)

    LuckysWardrobe.DevLog("Transmog Extra Sets: tab " .. tostring(extraTabID) .. " added beside Sets.")
end

function TransmogExtraSets:Init()
    filters.collected = true
    filters.uncollected = true
    -- Blizzard_Transmog loads on demand at the first transmogrifier visit, and
    -- the catalogue takes about a second to build, so starting it here has the
    -- sets ready by the time a player can reach the tab.
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Transmog", function()
        LuckysWardrobe.ExtraSetsCatalog:StartBuild()
        TransmogExtraSets:Attach(TransmogFrame)
    end)
end
