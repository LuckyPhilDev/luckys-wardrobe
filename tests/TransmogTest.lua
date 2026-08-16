-- luacheck: globals C_Timer C_TransmogCollection C_TransmogOutfitInfo Constants CreateFrame Enum GameTooltip LuckysWardrobe TRANSMOG_SLOTS TransmogFrame UnitClass hooksecurefunc math

LuckysWardrobe = {}

-- The icon palette Utils carries, shared with the situation buttons, and the
-- line the dev probe prints through.
local said = {}
LuckysWardrobe.Utils = {
    ICON_ON = { 1.0, 0.824, 0.392 },
    ICON_OFF = { 0.35, 0.35, 0.35 },
    Say = function(line) said[#said + 1] = line end,
}

-- The line dev logging goes out on, which is silent for anyone who has not
-- turned it on.
local logged = {}
LuckysWardrobe.DevLog = function(line) logged[#logged + 1] = line end

local eventFrame
local createdFrames = {}

local function makeTexture()
    return {
        SetAllPoints = function() end,
        SetTexture = function(self, texture) self.texture = texture end,
        SetAlpha = function(self, alpha) self.alpha = alpha end,
        SetVertexColor = function(self, red, green, blue) self.tint = { red, green, blue } end,
        SetColorTexture = function(self, red, green, blue) self.fill = { red, green, blue } end,
        SetSize = function() end,
        SetPoint = function() end,
    }
end

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
        SetShown = function(self, shown) self.shown = shown end,
        SetPoint = function(self, point, relativeTo, relativePoint, x)
            self.point, self.relativeTo, self.relativePoint, self.x =
                point, relativeTo, relativePoint, x
        end,
        ClearAllPoints = function(self) self.point, self.relativePoint = nil, nil end,
        SetSize = function(self, width, height) self.width, self.height = width, height end,
        SetFrameLevel = function(self, level) self.level = level end,
        GetFrameLevel = function(self) return self.level or 1 end,
        SetAtlas = function(self, atlas) self.atlas = atlas end,
        OnMouseDown = function(self) self.depressed = true end,
        OnMouseUp = function(self) self.depressed = false end,
        CreateTexture = function() return makeTexture() end,
        SetHighlightTexture = function(self, texture)
            self.highlight = self.highlight or makeTexture()
            self.highlight.texture = texture
        end,
        GetHighlightTexture = function(self) return self.highlight end,
    }
    table.insert(createdFrames, frame)
    if not parent and not eventFrame then eventFrame = frame end
    return frame
end

C_Timer = { After = function(_, callback) callback() end }

local tabHeaders = { selectedTabID = 2 }
local wardrobeCollection = {
    TabHeaders = tabHeaders,
    SetTab = function(_, tabID) tabHeaders.selectedTabID = tabID end,
}

-- A click lands on the strip, which passes it to the wardrobe through a closure
-- made when the frame loaded, exactly as the client does. Anything hooked onto
-- the wardrobe's own SetTab later is therefore deaf to clicks.
local selectTab = wardrobeCollection.SetTab
tabHeaders.SetTab = function(_, tabID, isUserAction)
    selectTab(wardrobeCollection, tabID, isUserAction)
end

-- The tab system says whether the player did it, which is how the client tells
-- a click apart from a tab change made on the player's behalf.
local function clickTab(tabID)
    tabHeaders:SetTab(tabID, true)
end

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
    TransmogOutfitSlotError = { Ok = 0, CannotUseItem = 10 },
}
Constants = { TransmogOutfitDataConsts = { TRANSMOG_OUTFIT_SLOT_NONE = -1 } }

-- Slot IDs the fixture rolls, plus one of each thing that must be left alone.
local HEAD, BACK = 0, 3
local CHEST, MAINHAND, SHOULDER_LEFT, TABARD, WRIST, FEET, LEGS, ILLUSION_SLOT = 4, 12, 2, 5, 7, 11, 8, 90
-- Two slots for the piece nothing can tell is wrong until it is on: the hands
-- have another to move on to, the waist has nothing but it.
local HANDS, WAIST = 10, 6

