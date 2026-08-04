-- luacheck: globals CHECK_ALL COLLECTED CollectionWardrobeUtil CreateFrame CreateDataProvider CreateScrollBoxListLinearView DEFAULT EventUtil GameTooltip GetUICameraInfo IsShiftKeyDown IsUnitModelReadyForUI LuckysWardrobe MenuResponse Mixin Model_ApplyUICamera NOT_COLLECTED PanelTemplates_ResizeTabsToFit PanelTemplates_SetNumTabs PanelTemplates_TabResize PlaySound QUESTION_MARK_ICON SOUNDKIT ScrollBoxConstants ScrollUtil UNCHECK_ALL UnitClass WardrobeCollectionFrame WardrobeSetsDetailsModelMixin hooksecurefunc C_TransmogSets C_TransmogCollection C_Item

LuckysWardrobe = {}

local devLogs = {}
LuckysWardrobe.DevLog = function(message) devLogs[#devLogs + 1] = message end

DEFAULT = "Default"
COLLECTED = "Collected"
NOT_COLLECTED = "Not Collected"
CHECK_ALL = "Check All"
UNCHECK_ALL = "Uncheck All"
MenuResponse = { Refresh = 1 }
for index = 0, 11 do _G["EXPANSION_NAME" .. index] = "Expansion " .. index end

dofile("src/Strings.lua")
dofile("src/ExtraSets.lua")

local ExtraSets = LuckysWardrobe.ExtraSets

-- Discovery has its own test (ExtraSetsCatalogTest.lua); here the catalogue
-- module is stubbed so the page logic can be driven directly.
local catalogRecords = {}
local catalogReady = true
local catalogBuildStarted = false
local catalogReadyCallback
LuckysWardrobe.ExtraSetsCatalog = {
    StartBuild = function() catalogBuildStarted = true end,
    IsReady = function() return catalogReady end,
    GetRecords = function() return catalogRecords end,
    OnReady = function(_, callback) catalogReadyCallback = callback end,
}

-- Schema validation.

local function validRecord(overrides)
    local record = {
        recordType = "TransmogSet",
        recordID = 20,
        name = "Test Garb",
        classMask = 0,
        build = "12.0.7.68887",
        slotSources = { HEAD = 2001, CHEST = 2003, LEGS = 2004 },
    }
    for key, value in pairs(overrides or {}) do record[key] = value end
    return record
end

assert(ExtraSets.ValidateRecord(validRecord()), "accepted a well-formed record")
assert(not ExtraSets.ValidateRecord(validRecord({ recordType = "Guess" })), "rejected unknown record types")
assert(not ExtraSets.ValidateRecord(validRecord({ recordID = 1.5 })), "rejected fractional record IDs")
assert(not ExtraSets.ValidateRecord(validRecord({ name = "" })), "rejected empty names")
local noBuild = validRecord()
noBuild.build = nil
assert(not ExtraSets.ValidateRecord(noBuild), "rejected records without a build")
local noMask = validRecord()
noMask.classMask = nil
assert(not ExtraSets.ValidateRecord(noMask), "rejected records without a class mask")
assert(ExtraSets.ValidateRecord(validRecord({ expansionID = 5 })), "accepted an optional expansion")
assert(not ExtraSets.ValidateRecord(validRecord({ expansionID = "five" })), "rejected non-numeric expansions")
assert(not ExtraSets.ValidateRecord(validRecord({ slotSources = {} })), "rejected records without pieces")
assert(not ExtraSets.ValidateRecord(validRecord({ slotSources = { ELBOW = 1 } })), "rejected unknown slots")
assert(
    not ExtraSets.ValidateRecord(validRecord({ slotSources = { HEAD = 7, CHEST = 7 } })),
    "rejected duplicate sources across slots"
)

-- Class mask maths.

assert(ExtraSets.ClassAllowed(0, 5), "zero mask allows every class")
assert(ExtraSets.ClassAllowed(4, 3), "mask bit matches its class")
assert(not ExtraSets.ClassAllowed(4, 1), "mask excludes other classes")
assert(ExtraSets.ClassAllowed(4, nil), "no class information means usable")

-- Entry building against a stub resolver.

local sourceStates = {
    [2001] = { appearanceID = 9001, collected = true },
    [2003] = { appearanceID = 9003, collected = false },
    [2004] = { appearanceID = 9003, collected = false }, -- same look as 2003
    [3001] = { appearanceID = 9101, collected = false },
    [3002] = {},                                         -- exists, still loading
}

local function stubResolver(classID)
    return {
        sourceState = function(sourceID) return sourceStates[sourceID] end,
        setName = function(record) return record.recordID == 20 and "Live Name" or nil end,
        playerClassID = function() return classID end,
    }
end

local records = {
    validRecord(),
    {
        recordType = "ItemSet",
        recordID = 500,
        name = "Loading Set",
        label = "Fixture",
        classMask = 4,
        build = "12.0.7.68887",
        slotSources = { HEAD = 3001, CHEST = 3002, LEGS = 3999 },
    },
    validRecord({ recordID = 21, slotSources = { HEAD = 4001, CHEST = 4002, LEGS = 4003 } }),
    { recordType = "Guess", recordID = 1 },
    validRecord(),
}

local entries = ExtraSets.BuildEntries(records, stubResolver(1))
assert(#entries == 3, "kept valid unique records only")
assert(#devLogs == 2, "reported both rejected records")

local garb = entries[1]
assert(garb.key == "TransmogSet:20", "keyed entries by Blizzard record type and ID")
assert(garb.name == "Live Name", "preferred the live runtime name")
assert(garb.collected == 1 and garb.total == 2, "counted shared appearances once")
assert(garb.missing == 1, "derived the missing count")
assert(garb.unavailable == 0 and not garb.loading, "fully resolvable set has no caveats")
assert(garb.usable, "unrestricted set is usable")
assert(garb.pieces[1].slot == "HEAD" and garb.pieces[1].state == "collected", "pieces keep slot order and state")
assert(garb.pieces[2].state == "missing" and garb.pieces[3].state == "missing", "uncollected pieces are missing")

local loadingSet = entries[2]
assert(loadingSet.name == "Loading Set", "fell back to the catalogue name")
assert(loadingSet.loading, "unresolved appearance data marks the entry loading")
assert(loadingSet.unavailable == 1, "unknown sources are counted unavailable")
assert(loadingSet.pieces[3].state == "unavailable", "the invalid source is labelled, not hidden")
assert(loadingSet.collected == 0 and loadingSet.total == 2, "unavailable pieces stay out of the totals")
assert(not loadingSet.usable, "class-restricted set is not usable for another class")
assert(ExtraSets.BuildEntries({ records[2] }, stubResolver(3))[1].usable, "matching class is usable")

-- Armour type is what actually gates most sets, and it reaches us as the
-- client's own per-source validity rather than through the class mask.
local armourResolver = {
    sourceState = function(sourceID)
        local state = sourceStates[sourceID]
        if not state then return nil end
        return {
            appearanceID = state.appearanceID,
            collected = state.collected,
            validForPlayer = sourceID ~= 2003,
        }
    end,
    setName = function() return nil end,
    playerClassID = function() return 1 end,
}
assert(not ExtraSets.BuildEntries({ records[1] }, armourResolver)[1].usable,
    "a set with a piece this character cannot use is not usable")

local wearableResolver = {
    sourceState = function(sourceID)
        local state = sourceStates[sourceID]
        if not state then return nil end
        return { appearanceID = state.appearanceID, collected = state.collected, validForPlayer = true }
    end,
    setName = function() return nil end,
    playerClassID = function() return 1 end,
}
assert(ExtraSets.BuildEntries({ records[1] }, wearableResolver)[1].usable,
    "a set this character can wear stays usable")

local ghost = entries[3]
assert(ghost.total == 0 and ghost.unavailable == 3, "a set with no valid sources stays visible")

-- Search.

assert(#ExtraSets.FilterEntries(entries, "") == 3, "blank query keeps everything")
assert(#ExtraSets.FilterEntries(entries, "  live  ") == 1, "matched trimmed case-insensitive names")
assert(#ExtraSets.FilterEntries(entries, "FIXTURE") == 1, "matched labels")
assert(#ExtraSets.FilterEntries(entries, "nothing") == 0, "unmatched query empties the list")

-- Sorting.

local sorted = ExtraSets.SortEntries(entries, "completion", "ascending")
assert(sorted[1].key == "TransmogSet:20", "closest-to-complete leads")
assert(sorted[2].key == "ItemSet:500", "more missing pieces follow")
assert(sorted[3].key == "TransmogSet:21", "sets with nothing resolvable sort last")
assert(ExtraSets.SortEntries(entries, "default", "ascending") == entries, "default order is untouched")
assert(entries[1].key == "TransmogSet:20", "sorting never mutates the source list")

local defaultDescending = ExtraSets.SortEntries(entries, "default", "descending")
assert(defaultDescending[1].key == entries[3].key and defaultDescending[3].key == entries[1].key,
    "descending reverses the default order")
local completionDescending = ExtraSets.SortEntries(entries, "completion", "descending")
assert(completionDescending[1].key == "TransmogSet:21" and completionDescending[3].key == "TransmogSet:20",
    "descending reverses the completion order")

-- Collected and expansion filters.

assert(ExtraSets.IsComplete({ loading = false, total = 2, collected = 2 }), "a full set counts as complete")
assert(not ExtraSets.IsComplete({ loading = true, total = 2, collected = 2 }), "loading sets are not complete yet")
assert(not ExtraSets.IsComplete({ loading = false, total = 0, collected = 0 }), "empty sets are never complete")

local completeEntry = { loading = false, total = 2, collected = 2, expansionID = 2 }
local partialEntry = { loading = false, total = 2, collected = 1, expansionID = 2 }
local unknownEntry = { loading = false, total = 3, collected = 0 }
local filterEntries = { completeEntry, partialEntry, unknownEntry }
local filterState = { collected = true, uncollected = true, expansions = { true, true } }

assert(#ExtraSets.ApplyFilters(filterEntries, filterState) == 3, "default filters keep everything")
filterState.collected = false
local uncollectedOnly = ExtraSets.ApplyFilters(filterEntries, filterState)
assert(#uncollectedOnly == 2 and uncollectedOnly[1] == partialEntry, "unchecking Collected hides complete sets")
filterState.collected = true
filterState.uncollected = false
local collectedOnly = ExtraSets.ApplyFilters(filterEntries, filterState)
assert(#collectedOnly == 1 and collectedOnly[1] == completeEntry, "unchecking Not Collected hides incomplete sets")
filterState.uncollected = true
filterState.expansions = { true, false }
local narrowedExpansions = ExtraSets.ApplyFilters(filterEntries, filterState)
assert(#narrowedExpansions == 1 and narrowedExpansions[1] == unknownEntry,
    "expansion narrowing hides matching sets but keeps unclassifiable ones")
filterState.expansions = { false, false }
assert(#ExtraSets.ApplyFilters(filterEntries, filterState) == 0, "unchecking every expansion empties the list")

-- UI harness: enough of the client to run CreatePage and Attach for real.

local createdFrames = {}
local capturedView

local function newFontString()
    local fontString = { shown = true }
    function fontString:SetPoint() end
    function fontString:SetWidth() end
    function fontString:SetTextColor() end
    function fontString:SetText(text) self.text = text end
    function fontString:SetFormattedText(format, ...) self.text = format:format(...) end
    function fontString:SetShown(shown) self.shown = shown end
    return fontString
end

local function newTexture()
    local texture = {}
    function texture:SetAtlas() end
    function texture:SetTexture(value) self.texture = value end
    function texture:SetDesaturated() end
    function texture:SetAlpha() end
    function texture:SetSize() end
    function texture:SetPoint() end
    function texture:SetHeight() end
    function texture:Hide() end
    return texture
end

function CreateFrame(frameType, name, parent, template)
    local frame = {
        frameType = frameType, name = name, parent = parent, template = template,
        scripts = {}, events = {}, shown = true,
        -- Children inherit the parent's level plus one, as in the client. The
        -- wardrobe starts high so a hardcoded low level would sink below the model.
        frameLevel = (parent and parent.frameLevel or 0) + 1,
    }
    function frame:SetScript(script, handler) self.scripts[script] = handler end
    function frame:HookScript(script, handler) self.scripts[script] = handler end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:RegisterForClicks() end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetShown(shown) self.shown = shown end
    function frame:IsShown() return self.shown end
    function frame:SetPoint() end
    function frame:SetAllPoints() end
    function frame:ClearAllPoints() end
    function frame:SetSize() end
    function frame:SetWidth() end
    function frame:SetFrameStrata() end
    function frame:SetFrameLevel(level) self.frameLevel = level end
    function frame:GetFrameLevel() return self.frameLevel end
    function frame:EnableMouse() end
    function frame:SetID(id) self.id = id end
    function frame:GetID() return self.id end
    function frame:SetText(text) self.text = text end
    function frame:GetText() return self.text or "" end
    function frame:GetName() return self.name end
    function frame:GetParent() return self.parent end
    frame.CreateFontString = function() return newFontString() end
    frame.CreateTexture = function() return newTexture() end
    function frame:SetMinMaxValues(minValue, maxValue) self.min, self.max = minValue, maxValue end
    function frame:SetValue(value) self.value = value end
    function frame:SetupMenu(builder) self.menuBuilder = builder end
    function frame:SetIsDefaultCallback(callback) self.isDefaultCheck = callback end
    function frame:SetDefaultCallback(callback) self.defaultReset = callback end
    function frame:SetDataProvider(provider) self.dataProvider = provider end
    function frame:ForEachFrame() end
    function frame:OnLoad() end
    function frame:Undress() self.triedOn = {} end
    function frame:TryOn(sourceID) table.insert(self.triedOn, sourceID) end
    function frame:RefreshCamera() end

    if template == "CollectionsBackgroundTemplate" then
        frame.BGCornerTopLeft = newTexture()
        frame.BGCornerTopRight = newTexture()
    elseif template == "CollectionsProgressBarTemplate" then
        frame.text = newFontString()
    end

    createdFrames[#createdFrames + 1] = frame
    if name then _G[name] = frame end
    return frame
end

local function findFrame(match)
    for _, frame in ipairs(createdFrames) do
        if match(frame) then return frame end
    end
end

function Mixin(target, mixin)
    for key, value in pairs(mixin or {}) do target[key] = value end
    return target
end

WardrobeSetsDetailsModelMixin = {}
CreateDataProvider = function(list) return list end
CreateScrollBoxListLinearView = function()
    capturedView = {
        SetElementInitializer = function(self, template, initializer)
            self.template = template
            self.initializer = initializer
        end,
        SetPadding = function() end,
    }
    return capturedView
end
ScrollUtil = { InitScrollBoxListWithScrollBar = function() end }
ScrollBoxConstants = { RetainScrollPosition = true }
local tooltip = { lines = {} }
GameTooltip = {
    SetOwner = function(_, owner)
        tooltip.owner = owner
        tooltip.lines = {}
        tooltip.appearanceData = nil
        tooltip.shown = false
    end,
    SetText = function(_, text) tooltip.lines[#tooltip.lines + 1] = text end,
    AddLine = function(_, text) tooltip.lines[#tooltip.lines + 1] = text end,
    SetHyperlink = function(_, link) tooltip.lines[#tooltip.lines + 1] = link end,
    Show = function() tooltip.shown = true end,
    Hide = function() tooltip.shown = false end,
}
CollectionWardrobeUtil = {
    SortSources = function(sources) tooltip.sortedSources = sources end,
    SetAppearanceTooltip = function(_, appearanceData)
        tooltip.appearanceData = appearanceData
    end,
}
QUESTION_MARK_ICON = 134400
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 42 }
local playedSound
function PlaySound(soundID) playedSound = soundID end
local shiftDown = false
function IsShiftKeyDown() return shiftDown end
function IsUnitModelReadyForUI() return true end
function UnitClass() return "Test", "TEST", 1 end
function Model_ApplyUICamera() end
function GetUICameraInfo() return 0, 0, 0, 0 end
function PanelTemplates_SetNumTabs(frame, count) frame.numTabs = count end
function PanelTemplates_TabResize() end
local resizeWidth
function PanelTemplates_ResizeTabsToFit(_, width) resizeWidth = width end

function hooksecurefunc(owner, method, hook)
    local original = owner[method]
    owner[method] = function(...)
        original(...)
        hook(...)
    end
end

local addonLoadedCallback
EventUtil = {
    ContinueOnAddOnLoaded = function(addonName, callback)
        assert(addonName == "Blizzard_Collections", "waited for the collections addon")
        addonLoadedCallback = callback
    end,
}

C_TransmogSets = {
    GetCameraIDs = function() return nil end,
    GetSetInfo = function(setID) return setID == 20 and { name = "Live Name" } or nil end,
}
C_TransmogCollection = {
    GetSourceInfo = function(sourceID)
        local state = sourceStates[sourceID]
        if not state then return nil end
        return {
            sourceID = sourceID,
            visualID = state.appearanceID,
            isCollected = state.sourceCollected or false,
        }
    end,
    GetAllAppearanceSources = function(visualID)
        local sources = {}
        for sourceID, state in pairs(sourceStates) do
            if state.appearanceID == visualID then sources[#sources + 1] = sourceID end
        end
        table.sort(sources)
        return sources
    end,
    -- MayReturnNothing in the client: it declines for looks outside the
    -- player's wardrobe context, which the stub models with outsideWardrobe.
    GetAppearanceInfoBySource = function(sourceID)
        local state = sourceStates[sourceID]
        if not state or state.appearanceID == nil or state.outsideWardrobe then return nil end
        return { appearanceID = state.appearanceID, appearanceIsCollected = state.collected }
    end,
    GetSourceIcon = function() return 1111 end,
    GetAppearanceSourceInfo = function() return nil end,
}
C_Item = { GetItemSetInfo = function() return nil end }

local trackedSources, trackedName
LuckysWardrobe.SetTracking = {
    TrackSources = function(_, sourceIDs, setName)
        trackedSources, trackedName = sourceIDs, setName
    end,
}

local function visibilityFrame(shown)
    return {
        shown = shown,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
    }
end

local wardrobe
wardrobe = {
    name = "WardrobeCollectionFrame",
    frameLevel = 20,
    numTabs = 2,
    selectedCollectionTab = 1,
    ItemsCollectionFrame = visibilityFrame(true),
    SetsCollectionFrame = visibilityFrame(false),
    SearchBox = visibilityFrame(true),
    FilterButton = visibilityFrame(true),
    ClassDropdown = visibilityFrame(true),
    progressBar = visibilityFrame(true),
    ContentFrames = {},
    GetName = function(self) return self.name end,
}
wardrobe.SetsCollectionFrame.searchType = 2

function wardrobe:SetTab(tabID)
    self.selectedCollectionTab = tabID
    if tabID == 1 then
        self.ItemsCollectionFrame:Show()
        self.SetsCollectionFrame:Hide()
    elseif tabID == 2 then
        self.ItemsCollectionFrame:Hide()
        self.SetsCollectionFrame:Show()
    end
end

function wardrobe:ClickTab(tab)
    self:SetTab(tab:GetID())
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

local originalSetTab = wardrobe.SetTab
WardrobeCollectionFrame = wardrobe

-- The live resolver has to answer for every source the client knows, or rows
-- sit on "Loading appearance data..." forever.

local liveResolver = ExtraSets.LiveResolver()
sourceStates[7001] = { appearanceID = 9701, collected = true, sourceCollected = true }
local inWardrobe = liveResolver.sourceState(7001)
assert(inWardrobe.appearanceID == 9701 and inWardrobe.collected == true,
    "used appearance-level collected state when the client offers it")

sourceStates[7002] = { appearanceID = 9702, collected = true, sourceCollected = false, outsideWardrobe = true }
local uncollectedOutside = liveResolver.sourceState(7002)
assert(uncollectedOutside.appearanceID == 9702, "fell back to the source's own visual")
assert(uncollectedOutside.collected == false, "resolved an uncollected look outside the wardrobe context")

sourceStates[7003] = { appearanceID = 9703, collected = false, sourceCollected = true, outsideWardrobe = true }
assert(liveResolver.sourceState(7003).collected == true,
    "fell back to the source's own collected flag rather than leaving it unresolved")

assert(liveResolver.sourceState(7999) == nil, "sources the client does not know stay unavailable")

local outsideRecord = validRecord({
    recordID = 70,
    slotSources = { HEAD = 7001, CHEST = 7002, LEGS = 7003 },
})
local outsideEntry = ExtraSets.BuildEntries({ outsideRecord }, liveResolver)[1]
assert(not outsideEntry.loading, "a set of looks outside the wardrobe context still resolves")
assert(outsideEntry.collected == 2 and outsideEntry.total == 3, "counted the fallback states")

sourceStates[7001], sourceStates[7002], sourceStates[7003] = nil, nil, nil

-- Attach through Init, exactly as Core does.

ExtraSets:Init()
assert(addonLoadedCallback, "deferred attach until the collections addon loads")
addonLoadedCallback()
assert(catalogBuildStarted, "started catalogue discovery when the collections addon loaded")
assert(catalogReadyCallback, "subscribed to catalogue completion")

local page = findFrame(function(frame) return frame.name == "LuckysWardrobeExtraSetsFrame" end)
local extraTab = findFrame(function(frame) return frame.template == "PanelTopTabButtonTemplate" end)
assert(page and extraTab, "created the Extra Sets page and subtab")
assert(page.shown == false, "kept the page hidden on the native tab")
assert(extraTab.name == "WardrobeCollectionFrameTab3" and extraTab.id == 3, "followed native tab naming and IDs")
assert(extraTab.text == "Extra Sets", "labelled the subtab")
assert(wardrobe.numTabs == 3, "registered exactly one extra subtab")
assert(wardrobe.ContentFrames[1] == page, "joined the native content lifecycle")
assert(page.searchType == wardrobe.SetsCollectionFrame.searchType, "kept the native search-event contract")
assert(resizeWidth ~= nil, "made room for the third tab")
assert(capturedView.template == "WardrobeSetsScrollFrameButtonTemplate", "reused the native sets row template")

-- Tab switching.

extraTab.scripts.OnClick()
assert(wardrobe.selectedCollectionTab == 3 and page.shown, "selected and showed Extra Sets")
assert(not wardrobe.ItemsCollectionFrame.shown and not wardrobe.SetsCollectionFrame.shown, "hid native pages")
assert(not wardrobe.SearchBox.shown and not wardrobe.FilterButton.shown, "hid native-only controls")
assert(not wardrobe.ClassDropdown.shown and not wardrobe.progressBar.shown, "hid the rest of the native controls")
assert(wardrobe.activeFrame == page, "became the active Appearances page")
assert(playedSound == SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "used the native tab sound")

wardrobe:SetTab(4)
assert(not page.shown and not wardrobe.SearchBox.shown, "left unknown third-party tabs alone")

wardrobe:SetTab(2)
assert(not page.shown and wardrobe.SetsCollectionFrame.shown, "restored the native Sets page")
assert(wardrobe.SearchBox.shown and wardrobe.FilterButton.shown and wardrobe.ClassDropdown.shown, "restored native controls")
assert(wardrobe.SetTab ~= originalSetTab, "hooked rather than replaced SetTab")

ExtraSets:Attach(wardrobe)
assert(wardrobe.numTabs == 3, "attach is idempotent")

-- Discovery lifecycle: building state first, then a repaint when the
-- catalogue lands while the page is open.

local scrollBox = findFrame(function(frame) return frame.template == "WowScrollBoxList" end)
catalogReady = false
wardrobe:SetTab(3)
page.scripts.OnShow(page)
assert(#scrollBox.dataProvider == 0, "no rows while discovery is running")

catalogReady = true
catalogRecords = { records[1], records[2] }
catalogReadyCallback()
assert(#scrollBox.dataProvider == 2, "catalogue completion repainted the open page")
for _, event in ipairs({
    "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT",
    "TRANSMOG_COLLECTION_ITEM_UPDATE", "TRANSMOG_COLLECTION_UPDATED",
}) do
    assert(page.events[event], "registered " .. event .. " while shown")
end
assert(#scrollBox.dataProvider == 2, "refresh populated the list from the catalogue")

local progressBar = findFrame(function(frame) return frame.template == "CollectionsProgressBarTemplate" end)
assert(progressBar.value == 0 and progressBar.max == 2, "no set is complete yet")

sourceStates[2003].collected = true
sourceStates[2004].collected = true
page.scripts.OnEvent(page, "TRANSMOG_COLLECTION_UPDATED")
assert(progressBar.value == 1, "collection events recompute completion live")

-- Search narrows the list through the page's own search box.

local searchBox = findFrame(function(frame) return frame.template == "SearchBoxTemplate" end)
searchBox.text = "Loading"
searchBox.scripts.OnTextChanged()
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].key == "ItemSet:500", "search filtered the list")
searchBox.text = ""
searchBox.scripts.OnTextChanged()
assert(#scrollBox.dataProvider == 2, "clearing the search restores the list")

-- Empty catalogue fallback.

catalogRecords = {}
page.scripts.OnEvent(page, "TRANSMOG_COLLECTION_UPDATED")
assert(#scrollBox.dataProvider == 0, "empty catalogue produces an empty list")
local emptyText
for _, frame in ipairs(createdFrames) do
    if frame.template == "InsetFrameTemplate" then emptyText = frame end
end
assert(emptyText, "left inset exists for the empty message")

page.scripts.OnHide(page)
assert(next(page.events) == nil, "unregistered every event on hide")

-- Row rendering and tracking.

catalogRecords = { records[1] }
page.scripts.OnShow(page)
local entry = scrollBox.dataProvider[1]

local button = {
    Name = newFontString(),
    Label = newFontString(),
    IconFrame = { Icon = newTexture(), Cover = { SetShown = function() end }, Favorite = { Hide = function() end } },
    New = { Hide = function() end },
    SelectedTexture = { SetShown = function() end },
    ProgressBar = { SetShown = function() end, SetWidth = function() end },
    SetScript = function(self, script, handler)
        self.scripts = self.scripts or {}
        self.scripts[script] = handler
    end,
}
button.IconFrame.SetScript = button.SetScript
capturedView.initializer(button, entry)
assert(button.Name.text == "Live Name", "row shows the set name")

shiftDown = true
button.scripts.OnClick(button, "LeftButton")
assert(trackedSources ~= nil and trackedName == "Live Name", "shift-click tracks the set's missing pieces")
assert(#trackedSources == 0, "only missing pieces are tracked")
shiftDown = false

sourceStates[2003].collected = false
sourceStates[2004].collected = false
page.scripts.OnEvent(page, "TRANSMOG_COLLECTION_UPDATED")
shiftDown = true
capturedView.initializer(button, scrollBox.dataProvider[1])
button.scripts.OnClick(button, "LeftButton")
assert(#trackedSources == 2, "both missing sources are tracked")
shiftDown = false

-- Piece tooltips. The details frame has to sit above the model or the model
-- swallows the hover and no tooltip ever appears.

local pieceButtons = {}
for _, frame in ipairs(createdFrames) do
    if frame.frameType == "Button" and frame.template == nil then
        pieceButtons[#pieceButtons + 1] = frame
    end
end
assert(#pieceButtons > 0, "created piece buttons")

local detailsFrame = pieceButtons[1].parent
local modelFrame = findFrame(function(frame) return frame.frameType == "DressUpModel" end)
assert(detailsFrame and modelFrame, "found the details frame and model")
assert(detailsFrame:GetFrameLevel() > modelFrame:GetFrameLevel(),
    "details frame sits above the model so pieces stay hoverable")

local collectedPiece = pieceButtons[1]
assert(collectedPiece.piece.state == "collected", "first piece is the collected one")
collectedPiece.scripts.OnEnter(collectedPiece)
assert(tooltip.owner == collectedPiece, "anchored the tooltip to the hovered piece")
assert(tooltip.appearanceData, "built a native appearance tooltip")
assert(tooltip.appearanceData.primarySourceID == collectedPiece.piece.sourceID,
    "passed the catalogued source as the primary one")
assert(#tooltip.appearanceData.sources > 0, "listed at least one source")
assert(tooltip.shown, "showed the tooltip")

local missingPiece = pieceButtons[2]
assert(missingPiece.piece.state == "missing", "second piece is missing")
missingPiece.scripts.OnEnter(missingPiece)
assert(tooltip.appearanceData, "missing pieces still get the native tooltip")
assert(tooltip.lines[#tooltip.lines] == LuckysWardrobe.Strings.extraSets.trackHint,
    "missing pieces mention shift-click tracking")

collectedPiece.scripts.OnLeave(collectedPiece)
assert(not tooltip.shown, "leaving a piece hides the tooltip")

catalogRecords = { records[2] }
page.scripts.OnEvent(page, "TRANSMOG_COLLECTION_UPDATED")
local unavailablePiece
for _, frame in ipairs(pieceButtons) do
    if frame.piece and frame.piece.state == "unavailable" then unavailablePiece = frame end
end
assert(unavailablePiece, "found the unavailable piece")
unavailablePiece.scripts.OnEnter(unavailablePiece)
assert(tooltip.appearanceData == nil, "unavailable pieces skip the appearance tooltip")
assert(tooltip.lines[1] == LuckysWardrobe.Strings.extraSets.pieceUnavailable,
    "unavailable pieces say so honestly")
assert(tooltip.shown, "unavailable pieces still show a tooltip")

catalogRecords = { records[1] }
page.scripts.OnEvent(page, "TRANSMOG_COLLECTION_UPDATED")

-- Filter menu, mirroring the Sets tab.

local filterButton = findFrame(function(frame) return frame.template == "WowStyle1FilterDropdownTemplate" end)
assert(filterButton, "created the native-style filter button")
assert(type(filterButton.menuBuilder) == "function", "attached the filter menu")
assert(filterButton.isDefaultCheck(), "filters start in the default state")

records[1].expansionID = 3
sourceStates[2003].collected = true
sourceStates[2004].collected = true
catalogRecords = { records[1], records[2] }
page.scripts.OnEvent(page, "TRANSMOG_COLLECTION_UPDATED")
assert(#scrollBox.dataProvider == 2, "both sets are on screen before filtering")
assert(scrollBox.dataProvider[1].expansionID == 3, "entries carry their expansion")

local toggles = {}
local radioSetters = {}
local expansionToggles = {}
local menuActions = {}
local function submenu(label)
    return {
        CreateCheckbox = function(_, boxLabel, _isChecked, toggle)
            if label == "Expansion" then expansionToggles[boxLabel] = toggle end
        end,
        CreateRadio = function(_, radioLabel, _isSelected, setSelected)
            radioSetters[label] = radioSetters[label] or {}
            radioSetters[label][radioLabel] = setSelected
        end,
        CreateButton = function(_, buttonLabel, callback)
            menuActions[label] = menuActions[label] or {}
            menuActions[label][buttonLabel] = callback
        end,
        CreateDivider = function() end,
    }
end
local menuRoot = {
    CreateCheckbox = function(_, label, _isChecked, toggle) toggles[label] = toggle end,
    CreateDivider = function() end,
    CreateButton = function(_, label) return submenu(label) end,
}
filterButton.menuBuilder(nil, menuRoot)
assert(toggles[COLLECTED] and toggles[NOT_COLLECTED], "offered the collected checkboxes")

toggles[NOT_COLLECTED]()
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].key == "TransmogSet:20",
    "hiding Not Collected leaves only the complete set")
assert(progressBar.value == 1 and progressBar.max == 1, "the progress bar counts only what filters leave")
assert(not filterButton.isDefaultCheck(), "narrowed filters are no longer the default")
toggles[NOT_COLLECTED]()

toggles[COLLECTED]()
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].key == "ItemSet:500",
    "hiding Collected leaves only the incomplete set")
toggles[COLLECTED]()

expansionToggles["Expansion 2"]()
assert(#scrollBox.dataProvider == 1 and scrollBox.dataProvider[1].key == "ItemSet:500",
    "unchecking a set's expansion hides it but keeps unclassifiable sets")
menuActions.Expansion[UNCHECK_ALL]()
assert(#scrollBox.dataProvider == 0, "unchecking every expansion empties the list")

filterButton.defaultReset()
assert(#scrollBox.dataProvider == 2, "resetting filters restores the list")
assert(filterButton.isDefaultCheck(), "reset filters read as the default state")

radioSetters["Sort By"].Completion()
assert(scrollBox.dataProvider[1].key == "TransmogSet:20", "completion sort puts the complete set first")
radioSetters["Sort Direction"].Descending()
assert(scrollBox.dataProvider[1].key == "ItemSet:500", "descending inverts the completion order")

print("Lucky's Wardrobe extra sets tests passed")
