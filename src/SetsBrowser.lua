-- luacheck: globals BetterWardrobeCollectionFrame CHECK_ALL COLLECTED CreateDataProvider DEFAULT EventUtil EXPANSION_NAME0 EXPANSION_NAME1 EXPANSION_NAME2 EXPANSION_NAME3 EXPANSION_NAME4 EXPANSION_NAME5 EXPANSION_NAME6 EXPANSION_NAME7 EXPANSION_NAME8 EXPANSION_NAME9 EXPANSION_NAME10 EXPANSION_NAME11 LE_TRANSMOG_SET_FILTER_COLLECTED LE_TRANSMOG_SET_FILTER_PVE LE_TRANSMOG_SET_FILTER_PVP LE_TRANSMOG_SET_FILTER_UNCOLLECTED MenuResponse NOT_COLLECTED SOURCES ScrollBoxConstants TRANSMOG_SET_PVE TRANSMOG_SET_PVP UNCHECK_ALL WardrobeCollectionFrame hooksecurefunc
-- luacheck: ignore 122

-- Lucky's Ensemble: Sorting and filtering for Blizzard's official Sets tab.
LuckysEnsemble = LuckysEnsemble or {}
LuckysEnsemble.SetsBrowser = {}

local SetsBrowser = LuckysEnsemble.SetsBrowser
local SetSources = LuckysEnsemble.SetSources
local DEBUG_TAG = "[DEBUG-settab-c7a2]"
local state = {
    sortMode = "default",
    sortDirection = "ascending",
    expansions = {},
    sources = {},
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

for index = 1, #expansionNames do
    state.expansions[index] = true
end

for _, category in ipairs(SetSources.Categories) do
    state.sources[category.id] = true
end

local function defaultOrder(left, right)
    local leftFavorite = left.favorite and true or false
    local rightFavorite = right.favorite and true or false
    if leftFavorite ~= rightFavorite then return leftFavorite end
    if left.expansionID ~= right.expansionID then return left.expansionID > right.expansionID end
    if left.patchID ~= right.patchID then return (left.patchID or 0) > (right.patchID or 0) end
    if left.uiOrder ~= right.uiOrder then return (left.uiOrder or 0) > (right.uiOrder or 0) end
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

function SetsBrowser:FilterAndSort(sets)
    local result, counts = {}, {}
    for _, set in ipairs(sets) do
        if state.expansions[set.expansionID] and state.sources[SetSources:Classify(set)] then
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
                before = defaultOrder(left, right)
            end
        else
            before = defaultOrder(left, right)
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
    if state.traceListApply then
        state.traceListApply = nil
        LuckysEnsemble.DevLog(DEBUG_TAG .. " rendered list applied; first="
            .. tostring(self.lastSets[1] and self.lastSets[1].setID))
    end
end

-- Filtering can hide the set that is currently selected. Left alone, the
-- details panel keeps showing it while the list highlights whichever row took
-- its place, so move the selection to the top of the filtered list instead.
function SetsBrowser:ReselectIfHidden(setsFrame)
    local selectedSetID = setsFrame:GetSelectedSetID()
    if selectedSetID then
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

local function refresh(setsFrame)
    LuckysEnsemble.DevLog(DEBUG_TAG .. " refresh; OnSearchUpdate="
        .. type(setsFrame.OnSearchUpdate) .. " init=" .. tostring(setsFrame.init))
    if setsFrame.OnSearchUpdate then
        setsFrame:OnSearchUpdate()
    end
end

local function setBaseFilter(filter)
    C_TransmogSets.SetBaseSetsFilter(filter, not C_TransmogSets.GetBaseSetsFilter(filter))
end

function SetsBrowser:SetupFilterMenu(frame)
    if not frame then
        LuckysEnsemble.DevLog(DEBUG_TAG .. " collection frame missing")
        return
    end
    local setsFrame = frame.SetsCollectionFrame
    local button = frame.FilterButton
    if not button or not setsFrame then
        LuckysEnsemble.DevLog(DEBUG_TAG .. " filter button=" .. tostring(button ~= nil)
            .. " sets frame=" .. tostring(setsFrame ~= nil))
        return
    end

    button:SetIsDefaultCallback(function()
        for index = 1, #expansionNames do
            if not state.expansions[index] then return false end
        end
        for _, category in ipairs(SetSources.Categories) do
            if not state.sources[category.id] then return false end
        end
        return C_TransmogSets.IsUsingDefaultBaseSetsFilters()
    end)

    button:SetDefaultCallback(function()
        for index = 1, #expansionNames do state.expansions[index] = true end
        for _, category in ipairs(SetSources.Categories) do state.sources[category.id] = true end
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

        local sort = root:CreateButton("Sort By")
        for _, option in ipairs({ { key = "default", label = DEFAULT }, { key = "completion", label = "Completion" } }) do
            local mode = option
            sort:CreateRadio(mode.label, function() return state.sortMode == mode.key end, function()
                state.sortMode = mode.key
                state.traceNextRead = true
                LuckysEnsemble.DevLog(DEBUG_TAG .. " sort mode=" .. mode.key)
                refresh(setsFrame)
            end)
        end

        local direction = root:CreateButton("Sort Direction")
        for _, option in ipairs({ { key = "ascending", label = "Ascending" }, { key = "descending", label = "Descending" } }) do
            local sortDirection = option
            direction:CreateRadio(sortDirection.label, function() return state.sortDirection == sortDirection.key end, function()
                state.sortDirection = sortDirection.key
                state.traceNextRead = true
                LuckysEnsemble.DevLog(DEBUG_TAG .. " sort direction=" .. sortDirection.key)
                refresh(setsFrame)
            end)
        end

        local expansions = root:CreateButton("Expansion")
        expansions:CreateButton(CHECK_ALL, function()
            for index = 1, #expansionNames do state.expansions[index] = true end
            refresh(setsFrame)
            return MenuResponse.Refresh
        end)
        expansions:CreateButton(UNCHECK_ALL, function()
            for index = 1, #expansionNames do state.expansions[index] = false end
            refresh(setsFrame)
            return MenuResponse.Refresh
        end)
        expansions:CreateDivider()
        for index, name in ipairs(expansionNames) do
            local expansionIndex = index
            expansions:CreateCheckbox(name, function() return state.expansions[expansionIndex] end, function()
                state.expansions[expansionIndex] = not state.expansions[expansionIndex]
                refresh(setsFrame)
            end)
        end

        local sources = root:CreateButton(SOURCES)
        sources:CreateButton(CHECK_ALL, function()
            for _, category in ipairs(SetSources.Categories) do state.sources[category.id] = true end
            refresh(setsFrame)
            return MenuResponse.Refresh
        end)
        sources:CreateButton(UNCHECK_ALL, function()
            for _, category in ipairs(SetSources.Categories) do state.sources[category.id] = false end
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
    LuckysEnsemble.DevLog(DEBUG_TAG .. " menu attached to " .. tostring(frame:GetName()))
end

function SetsBrowser:Init()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", function()
        LuckysEnsemble.DevLog(DEBUG_TAG .. " collections loaded; stock="
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
                if state.traceNextRead then
                    state.traceNextRead = nil
                    state.traceListApply = true
                    LuckysEnsemble.DevLog(DEBUG_TAG .. " GetBaseSets read; count=" .. #sorted
                        .. " mode=" .. state.sortMode .. " direction=" .. state.sortDirection
                        .. " before=" .. tostring(sets[1] and sets[1].setID)
                        .. " after=" .. tostring(sorted[1] and sorted[1].setID))
                end
                return sorted
            end
            LuckysEnsemble.DevLog(DEBUG_TAG .. " GetBaseSets wrapped")
        end

        local listContainer = WardrobeCollectionFrame and WardrobeCollectionFrame.SetsCollectionFrame
            and WardrobeCollectionFrame.SetsCollectionFrame.ListContainer
        if listContainer and type(listContainer.UpdateDataProvider) == "function"
            and not SetsBrowser.listHooked then
            SetsBrowser.listHooked = true
            hooksecurefunc(listContainer, "UpdateDataProvider", function(container)
                SetsBrowser:ApplyListOrder(container)
            end)
            LuckysEnsemble.DevLog(DEBUG_TAG .. " rendered list hooked")
        end

        if WardrobeCollectionFrame and type(WardrobeCollectionFrame.InitBaseSetsFilterButton) == "function"
            and not SetsBrowser.filterHooked then
            SetsBrowser.filterHooked = true
            hooksecurefunc(WardrobeCollectionFrame, "InitBaseSetsFilterButton", function(frame)
                LuckysEnsemble.DevLog(DEBUG_TAG .. " filter initializer ran")
                SetsBrowser:SetupFilterMenu(frame)
            end)
            LuckysEnsemble.DevLog(DEBUG_TAG .. " filter initializer hooked")
        end

        SetsBrowser:SetupFilterMenu(WardrobeCollectionFrame)
    end)
end
