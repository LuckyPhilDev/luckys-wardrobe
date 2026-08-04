-- luacheck: globals C_Timer C_TransmogCollection C_TransmogOutfitInfo Constants CreateFrame Enum LuckysWardrobe TRANSMOG_SLOTS TransmogFrame hooksecurefunc math

LuckysWardrobe = {}

local eventFrame
local watcher
local createdFrames = {}

-- SetScript keeps handlers off the frame table, the way the real client does,
-- so a mixin method and a script of the same name can both exist.
function CreateFrame(_, _, parent, template)
    local frame = {
        parent = parent,
        template = template,
        scripts = {},
        shown = true,
        RegisterEvent = function() end,
        SetScript = function(self, script, handler) self.scripts[script] = handler end,
        GetScript = function(self, script) return self.scripts[script] end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetPoint = function(self, point, x, y) self.point, self.x, self.y = point, x, y end,
        SetFrameLevel = function(self, level) self.level = level end,
        GetFrameLevel = function(self) return self.level or 1 end,
        SetAtlas = function(self, atlas) self.atlas = atlas end,
        OnMouseDown = function(self) self.depressed = true end,
        OnMouseUp = function(self) self.depressed = false end,
    }
    table.insert(createdFrames, frame)
    if not parent then
        if not eventFrame then eventFrame = frame else watcher = frame end
    end
    return frame
end

C_Timer = { After = function(_, callback) callback() end }

local tabHeaders = { selectedTabID = 2 }
local wardrobeCollection = {
    TabHeaders = tabHeaders,
    SetTab = function(_, tabID) tabHeaders.selectedTabID = tabID end,
}

function hooksecurefunc(target, method, callback)
    local original = target[method]
    target[method] = function(...)
        original(...)
        callback(...)
    end
end

Enum = {
    TransmogType = { Appearance = 0, Illusion = 1 },
    TransmogOutfitSlotOption = { None = 0 },
    TransmogOutfitDisplayType = { Unassigned = 0, Assigned = 1, Equipped = 2, Hidden = 3, Disabled = 4 },
}
Constants = { TransmogOutfitDataConsts = { TRANSMOG_OUTFIT_SLOT_NONE = -1 } }

-- Slot IDs the fixture rolls, plus one of each thing that must be left alone.
local HEAD, BACK = 0, 3
local CHEST, MAINHAND, SHOULDER_LEFT, TABARD, WRIST, FEET, ILLUSION_SLOT = 4, 12, 2, 5, 7, 11, 90

local CATEGORY = {
    [HEAD] = 101, [BACK] = 102, [CHEST] = 103, [MAINHAND] = 104,
    [SHOULDER_LEFT] = 105, [TABARD] = 106, [WRIST] = 107, [FEET] = 108,
    [ILLUSION_SLOT] = 109,
}

local function makeLocation(slot, options)
    options = options or {}
    local data = { slotID = slot }
    return {
        GetSlot = function() return slot end,
        GetType = function() return options.transmogType or Enum.TransmogType.Appearance end,
        GetData = function() return data end,
        IsAppearance = function()
            return (options.transmogType or Enum.TransmogType.Appearance) == Enum.TransmogType.Appearance
        end,
        IsSecondary = function() return options.isSecondary == true end,
    }
end

local function slotEntry(slot, options)
    return { location = makeLocation(slot, options), armorCategoryID = CATEGORY[slot] }
end

TRANSMOG_SLOTS = {
    [1] = slotEntry(HEAD),
    [2] = slotEntry(BACK),
    [3] = slotEntry(CHEST),
    [4] = slotEntry(MAINHAND),
    [5] = slotEntry(SHOULDER_LEFT, { isSecondary = true }),
    [6] = slotEntry(TABARD),
    [7] = slotEntry(WRIST),
    [8] = slotEntry(FEET),
    [9] = slotEntry(ILLUSION_SLOT, { transmogType = Enum.TransmogType.Illusion }),
}

