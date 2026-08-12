-- luacheck: globals BetterWardrobeCollectionFrame CHECK_ALL COLLECTED CreateDataProvider DEFAULT EventUtil LE_TRANSMOG_SET_FILTER_COLLECTED LE_TRANSMOG_SET_FILTER_PVE LE_TRANSMOG_SET_FILTER_PVP LE_TRANSMOG_SET_FILTER_UNCOLLECTED MenuResponse NOT_COLLECTED SOURCES ScrollBoxConstants TRANSMOG_SET_PVE TRANSMOG_SET_PVP UNCHECK_ALL WardrobeCollectionFrame hooksecurefunc
-- luacheck: ignore 122

-- Lucky's Wardrobe: Sorting and filtering for Blizzard's official Sets tab.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.SetsBrowser = {}

local SetsBrowser = LuckysWardrobe.SetsBrowser
local SetSources = LuckysWardrobe.SetSources
local state = {
    sortMode = "default",
    sortDirection = "ascending",
    expansions = {},
    sources = {},
}

local Utils = LuckysWardrobe.Utils
local expansionNames = Utils.EXPANSION_NAMES

local function setAllExpansions(shown)
    Utils.SetAllExpansions(state.expansions, shown)
end

local function setAllSources(shown)
    for _, category in ipairs(SetSources.Categories) do state.sources[category.id] = shown end
end

-- True while our own filters are hiding something, which is what makes the
-- list differ from the one Blizzard's own filters produced.
local function isNarrowed()
    if Utils.AnyExpansionHidden(state.expansions) then return true end
    for _, category in ipairs(SetSources.Categories) do
        if not state.sources[category.id] then return true end
    end
    return false
end

setAllExpansions(true)
setAllSources(true)

-- Blizzard populates favoriteSetID from DetermineFavorites, which calls GetBaseSets and so runs
-- after our sort. Work the favourite out ourselves: a base set counts when it or a variant is one.
local function isFavorite(set, favorites)
    local favorite = favorites[set.setID]
    if favorite == nil then
        favorite = set.favorite and true or false
        if not favorite then
            for _, variant in ipairs(C_TransmogSets.GetVariantSets(set.setID) or {}) do
                if variant.favorite then
                    favorite = true
                    break
                end
            end
        end
        favorites[set.setID] = favorite
    end
    return favorite
end

local function releaseOrder(left, right)
    if left.expansionID ~= right.expansionID then return left.expansionID > right.expansionID end
    local leftPatch, rightPatch = left.patchID or 0, right.patchID or 0
    if leftPatch ~= rightPatch then return leftPatch > rightPatch end
    local leftUiOrder, rightUiOrder = left.uiOrder or 0, right.uiOrder or 0
    if leftUiOrder ~= rightUiOrder then return leftUiOrder > rightUiOrder end
    return left.setID > right.setID
end

local function sourceCounts(setID, counts)
    if not counts[setID] then
        local collected, total = 0, 0
        for _, appearance in ipairs(C_TransmogSets.GetSetPrimaryAppearances(setID) or {}) do
            if appearance.collected then collected = collected + 1 end
            total = total + 1
        end
        counts[setID] = { collected = collected, total = total }
    end
    return counts[setID]
end

local function completionCounts(setID, counts)
    local best = sourceCounts(setID, counts)
    for _, variant in ipairs(C_TransmogSets.GetVariantSets(setID) or {}) do
        local candidate = sourceCounts(variant.setID, counts)
        local missing = candidate.total - candidate.collected
        local bestMissing = best.total - best.collected
        if missing < bestMissing or (missing == bestMissing and candidate.total > best.total) then
            best = candidate
        end
    end
    return best
end