local CATEGORY = {
    [HEAD] = 101, [BACK] = 102, [CHEST] = 103, [MAINHAND] = 104,
    [SHOULDER_LEFT] = 105, [TABARD] = 106, [WRIST] = 107, [FEET] = 108,
    [LEGS] = 110, [ILLUSION_SLOT] = 109, [HANDS] = 111, [WAIST] = 112,
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
        GetSlotName = function() return "SLOT_" .. slot end,
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
    [9] = slotEntry(LEGS),
    [10] = slotEntry(ILLUSION_SLOT, { transmogType = Enum.TransmogType.Illusion }),
    [11] = slotEntry(HANDS),
    [12] = slotEntry(WAIST),
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
-- An appearance the class can wear that this character has collected only as a
-- source another class is restricted to.
local WRONG_CLASS_VISUAL, WRONG_CLASS_SOURCE = 998, 9980
-- And one nothing objects to until it is on the slot, where the client answers
-- with an error of its own.
local REFUSED_VISUAL, REFUSED_SOURCE = 997, 9970
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
-- Last in each pool, so the first draw lands on it.
table.insert(categoryAppearances[CATEGORY[HANDS]],
    { visualID = REFUSED_VISUAL, isCollected = true, isUsable = true })
categoryAppearances[CATEGORY[WAIST]] = {
    { visualID = REFUSED_VISUAL, isCollected = true, isUsable = true },
}
table.insert(categoryAppearances[CATEGORY[HEAD]],
    { visualID = ALTERNATE_VISUAL, isCollected = true, isUsable = true })
-- Third in the head's eligible pool, so the second roll draws it.
table.insert(categoryAppearances[CATEGORY[HEAD]],
    { visualID = WRONG_CLASS_VISUAL, isCollected = true, isUsable = true })

-- Wearing a source is refused by the client setting an error on it, which is
-- what the Items tab reads and so what a roll has to read. A source can answer
-- no to isValidSourceForPlayer and still carry no error, and the tab wears those
-- without complaint, so the fixture sets the two apart.
local USE_ERROR = 3

-- The one to pick is last, behind an uncollected source and a collected one the
-- character may not wear.
local appearanceSources = {}
for slot in pairs(CATEGORY) do
    appearanceSources[VISUAL[slot]] = {
        { sourceID = SOURCE[slot] - 2, isCollected = false },
        { sourceID = SOURCE[slot] - 1, isCollected = true, useErrorType = USE_ERROR },
        { sourceID = SOURCE[slot], isCollected = true },
    }
end
-- The hide visual's lone source is not offered cleanly.
appearanceSources[VISUAL[BACK]] = {
    { sourceID = SOURCE[BACK], isCollected = true, useErrorType = USE_ERROR },
}
appearanceSources[VISUAL[FEET]] = nil -- MayReturnNothing
-- The legs slot owns nothing but an appearance the character may not wear.
appearanceSources[VISUAL[LEGS]] = {
    { sourceID = SOURCE[LEGS], isCollected = true, useErrorType = USE_ERROR },
}
-- Wearable, and flagged as no valid source for the player all the same. This is
-- the one the roll used to throw away.
appearanceSources[ALTERNATE_VISUAL] = {
    { sourceID = ALTERNATE_SOURCE, isCollected = true, isValidSourceForPlayer = false },
}
-- Collected, carrying no error at all, and belonging to another class. Nothing
-- on the source says so, which is why the roll has to ask for the sources valid
-- for a class rather than reading every source an appearance has.
appearanceSources[WRONG_CLASS_VISUAL] = {
    { sourceID = WRONG_CLASS_SOURCE, isCollected = true },
}
-- Collected, valid for the class, carrying no error, and refused by the slot all
-- the same. Nothing before the piece lands says so.
appearanceSources[REFUSED_VISUAL] = {
    { sourceID = REFUSED_SOURCE, isCollected = true },
}
appearanceSources[UNCOLLECTED_VISUAL] = {
    { sourceID = 11, isCollected = true },
}
appearanceSources[UNUSABLE_VISUAL] = {
    { sourceID = 12, isCollected = true },
}

-- The client's own verdict on a slot, which only exists once something is on it.
-- The waist is already showing one the client refuses, so once its pool comes to
-- nothing it is handed back a piece in error and the spin ends with it there.
local REFUSED = { [REFUSED_SOURCE] = true }
local reverted = {}
-- A slot the client refuses whatever is on it, because what it objects to is
-- already applied there. Nothing the roll puts on or takes off can clear it.
local STUCK_SLOT = { [WAIST] = true }
-- And one that stops taking changes at all while it is holding a refused piece,
-- which is the way a slot shuts every route to clearing it but the revert.
local LOCKS_UP = { [HANDS] = true }
local lastPending = {}
local WORN = {}
for slot in pairs(CATEGORY) do WORN[slot] = 5000 + slot end

local hiddenVisuals = { [VISUAL[BACK]] = true }
local hiddenChecks = {}
local pendingCalls = {}
local canTransmogrify = {
    [HEAD] = true, [BACK] = true, [CHEST] = false, [MAINHAND] = true,
    [SHOULDER_LEFT] = true, [FEET] = true, [LEGS] = true, [ILLUSION_SLOT] = true,
    [HANDS] = true, [WAIST] = true,
    -- TABARD is absent, so its slot info comes back as nothing at all.
}

-- The Items tab narrows this same call by colour and expansion, so the fixture
-- leaves the narrowed one answering with an empty page and puts the real pools
-- behind the client's own function, which is what the roll has to read.
local narrowedReads = 0

-- The client hands out every source an appearance has, and a second call for the
-- ones a class may actually wear. Only the wrong-class visual differs between
-- the two, which is the whole of what the roll has to notice.
local PLAYER_CLASS = 10
function UnitClass()
    return "Monk", "MONK", PLAYER_CLASS
end

C_TransmogCollection = {
    GetCategoryAppearances = function()
        narrowedReads = narrowedReads + 1
        return {}
    end,
    GetAppearanceSources = function(visualID) return appearanceSources[visualID] end,
    GetValidAppearanceSourcesForClass = function(visualID, classID)
        assert(classID == PLAYER_CLASS, "asks for the sources this character's class may wear")
        if visualID == WRONG_CLASS_VISUAL then return {} end
        return appearanceSources[visualID]
    end,
    IsAppearanceHiddenVisual = function(appearanceID)
        table.insert(hiddenChecks, appearanceID)
        return hiddenVisuals[appearanceID] == true
    end,
    -- What the dev probe names a piece from.
    GetAllAppearanceSources = function(visualID) return { visualID * 10 } end,
    GetSourceInfo = function(sourceID) return { name = "piece " .. sourceID } end,
}

-- Which slots hold a change the player has not applied yet, which is the client's
-- own answer to whether anything is set on a slot.
local pending = {}

C_TransmogOutfitInfo = {
    IsSlotWeaponSlot = function(slot) return slot == MAINHAND end,
    GetViewedOutfitSlotInfo = function(slot)
        if canTransmogrify[slot] == nil then return nil end
        local errored = STUCK_SLOT[slot] or REFUSED[lastPending[slot]]
        return {
            -- A slot holding a piece the client has refused can stop answering
            -- that it may be transmogrified at all, and every way of setting a
            -- slot runs through that answer.
            canTransmogrify = canTransmogrify[slot] and not (LOCKS_UP[slot] and errored),
            hasPending = pending[slot] == true,
            -- What the slot is showing, which is what a refused draw is handed
            -- back once the pool has nothing left to offer it.
            transmogID = WORN[slot],
            displayType = Enum.TransmogOutfitDisplayType.Equipped,
            error = errored
                and Enum.TransmogOutfitSlotError.CannotUseItem
                or Enum.TransmogOutfitSlotError.Ok,
        }
    end,
    SetPendingTransmog = function(slot, transmogType, option, transmogID, displayType)
        pending[slot] = true
        lastPending[slot] = transmogID
        table.insert(pendingCalls, {
            slot = slot,
            transmogType = transmogType,
            option = option,
            transmogID = transmogID,
            displayType = displayType,
        })
    end,
    RevertPendingTransmog = function(slot)
        pending[slot] = nil
        -- Back to what is applied, which is what the slot was showing and is not
        -- a piece the roll chose, so the client's objection goes with it.
        lastPending[slot] = nil
        reverted[slot] = (reverted[slot] or 0) + 1
    end,
    ClearAllPendingTransmogs = function() pending = {} end,
}

-- The slot buttons the character preview lays out, handed round from a pool the
-- way the client hands them round. Each carries a padlock of ours, which is both
-- the sign that a slot is locked and the switch that locks it.
-- The two columns the client lays the slots out in, which is what says whether a
-- slot's padlock belongs on its left or its right.
local leftSlots, rightSlots = {}, {}

local slotFrames = {}
for _, slot in ipairs({ HEAD, BACK, CHEST, MAINHAND }) do
    table.insert(slotFrames, { slot = slot, column = leftSlots })
end
for _, slot in ipairs({ TABARD, WRIST, FEET, LEGS }) do
    table.insert(slotFrames, { slot = slot, column = rightSlots })
end
for _, frame in ipairs(slotFrames) do
    frame.GetSlot = function(self) return self.slot end
    frame.GetFrameLevel = function() return 3 end
    frame.GetParent = function(self) return self.column end
end

local function lockFor(slot)
    for _, frame in ipairs(slotFrames) do
        if frame.slot == slot then return frame.luckysWardrobeLock end
    end
end

-- The two drawings the padlock is struck from, named here so a mistyped path in
-- the addon shows up as a failure rather than as a slot with nothing beside it.
local LOCK_SHUT = "Interface\\AddOns\\Luckys_Wardrobe\\Images\\icons\\lock"
local LOCK_OPEN = "Interface\\AddOns\\Luckys_Wardrobe\\Images\\icons\\lock-open"

-- A shut padlock is a locked slot, an open one a slot the roll will spin.
local function isShut(slot)
    return lockFor(slot).Icon.texture == LOCK_SHUT
end

-- The padlock's spot stays live whether or not the drawing is there to see, so
-- what shows is the icon's alpha rather than whether the button is up.
local function isVisible(slot)
    return lockFor(slot).Icon.alpha > 0
end

-- Lit when the slot is locked, grey when it is not, the same two tints the
-- situation buttons use.
local function tintOf(texture)
    return table.concat(texture.tint, ",")
end

local LIT = table.concat(LuckysWardrobe.Utils.ICON_ON, ",")
local GREY = table.concat(LuckysWardrobe.Utils.ICON_OFF, ",")

local function clickLock(slot)
    local lock = lockFor(slot)
    lock.scripts.OnClick(lock)
end

-- What the tooltip says while the cursor is over a padlock.
local tooltipLines = {}

GameTooltip = {
    SetOwner = function() end,
    SetText = function(_, text) tooltipLines = { text } end,
    AddLine = function(_, text) tooltipLines[#tooltipLines + 1] = text end,
    Show = function() end,
    Hide = function() tooltipLines = {} end,
}

local function enterLock(slot)
    local lock = lockFor(slot)
    lock.scripts.OnEnter(lock)
end

local function leaveLock(slot)
    local lock = lockFor(slot)
    lock.scripts.OnLeave(lock)
end

-- Hovering and coming away again, so a check on what the tooltip said does not
-- leave the cursor sitting on the padlock for the checks after it.
local function hoverLock(slot)
    enterLock(slot)
    local shown = { tooltipLines[1], tooltipLines[2] }
    leaveLock(slot)
    return shown
end

local modelScene = { GetFrameLevel = function() return 2 end }
local characterPreview = {
    ModelScene = modelScene,
    GetFrameLevel = function() return 1 end,
    RefreshSlots = function() end,
    LeftSlots = leftSlots,
    RightSlots = rightSlots,
    CharacterAppearanceSlotFramePool = {
        EnumerateActive = function()
            local index = 0
            return function()
                index = index + 1
                return slotFrames[index]
            end
        end,
    },
}
-- Selecting a slot sends the wardrobe back to Items on its way through, without
-- the player having asked for it, exactly as the client does.
TransmogFrame = {
    CharacterPreview = characterPreview,
    WardrobeCollection = wardrobeCollection,
    SelectSlot = function(_, _, _) wardrobeCollection:SetTab(1) end,
}

-- The colour the Items tab's strip is set to, and which visuals carry it. Only
-- the head's alternate appearance does, so a roll in colour has one place to go
-- on that slot and nowhere to go on any other.
local COLOUR_TARGET = { "green shades" }
local COLOUR_SHADE = { 40, 160, 60 }
local carriesColour = { [ALTERNATE_VISUAL] = true }

local picked = {}

LuckysWardrobe.Colours = {
    Matches = function(visualID, target)
        return target == COLOUR_TARGET and carriesColour[visualID] == true
    end,
}

LuckysWardrobe.TransmogItems = {
    CategoryAppearances = function(category) return categoryAppearances[category] end,
    PickedColour = function() return picked.key, picked.target, picked.preset end,
    PaintSwatch = function(texture, preset)
        local shade = preset.shades[1]
        texture:SetColorTexture(shade[1] / 255, shade[2] / 255, shade[3] / 255)
    end,
}

-- unmatched is the strip's last swatch, which is not a colour: it keeps the
-- pieces the twelve leave behind, and the dice has its own name for that roll.
local function pickColour(key, unmatched)
    picked.key = key
    picked.target = key and COLOUR_TARGET or nil
    picked.preset = key and { key = key, unmatched = unmatched, shades = { COLOUR_SHADE } } or nil
    LuckysWardrobe.Randomiser:OnColourPicked()
end

dofile("src/Strings.lua")
dofile("src/Randomiser.lua")
dofile("src/Transmog.lua")

local db = { keepTransmogTab = true }
LuckysWardrobe.Transmog:Init(db)
eventFrame.scripts.OnEvent(nil, "TRANSMOGRIFY_OPEN")

-- Keeping the active tab.

clickTab(2)
TransmogFrame:SelectSlot(nil, true)
assert(tabHeaders.selectedTabID == 2, "kept the active tab after an outfit refresh")

TransmogFrame:SelectSlot(nil, false)
assert(tabHeaders.selectedTabID == 1, "let a manual slot click open Items")

clickTab(2)
db.keepTransmogTab = false
TransmogFrame:SelectSlot(nil, true)
assert(tabHeaders.selectedTabID == 1, "respected the disabled setting")

-- A refresh that opened Items is not the player choosing Items, so the next
-- refresh still goes back to the tab they had picked.
db.keepTransmogTab = true
TransmogFrame:SelectSlot(nil, true)
assert(tabHeaders.selectedTabID == 2, "did not mistake its own trip through Items for a choice")

-- The randomiser button.

-- The padlocks and the colour roll share the dice's template. The dice is the
-- one on the preview carrying no swatch.
local function onPreview(frame)
    return frame.template == "SquareIconButtonTemplate" and frame.parent == characterPreview
end

local function isDice(frame)
    return onPreview(frame) and not frame.Swatch
end

local button, colourButton, driver
for _, frame in ipairs(createdFrames) do
    if isDice(frame) then
        assert(not button, "created only one randomiser button")
        button = frame
    elseif onPreview(frame) then
        colourButton = frame
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
    if isDice(frame) then buttonCount = buttonCount + 1 end
end
assert(buttonCount == 1, "reused the button on a second open")
assert(narrowedReads == 0,
    "built the pools off the client's own list rather than the page the Items tab filters, "
    .. "which would put its colour ranking and item requests through every category on each open")

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

-- ALTERNATE_SOURCE is the one flagged as no valid source for the player while
-- carrying no error against wearing it. The tab wears those, so the roll must
-- too: dropping them left slots owning one piece in a colour with nothing to
-- land on but the entry that wears nothing.
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
assert(#pendingFor(LEGS) == 0, "left alone the slot whose only appearance the character may not wear")

local backCalls = pendingFor(BACK)
assert(#backCalls == 1, "rolled the hide visual's slot")
assert(backCalls[1].displayType == Enum.TransmogOutfitDisplayType.Hidden, "queued a hidden visual as hidden")
assert(backCalls[1].transmogID == SOURCE[BACK], "took the hide visual's source even though it is not flagged valid")
-- Nothing before the piece landed said the slot would refuse it, so the roll put
-- it on, read the client's answer and drew again.
local handsCalls = pendingFor(HANDS)
assert(#handsCalls == 2, "put the refused piece on the hands and then took it off")
assert(handsCalls[1].transmogID == REFUSED_SOURCE, "the draw landed on the refused piece first")
assert(handsCalls[2].transmogID == SOURCE[HANDS], "and came to rest on one the client takes")

-- The waist has nothing else to offer, so its pending change is dropped and the
-- slot goes back to what is applied, rather than being handed a piece by
-- guesswork or left holding one the slot is marking in error.
local waistCalls = pendingFor(WAIST)
assert(#waistCalls == 1, "put the refused piece on the waist")
assert(waistCalls[1].transmogID == REFUSED_SOURCE, "which is the one it drew")
assert((reverted[WAIST] or 0) == 1, "and took it off by reverting the slot")

-- The feet's visual is among them: whether a visual is the hidden one is asked
-- before its sources are, so that a hide entry whose sources come back empty can
-- still be taken on trust.
local drawnVisuals = {
    [VISUAL[HEAD]] = true, [ALTERNATE_VISUAL] = true, [WRONG_CLASS_VISUAL] = true,
    [VISUAL[BACK]] = true, [VISUAL[LEGS]] = true, [VISUAL[FEET]] = true,
    [VISUAL[HANDS]] = true, [REFUSED_VISUAL] = true,
}
assert(#hiddenChecks > 0, "checked drawn appearances for a hidden visual")
for _, checked in ipairs(hiddenChecks) do
    assert(drawnVisuals[checked], "asked whether the visual ID was hidden, not the source ID")
end

-- The head's second draw lands on the appearance belonging to another class, so
-- this roll only produces a pending change if the draw moves on to another. Its
-- source is collected and carries no error of any kind, so a roll reading every
-- source an appearance has takes it and locks the slot with a piece the
-- character is refused.
driver.scripts.OnUpdate(driver, 0.09)
assert(#pendingFor(HEAD) == 2, "kept rolling while the button was held")
assert(pendingFor(HEAD)[2].transmogID ~= WRONG_CLASS_SOURCE,
    "drew again past the appearance no source of this class can wear")

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

-- A slot the client is still marking in error once the reel has stopped is said
-- so, naming the piece on it. The check each draw makes is the same one a moment
-- earlier, so a slot that passes it there and shows up here is one the client
-- made its mind up about after the call that put the piece on.
local function stuckLines()
    local lines = {}
    for _, line in ipairs(logged) do
        if line:find("in an error", 1, true) then lines[#lines + 1] = line end
    end
    return lines
end

local stuck = stuckLines()
assert(#stuck > 0, "said which slot the spin left in an error")
assert(stuck[1]:find(tostring(WAIST), 1, true), "named the slot it was left on")
assert(stuck[1]:find("already in this error before the spin", 1, true),
    "said the slot was in that state before the roll touched it")

-- It is tried once, and a slot still in error with nothing of the roll's on it
-- is let be from there rather than drawn at on every redraw.
characterPreview:RefreshSlots()
local tried = #stuckLines()
characterPreview:RefreshSlots()
characterPreview:RefreshSlots()
assert(#stuckLines() == tried, "left alone the slot no draw of its own can clear")

-- The hands lock up when the client turns against what is on them, which is the
-- state a slot cannot be rolled out of: every way of setting one runs through
-- the answer that error clears. So that slot is read on every redraw for as long
-- as it stands there, however many have found it clean before.
local handsBefore = #pendingFor(HANDS)
REFUSED[SOURCE[HANDS]] = true
characterPreview:RefreshSlots()

assert((reverted[HANDS] or 0) == 1, "gave up the piece the client turned against")
assert(#pendingFor(HANDS) == handsBefore, "and put nothing else on, its pool having run out")

local handsStuck
for _, line in ipairs(stuckLines()) do
    if line:find("left " .. HANDS .. " in an error", 1, true) then handsStuck = line end
end
assert(handsStuck, "said which slot it was")
assert(handsStuck:find("clear before the spin", 1, true),
    "and that this one was the roll's own doing")
assert(handsStuck:find("can transmogrify false", 1, true),
    "and that the slot had stopped answering it could be transmogrified, which is the dead end")
REFUSED[SOURCE[HANDS]] = nil

-- A slot the client marks but still answers for is a different thing, being one
-- a later spin can reach. That error is read once: a redraw that found the slot
-- clean is the client saying it has made its mind up, and an error arriving on a
-- later redraw is it part way through loading the slot's items. Reading those
-- took good pieces off slots nobody had touched, the outfit reshuffling itself
-- while the player was looking at one slot of it.
local headPiece = lastPending[HEAD]
characterPreview:RefreshSlots()
local headBefore = #pendingFor(HEAD)
local headReverts = reverted[HEAD] or 0

REFUSED[headPiece] = true
characterPreview:RefreshSlots()
characterPreview:RefreshSlots()
assert(#pendingFor(HEAD) == headBefore, "drew nothing new on the slot it had settled")
assert((reverted[HEAD] or 0) == headReverts, "and left the piece it settled on where it was")
REFUSED[headPiece] = nil

-- And the same read on demand, for a slot found in that state later. It says
-- what every slot is holding, what the client makes of it, and what the source
-- itself answers to each of the questions a roll could have asked first.
said = {}
LuckysWardrobe.Randomiser:PrintSlots()
local dump = table.concat(said, "\n")
assert(dump:find("what %d+ slots are holding"), "headed the dump with what it covers")
assert(dump:find("useErrorType", 1, true) and dump:find("valid for player", 1, true),
    "said what the source answers to every question a roll could ask")
assert(dump:find("rolled by us", 1, true), "said whether the piece on the slot is one it rolled")

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

local wearable = { [SOURCE[LEGS]] = false, [WRONG_CLASS_SOURCE] = false }
for _, call in ipairs(pendingCalls) do
    assert(wearable[call.transmogID] == nil,
        "never queued a source the character may not wear, which would leave the slot stuck in an error state")
end
assert(#pendingFor(LEGS) == 0, "carried on leaving the unwearable slot alone for the whole spin")

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

-- Locking the slots the player set.

local function spin()
    pendingCalls = {}
    button.scripts.OnMouseDown(button, "LeftButton")
    button.scripts.OnMouseUp(button, "LeftButton")
    guard = 0
    while driver.shown and guard < 100 do
        driver.scripts.OnUpdate(driver, 1)
        guard = guard + 1
    end
end

local S = LuckysWardrobe.Strings.randomiser

canTransmogrify[BACK] = true
C_TransmogOutfitInfo.ClearAllPendingTransmogs()
assert(not isVisible(HEAD), "kept the padlock out of sight on a slot with nothing set on it")
assert(lockFor(HEAD).shown, "kept its spot live all the same, so the cursor can still find it")

enterLock(HEAD)
assert(isVisible(HEAD), "showed the padlock when the cursor found the spot it sits in")
leaveLock(HEAD)
assert(not isVisible(HEAD), "put it away again when the cursor came off")

-- What the client does when the player picks a piece off the Items tab.
C_TransmogOutfitInfo.SetPendingTransmog(HEAD, Enum.TransmogType.Appearance,
    Enum.TransmogOutfitSlotOption.None, SOURCE[HEAD], Enum.TransmogOutfitDisplayType.Assigned)
assert(isVisible(HEAD), "showed the padlock once a piece was set on the slot")
assert(not lockFor(MAINHAND).shown, "left the slots a roll never touches without one at all")

-- The padlock sits on the side of the slot the model is on, so the two columns
-- carry theirs on opposite sides, each pushed clear of its slot rather than back
-- over it.
local head, feet = lockFor(HEAD), lockFor(FEET)
assert(head.point == "LEFT" and head.relativePoint == "RIGHT" and head.x > 0,
    "hung the left column's padlock off the right of its slot, clear of the border")
assert(feet.point == "RIGHT" and feet.relativePoint == "LEFT" and feet.x < 0,
    "hung the right column's padlock off the left of its slot, clear of the border")

assert(isShut(HEAD), "shut the padlock on the slot the player set a piece on")
assert(tintOf(lockFor(HEAD).Icon) == LIT, "lit the padlock on a locked slot")
assert(lockFor(HEAD).highlight.texture == LOCK_SHUT, "showed the same drawing on hover")
assert(tintOf(lockFor(HEAD).highlight) == LIT, "and in the same colour")

local hovered = hoverLock(HEAD)
assert(hovered[1] == S.unlockTitle and hovered[2] == S.unlockHint,
    "offered to unlock the slot once it was locked")

assert(not isShut(BACK), "left the slots the player did not touch unlocked")
assert(lockFor(BACK).Icon.texture == LOCK_OPEN, "drew the open padlock on an unlocked slot")
assert(tintOf(lockFor(BACK).Icon) == GREY, "left an unlocked slot's padlock grey")
hovered = hoverLock(BACK)
assert(hovered[1] == S.lockTitle and hovered[2] == S.lockHint,
    "offered to lock a slot that was not locked yet")

spin()
assert(#pendingFor(HEAD) == 0, "left the locked slot as the player set it")
assert(#pendingFor(BACK) > 0, "carried on rolling the slots that were not locked")
assert(not isShut(BACK), "did not read the reel's own spin as a piece the player chose")
assert(isVisible(BACK),
    "put a padlock on the slot the reel landed on, so a piece it found can be kept")

C_TransmogOutfitInfo.RevertPendingTransmog(HEAD, Enum.TransmogType.Appearance,
    Enum.TransmogOutfitSlotOption.None)
assert(not isShut(HEAD), "took the lock off the slot the player put back")
assert(not isVisible(HEAD), "took the padlock out of sight with the piece that was put back")
spin()
assert(#pendingFor(HEAD) > 0, "rolled the slot again once its lock had come off")

-- A piece the player sets straight after a spin, before any redraw has judged
-- what the reel left, locks the slot and is theirs. The reel does not take it
-- off however the client marks it.
C_TransmogOutfitInfo.SetPendingTransmog(HEAD, Enum.TransmogType.Appearance,
    Enum.TransmogOutfitSlotOption.None, SOURCE[HEAD], Enum.TransmogOutfitDisplayType.Assigned)
assert(isShut(HEAD), "locked the slot on the piece the player picked")

local chosen = #pendingFor(HEAD)
local headReverted = reverted[HEAD] or 0
REFUSED[SOURCE[HEAD]] = true
characterPreview:RefreshSlots()
assert(#pendingFor(HEAD) == chosen, "drew nothing over the piece the player chose")
assert((reverted[HEAD] or 0) == headReverted, "and did not revert the slot they set it on")
REFUSED[SOURCE[HEAD]] = nil

C_TransmogOutfitInfo.RevertPendingTransmog(HEAD, Enum.TransmogType.Appearance,
    Enum.TransmogOutfitSlotOption.None)
assert(not isShut(HEAD), "and the lock came off with the piece when they put it back")

clickLock(HEAD)
assert(isShut(HEAD), "locked the slot when its padlock was clicked")
assert(tooltipLines[1] == S.unlockTitle,
    "put the tooltip back up saying what a second click would do")
spin()
assert(#pendingFor(HEAD) == 0, "left the slot locked by hand alone")

clickLock(HEAD)
assert(not isShut(HEAD), "unlocked the slot on a second click")

clickLock(HEAD)
C_TransmogOutfitInfo.ClearAllPendingTransmogs()
assert(not isShut(HEAD), "dropped every lock when the player cleared their changes")
assert(not isVisible(HEAD), "took every padlock out of sight with the changes that were cleared")

-- What a draw weighs the entry that wears nothing at.

local DrawIndex = LuckysWardrobe.Randomiser.DrawIndex
local HIDDEN = "wears nothing"

local landed = {}
for roll = 1, 10 do
    landed[roll] = DrawIndex({ 11, 12, 13, HIDDEN }, HIDDEN, function() return roll end)
end
assert(table.concat(landed, ",") == "1,1,1,2,2,2,3,3,3,4",
    "gave each of three pieces three draws in ten and the hide entry one, a third of a piece")

local asked
assert(DrawIndex({ 11, 12, 13 }, HIDDEN, function(range) asked = range return 2 end) == 2,
    "drew straight from a pool with no hide entry on the end of it")
assert(asked == 3, "over the pool itself, with nothing weighted against it")

assert(DrawIndex({ HIDDEN }, HIDDEN, function(range) asked = range return range end) == 1,
    "landed on the hide entry where it was the only thing left")
assert(asked == 1, "with no pieces to weigh it against")

assert(DrawIndex({}, HIDDEN, function() error("drew from an empty pool") end) == nil,
    "answered with nothing for a pool with nothing in it")

-- Rolling in one colour.

local function spinWith(rollButton)
    pendingCalls = {}
    rollButton.scripts.OnMouseDown(rollButton, "LeftButton")
    rollButton.scripts.OnMouseUp(rollButton, "LeftButton")
    guard = 0
    while driver.shown and guard < 100 do
        driver.scripts.OnUpdate(driver, 1)
        guard = guard + 1
    end
end

C_TransmogOutfitInfo.ClearAllPendingTransmogs()
assert(colourButton, "created the colour roll beside the dice")
assert(colourButton.parent == characterPreview, "parented it to the character preview")
assert(colourButton.atlas == button.atlas, "gave it the same dice the plain roll carries")
assert(not colourButton.shown, "kept it away while the Items tab had no colour lit")

pickColour("green")
assert(colourButton.shown, "brought it out once a colour was lit")
assert(colourButton.Swatch.fill[1] == COLOUR_SHADE[1] / 255
    and colourButton.Swatch.fill[2] == COLOUR_SHADE[2] / 255
    and colourButton.Swatch.fill[3] == COLOUR_SHADE[3] / 255,
    "stamped it with the colour the strip is set to")
assert(colourButton.tooltipTitle == S.colourTitle:format(LuckysWardrobe.Strings.colours.green),
    "named the colour in its tooltip")

-- The last swatch is not a colour, and "Roll a Other Colours Outfit" is not a
-- sentence, so the roll it offers is named in its own right.
pickColour("other", true)
assert(colourButton.tooltipTitle == S.otherTitle, "named the leftovers roll its own way")
pickColour("green")

spinWith(colourButton)
assert(#pendingFor(HEAD) > 0, "rolled the head, which has a piece in that colour")
for _, call in ipairs(pendingFor(HEAD)) do
    assert(call.transmogID == ALTERNATE_SOURCE, "rolled the head only within the lit colour")
    assert(call.displayType == Enum.TransmogOutfitDisplayType.Assigned,
        "did not reach for hiding a slot that had a piece in the colour to wear")
end

-- The back's only entry is the one that wears nothing, which keeps to any
-- colour, so it is what the slot lands on rather than the slot sitting the
-- spin out in whatever it already had on.
local hiddenCalls = pendingFor(BACK)
assert(#hiddenCalls > 0, "hid the slot with nothing in that colour rather than leaving it")
assert(hiddenCalls[1].transmogID == SOURCE[BACK] and
    hiddenCalls[1].displayType == Enum.TransmogOutfitDisplayType.Hidden,
    "queued that slot as hidden")
assert(#pendingFor(LEGS) == 0,
    "left alone a slot with neither a piece in the colour nor anything to hide it with")

-- A locked slot sits out a colour roll the same as it sits out a plain one.
clickLock(HEAD)
spinWith(colourButton)
assert(#pendingFor(HEAD) == 0, "left the locked slot alone on a colour roll")
clickLock(HEAD)

-- The colour narrows that spin alone, so the dice beside it still draws from
-- everything afterwards.
spinWith(button)
local drewOutsideColour = false
for _, call in ipairs(pendingFor(HEAD)) do
    if call.transmogID ~= ALTERNATE_SOURCE then drewOutsideColour = true end
end
assert(drewOutsideColour, "gave the plain roll the whole pool back after a colour roll")

pickColour(nil)
assert(not colourButton.shown, "put it away again when the colour was cleared")

-- The dev probe, which has to survive every slot the table holds: the ones a
-- spin reaches and each of the reasons the rest are passed over.

pickColour("green")
said = {}
LuckysWardrobe.Randomiser:PrintPools()
assert(#said > #TRANSMOG_SLOTS, "said something about every slot, and the count on top")
assert(said[1]:find("slots in play"), "opened with how many slots a spin can reach")

local skipped, coloured = 0, 0
for _, line in ipairs(said) do
    if line:find("skipped") then skipped = skipped + 1 end
    if line:find("in the lit colour") then coloured = coloured + 1 end
end
assert(skipped > 0 and coloured > 0,
    "gave a reason for the slots it passes over and a colour count for the ones it does not")

-- Named for one category, so a piece that ought to be in a pool can be found.
said = {}
LuckysWardrobe.Randomiser:PrintPools(tostring(CATEGORY[HEAD]))
local named = 0
for _, line in ipairs(said) do
    if line:find("collected .* wearable") then named = named + 1 end
end
assert(named > 0, "named the pieces carrying the colour for the category asked about")

said = {}
LuckysWardrobe.Randomiser:PrintPools(tostring(CATEGORY[BACK]))
for _, line in ipairs(said) do
    assert(not line:find("visual %d+: collected"),
        "named nothing for a category whose only entry in the colour wears nothing")
end

pickColour(nil)
said = {}
LuckysWardrobe.Randomiser:PrintPools()
for _, line in ipairs(said) do
    assert(not line:find("in the lit colour"), "left the colour counts out with no colour lit")
end

-- Closing.

clickLock(HEAD)
eventFrame.scripts.OnEvent(nil, "TRANSMOGRIFY_CLOSE")
assert(not driver.shown, "stopped rolling when the transmogrifier closed")
pendingCalls = {}
button.scripts.OnMouseDown(button, "LeftButton")
assert(#pendingCalls == 0, "did not roll against a closed transmogrifier")

eventFrame.scripts.OnEvent(nil, "TRANSMOGRIFY_OPEN")
assert(not isShut(HEAD), "opened the next visit with every lock dropped")

print("Lucky's Wardrobe transmog test passed")