-- The one appearance per slot that a roll should land on, and the one source it
-- should resolve to.
local VISUAL, SOURCE = {}, {}
for slot, category in pairs(CATEGORY) do
    VISUAL[slot] = 700 + category
    SOURCE[slot] = 7000 + category * 10
end

-- Every pool carries two decoys. They resolve to sources of their own, so a
-- filter that lets one through queues a visibly wrong appearance rather than
-- quietly failing to resolve.
local UNCOLLECTED_VISUAL, UNUSABLE_VISUAL = 1, 2

local function pool(slot, extra)
    local entry = { visualID = VISUAL[slot], isCollected = true, isUsable = true }
    for key, value in pairs(extra or {}) do entry[key] = value end
    return {
        { visualID = UNCOLLECTED_VISUAL, isCollected = false, isUsable = true },
        { visualID = UNUSABLE_VISUAL, isCollected = true, isUsable = false },
        entry,
    }
end

-- A counter per pool size in place of chance. Every slot but the head has one
-- eligible appearance, so only the head's rolls vary, and they alternate: a
-- repeated selection can then only come from the settle sending the last one
-- again.
local ALTERNATE_VISUAL, ALTERNATE_SOURCE = 999, 9990
local rollCounts = {}
math.random = function(n)
    rollCounts[n] = (rollCounts[n] or 0) + 1
    return (rollCounts[n] % n) + 1
end

local categoryAppearances = {}
for slot in pairs(CATEGORY) do
    categoryAppearances[CATEGORY[slot]] = pool(slot)
end
categoryAppearances[CATEGORY[BACK]] = pool(BACK, { isHideVisual = true })
categoryAppearances[CATEGORY[WRIST]] = nil -- MayReturnNothing
table.insert(categoryAppearances[CATEGORY[HEAD]],
    { visualID = ALTERNATE_VISUAL, isCollected = true, isUsable = true })

-- The one to pick is last, behind an uncollected source and a collected one the
-- character may not wear.
local appearanceSources = {}
for slot in pairs(CATEGORY) do
    appearanceSources[VISUAL[slot]] = {
        { sourceID = SOURCE[slot] - 2, isCollected = false, isValidSourceForPlayer = true },
        { sourceID = SOURCE[slot] - 1, isCollected = true, isValidSourceForPlayer = false },
        { sourceID = SOURCE[slot], isCollected = true, isValidSourceForPlayer = true },
    }
end
-- The hide visual's lone source is not flagged valid for the player.
appearanceSources[VISUAL[BACK]] = {
    { sourceID = SOURCE[BACK], isCollected = true, isValidSourceForPlayer = false },
}
appearanceSources[VISUAL[FEET]] = nil -- MayReturnNothing
appearanceSources[ALTERNATE_VISUAL] = {
    { sourceID = ALTERNATE_SOURCE, isCollected = true, isValidSourceForPlayer = true },
}
appearanceSources[UNCOLLECTED_VISUAL] = {
    { sourceID = 11, isCollected = true, isValidSourceForPlayer = true },
}
appearanceSources[UNUSABLE_VISUAL] = {
    { sourceID = 12, isCollected = true, isValidSourceForPlayer = true },
}

local hiddenVisuals = { [VISUAL[BACK]] = true }
local hiddenChecks = {}
local pendingCalls = {}
local canTransmogrify = {
    [HEAD] = true, [BACK] = true, [CHEST] = false, [MAINHAND] = true,
    [SHOULDER_LEFT] = true, [FEET] = true, [ILLUSION_SLOT] = true,
    -- TABARD is absent, so its slot info comes back as nothing at all.
}

C_TransmogCollection = {
    GetCategoryAppearances = function(category) return categoryAppearances[category] end,
    GetAppearanceSources = function(visualID) return appearanceSources[visualID] end,
    IsAppearanceHiddenVisual = function(appearanceID)
        table.insert(hiddenChecks, appearanceID)
        return hiddenVisuals[appearanceID] == true
    end,
}

