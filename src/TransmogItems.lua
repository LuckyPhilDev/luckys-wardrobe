-- luacheck: globals C_Item C_TransmogCollection CHECK_ALL CreateFrame EventUtil FILTERS MenuResponse SOURCES TransmogFrame UNCHECK_ALL WardrobeCollectionFrame

-- Lucky's Wardrobe: the Expansion submenu the set lists carry, brought to the
-- Items tab at the transmogrifier. Picking a weapon to go with a set from one
-- expansion means reading a category of hundreds with nothing to go on but the
-- look of each, and the tab's own button narrows by where a piece came from
-- rather than when.
--
-- With two things to narrow by, the button is Filters rather than Sources and
-- holds one submenu for each. Blizzard's own source boxes are rebuilt here to
-- get there: the menu API can add to the menu they build but cannot take
-- anything out of it, and a page of loose boxes with a submenu on the end reads
-- as two different kinds of thing.
--
-- The Collections journal's Appearances tab reads the same call and carries no
-- box of ours to undo a filter with, so it is left alone.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.TransmogItems = {}

local TransmogItems = LuckysWardrobe.TransmogItems
local ExtraSets = LuckysWardrobe.ExtraSets
local Utils = LuckysWardrobe.Utils

-- The box for a piece the client files under no expansion at all, keyed by a
-- name so it can never collide with an expansionID. Shop and promotional pieces
-- land in it, and it is the Items tab's alone: only a piece carries an item to
-- read a source off, which is what places it there.
local NO_EXPANSION = "none"

-- Which expansions the tab is showing, keyed by Blizzard's expansionID, plus the
-- one box below the divider. Held for the session rather than saved, as every
-- other list here holds its own.
--
-- There is no Unknown box, which the Extra Sets lists carry. Theirs holds sets a
-- bundled snapshot cannot date and never will; an appearance here is undated
-- only for the moment before the client answers about its item, so a box for it
-- would read as permanently empty and hide half a cold slot if it were ticked
-- off. Undated appearances are simply kept.
local expansions = {}

local function setAllExpansions(shown)
    Utils.SetAllExpansions(expansions, shown)
    expansions[NO_EXPANSION] = shown
end

local function anyExpansionHidden()
    if not expansions[NO_EXPANSION] then return true end
    return Utils.AnyExpansionHidden(expansions)
end

setAllExpansions(true)

-- Which colour the strip is set to, as the key of a preset, that preset's shades
-- ready to be matched against, and the preset itself. Session-only, like the
-- expansions.
local colour
local colourTarget
local colourPreset

-- What the strip is set to, for the parts of the addon outside this tab that
-- answer to it. The dice on the character preview offers a roll in this colour
-- while one is lit, and needs all three: the key to name it, the target to match
-- a piece against, and the preset to paint its own swatch from.
function TransmogItems.PickedColour()
    return colour, colourTarget, colourPreset
end

-- Paints a texture as the swatch for a preset, wherever the picked colour is
-- shown: the strip itself and the dice beside the character preview.
--
-- The unmatched swatch is not one colour, so it is painted across the two the
-- preset carries for the purpose rather than in either of them.
function TransmogItems.PaintSwatch(texture, preset)
    local shade = preset.shades[1]
    if not preset.unmatched then
        texture:SetColorTexture(shade[1] / 255, shade[2] / 255, shade[3] / 255)
        return
    end

    local second = preset.shades[2]
    texture:SetColorTexture(1, 1, 1)
    texture:SetGradient("HORIZONTAL",
        CreateColor(shade[1] / 255, shade[2] / 255, shade[3] / 255),
        CreateColor(second[1] / 255, second[2] / 255, second[3] / 255))
end