-- Every look a base set and its difficulty variants hold between them, counted
-- once each, with how many colourways that is.
--
-- Blizzard's own row counts the best single variant, which answers "how far
-- through one difficulty am I" and never "how much of this set is left". The
-- variants are recolours of one another, so their looks are almost all
-- different and the two numbers are nothing alike: a tier collected on Normal
-- and untouched on Heroic reads as finished.
--
-- Looks shared between variants count once, because collecting one collects it
-- everywhere. That is why the total can come out below the sum of what the
-- picker shows each colourway holding.
--
-- The base set is asked about alongside its variants rather than instead of
-- them. GetVariantSets lists the set among its own variants, so this is usually
-- a repeat, and a repeated look is already counted once.
function SetsBrowser:VariantCounts(baseSetID)
    local variants = C_TransmogSets.GetVariantSets(baseSetID) or {}
    if #variants < 2 then return nil end

    local seen, collected, total = {}, 0, 0
    local function count(setID)
        for _, appearance in ipairs(C_TransmogSets.GetSetPrimaryAppearances(setID) or {}) do
            local appearanceID = appearance.appearanceID
            if appearanceID and not seen[appearanceID] then
                seen[appearanceID] = true
                total = total + 1
                if appearance.collected then collected = collected + 1 end
            end
        end
    end

    count(baseSetID)
    for _, variant in ipairs(variants) do count(variant.setID) end
    return { colourways = #variants, collected = collected, total = total }
end

-- What the tab draws itself, plus what it leaves out: a row standing for
-- several colourways says how many in the corner, and spends the line under the
-- name on how much of all of them is collected rather than on the difficulty of
-- whichever one Blizzard picked to show.
function SetsBrowser:MarkVariants(scrollBox)
    scrollBox:ForEachFrame(function(button)
        if not button.setID then return end

        local counts = SetsBrowser:VariantCounts(button.setID)
        if not LuckysWardrobe.Utils.MarkVariantCount(button, counts and counts.colourways) then return end
        button.Label:SetText(LuckysWardrobe.Strings.setRow.counts:format(counts.collected, counts.total))
    end)
end

function SetsBrowser:FilterAndSort(sets)
    local result, counts, favorites = {}, {}, {}
    local SetSearch = LuckysWardrobe.SetSearch
    local narrowedTo = SetSearch.Narrowing()
    for _, set in ipairs(sets) do
        local source = SetSources:Classify(set)
        if state.expansions[set.expansionID] and state.sources[source]
            and SetSearch.Matches(narrowedTo, set.expansionID,
                source == SetSources.PVP, source == SetSources.RAID) then
            result[#result + 1] = set
        end
    end

    table.sort(result, function(left, right)
        local before
        if state.sortMode == "completion" then
            local leftCounts = completionCounts(left.setID, counts)
            local rightCounts = completionCounts(right.setID, counts)
            local leftMissing = leftCounts.total - leftCounts.collected
            local rightMissing = rightCounts.total - rightCounts.collected
            if leftMissing ~= rightMissing then
                before = leftMissing < rightMissing
            elseif leftCounts.total ~= rightCounts.total then
                before = leftCounts.total > rightCounts.total
            else
                before = releaseOrder(left, right)
            end
        else
            -- Favourites lead the default order in both directions. Completion sorts strictly by
            -- what is left to collect, so a favourite stays wherever its progress puts it.
            local leftFavorite = isFavorite(left, favorites)
            local rightFavorite = isFavorite(right, favorites)
            if leftFavorite ~= rightFavorite then return leftFavorite end
            before = releaseOrder(left, right)
        end
        if state.sortDirection == "descending" then return not before end
        return before
    end)
    return result
end

function SetsBrowser:ApplyListOrder(container)
    if not self.lastSets or not container or not container.ScrollBox then return end
    container.ScrollBox:SetDataProvider(
        CreateDataProvider(self.lastSets),
        ScrollBoxConstants.RetainScrollPosition
    )
    if container.UpdateListSelection then container:UpdateListSelection() end
    self:ReselectIfHidden(container:GetParent())
end

-- Filtering can hide the set that is currently selected. Left alone, the
-- details panel keeps showing it while the list highlights whichever row took
-- its place, so move the selection to the top of the filtered list instead.
function SetsBrowser:ReselectIfHidden(setsFrame)
    local selectedSetID = setsFrame:GetSelectedSetID()
    if selectedSetID then
        -- A set the game does not list here at all is on screen because something
        -- put it there on purpose, which is what the instance list does when it
        -- opens another class's set. No filter of ours hid it, so no filter of
        -- ours should take it away again.
        if not C_TransmogSets.IsSetVisible(selectedSetID) then return end

        -- Matched on either ID: the list holds base sets, but the selected set
        -- may be a variant of one of them.
        local selectedBaseSetID = C_TransmogSets.GetBaseSetID(selectedSetID)
        for _, set in ipairs(self.lastSets) do
            if set.setID == selectedBaseSetID or set.setID == selectedSetID then return end
        end
    end

    local first = self.lastSets[1]
    if first then
        setsFrame:SelectSet(setsFrame:GetDefaultSetIDForBaseSet(first.setID))
    else
        setsFrame.selectedSetID = nil
        setsFrame:DisplaySet(nil)
    end
end

-- Blizzard counts every set its own filters allow, so the progress bar goes on
-- counting sets our own filters have taken off the list. Recount what is
-- actually on screen and write that over the native numbers.
function SetsBrowser:UpdateProgressBar(setsFrame)
    if not self.lastSets then return end

    local collected = 0
    for _, set in ipairs(self.lastSets) do
        if C_TransmogSets.IsBaseSetCollected(set.setID) then collected = collected + 1 end
    end

    -- With nothing of ours hidden the list is Blizzard's own, so the recount
    -- should land on Blizzard's numbers. A mismatch means the two disagree on
    -- what makes a base set collected, which is worth seeing while testing.
    if not isNarrowed() then
        local nativeCollected, nativeTotal = C_TransmogSets.GetFilteredBaseSetsCounts()
        if nativeCollected ~= collected or nativeTotal ~= #self.lastSets then
            LuckysWardrobe.DevLog("Sets tab: unfiltered count mismatch; ours="
                .. collected .. "/" .. #self.lastSets
                .. " blizzard=" .. nativeCollected .. "/" .. nativeTotal)
        end
    end

    setsFrame:GetParent():UpdateProgressBar(collected, #self.lastSets)
end

local function refresh(setsFrame)
    LuckysWardrobe.DevLog("Sets tab: refresh; OnSearchUpdate="
        .. type(setsFrame.OnSearchUpdate) .. " init=" .. tostring(setsFrame.init))
    if setsFrame.OnSearchUpdate then
        setsFrame:OnSearchUpdate()
    end
end

-- Redraws the tab for something changed outside its own filter menu, an
-- expansion typed into the search box among them.
function SetsBrowser:Refresh()
    local setsFrame = WardrobeCollectionFrame and WardrobeCollectionFrame.SetsCollectionFrame
    if setsFrame and setsFrame:IsShown() then refresh(setsFrame) end
end

local function setBaseFilter(filter)
    C_TransmogSets.SetBaseSetsFilter(filter, not C_TransmogSets.GetBaseSetsFilter(filter))
end

function SetsBrowser:SetupFilterMenu(frame)
    if not frame then
        LuckysWardrobe.DevLog("Sets tab: collection frame missing")
        return
    end
    local setsFrame = frame.SetsCollectionFrame
    local button = frame.FilterButton
    if not button or not setsFrame then
        LuckysWardrobe.DevLog("Sets tab: filter button=" .. tostring(button ~= nil)
            .. " sets frame=" .. tostring(setsFrame ~= nil))
        return
    end

    button:SetIsDefaultCallback(function()
        return not isNarrowed() and C_TransmogSets.IsUsingDefaultBaseSetsFilters()
    end)

    button:SetDefaultCallback(function()
        setAllExpansions(true)
        setAllSources(true)
        C_TransmogSets.SetDefaultBaseSetsFilters()
        refresh(setsFrame)
    end)

    button:SetupMenu(function(_dropdown, root)
        root:CreateCheckbox(COLLECTED, C_TransmogSets.GetBaseSetsFilter, function(filter)
            setBaseFilter(filter)
            refresh(setsFrame)
        end, LE_TRANSMOG_SET_FILTER_COLLECTED)
        root:CreateCheckbox(NOT_COLLECTED, C_TransmogSets.GetBaseSetsFilter, function(filter)
            setBaseFilter(filter)
            refresh(setsFrame)
        end, LE_TRANSMOG_SET_FILTER_UNCOLLECTED)
        root:CreateCheckbox(TRANSMOG_SET_PVE, C_TransmogSets.GetBaseSetsFilter, function(filter)
            setBaseFilter(filter)
            refresh(setsFrame)
        end, LE_TRANSMOG_SET_FILTER_PVE)
        root:CreateCheckbox(TRANSMOG_SET_PVP, C_TransmogSets.GetBaseSetsFilter, function(filter)
            setBaseFilter(filter)
            refresh(setsFrame)
        end, LE_TRANSMOG_SET_FILTER_PVP)
        root:CreateDivider()

        local S = LuckysWardrobe.Strings.filterMenu
        local sort = root:CreateButton(S.sortBy)
        for _, option in ipairs({ { key = "default", label = DEFAULT }, { key = "completion", label = S.byCompletion } }) do
            local mode = option
            sort:CreateRadio(mode.label, function() return state.sortMode == mode.key end, function()
                state.sortMode = mode.key
                LuckysWardrobe.DevLog("Sets tab: sort mode=" .. mode.key)
                refresh(setsFrame)
            end)
        end

        local direction = root:CreateButton(S.sortDirection)
        for _, option in ipairs({ { key = "ascending", label = S.ascending }, { key = "descending", label = S.descending } }) do
            local sortDirection = option
            direction:CreateRadio(sortDirection.label, function() return state.sortDirection == sortDirection.key end, function()
                state.sortDirection = sortDirection.key
                LuckysWardrobe.DevLog("Sets tab: sort direction=" .. sortDirection.key)
                refresh(setsFrame)
            end)
        end

        local expansions = root:CreateButton(S.expansion)
        expansions:CreateButton(CHECK_ALL, function()
            setAllExpansions(true)
            refresh(setsFrame)
            return MenuResponse.Refresh
        end)
        expansions:CreateButton(UNCHECK_ALL, function()
            setAllExpansions(false)
            refresh(setsFrame)
            return MenuResponse.Refresh
        end)
        expansions:CreateDivider()
        for index, name in ipairs(expansionNames) do
            local expansionID = index - 1
            expansions:CreateCheckbox(name, function() return state.expansions[expansionID] end, function()
                state.expansions[expansionID] = not state.expansions[expansionID]
                refresh(setsFrame)
            end)
        end

        local sources = root:CreateButton(SOURCES)
        sources:CreateButton(CHECK_ALL, function()
            setAllSources(true)
            refresh(setsFrame)
            return MenuResponse.Refresh
        end)
        sources:CreateButton(UNCHECK_ALL, function()
            setAllSources(false)
            refresh(setsFrame)
            return MenuResponse.Refresh
        end)
        sources:CreateDivider()
        for _, category in ipairs(SetSources.Categories) do
            local source = category
            sources:CreateCheckbox(source.label, function() return state.sources[source.id] end, function()
                state.sources[source.id] = not state.sources[source.id]
                refresh(setsFrame)
            end)
        end
    end)
    LuckysWardrobe.DevLog("Sets tab: menu attached to " .. tostring(frame:GetName()))
end

function SetsBrowser:Init()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", function()
        LuckysWardrobe.DevLog("Sets tab: collections loaded; stock="
            .. tostring(WardrobeCollectionFrame ~= nil) .. " better="
            .. tostring(BetterWardrobeCollectionFrame ~= nil) .. " initializer="
            .. type(WardrobeCollectionFrame and WardrobeCollectionFrame.InitBaseSetsFilterButton) .. " GetBaseSets="
            .. type(C_TransmogSets.GetBaseSets) .. " GetAllSets="
            .. type(C_TransmogSets.GetAllSets))
        if not SetsBrowser.getBaseSets and type(C_TransmogSets.GetBaseSets) == "function" then
            SetsBrowser.getBaseSets = C_TransmogSets.GetBaseSets
            C_TransmogSets.GetBaseSets = function(...)
                local sets = SetsBrowser.getBaseSets(...)
                local sorted = SetsBrowser:FilterAndSort(sets)
                SetsBrowser.lastSets = {}
                for index, set in ipairs(sorted) do SetsBrowser.lastSets[index] = set end
                return sorted
            end
            LuckysWardrobe.DevLog("Sets tab: GetBaseSets wrapped")
        end

        local setsFrame = WardrobeCollectionFrame and WardrobeCollectionFrame.SetsCollectionFrame
        local listContainer = setsFrame and setsFrame.ListContainer
        if listContainer and type(listContainer.UpdateDataProvider) == "function"
            and not SetsBrowser.listHooked then
            SetsBrowser.listHooked = true
            hooksecurefunc(listContainer, "UpdateDataProvider", function(container)
                SetsBrowser:ApplyListOrder(container)
            end)
            LuckysWardrobe.DevLog("Sets tab: rendered list hooked")
        end

        -- The rows themselves, which Blizzard fills in as the ScrollBox lays
        -- them out. Marking them from its own Update catches every scroll, sort
        -- and filter change from one place, the way the tracking crosshair
        -- already marks the same rows.
        local listScrollBox = listContainer and listContainer.ScrollBox
        if listScrollBox and not SetsBrowser.rowsHooked then
            SetsBrowser.rowsHooked = true
            hooksecurefunc(listScrollBox, "Update", function(scrollBox)
                SetsBrowser:MarkVariants(scrollBox)
            end)
            LuckysWardrobe.DevLog("Sets tab: rows hooked")
        end

        if setsFrame and type(setsFrame.UpdateProgressBar) == "function"
            and not SetsBrowser.progressHooked then
            SetsBrowser.progressHooked = true
            hooksecurefunc(setsFrame, "UpdateProgressBar", function(frame)
                SetsBrowser:UpdateProgressBar(frame)
            end)
            LuckysWardrobe.DevLog("Sets tab: progress bar hooked")
        end

        if WardrobeCollectionFrame and type(WardrobeCollectionFrame.InitBaseSetsFilterButton) == "function"
            and not SetsBrowser.filterHooked then
            SetsBrowser.filterHooked = true
            hooksecurefunc(WardrobeCollectionFrame, "InitBaseSetsFilterButton", function(frame)
                LuckysWardrobe.DevLog("Sets tab: filter initializer ran")
                SetsBrowser:SetupFilterMenu(frame)
            end)
            LuckysWardrobe.DevLog("Sets tab: filter initializer hooked")
        end

        SetsBrowser:SetupFilterMenu(WardrobeCollectionFrame)
    end)
end