C_TransmogOutfitInfo = {
    IsSlotWeaponSlot = function(slot) return slot == MAINHAND end,
    GetViewedOutfitSlotInfo = function(slot)
        if canTransmogrify[slot] == nil then return nil end
        return { canTransmogrify = canTransmogrify[slot] }
    end,
    SetPendingTransmog = function(slot, transmogType, option, transmogID, displayType)
        table.insert(pendingCalls, {
            slot = slot,
            transmogType = transmogType,
            option = option,
            transmogID = transmogID,
            displayType = displayType,
        })
    end,
}

local modelScene = { GetFrameLevel = function() return 2 end }
local characterPreview = { ModelScene = modelScene, GetFrameLevel = function() return 1 end }
TransmogFrame = {
    CharacterPreview = characterPreview,
    WardrobeCollection = wardrobeCollection,
    SelectSlot = function(_, _, _) tabHeaders.selectedTabID = 1 end,
}

dofile("src/Strings.lua")
dofile("src/Randomiser.lua")
dofile("src/Transmog.lua")

local db = { keepTransmogTab = true }
LuckysWardrobe.Transmog:Init(db)
eventFrame.scripts.OnEvent(nil, "TRANSMOGRIFY_OPEN")
watcher.scripts.OnUpdate()

-- Keeping the active tab.

TransmogFrame:SelectSlot(nil, true)
assert(tabHeaders.selectedTabID == 2, "kept the active tab after an outfit refresh")

TransmogFrame:SelectSlot(nil, false)
assert(tabHeaders.selectedTabID == 1, "let a manual slot click open Items")

tabHeaders.selectedTabID = 2
watcher.scripts.OnUpdate()
db.keepTransmogTab = false
TransmogFrame:SelectSlot(nil, true)
assert(tabHeaders.selectedTabID == 1, "respected the disabled setting")

-- The randomiser button.

local button, driver
for _, frame in ipairs(createdFrames) do
    if frame.template == "SquareIconButtonTemplate" then
        assert(not button, "created only one randomiser button")
        button = frame
    elseif button and frame.parent == button then
        driver = frame
    end
end

assert(button, "created the randomiser button")
assert(button.parent == characterPreview, "parented the button to the character preview")
assert(button.level > modelScene:GetFrameLevel(), "put the button above the model scene")
assert(button.atlas, "gave the button an icon")
assert(button.tooltipTitle and button.tooltipText, "gave the button a tooltip")
assert(not button.scripts.OnEnter and not button.scripts.OnLeave,
    "left the template's own tooltip scripts alone")
assert(driver and not driver.shown, "created the roll driver idle")

eventFrame.scripts.OnEvent(nil, "TRANSMOGRIFY_OPEN")
local buttonCount = 0
for _, frame in ipairs(createdFrames) do
    if frame.template == "SquareIconButtonTemplate" then buttonCount = buttonCount + 1 end
end
assert(buttonCount == 1, "reused the button on a second open")

-- Rolling.

local function pendingFor(slot)
    local calls = {}
    for _, call in ipairs(pendingCalls) do
        if call.slot == slot then table.insert(calls, call) end
    end
    return calls
end

