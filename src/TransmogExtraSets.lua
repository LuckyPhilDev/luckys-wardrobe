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
local Utils = LuckysWardrobe.Utils

-- How many items one pass will ask for. This page lists hundreds of sets, and
-- asking about every one of them at once is a burst the client answers no
-- faster for.
local ITEM_LOAD_BUDGET = 200

-- The grid spacing Blizzard gives the native Sets tab's card grid.
local CARD_GRID_X_PADDING = 27
local CARD_GRID_Y_PADDING = 19

-- The record slots, in the order the viewed outfit is read.
local SLOT_KEYS = Utils.ARMOUR_SLOTS

-- Session-only state behind the filter button, mirroring the native Sets tab
-- menu: fully collected sets and everything short of that, and which expansions
-- are on show. No source boxes, which the Collections page offers and this one
-- has no room beside the card grid for.
local filters = {
    collected = true,
    uncollected = true,
    expansions = {},
}

LuckysWardrobe.ExtraSets.SetAllExpansions(filters.expansions, true)

local attachedWardrobe
local extraTabID

-- Pure catalogue logic. Everything below takes plain tables plus injected
-- resolvers so the rules stay testable outside the client.

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
--
-- wearable is for a caller judging the rows a slice at a time across several
-- frames: handing back the same list each slice gathers the verdicts into it in
-- order, and leaving it out judges the whole lot in one go.
function TransmogExtraSets.WearableEntries(entries, classID, sourceValidity, wearable)
    wearable = wearable or {}
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
--
-- The Collections page's own narrowing does the filtering, so the boxes the two
-- share mean the same thing on both. It reads the source boxes only when a page
-- offers them, and this one does not.
function TransmogExtraSets.VisibleEntries(entries, filterState, query)
    local ExtraSets = LuckysWardrobe.ExtraSets
    local narrowed = ExtraSets.ApplyFilters(entries, filterState)
    return ExtraSets.SortEntries(ExtraSets.FilterEntries(narrowed, query), "completion", "ascending")
end

-- What the page draws, as one comparable value: the cards in the order they sit
-- in, each with the counts printed on it. Two lists agreeing here draw the same
-- page, so the cards already on screen can be left where they are.
--
-- Worth asking before drawing because drawing is not cheap: the card grid
-- releases every model on the page and dresses it again from nothing, which a
-- player watches as the page loading a second time. Most of what asks the page
-- to draw itself again, a pass over the client's verdicts above all, changes
-- none of what it would draw.
function TransmogExtraSets.PageSignature(entries)
    local parts = {}
    for index, entry in ipairs(entries) do
        parts[index] = ("%s %d/%d%s"):format(
            entry.key, entry.collected, entry.total, entry.loading and " loading" or "")
    end
    return table.concat(parts, "\n")
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

-- Building the rows in one go is a fifth of a second, and a fifth of a second is
-- a frame a player feels wherever it is spent. Ahead of a visit there is no
-- reason to spend it all at once, so it is built the way the catalogue builds
-- itself: a slice per frame, small enough to be lost in the noise of a frame.
--
-- The pacing counts pieces rather than sets, for the catalogue's own reason: a
-- tier is nine pieces and an ensemble can teach over a hundred, so a fixed
-- number of sets would make one frame twenty times the work of another.
--
-- Lower than the catalogue's own count because a piece costs more here: the
-- catalogue asks the client one question about each, where building a row asks
-- one and judging it asks two, every one of them handing back a table.
--
-- Not much lower, though, because the build is racing the player to the tab.
-- Thin slices sit lighter on a frame but take more of them, and a build still
-- running when the tab opens is one the player waits on the rest of. Two or
-- three milliseconds a slice is the trade: light enough not to drop a frame,
-- few enough to be finished before anyone has read the tab strip.
local PIECES_PER_BUILD_STEP = 250

local buildFrame
local build

local function stopPacedBuild()
    build = nil
    if buildFrame then buildFrame:SetScript("OnUpdate", nil) end
end

function TransmogExtraSets.InvalidateEntries()
    stopPacedBuild()
    cachedRows = nil
    cachedEntries = nil
end

-- Judges the rows again without building them again, which is what item data
-- landing calls for: the sets have not changed, only what the client will say
-- about them.
function TransmogExtraSets.RejudgeEntries()
    stopPacedBuild()
    cachedEntries = nil
end

