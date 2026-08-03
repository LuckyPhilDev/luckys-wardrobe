-- luacheck: globals C_TransmogSets CreateDataProvider DEFAULT EventUtil EXPANSION_NAME0 EXPANSION_NAME1 EXPANSION_NAME2 EXPANSION_NAME3 EXPANSION_NAME4 EXPANSION_NAME5 EXPANSION_NAME6 EXPANSION_NAME7 EXPANSION_NAME8 EXPANSION_NAME9 EXPANSION_NAME10 EXPANSION_NAME11 LuckysEnsemble ScrollBoxConstants WardrobeCollectionFrame hooksecurefunc
-- luacheck: ignore 121

local devLogs = {}
LuckysEnsemble = {
    DevLog = function(message) devLogs[#devLogs + 1] = message end,
}
DEFAULT = "Default"
for index = 0, 11 do _G["EXPANSION_NAME" .. index] = "Expansion " .. index end

C_TransmogSets = {
    GetBaseSets = function()
        return {
            { setID = 2, expansionID = 1, favorite = false },
            { setID = 1, expansionID = 1, favorite = false },
        }
    end,
    GetSetPrimaryAppearances = function(setID)
        return ({
            [1] = { { collected = true }, { collected = true }, { collected = false } },
            [2] = { { collected = true }, { collected = false } },
            [3] = { { collected = false } },
        })[setID] or {}
    end,
    GetVariantSets = function() return {} end,
}

dofile("src/SetsBrowser.lua")

local browser = LuckysEnsemble.SetsBrowser
local sorted = browser:FilterAndSort({
    { setID = 1, expansionID = 1, favorite = false },
    { setID = 2, expansionID = 1, favorite = false },
    { setID = 3, expansionID = 2, favorite = false },
})
assert(sorted[1].setID == 3, "use Blizzard's expansion-first order by default")
assert(sorted[2].setID == 2, "use Blizzard's set order within an expansion")
assert(sorted[3].setID == 1, "leave older sets later in the default order")

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
local setsFrame = {
    init = true,
    ListContainer = listContainer,
    OnSearchUpdate = function()
        refreshes = refreshes + 1
        listContainer:UpdateDataProvider()
    end,
}
WardrobeCollectionFrame = {
    FilterButton = filterButton,
    SetsCollectionFrame = setsFrame,
    GetName = function() return "WardrobeCollectionFrame" end,
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
assert(type(filterButton.menu) == "function", "restored the Ensemble menu after Blizzard rebuilt it")
assert(C_TransmogSets.GetBaseSets()[1].setID == 2, "returned Blizzard's default order initially")
assert(#devLogs > 0, "reported the in-game hook state through Dev Mode")

local sortLabels, sortSetters = {}, {}
local root = {
    CreateCheckbox = function() end,
    CreateDivider = function() end,
    CreateButton = function(_, label)
        return {
            CreateButton = function() end,
            CreateDivider = function() end,
            CreateCheckbox = function() end,
            CreateRadio = function(_, radioLabel, _isSelected, setSelected)
                if label == "Sort By" then
                    sortLabels[#sortLabels + 1] = radioLabel
                    sortSetters[radioLabel] = setSelected
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

print("Lucky's Ensemble sets browser test passed")
