-- luacheck: globals C_TransmogSets CreateDataProvider DEFAULT EventUtil GRAY_FONT_COLOR IN_PROGRESS_FONT_COLOR NORMAL_FONT_COLOR EXPANSION_NAME0 EXPANSION_NAME1 EXPANSION_NAME2 EXPANSION_NAME3 EXPANSION_NAME4 EXPANSION_NAME5 EXPANSION_NAME6 EXPANSION_NAME7 EXPANSION_NAME8 EXPANSION_NAME9 EXPANSION_NAME10 EXPANSION_NAME11 LuckysWardrobe SOURCES ScrollBoxConstants WardrobeCollectionFrame hooksecurefunc
-- luacheck: ignore 121

local devLogs = {}
LuckysWardrobe = {
    DevLog = function(message) devLogs[#devLogs + 1] = message end,
}
DEFAULT = "Default"
SOURCES = "Sources"
-- Blizzard's own row colours, which the tab paints a set's progress in.
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
IN_PROGRESS_FONT_COLOR = { r = 0.251, g = 0.753, b = 0.251 }
GRAY_FONT_COLOR = { r = 0.5, g = 0.5, b = 0.5 }
for index = 0, 11 do _G["EXPANSION_NAME" .. index] = "Expansion " .. index end

local testSets = {
    { setID = 2, expansionID = 1, favorite = false },
    { setID = 1, expansionID = 1, favorite = false },
}
local collectedSets = {}
-- Which looks the player holds, so a row can be redrawn part way through a set.
local collectedAppearances = { [901] = true, [902] = true }
-- Sets the game itself would never put on this list, which is how another class's
-- set reads to the Sets tab.
local unlistedSets = {}
C_TransmogSets = {
    GetBaseSets = function() return testSets end,
    GetBaseSetID = function(setID) return setID end,
    IsSetVisible = function(setID) return not unlistedSets[setID] end,
    IsBaseSetCollected = function(setID) return collectedSets[setID] == true end,
    -- Blizzard's own counter, which sees only its own filters and so always
    -- covers the whole list our own filters are narrowing.
    GetFilteredBaseSetsCounts = function()
        local collected = 0
        for _, set in ipairs(testSets) do
            if collectedSets[set.setID] then collected = collected + 1 end
        end
        return collected, #testSets
    end,
    GetSetPrimaryAppearances = function(setID)
        return ({
            [1] = { { collected = true }, { collected = true }, { collected = false } },
            [2] = { { collected = true }, { collected = false } },
            [3] = { { collected = false } },
            -- A tier and its difficulty recolours. The two colourways are
            -- different looks but for the one piece that was never retinted,
            -- which both of them grant.
            [70] = {
                { appearanceID = 901, collected = collectedAppearances[901] or false },
                { appearanceID = 902, collected = collectedAppearances[902] or false },
                { appearanceID = 909, collected = collectedAppearances[909] or false },
            },
            [71] = {
                { appearanceID = 911, collected = collectedAppearances[911] or false },
                { appearanceID = 912, collected = collectedAppearances[912] or false },
                { appearanceID = 909, collected = collectedAppearances[909] or false },
            },
        })[setID] or {}
    end,
    GetVariantSets = function(setID)
        return ({
            [4] = { { setID = 41, favorite = true } },
            -- The client lists a set among its own variants, which is why the
            -- base is counted alongside them rather than instead of them.
            [70] = { { setID = 70 }, { setID = 71 } },
        })[setID] or {}
    end,
}

dofile("src/Strings.lua")
dofile("src/Utils.lua")
dofile("src/SetSearch.lua")
dofile("src/SetSources.lua")
dofile("src/SetsBrowser.lua")

local browser = LuckysWardrobe.SetsBrowser
local sorted = browser:FilterAndSort({
    { setID = 1, expansionID = 1, favorite = false },
    { setID = 2, expansionID = 1, favorite = false },
    { setID = 3, expansionID = 2, favorite = false },
})
assert(sorted[1].setID == 3, "use Blizzard's expansion-first order by default")
assert(sorted[2].setID == 2, "use Blizzard's set order within an expansion")
assert(sorted[3].setID == 1, "leave older sets later in the default order")

-- Blizzard numbers expansions from 0 for Classic, so a set from the oldest
-- expansion has to survive the default filter like any other. Keying the filter
-- as a 1-based array silently dropped every vanilla set from the Sets tab.
local withClassic = browser:FilterAndSort({
    { setID = 1, expansionID = 0, favorite = false },
    { setID = 3, expansionID = 2, favorite = false },
})
assert(#withClassic == 2, "a Classic set survives the default filter, got " .. #withClassic)
assert(withClassic[2].setID == 1, "and sorts oldest last")

local withFavorite = browser:FilterAndSort({
    { setID = 1, expansionID = 1, favorite = false },
    { setID = 2, expansionID = 1, favorite = true },
    { setID = 3, expansionID = 2, favorite = false },
})
assert(withFavorite[1].setID == 2, "surface a favourited set above newer expansions")
assert(withFavorite[2].setID == 3, "keep the expansion order below the favourites")

local withFavoriteVariant = browser:FilterAndSort({
    { setID = 1, expansionID = 1, favorite = false },
    { setID = 3, expansionID = 2, favorite = false },
    { setID = 4, expansionID = 1, favorite = false },
})
assert(withFavoriteVariant[1].setID == 4, "surface a set whose variant is favourited")

local filterButton = {
    SetIsDefaultCallback = function(self, callback) self.defaultCheck = callback end,
    SetDefaultCallback = function(self, callback) self.defaultSet = callback end,
    SetupMenu = function(self, callback) self.menu = callback end,
}
CreateDataProvider = function(elements) return elements end
ScrollBoxConstants = { RetainScrollPosition = 1 }

local refreshes = 0
local scrollBox = {
    SetDataProvider = function(self, provider) self.dataProvider = provider end,
}
local listContainer = {
    ScrollBox = scrollBox,
    UpdateDataProvider = function(self)
        local sets = C_TransmogSets.GetBaseSets()
        table.sort(sets, function(left, right) return left.setID > right.setID end)
        self.ScrollBox:SetDataProvider(CreateDataProvider(sets))
    end,
    UpdateListSelection = function() end,
}
local progressBar = {}
local setsFrame = {
    init = true,
    ListContainer = listContainer,
    OnSearchUpdate = function(self)
        refreshes = refreshes + 1
        listContainer:UpdateDataProvider()
        self:UpdateProgressBar()
    end,
    UpdateProgressBar = function(self)
        self:GetParent():UpdateProgressBar(C_TransmogSets.GetFilteredBaseSetsCounts())
    end,
    GetParent = function() return WardrobeCollectionFrame end,
    GetSelectedSetID = function(self) return self.selectedSetID end,
    SelectSet = function(self, setID) self.selectedSetID = setID end,
    GetDefaultSetIDForBaseSet = function(_, baseSetID) return baseSetID end,
    DisplaySet = function(self, setID) self.displayedSetID = setID end,
}
listContainer.GetParent = function() return setsFrame end
WardrobeCollectionFrame = {
    FilterButton = filterButton,
    SetsCollectionFrame = setsFrame,
    GetName = function() return "WardrobeCollectionFrame" end,
    UpdateProgressBar = function(_, value, max)
        progressBar.value, progressBar.max = value, max
    end,
    InitBaseSetsFilterButton = function(self)
        self.FilterButton.menu = "stock"
    end,
}
EventUtil = { ContinueOnAddOnLoaded = function(_, callback) callback() end }
function hooksecurefunc(target, method, callback)
    local original = target[method]
    target[method] = function(...)
        original(...)
        callback(...)
    end
end

browser:Init()
assert(filterButton.menu, "attached the filter menu to the Collections Journal Sets tab")
filterButton.menu = nil
WardrobeCollectionFrame:InitBaseSetsFilterButton()
assert(type(filterButton.menu) == "function", "restored our filter menu after Blizzard rebuilt it")
assert(C_TransmogSets.GetBaseSets()[1].setID == 2, "returned Blizzard's default order initially")
assert(#devLogs > 0, "reported the in-game hook state through Dev Mode")

local sortLabels, sortSetters, directionSetters = {}, {}, {}
local sourceToggles = {}
local root = {
    CreateCheckbox = function() end,
    CreateDivider = function() end,
    CreateButton = function(_, label)
        return {
            CreateButton = function() end,
            CreateDivider = function() end,
            CreateCheckbox = function(_, checkboxLabel, _isChecked, toggle)
                if label == SOURCES then
                    sourceToggles[checkboxLabel] = toggle
                end
            end,
            CreateRadio = function(_, radioLabel, _isSelected, setSelected)
                if label == "Sort By" then
                    sortLabels[#sortLabels + 1] = radioLabel
                    sortSetters[radioLabel] = setSelected
                elseif label == "Sort Direction" then
                    directionSetters[radioLabel] = setSelected
                end
            end,
        }
    end,
}
filterButton.menu(nil, root)
assert(sortLabels[1] == "Default" and sortLabels[2] == "Completion",
    "listed Default before Completion")
sortSetters.Completion()
assert(refreshes == 1, "refreshed the Sets list after choosing Completion")
assert(scrollBox.dataProvider[1].setID == 1, "preserved completion order at the rendered list")
assert(C_TransmogSets.GetBaseSets()[1].setID == 1, "returned completion order after the menu click")

sortSetters.Default()
directionSetters.Descending()
local descending = browser:FilterAndSort({
    { setID = 1, expansionID = 1, favorite = false },
    { setID = 2, expansionID = 1, favorite = true },
    { setID = 3, expansionID = 2, favorite = false },
})
assert(descending[1].setID == 2, "keep favourites on top when sorting descending")
assert(descending[2].setID == 1, "reverse the remaining sets when sorting descending")
directionSetters.Ascending()

sortSetters.Completion()
local byCompletion = browser:FilterAndSort({
    { setID = 1, expansionID = 1, favorite = false },
    { setID = 2, expansionID = 1, favorite = false },
    { setID = 3, expansionID = 2, favorite = true },
})
assert(byCompletion[1].setID == 1, "sort strictly by completion rather than by favourite")
assert(byCompletion[3].setID == 3, "leave a favourited set at the completion position it earned")

assert(sourceToggles["Raid"] and sourceToggles["Miscellaneous"],
    "listed a checkbox per source category in the Sources submenu")

testSets = {
    { setID = 5, expansionID = 1, favorite = false, description = "Mythic", classMask = 4 },
    { setID = 4, expansionID = 1, favorite = false, classMask = 4 },
}
collectedSets = { [4] = true }
setsFrame.selectedSetID = 4
setsFrame:OnSearchUpdate()
assert(progressBar.value == 1 and progressBar.max == 2,
    "counted the whole list while nothing was unticked")

local refreshesBefore = refreshes
sourceToggles["Miscellaneous"]()
assert(refreshes == refreshesBefore + 1, "refreshed the Sets list after unticking a source")
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].setID == 5,
    "hid the sets whose source was unticked")
assert(setsFrame.selectedSetID == 5, "moved the selection off the hidden set")
assert(progressBar.value == 0 and progressBar.max == 1,
    "counted only the sets left after filtering")

setsFrame.displayedSetID = 5
sourceToggles["Raid"]()
assert(#scrollBox.dataProvider == 0, "emptied the list with every reachable source unticked")
assert(setsFrame.selectedSetID == nil and setsFrame.displayedSetID == nil,
    "cleared the selection and details panel with nothing left to show")
assert(progressBar.value == 0 and progressBar.max == 0, "counted nothing with the list empty")

-- Another class's set, put on screen by the instance list. The game does not list
-- it here at all, so nothing of ours hid it and nothing of ours should replace it.
sourceToggles["Raid"]()
unlistedSets[9] = true
setsFrame.selectedSetID, setsFrame.displayedSetID = 9, 9
setsFrame:OnSearchUpdate()
assert(setsFrame.selectedSetID == 9 and setsFrame.displayedSetID == 9,
    "a set opened from outside the list was replaced by one from it")

-- A set the list would hold and the filters took away is still moved off, which is
-- the case this reselect exists for.
setsFrame.selectedSetID = 4
setsFrame:OnSearchUpdate()
assert(setsFrame.selectedSetID == 5, "the selection stayed on a set the filters had hidden")

-- Colourways on the Sets tab. Blizzard's row counts the best single difficulty,
-- which says nothing about how much of the set is left to collect.

local counts = browser:VariantCounts(70)
assert(counts.colourways == 2, "counted the colourways the client lists")
assert(counts.total == 5, "counted five distinct looks, not the six the two colourways list between them")
assert(counts.collected == 2, "and counted what is collected across all of them")
assert(browser:VariantCounts(1) == nil, "a set with no colourways has nothing to count")
assert(browser:VariantCounts(4) == nil, "nor has one the client lists a single variant for")

local function newRowButton(setID)
    return {
        setID = setID,
        Name = {
            SetWidth = function(self, width) self.width = width end,
            SetTextColor = function(self, r, g, b) self.colour = { r, g, b } end,
        },
        Label = { SetText = function(self, text) self.text = text end },
        IconFrame = { SetIconCoverShown = function(self, shown) self.cover = shown end },
        ProgressBar = {
            SetShown = function(self, shown) self.shown = shown end,
            SetWidth = function(self, width) self.width = width end,
        },
        CreateFontString = function()
            return {
                SetPoint = function() end,
                SetTextColor = function() end,
                SetText = function(self, text) self.text = text end,
            }
        end,
    }
end

local rows = { newRowButton(70), newRowButton(1) }
browser:MarkVariants({ ForEachFrame = function(_, action)
    for _, row in ipairs(rows) do action(row) end
end })
assert(rows[1].luckysVariantCount.text == "x2", "the row says how many colourways stand behind it")
assert(rows[1].Label.text == "2/5 collected", "and counts every look across them under the name")
assert(rows[1].Name.width == 168, "the name gives up the width the badge needs")
assert(rows[2].luckysVariantCount.text == "" and rows[2].Name.width == 190,
    "a set with one colourway is left as Blizzard drew it")
assert(rows[2].Label.text == nil, "keeping the difficulty label the tab put there")
assert(rows[2].ProgressBar.shown == nil and rows[2].Name.colour == nil,
    "and its progress untouched, being about the only colourway there is")

-- The bar is the same statement as the counts beside it. Blizzard fills it from
-- the best single difficulty, which on this set would read as nearly half.
assert(rows[1].ProgressBar.shown == true, "a part-collected set shows its bar")
assert(math.abs(rows[1].ProgressBar.width - 204 * 2 / 5) < 0.001,
    "filled to what is collected across every colourway, got " .. tostring(rows[1].ProgressBar.width))
assert(rows[1].Name.colour[2] == IN_PROGRESS_FONT_COLOR.g, "and the name reads as still in progress")
assert(rows[1].IconFrame.cover == true, "with the icon still covered")

-- Finishing one difficulty is what makes Blizzard call the whole set collected.
-- Every look of the other one is still out there.
collectedAppearances = { [901] = true, [902] = true, [909] = true }
local oneDifficultyDone = { newRowButton(70) }
browser:MarkVariants({ ForEachFrame = function(_, action)
    for _, row in ipairs(oneDifficultyDone) do action(row) end
end })
local row = oneDifficultyDone[1]
assert(row.Label.text == "3/5 collected", "the row counts what is left across the rest")
assert(row.ProgressBar.shown == true and row.Name.colour[1] == IN_PROGRESS_FONT_COLOR.r,
    "and neither the bar nor the name calls the set finished")
assert(row.IconFrame.cover == true, "nor does the icon")

-- Nothing collected anywhere, and the whole lot collected, are the two ends.
collectedAppearances = {}
local untouched = newRowButton(70)
browser:MarkVariants({ ForEachFrame = function(_, action) action(untouched) end })
assert(untouched.ProgressBar.shown == false and untouched.Name.colour[1] == GRAY_FONT_COLOR.r,
    "a set with nothing collected shows no bar at all")

collectedAppearances = { [901] = true, [902] = true, [909] = true, [911] = true, [912] = true }
local finished = newRowButton(70)
browser:MarkVariants({ ForEachFrame = function(_, action) action(finished) end })
assert(finished.Label.text == "5/5 collected", "every look across every colourway")
assert(finished.ProgressBar.shown == false and finished.Name.colour[1] == NORMAL_FONT_COLOR.r,
    "and only then does the row read as finished")
assert(finished.IconFrame.cover == false, "the cover coming off the icon with it")

print("Lucky's Wardrobe sets browser test passed")