-- Hiding a slot belongs to no expansion, and is the one entry a filter must
-- never take away: without it there is no way to wear nothing. It is asked
-- about first so nothing goes looking for a date it could not have.
local function keeps(appearance, shownExpansions, expansionOf)
    if appearance.isHideVisual then return true end

    -- No box for it covers two things, and neither is taken away on the strength
    -- of having nowhere to go. An appearance the client has not answered about
    -- yet is answered a moment later and filed properly, and one dated to an
    -- expansion this version has no name for would otherwise vanish from a
    -- filtered page the patch it shipped in.
    local shown = shownExpansions[expansionOf(appearance.visualID)]
    return shown ~= false
end

-- The appearances from the expansions still ticked. expansionOf answers with an
-- expansionID, the No Expansion box, or nil for an appearance nothing dates yet.
function TransmogItems.AppearancesFromExpansions(appearances, shownExpansions, expansionOf)
    local kept = {}
    for _, appearance in ipairs(appearances) do
        if keeps(appearance, shownExpansions, expansionOf) then kept[#kept + 1] = appearance end
    end
    return kept
end

-- The appearances made of the colour picked on the strip, most of it first.
-- rank answers for one appearance with how little of it is that colour, so
-- smaller is more, or nil for one that is not made of it at all. An appearance it cannot
-- place is dropped rather than kept: the bundled colours cover the whole
-- collection, so nothing to go on means a piece from a patch newer than the
-- snapshot, and a page of unplaceable pieces would be the one thing a colour
-- filter must not show.
--
-- Hiding a slot is kept whatever colour is picked, for the same reason the
-- expansion boxes keep it: it is the only way to wear nothing.
--
-- The order is carried on uiOrder rather than by the order of the list, because
-- the tab sorts what it is given. Its own comparator settles the collected,
-- usable and favourite pieces first and only then reads uiOrder, so a rank
-- written here orders the page within those groups and leaves them intact.
-- Highest first is what that comparator wants, so the rank is negated.
function TransmogItems.AppearancesInColour(appearances, rank)
    local kept = {}
    for _, appearance in ipairs(appearances) do
        if appearance.isHideVisual then
            kept[#kept + 1] = appearance
        else
            local matched = rank(appearance.visualID)
            if matched then
                appearance.uiOrder = -matched
                kept[#kept + 1] = appearance
            end
        end
    end
    return kept
end

-- Which piece a roll lands on, or nil for a page with nothing to land on. It
-- draws from the page as the filters have left it, so the colour picked on the
-- strip is what a roll keeps to.
--
-- A piece nobody can wear is no use to a roll. Neither is hiding the slot: it is
-- on the page because no filter may take it away, and a colour roll answering
-- with the one entry that carries no colour reads as a button gone wrong.
--
-- previous is what the last roll landed on. Landing there again looks like a
-- button doing nothing, so the roll takes the next piece along, which leaves a
-- page holding one piece still answering with that piece.
function TransmogItems.RollVisual(appearances, previous, pick)
    local candidates = {}
    for _, appearance in ipairs(appearances) do
        if appearance.isCollected and appearance.isUsable and not appearance.isHideVisual then
            candidates[#candidates + 1] = appearance.visualID
        end
    end
    if #candidates == 0 then return nil end

    local index = pick(#candidates)
    if candidates[index] == previous then index = index % #candidates + 1 end
    return candidates[index]
end

-- Live glue from here down.

-- The client's own answer, for the parts of the addon that want the whole
-- collection rather than the page this tab has narrowed. Init replaces the
-- client's call with one that filters, and anything reading it for its own
-- purposes gets the filter as well: a roll drawing from the colour on the strip,
-- and the tab's colour ranking and item requests run over every category on the
-- way. Callers that mean the collection ask here instead.
function TransmogItems.CategoryAppearances(category, locationData)
    local read = TransmogItems.getCategoryAppearances or C_TransmogCollection.GetCategoryAppearances
    return read(category, locationData)
end

-- What an appearance is dated to, worked out once and kept for the session. The
-- tab asks about every appearance it lists on every refresh and a category runs
-- to hundreds, so asking the client again each time would be thousands of reads
-- a keystroke.
local dated = {}

-- Items already asked about, so a pass asks after the ones nothing has been
-- asked about rather than asking again for answers still in flight.
local requested = {}

-- How many items one pass is willing to ask about, matching the Extra Sets tab.
-- A cold client knows almost nothing about the collection, and asking after
-- every appearance at once is thousands of requests in a single frame.
local ITEM_LOAD_BUDGET = 200
local budget = 0

-- Listens for the answers to come back, so the tab can read the dates again.
local itemFrame = CreateFrame("Frame")

local refreshWhenItemsLand = Utils.Debounced(Utils.ITEM_LOAD_DELAY_SECONDS, function()
    -- Answers stop being interesting the moment the pass has nothing left to
    -- wait for, and this event fires all game long. The next pass asks for more
    -- and registers again if anything is still cold.
    itemFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    TransmogItems:Refresh()
end)

itemFrame:SetScript("OnEvent", refreshWhenItemsLand)

-- Only an item's own data carries the expansion it belongs to, and the client
-- holds none of it until asked. An appearance has several sources and any one
-- of them dates it, so the first that answers settles the matter. Where none
-- answers, one item is asked after rather than all of them: the rest would be
-- a thousand requests for an answer the first will bring back anyway.
--
-- Expansion 0 is what the client answers both for a piece that really is
-- Classic and for one it files under no expansion at all, so a shop crest lands
-- beside Ragnaros' drops. Whether anything says where the piece came from is
-- what separates them: the pieces filed under nothing carry no source either,
-- while a Classic drop is a boss drop, a quest reward, or a vendor's.
local function expansionOf(visualID)
    local known = dated[visualID]
    if known ~= nil then return known end

    local expansionID, sourced, cold
    for _, sourceID in ipairs(C_TransmogCollection.GetAllAppearanceSources(visualID) or {}) do
        local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
        local itemID = sourceInfo and sourceInfo.itemID
        if itemID then
            if sourceInfo.sourceType ~= nil then sourced = true end
            if expansionID == nil then
                expansionID = select(15, C_Item.GetItemInfo(itemID))
                if expansionID == nil then cold = cold or itemID end
            end
        end
    end

    if expansionID == nil then
        if cold and not requested[cold] and budget > 0 then
            budget = budget - 1
            requested[cold] = true
            C_Item.RequestLoadItemDataByID(cold)
            itemFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        end
        return nil
    end

    if expansionID == 0 and not sourced then expansionID = NO_EXPANSION end
    dated[visualID] = expansionID
    return expansionID
end

local function rankColour(visualID)
    return LuckysWardrobe.Colours.Rank(visualID, colourTarget)
end

local function itemsFrame()
    local wardrobe = TransmogFrame and TransmogFrame.WardrobeCollection
    local content = wardrobe and wardrobe.TabContent
    return content and content.ItemsFrame
end

-- Redraws the tab for a filter changed while the transmogrifier is open. The
-- frame reads the appearance list afresh, so there is nothing of ours to clear
-- first.
function TransmogItems:Refresh()
    local frame = itemsFrame()
    if frame and frame:IsShown() and type(frame.RefreshCollectionEntries) == "function" then
        frame:RefreshCollectionEntries()
    end
end

-- Whether this call is the transmogrifier's Items tab asking with something
-- actually narrowed. The Collections journal reads the same call, and while it
-- is on screen it is the one asking, so it takes the client's own list back.
local function narrowing()
    if not anyExpansionHidden() and not colour then return false end
    if WardrobeCollectionFrame and WardrobeCollectionFrame:IsVisible() then return false end

    local frame = itemsFrame()
    return frame ~= nil and frame:IsVisible()
end

-- Blizzard's own source boxes, put behind a submenu to sit beside the expansion
-- one. Every box is read off the client rather than named here, so a patch that
-- adds a source brings it along, and each does exactly what it did loose: the
-- tab redraws off the collection changing rather than off the menu.
local function addSourceFilter(rootDescription)
    local menu = rootDescription:CreateButton(SOURCES)
    menu:CreateButton(CHECK_ALL, function()
        C_TransmogCollection.SetAllSourceTypeFilters(true)
        return MenuResponse.Refresh
    end)
    menu:CreateButton(UNCHECK_ALL, function()
        C_TransmogCollection.SetAllSourceTypeFilters(false)
        return MenuResponse.Refresh
    end)
    menu:CreateDivider()

    local function isChecked(source)
        return C_TransmogCollection.IsSourceTypeFilterChecked(source)
    end
    local function setChecked(source)
        C_TransmogCollection.SetSourceTypeFilter(source, not isChecked(source))
    end
    for source = 1, C_TransmogCollection.GetNumTransmogSources() do
        if C_TransmogCollection.IsValidTransmogSource(source) then
            menu:CreateCheckbox(_G["TRANSMOG_SOURCE_" .. source], isChecked, setChecked, source)
        end
    end
end

-- The tab's own filter button, where somebody narrowing the list is already
-- looking. The tag Blizzard put on the menu they built comes along, so another
-- addon that appends to it still finds it here.
local function buildFilterMenu(_dropdown, rootDescription)
    rootDescription:SetTag("MENU_TRANSMOG_ITEMS_FILTER")

    addSourceFilter(rootDescription)
    ExtraSets.AddExpansionFilter(rootDescription, expansions, function()
        TransmogItems:Refresh()
    end, { { key = NO_EXPANSION, label = LuckysWardrobe.Strings.filterMenu.noExpansion } })
end

-- The colour strip. Blizzard's own colour picker was the other way to do this
-- and is not what the tab wants: a wheel asks somebody to name a colour before
-- they can look for it, and the answer they are after is "the green ones". A
-- dozen swatches are the whole vocabulary, in one row, one click each.
local SWATCH_SIZE = 16
local SWATCH_GAP = 4

local strip
local swatches = {}
local rollButton

local function paintSwatches()
    for _, swatch in ipairs(swatches) do
        local picked = swatch.key == colour
        swatch.Border:SetColorTexture(picked and 1 or 0, picked and 0.82 or 0, picked and 0.39 or 0,
            picked and 1 or 0.7)
        swatch.Border:SetPoint("TOPLEFT", picked and -2 or -1, picked and 2 or 1)
        swatch.Border:SetPoint("BOTTOMRIGHT", picked and 2 or 1, picked and -2 or -1)
    end
    if rollButton then rollButton:SetShown(colour ~= nil) end
end

-- Picking the colour already picked puts it back, which is the whole of the
-- undo: a strip with a clear button on the end would spend a swatch's worth of
-- room saying what clicking the lit one already does.
local function pickColour(key)
    colour = key ~= colour and key or nil
    colourTarget, colourPreset = nil, nil
    for _, preset in ipairs(LuckysWardrobe.Colours.PRESETS) do
        if preset.key == colour then
            colourTarget = LuckysWardrobe.Colours.Target(preset)
            colourPreset = preset
        end
    end
    paintSwatches()
    TransmogItems:Refresh()
end

-- The roll beside the strip, which is the strip's own: it draws from the page as
-- filtered, so a colour narrows what it can land on, and it dresses the one slot
-- the tab is open on. The dice on the preview rolls every armour slot at once
-- from the whole collection and is a different offer, so this one only appears
-- once a colour is picked, where it has something to say the other cannot.
local ROLL_SIZE = 20

local rolled

local function roll()
    local frame = itemsFrame()
    local entries = frame and frame.itemCollectionEntries
    if not entries then return end

    local visualID = TransmogItems.RollVisual(entries, rolled, math.random)
    if not visualID then return end

    rolled = visualID
    -- The tab's own call, so a rolled piece is worn exactly as a clicked one is:
    -- it settles which source to use, marks the slot, and clicks.
    frame:SelectVisual(visualID)

    -- A roll can land pages from where somebody is looking, and the piece it
    -- landed on is what they carry on browsing from.
    frame:PageToTransmogID(frame:GetAnAppearanceSourceFromVisual(visualID, true))
end

local function buildRollButton()
    local S = LuckysWardrobe.Strings.colours

    rollButton = CreateFrame("Button", nil, strip, "SquareIconButtonTemplate")
    rollButton:SetSize(ROLL_SIZE, ROLL_SIZE)
    rollButton:SetPoint("RIGHT", strip, "LEFT", -6, 0)
    rollButton:SetAtlas("charactercreate-icon-dice")

    rollButton.tooltipTitle = S.roll
    rollButton.tooltipText = S.rollHint
    rollButton.tooltipAnchor = "ANCHOR_RIGHT"

    -- Hooked rather than set, so the template keeps its own click.
    rollButton:HookScript("OnClick", roll)
end

local function buildStrip(frame)
    local S = LuckysWardrobe.Strings.colours
    strip = CreateFrame("Frame", nil, frame)
    strip:SetSize(#LuckysWardrobe.Colours.PRESETS * (SWATCH_SIZE + SWATCH_GAP), SWATCH_SIZE)

    -- Anchored to the grid rather than to the frame, so the row sits directly
    -- above whatever the page is showing however the tab's own header is laid
    -- out for the slot in hand. Weapon slots carry a dropdown armour slots do
    -- not, and it is the grid that moves for it.
    strip:SetPoint("BOTTOMRIGHT", frame.PagedContent, "TOPRIGHT", -4, 6)

    for index, preset in ipairs(LuckysWardrobe.Colours.PRESETS) do
        local swatch = CreateFrame("Button", nil, strip)
        swatch.key = preset.key
        swatch:SetSize(SWATCH_SIZE, SWATCH_SIZE)
        swatch:SetPoint("LEFT", (index - 1) * (SWATCH_SIZE + SWATCH_GAP), 0)

        swatch.Border = swatch:CreateTexture(nil, "BACKGROUND")
        swatch.Fill = swatch:CreateTexture(nil, "ARTWORK")
        swatch.Fill:SetAllPoints()
        TransmogItems.PaintSwatch(swatch.Fill, preset)

        -- What the swatch offers is not what a colour offers, so it says so
        -- itself rather than leaving the strip's line to cover both.
        swatch.hint = preset.unmatched and S.otherHint or S.pickHint

        swatch:SetScript("OnClick", function(self) pickColour(self.key) end)
        swatch:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(S[self.key])
            GameTooltip:AddLine(self.key == colour and S.clearHint or self.hint, 1, 1, 1)
            GameTooltip:Show()
        end)
        swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)
        swatches[index] = swatch
    end

    buildRollButton()
    paintSwatches()
end

-- The button also marks itself as holding a filter, and offers to put it back.
-- Left alone it would answer for Blizzard's own boxes and quietly ignore ours,
-- so a list narrowed by ours would look untouched and the reset would leave it
-- narrowed.
local function claimFilterButton()
    local frame = itemsFrame()
    local button = frame and frame.FilterButton
    if not button then return end

    if frame.PagedContent and not strip then buildStrip(frame) end

    -- Sources is no longer the whole of what the button holds.
    button:SetText(FILTERS)
    button:SetupMenu(buildFilterMenu)

    -- The strip is a filter like any other, so the button answers for it too.
    -- Left out, a page narrowed to one colour would look untouched and the
    -- reset would leave it narrowed.
    button:SetIsDefaultCallback(function()
        return colour == nil and not anyExpansionHidden()
            and C_TransmogCollection.IsUsingDefaultFilters()
    end)
    button:SetDefaultCallback(function()
        setAllExpansions(true)
        C_TransmogCollection.SetDefaultFilters()
        -- Picking nothing is what clears the strip, so the reset goes the same
        -- way a click on the lit swatch does rather than undoing it by hand. It
        -- redraws on its way out, which is the one redraw the reset owes.
        pickColour(nil)
    end)
end

-- Dev only. Expansion 0 is what the client answers both for a piece that really
-- is Classic and for one it will not date at all, so shop and promotional pieces
-- land in the Classic box beside Ragnaros' drops. Which of the client's own
-- answers separates the two has to be read off the client rather than guessed
-- at, so this lists them for the category on screen: the source type behind
-- every appearance in a box, counted, with a few named.
local EXAMPLE_LIMIT = 20

local function sourceNames()
    local names = {}
    for name, value in pairs(Enum.TransmogSource or {}) do names[value] = name end
    return names
end

local function firstSourceInfo(visualID)
    for _, sourceID in ipairs(C_TransmogCollection.GetAllAppearanceSources(visualID) or {}) do
        local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
        if sourceInfo and sourceInfo.itemID then return sourceInfo end
    end
end

-- box is what was typed after the command: an expansion's number, or the name
-- of one of the boxes below the divider, and Classic when nothing was.
function TransmogItems:PrintDates(box)
    local S = LuckysWardrobe.Strings.transmogItems
    local frame = itemsFrame()
    if not frame or not frame.activeCategoryID or not frame.transmogLocation then
        return Utils.Say(S.noCategory)
    end

    local expansionID = tonumber(box) or (box ~= "" and box) or 0
    local appearances =
        TransmogItems.CategoryAppearances(frame.activeCategoryID, frame.transmogLocation:GetData()) or {}

    -- The probe warms the cache the same way a filtered pass does, so running it
    -- twice says more than running it once.
    budget = ITEM_LOAD_BUDGET
    local names = sourceNames()
    local counts, order, examples, inBox = {}, {}, {}, 0
    for _, appearance in ipairs(appearances) do
        if not appearance.isHideVisual and expansionOf(appearance.visualID) == expansionID then
            inBox = inBox + 1
            local sourceInfo = firstSourceInfo(appearance.visualID)
            local source = names[sourceInfo and sourceInfo.sourceType] or UNKNOWN
            if not counts[source] then order[#order + 1] = source end
            counts[source] = (counts[source] or 0) + 1
            if #examples < EXAMPLE_LIMIT then
                local itemID = sourceInfo and sourceInfo.itemID
                local name = sourceInfo and sourceInfo.name
                if (not name or name == "") and itemID then name = C_Item.GetItemInfo(itemID) end
                examples[#examples + 1] =
                    S.datesExample:format(name or UNKNOWN, tostring(itemID), source)
            end
        end
    end

    local label = type(expansionID) == "number"
        and (Utils.EXPANSION_NAMES[expansionID + 1] or expansionID)
        or expansionID
    -- The client will not always name a category, so its number stands in
    -- rather than an empty space where the slot should be.
    local category = C_TransmogCollection.GetCategoryInfo(frame.activeCategoryID)
    if not category or category == "" then category = frame.activeCategoryID end
    Utils.Say(S.datesHeader:format(tostring(category), inBox, #appearances, tostring(label)))
    for _, source in ipairs(order) do
        Utils.Say(S.datesSource:format(source, counts[source]))
    end
    for _, example in ipairs(examples) do Utils.Say(example) end
end

function TransmogItems:Init()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Transmog", claimFilterButton)

    -- The tab builds its page from this one call, so narrowing the answer
    -- narrows the tab without touching a frame the client owns.
    if TransmogItems.getCategoryAppearances
        or type(C_TransmogCollection.GetCategoryAppearances) ~= "function" then
        return
    end
    TransmogItems.getCategoryAppearances = C_TransmogCollection.GetCategoryAppearances
    C_TransmogCollection.GetCategoryAppearances = function(...)
        local appearances = TransmogItems.getCategoryAppearances(...)
        if not appearances or not narrowing() then return appearances end

        budget = ITEM_LOAD_BUDGET
        appearances = TransmogItems.AppearancesFromExpansions(appearances, expansions, expansionOf)
        if not colourTarget then return appearances end

        -- Narrowed by expansion first, so the colours are only worked out for
        -- the pieces still on the page.
        return TransmogItems.AppearancesInColour(appearances, rankColour)
    end
end