button.scripts.OnMouseDown(button, "RightButton")
assert(#pendingCalls == 0 and not driver.shown, "ignored a press that was not the left button")
button.scripts.OnMouseUp(button, "RightButton")

button.scripts.OnMouseDown(button, "LeftButton")
assert(button.depressed, "ran the template's depress animation on mouse down")
assert(driver.shown, "started the roll driver")

local collectedAndUsable = { [SOURCE[HEAD]] = true, [ALTERNATE_SOURCE] = true }
local headCalls = pendingFor(HEAD)
assert(#headCalls == 1, "rolled once the moment the button went down")
assert(collectedAndUsable[headCalls[1].transmogID], "queued a collected source of a usable appearance")
assert(headCalls[1].displayType == Enum.TransmogOutfitDisplayType.Assigned, "queued a normal appearance as assigned")
assert(headCalls[1].option == Enum.TransmogOutfitSlotOption.None, "queued the armour slot option")
assert(headCalls[1].transmogType == Enum.TransmogType.Appearance, "queued against the appearance type")

assert(#pendingFor(CHEST) == 0, "left a slot that cannot be transmogrified alone")
assert(#pendingFor(MAINHAND) == 0, "left the weapon slot alone")
assert(#pendingFor(SHOULDER_LEFT) == 0, "left the secondary slot alone")
assert(#pendingFor(ILLUSION_SLOT) == 0, "left the illusion location alone")
assert(#pendingFor(WRIST) == 0, "dropped the slot whose appearance query returned nothing")
assert(#pendingFor(TABARD) == 0, "left the slot whose slot info returned nothing alone")
assert(#pendingFor(FEET) == 0, "left the slot whose source query returned nothing alone")

local backCalls = pendingFor(BACK)
assert(#backCalls == 1, "rolled the hide visual's slot")
assert(backCalls[1].displayType == Enum.TransmogOutfitDisplayType.Hidden, "queued a hidden visual as hidden")
assert(backCalls[1].transmogID == SOURCE[BACK], "fell back to the collected source for the hide visual")
local rolledVisuals = { [VISUAL[HEAD]] = true, [ALTERNATE_VISUAL] = true, [VISUAL[BACK]] = true }
assert(#hiddenChecks == 2, "checked both rolled appearances for a hidden visual")
for _, checked in ipairs(hiddenChecks) do
    assert(rolledVisuals[checked], "asked whether the visual ID was hidden, not the source ID")
end

driver.scripts.OnUpdate(driver, 0.09)
assert(#pendingFor(HEAD) == 2, "kept rolling while the button was held")

driver.scripts.OnUpdate(driver, 0.01)
assert(#pendingFor(HEAD) == 2, "waited out the interval between rolls")

button.scripts.OnMouseUp(button, "LeftButton")
assert(not button.depressed, "released the template's depress animation")
assert(driver.shown, "carried on rolling after the button came up")

local guard = 0
while driver.shown and guard < 100 do
    driver.scripts.OnUpdate(driver, 1)
    guard = guard + 1
end
assert(not driver.shown, "came to a stop on its own")

headCalls = pendingFor(HEAD)
assert(#headCalls > 4, "slowed to a stop over several more rolls")
local settled, lastRoll = headCalls[#headCalls], headCalls[#headCalls - 1]
assert(settled.transmogID == lastRoll.transmogID and settled.displayType == lastRoll.displayType,
    "sent the final selection again once the reel settled")
assert(headCalls[#headCalls - 2].transmogID ~= lastRoll.transmogID,
    "rolled something new on every roll, so only the settle repeats")
for _, call in ipairs(headCalls) do
    assert(collectedAndUsable[call.transmogID], "queued only collected sources of usable appearances")
end

-- A fresh spin does not re-send a slot it never rolled.

pendingCalls = {}
canTransmogrify[BACK] = false
button.scripts.OnMouseDown(button, "LeftButton")
button.scripts.OnMouseUp(button, "LeftButton")
guard = 0
while driver.shown and guard < 100 do
    driver.scripts.OnUpdate(driver, 1)
    guard = guard + 1
end
assert(#pendingFor(BACK) == 0, "left the newly ineligible slot as the player had it")

-- Closing.

eventFrame.scripts.OnEvent(nil, "TRANSMOGRIFY_CLOSE")
assert(not driver.shown, "stopped rolling when the transmogrifier closed")
pendingCalls = {}
button.scripts.OnMouseDown(button, "LeftButton")
assert(#pendingCalls == 0, "did not roll against a closed transmogrifier")

print("Lucky's Wardrobe transmog test passed")