-- One frame's worth of the build, and whether there is more of it left. The
-- stages run in order: this character's records picked out, rows built from
-- them, the looks the Sets tab already shows gathered, the rows folded against
-- those, then each row judged against what this character can wear.
--
-- Three of the five are one frame each and take as long as they take. They are
-- timed under their own names so a report says which of them, if any, is the
-- frame worth slicing next.
local function pacedBuildStep()
    local ExtraSets = LuckysWardrobe.ExtraSets

    if build.stage == "records" then
        LuckysWardrobe.Perf:Begin("transmog records picked")
        build.records = ExtraSets.RecordsForClass(ExtraSets.Records(), build.classID)
        LuckysWardrobe.Perf:End("transmog records picked")
        build.stage = "rows"
        return true
    end

    if build.stage == "looks" then
        LuckysWardrobe.Perf:Begin("transmog looks gathered")
        build.nativeLooks = ExtraSets.NativeLooks(build.classID)
        LuckysWardrobe.Perf:End("transmog looks gathered")
        build.stage = "collapse"
        return true
    end

    if build.stage == "collapse" then
        LuckysWardrobe.Perf:Begin("transmog rows folded")
        build.rows = ExtraSets.CollapseDuplicates(build.rows, build.nativeLooks)
        LuckysWardrobe.Perf:End("transmog rows folded")
        -- Published here rather than at the end, so a player who reaches the tab
        -- mid-build only has the judging left to pay for rather than the lot.
        cachedRows = build.rows
        build.stage = "judge"
        build.cursor = 0
        return true
    end

    local source = build.stage == "rows" and build.records or build.rows
    local slice, pieces = {}, 0
    while pieces < PIECES_PER_BUILD_STEP do
        local item = source[build.cursor + 1]
        if not item then break end
        build.cursor = build.cursor + 1
        pieces = pieces + #item.pieces
        slice[#slice + 1] = item
    end

    if build.stage == "rows" then
        ExtraSets.BuildEntries(slice, build.resolver, build.rows, build.seen)
        if build.cursor >= #build.records then build.stage = "looks" end
        return true
    end

    TransmogExtraSets.WearableEntries(slice, build.classID, build.resolver.sourceValidity, build.wearable)
    return build.cursor < #build.rows
end

local function runPacedBuild()
    LuckysWardrobe.Perf:Begin("transmog build step")
    local more = pacedBuildStep()
    LuckysWardrobe.Perf:End("transmog build step")
    if more then return end

    cachedEntries = build.wearable
    stopPacedBuild()
end

--- Starts building the rows ahead of the visit that wants them, a slice a frame.
--- Does nothing when they are already built, or a build is already running.
--- Rows already built are kept and only judged, which is what a rejudge leaves.
function TransmogExtraSets.BuildAhead()
    if build or cachedEntries then return end

    local ExtraSets = LuckysWardrobe.ExtraSets
    local resolver = ExtraSets.LiveResolver()
    build = {
        resolver = resolver,
        classID = resolver.playerClassID(),
        stage = cachedRows and "judge" or "records",
        rows = cachedRows or {},
        seen = {},
        cursor = 0,
        wearable = {},
    }
    buildFrame = buildFrame or CreateFrame("Frame")
    buildFrame:SetScript("OnUpdate", runPacedBuild)
end

-- Whether any row is still waiting on the client to name one of its pieces.
-- Such a row counted that piece as neither collected nor missing, so what it
-- says is provisional: it has to be built again rather than only judged again.
local function rowsWaiting()
    for _, entry in ipairs(cachedRows or {}) do
        if entry.loading then return true end
    end
    return false
end

function TransmogExtraSets.Entries()
    if not cachedEntries then
        -- Half a build is no use to somebody who wants a page now, and the rows
        -- it did get through are already published, so the rest is finished here
        -- and the slices stop.
        stopPacedBuild()
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
--
-- Takes catalogue records as readily as built entries: both carry the pieces,
-- and a record has no verdict on a piece to skip it by.
local function requestUnjudgedItems(sets)
    local asked = 0
    for _, set in ipairs(sets) do
        if asked >= ITEM_LOAD_BUDGET then break end
        for _, piece in ipairs(set.pieces) do
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

-- Told after each round of answers lands, so the page can read the verdicts
-- again. Set once the page exists; the rounds run whether it does or not.
local afterItemsLoaded

-- Told when the collection has changed under the rows, so the page can build
-- itself again. Set once the page exists, as the rows are dropped either way.
local afterCollectionChanged

-- Building the rows is the most expensive thing this tab does, a good tenth of
-- a second, and the collection changing is what makes them wrong. The page used
-- to throw them away every time it opened, because it only listened for that
-- while it was on screen and so could not know whether anything had happened
-- while it was away. Listening for the whole session answers that: a tab opened
-- again on a collection nothing has happened to opens on the rows it was left
-- with, and pays nothing for them.
local function watchCollection()
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
    watcher:SetScript("OnEvent", function(_, event)
        LuckysWardrobe.Perf:Count("event " .. event)
        TransmogExtraSets.InvalidateEntries()
        if afterCollectionChanged then afterCollectionChanged() end
    end)
end

-- A set the client has not judged stays on the page, because a cold cache is
-- not a refusal. So a page built before the answers are in lists sets that
-- disappear from it as they arrive, and what a player sees is the cards
-- shuffling under them for a second or two after the tab opens.
--
-- The cure is to have asked already. Asking starts as soon as there are sets to
-- ask about, which is at login rather than at the transmogrifier, and carries
-- on a budget at a time until every set has been asked about once. Nothing is
-- asked about twice, so the rounds run out on their own.
local warmingItems = false

-- The rows the tab lists, started before the visit that wants them so the slices
-- are through by the time anyone clicks.
--
-- Held back until the transmogrifier has been opened, so a player who never goes
-- near one never pays for a page they are not going to look at, and until the
-- client has answered what it is going to about the sets, so the rows are built
-- against settled verdicts and the tab opens on its final list rather than
-- settling onto it while the player watches.
local function prebuildRows()
    if not attachedWardrobe or warmingItems then return end
    if not LuckysWardrobe.ExtraSetsCatalog:IsReady() then return end
    TransmogExtraSets.BuildAhead()
end

local function warmItemData()
    if warmingItems then return end
    warmingItems = true

    local ExtraSets = LuckysWardrobe.ExtraSets
    local resolver = ExtraSets.LiveResolver()
    local classID = resolver.playerClassID()
    local records = ExtraSets.RecordsForClass(ExtraSets.Records(), classID)

    -- The looks the Sets tab already shows this class, worked out here rather
    -- than mid-build. It is the same frame's work wherever it is spent, and at
    -- login it is spent where nothing is waiting on it. The answer is kept for
    -- the session and both pages read the same one, so whichever is opened first
    -- finds it already worked out.
    --
    -- On the next frame rather than this one. The warm-up starts from inside the
    -- last step of the catalogue's own build, and hanging this off the end of it
    -- makes that one step ten times the size of every other.
    C_Timer.After(0, function()
        LuckysWardrobe.Perf:Begin("transmog looks gathered")
        ExtraSets.NativeLooks(classID)
        LuckysWardrobe.Perf:End("transmog looks gathered")
    end)

    local function round()
        if not requestUnjudgedItems(records) then
            warmingItems = false
            prebuildRows()
            return
        end
        C_Timer.After(Utils.ITEM_LOAD_DELAY_SECONDS, function()
            TransmogExtraSets.RejudgeEntries()
            if afterItemsLoaded then afterItemsLoaded() end
            round()
        end)
    end
    round()
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
            -- Only the armour lists number their sets the way Wowhead's own set
            -- pages do. A set that reached the page as an ensemble is numbered
            -- the way the client numbers it, so the address that finds it is
            -- the ensemble item's rather than a set page it does not have.
            if entry.fromEnsemble then
                LuckysWardrobe.WowheadLink:ShowForItem(entry.ensembles[1])
            else
                LuckysWardrobe.WowheadLink:ShowForTransmogSet(entry.setID)
            end
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

    -- What the cards on screen are showing, so a pass that would draw the same
    -- page again can leave them alone.
    local paintedSignature

    local function paint(visible)
        LuckysWardrobe.Perf:Begin("transmog page painted")
        local elements = {}
        for _, entry in ipairs(visible) do
            elements[#elements + 1] = { templateKey = "EXTRA_SET", entry = entry, page = page }
        end
        local retainCurrentPage = true
        pagedContent:SetDataProvider(CreateDataProvider({ { elements = elements } }), retainCurrentPage)
        LuckysWardrobe.Perf:End("transmog page painted")
    end

    local function refresh()
        LuckysWardrobe.Perf:Begin("transmog page refresh")
        local entries = TransmogExtraSets.Entries()
        local visible = TransmogExtraSets.VisibleEntries(entries, filters, searchBox:GetText())

        -- Why the page has nothing on it can change while the page itself does
        -- not: an empty page whose catalogue has finished building is an answer
        -- rather than a wait, so the line is told before the cards are asked.
        if not LuckysWardrobe.ExtraSetsCatalog:IsReady() then
            noEntriesText:SetText(S.building)
        elseif #entries == 0 then
            noEntriesText:SetText(S.empty)
        else
            noEntriesText:SetText(S.noResults)
        end
        noEntriesText:SetShown(#visible == 0)

        local signature = TransmogExtraSets.PageSignature(visible)
        if signature == paintedSignature then
            LuckysWardrobe.Perf:Count("transmog page unchanged")
        else
            paintedSignature = signature
            paint(visible)
        end
        LuckysWardrobe.Perf:End("transmog page refresh")
    end

    -- The page drawn again whether or not it would come out any different,
    -- which is what a rebuilt player model calls for: the cards are wearing the
    -- old one until the grid dresses them from scratch.
    local function repaint()
        paintedSignature = nil
        refresh()
    end

    -- Everything a visit to the tab asks for: the page drawn from the rows as
    -- they stand, and the item data behind any set the client has still not
    -- judged asked for. Neither costs anything when there is nothing to do.
    local function refreshAndWarm()
        refresh()
        warmItemData()
    end

    -- A round of item answers is what moves the client's verdicts, and a verdict
    -- is what keeps a set off the page, so the page reads them again each time a
    -- round lands. Off screen it reads nothing: coming back reads everything.
    afterItemsLoaded = function()
        if page:IsShown() then refresh() end
    end

    -- The rows have already been thrown away by the time this runs; what the
    -- delay collapses is the burst of them that learning one appearance sets off.
    -- On screen the page wants drawing now, so the rows are rebuilt on the spot.
    -- Off it, they are built back a slice at a time, which has the next visit
    -- opening on rows that were ready before anybody asked for them.
    afterCollectionChanged = Utils.Debounced(Utils.REBUILD_DELAY_SECONDS, function()
        if page:IsShown() then
            refreshAndWarm()
        else
            prebuildRows()
        end
    end)

    filterButton:SetIsDefaultCallback(function()
        return filters.collected and filters.uncollected
            and not LuckysWardrobe.ExtraSets.AnyExpansionHidden(filters.expansions)
    end)

    filterButton:SetDefaultCallback(function()
        filters.collected = true
        filters.uncollected = true
        LuckysWardrobe.ExtraSets.SetAllExpansions(filters.expansions, true)
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
        LuckysWardrobe.ExtraSets.AddExpansionFilter(rootDescription, filters.expansions, refresh)
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
        self:RegisterEvent("VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS")
        self:RegisterEvent("UI_SCALE_CHANGED")
        self:RegisterEvent("DISPLAY_SIZE_CHANGED")
        local hasAlternateForm, inAlternateForm = C_PlayerInfo.GetAlternateFormInfo()
        if hasAlternateForm then
            self:RegisterUnitEvent("UNIT_FORM_CHANGED", "player")
            self.inAlternateForm = inAlternateForm
        end
        -- The collection is watched all session, so the rows this tab was left
        -- with are still the right ones and are opened on. A row still waiting
        -- on the client is the exception: what it counted is provisional until
        -- the client has named the piece, so those are counted again.
        if rowsWaiting() then TransmogExtraSets.InvalidateEntries() end
        refreshAndWarm()
    end)

    page:SetScript("OnHide", function(self)
        self:UnregisterEvent("VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS")
        self:UnregisterEvent("UI_SCALE_CHANGED")
        self:UnregisterEvent("DISPLAY_SIZE_CHANGED")
        self:UnregisterEvent("UNIT_FORM_CHANGED")
    end)

    page:SetScript("OnEvent", function(self, event)
        LuckysWardrobe.Perf:Count("event " .. event)
        if event == "VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS" then
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
                    repaint()
                end
            end
        end
    end)

    page.Refresh = refreshAndWarm
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
    -- the moment it lands, and take that as the cue to build the rows too.
    LuckysWardrobe.ExtraSetsCatalog:OnReady(function()
        TransmogExtraSets.InvalidateEntries()
        if page:IsShown() then page.Refresh() end
        prebuildRows()
    end)

    LuckysWardrobe.DevLog("Transmog Extra Sets: tab " .. tostring(extraTabID) .. " added beside Sets.")
end

function TransmogExtraSets:Init()
    filters.collected = true
    filters.uncollected = true
    LuckysWardrobe.ExtraSets.SetAllExpansions(filters.expansions, true)
    watchCollection()
    -- The catalogue is built at the first entry into the world, so the sets are
    -- there to ask the client about hours before anyone stands at a
    -- transmogrifier. Asking then is what has the tab open on the sets this
    -- character can wear rather than settle onto them while the player watches.
    LuckysWardrobe.ExtraSetsCatalog:OnReady(warmItemData)
    -- Blizzard_Transmog loads on demand at the first transmogrifier visit, and
    -- the catalogue takes about a second to build, so starting it here has the
    -- sets ready by the time a player can reach the tab.
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Transmog", function()
        LuckysWardrobe.ExtraSetsCatalog:StartBuild()
        TransmogExtraSets:Attach(TransmogFrame)
    end)
end
