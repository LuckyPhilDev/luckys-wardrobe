-- luacheck: globals C_Item C_TransmogCollection C_TransmogOutfitInfo Constants CreateFrame Enum GameTooltip TRANSMOG_SLOTS TransmogFrame UNKNOWN hooksecurefunc

-- Lucky's Wardrobe: Spin every armour slot through appearances you already own,
-- past the slots you set yourself.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.Randomiser = {}

local Randomiser = LuckysWardrobe.Randomiser
local Utils = LuckysWardrobe.Utils

-- Held rolls run fast enough to blur into a spin. Letting go stretches each
-- wait by SLOWDOWN until the next one would outlast a reel coming to rest.
local ROLL_INTERVAL = 0.08
local SLOWDOWN = 2
local SLOWEST_INTERVAL = 0.4
-- The model redresses a frame or two behind a burst of pending changes, so the
-- final selection is sent again once the reel has been still this long.
local SETTLE_DELAY = 0.15

local HOLDING, SLOWING, SETTLING = "holding", "slowing", "settling"

-- Armour slots carry no weapon or sheathe variants.
local SLOT_OPTION = Enum.TransmogOutfitSlotOption.None

local button
local colourButton
local driver
local targets
local phase
local interval
local elapsed

-- The slots a roll leaves as they are. Setting a piece on a slot locks it, so a
-- look built by hand survives every later spin, and the padlock beside the slot
-- puts the lock on or takes it off. Kept for the visit alone: the transmogrifier
-- drops every pending change on the way out, so by the next visit there is
-- nothing left for a lock to protect.
local locked = {}

-- True while the roll is the one queueing changes, so the hook watching for the
-- player setting a slot does not read the reel's own spin as a piece they chose.
local rolling

local paintLocks
-- Declared up here because the hook that runs it is installed before the pools
-- and the draw it needs are in scope.
local correctStuckSlots

-- Which entry a roll lands on, or nil for a pool with nothing in it. Wearing
-- nothing is one more thing a slot can land on, but at a third of a piece's
-- weight: a roll reaching for it as readily as a real piece would undress a
-- character it had pieces for. Where the pieces run out it is all there is, and
-- the slot is hidden.
--
-- The entry that wears nothing sits last in the pool, so a draw finds it without
-- hunting. Each piece answers for PIECE_WEIGHT of the range drawn over and it
-- answers for one.
local PIECE_WEIGHT = 3

function Randomiser.DrawIndex(pool, hiddenVisual, pick)
    local size = #pool
    if size == 0 then return nil end
    if pool[size] ~= hiddenVisual then return pick(size) end

    local pieces = size - 1
    local roll = pick(pieces * PIECE_WEIGHT + 1)
    if roll > pieces * PIECE_WEIGHT then return size end
    return math.ceil(roll / PIECE_WEIGHT)
end

-- Read through the Items tab's own accessor rather than the client's call, which
-- that tab replaces with one narrowed by the colour and expansion filters. A page
-- narrowed to one colour is not what the dice offers, and building eleven pools
-- out of it put the tab's colour ranking and its item requests over every
-- category on each open.
local function collectedVisuals(category, locationData)
    local visuals, hiddenVisual = {}, nil
    local appearances = LuckysWardrobe.TransmogItems.CategoryAppearances(category, locationData)
    if not appearances then return visuals end

    for _, appearance in ipairs(appearances) do
        if appearance.isCollected and appearance.isUsable then
            if appearance.isHideVisual then
                hiddenVisual = appearance.visualID
            else
                table.insert(visuals, appearance.visualID)
            end
        end
    end

    -- Last, which is where the draw expects to find it.
    if hiddenVisual then table.insert(visuals, hiddenVisual) end

    return visuals, hiddenVisual
end

-- Rebuilt on each open rather than watched for changes. Learning an appearance
-- means acquiring and binding an item, which is not something that happens
-- while standing at the transmogrifier, so a pool built at open stays accurate
-- for the visit.
local function buildTargets()
    targets = {}

    for _, slotEntry in pairs(TRANSMOG_SLOTS) do
        local location = slotEntry.location
        local category = slotEntry.armorCategoryID
        if location and category and location:IsAppearance() and not location:IsSecondary() then
            local slot = location:GetSlot()
            local isRollable = slot
                and slot ~= Constants.TransmogOutfitDataConsts.TRANSMOG_OUTFIT_SLOT_NONE
                and not C_TransmogOutfitInfo.IsSlotWeaponSlot(slot)
            if isRollable then
                local locationData = location:GetData()
                local visuals, hiddenVisual = collectedVisuals(category, locationData)
                if #visuals > 0 then
                    table.insert(targets, {
                        slot = slot,
                        slotName = _G[location:GetSlotName() or ""] or tostring(slot),
                        transmogType = location:GetType(),
                        category = category,
                        locationData = locationData,
                        visuals = visuals,
                        hiddenVisual = hiddenVisual,
                    })
                end
            end
        end
    end
end

local function targetFor(slot)
    for _, target in ipairs(targets or {}) do
        if target.slot == slot then return target end
    end
end

-- Only a slot the roll would otherwise land on can be locked. A weapon, or a
-- slot with nothing collected to put on it, is left alone anyway, so locking one
-- would promise something the roll was never going to do.
local function setLocked(slot, isLocked)
    if not targetFor(slot) then return end
    locked[slot] = isLocked or nil
    paintLocks()
end

-- The padlock beside a slot with a piece set on it, whether the player set it or
-- the reel did. It stands there whether the slot is locked or not, because it is
-- the switch as well as the sign: a shut padlock is a slot the roll leaves alone,
-- an open one a slot it will spin.
--
-- A slot with nothing set on it keeps its padlock out of sight rather than losing
-- it, so the window is not lined with padlocks for pieces nobody has chosen while
-- the cursor can still find one and lock the slot on what is already being worn.
--
-- Bare artwork rather than a button plate. The slots sit close together and a
-- square of chrome between two of them reads as a third slot, so the padlock is
-- the drawing alone and the hover glow is the same drawing added over itself.
local LOCK_SHUT = "Interface\\AddOns\\Luckys_Wardrobe\\Images\\icons\\lock"
local LOCK_OPEN = "Interface\\AddOns\\Luckys_Wardrobe\\Images\\icons\\lock-open"
local LOCK_SIZE = 20
local LOCK_GAP = 4
local GLOW_ALPHA = 0.35
-- A slot draws its pending and selected states on child frames of its own, and
-- the padlock hangs off the slot's edge over the model scene, so it needs a level
-- above both rather than above the button alone.
local LOCK_LEVELS = 300

local function showLockTooltip(lock)
    local S = LuckysWardrobe.Strings.randomiser
    local isLocked = locked[lock.slotFrame:GetSlot()] == true

    GameTooltip:SetOwner(lock, "ANCHOR_RIGHT")
    GameTooltip:SetText(isLocked and S.unlockTitle or S.lockTitle)
    GameTooltip:AddLine(isLocked and S.unlockHint or S.lockHint, 1, 1, 1, true)
    GameTooltip:Show()
end

-- The padlock's own spot stays live on every slot a roll can reach, so a slot
-- with nothing set on it can still be found and locked. What changes is whether
-- the drawing is there to see.
local function paintLock(lock)
    local slotFrame = lock.slotFrame
    local slot = slotFrame:GetSlot()
    local target = targetFor(slot)
    local slotInfo = target
        and C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(slot, target.transmogType, SLOT_OPTION)
    lock:SetShown(target ~= nil)

    -- On whichever side of the slot faces the model, so the padlocks gather
    -- down the middle rather than trailing off both edges of the window.
    lock:ClearAllPoints()
    local preview = TransmogFrame and TransmogFrame.CharacterPreview
    if preview and slotFrame:GetParent() == preview.RightSlots then
        lock:SetPoint("RIGHT", slotFrame, "LEFT", -LOCK_GAP, 0)
    else
        lock:SetPoint("LEFT", slotFrame, "RIGHT", LOCK_GAP, 0)
    end

    -- Shape and colour both carry the state, the way the situation buttons above
    -- these slots are lit when what they stand for is on.
    local isLocked = locked[slot] == true
    local icon = isLocked and LOCK_SHUT or LOCK_OPEN
    local tint = isLocked and Utils.ICON_ON or Utils.ICON_OFF
    lock.Icon:SetTexture(icon)
    lock.Icon:SetVertexColor(tint[1], tint[2], tint[3])
    lock.Glow:SetTexture(icon)
    lock.Glow:SetVertexColor(tint[1], tint[2], tint[3])

    local isSet = slotInfo ~= nil and slotInfo.hasPending == true
    local seen = isLocked or isSet or lock.hovered == true
    lock.Icon:SetAlpha(seen and 1 or 0)
end

local function onLockClick(lock)
    local slot = lock.slotFrame:GetSlot()
    if not slot then return end

    setLocked(slot, not locked[slot])
    -- The tooltip is still up under the cursor offering what the click just did,
    -- so it goes up again saying the opposite.
    showLockTooltip(lock)
end

local function onLockEnter(lock)
    lock.hovered = true
    paintLock(lock)
    showLockTooltip(lock)
end

local function onLockLeave(lock)
    lock.hovered = nil
    paintLock(lock)
    GameTooltip:Hide()
end

local function attachLock(slotFrame)
    if slotFrame.luckysWardrobeLock then return end

    local lock = CreateFrame("Button", nil, slotFrame)
    lock.slotFrame = slotFrame
    lock:SetSize(LOCK_SIZE, LOCK_SIZE)
    lock:SetFrameLevel(slotFrame:GetFrameLevel() + LOCK_LEVELS)

    lock.Icon = lock:CreateTexture(nil, "OVERLAY")
    lock.Icon:SetAllPoints()

    lock:SetHighlightTexture(LOCK_SHUT, "ADD")
    lock.Glow = lock:GetHighlightTexture()
    lock.Glow:SetAllPoints()
    lock.Glow:SetAlpha(GLOW_ALPHA)

    lock:SetScript("OnClick", onLockClick)
    lock:SetScript("OnEnter", onLockEnter)
    lock:SetScript("OnLeave", onLockLeave)

    slotFrame.luckysWardrobeLock = lock
end

function paintLocks()
    local preview = TransmogFrame and TransmogFrame.CharacterPreview
    local pool = preview and preview.CharacterAppearanceSlotFramePool
    if not pool then return end

    for slotFrame in pool:EnumerateActive() do
        attachLock(slotFrame)
        paintLock(slotFrame.luckysWardrobeLock)
    end
end

local hooked

local function installLockHooks(preview)
    if hooked then return end
    hooked = true

    -- Every way of setting a slot ends here, so the piece picked off the Items
    -- tab, the hidden and show-equipped buttons, and a piece rolled out of the
    -- colour strip all lock the slot they land on.
    hooksecurefunc(C_TransmogOutfitInfo, "SetPendingTransmog", function(slot)
        if not rolling then setLocked(slot, true) end
    end)

    -- Right-clicking a slot puts back what the player is wearing, which is them
    -- taking the piece off rather than choosing one, so the lock goes with it.
    hooksecurefunc(C_TransmogOutfitInfo, "RevertPendingTransmog", function(slot)
        setLocked(slot, false)
    end)
    hooksecurefunc(C_TransmogOutfitInfo, "ClearAllPendingTransmogs", function()
        locked = {}
        paintLocks()
    end)

    -- Slots are pooled and laid out again whenever the client thinks they have
    -- changed, so the padlock and its click go on whatever the pool hands out
    -- rather than once on the frames the first layout happened to use.
    -- The transmogrifier redraws its slots when the client has settled what it
    -- makes of them, which is the one moment a piece it has decided to refuse can
    -- be seen for what it is.
    hooksecurefunc(preview, "RefreshSlots", function()
        paintLocks()
        correctStuckSlots()
    end)
end

local classID
local function playerClassID()
    classID = classID or select(3, UnitClass("player"))
    return classID
end

-- Takes a source this character may transmogrify to. An appearance the whole
-- class can wear may still be collected only as a source restricted to another
-- class, and queueing one of those locks the slot with a piece the character is
-- refused, in an error state no later roll can clear.
--
-- Which sources are asked for matters as much as what is asked of them. Every
-- source an appearance has is on offer, another class's among them, and nothing
-- on one says so: the error it would raise is not there to be read until it is
-- worn. The Items tab never meets them, because it asks for the sources valid
-- for a class rather than for all of them, and so does this.
--
-- What is then asked of them is the tab's own question, of useErrorType: a
-- source with none set is one clicking the piece on that tab puts on without
-- complaint. isValidSourceForPlayer looks like the field to read and is not,
-- being a narrower thing that plenty of wearable sources answer no to; reading
-- it dropped each of those from a slot's pool the first draw that found it.
--
-- Artifact appearances carry an error of their own outside their own spec, which
-- the tab forgives in the ordinary weapon categories. No weapon slot is ever
-- rolled, so that error cannot reach here.
--
-- The "hide this slot" entries are the one exception: their lone source is not
-- always offered cleanly, or to a class at all, so it is taken on trust.
local function wearableSource(visualID, target)
    -- The hidden check reads the visual, not the source it resolves to.
    local isHidden = C_TransmogCollection.IsAppearanceHiddenVisual(visualID)

    local sources = C_TransmogCollection.GetValidAppearanceSourcesForClass(
        visualID, playerClassID(), target.category, target.locationData)
    for _, source in ipairs(sources or {}) do
        if source.isCollected and not source.useErrorType then return source.sourceID, isHidden end
    end

    if isHidden then
        local any = C_TransmogCollection.GetAppearanceSources(
            visualID, target.category, target.locationData)
        for _, source in ipairs(any or {}) do
            if source.isCollected then return source.sourceID, true end
        end
    end
end

-- A visual that resolves to nothing wearable is no use on any later roll
-- either, so it leaves the pool and the draw moves on to another. A plain spin
-- draws from the slot's whole pool, so those removals last the visit; a spin in
-- one colour draws from a shortlist built for it, and they last the spin.
local function drawSource(target)
    while #target.pool > 0 do
        local index = Randomiser.DrawIndex(target.pool, target.hiddenVisual, math.random)
        local sourceID, isHidden = wearableSource(target.pool[index], target)
        if sourceID then return sourceID, isHidden, index end
        table.remove(target.pool, index)
    end
end

-- What the client makes of a piece once it is on the slot is the only answer
-- that settles it, and it is not one that can be asked in advance. A source can
-- be collected, valid for this character's class and carrying no error of its
-- own, and the slot still refuse it: the reasons run past class to the race, the
-- form, the item's own type and quality, none of which are on the source to
-- read. Every draw is therefore looked at once it has landed.
--
-- Two answers come back: whether the client is marking the slot at all, and
-- whether it has stopped saying the slot can be transmogrified. The second is
-- what tells a slot that has gone wrong from one the client is still thinking
-- about. Every way of setting a slot runs through that answer, so a slot that
-- has lost it is a dead end no later spin can reach: it has to be freed where it
-- stands, or it keeps its warning for the rest of the visit however much is
-- rolled afterwards.
local function slotErrored(target)
    local slotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(
        target.slot, target.transmogType, SLOT_OPTION)
    if not slotInfo then return false, false end
    local errored = slotInfo.error ~= nil and slotInfo.error ~= Enum.TransmogOutfitSlotError.Ok
    return errored, errored and slotInfo.canTransmogrify == false
end

-- The visuals in a slot's pool carrying the colour lit on the Items tab, plus the
-- entry that wears nothing on the end. Wearing nothing keeps to any colour, so it
-- stands among the pieces as one more thing a slot can land on, exactly as it
-- does on a plain spin. A slot the colour leaves with nothing else is then hidden
-- rather than left wearing whatever was on it, which would be the one piece on
-- the character not keeping to the colour asked for.
local function inColour(visuals, target, hiddenVisual)
    local kept = {}
    for _, visualID in ipairs(visuals) do
        if visualID ~= hiddenVisual and LuckysWardrobe.Colours.Matches(visualID, target) then
            kept[#kept + 1] = visualID
        end
    end

    if hiddenVisual then kept[#kept + 1] = hiddenVisual end

    return kept
end

-- A piece just set is a piece the client has not had its say on yet, so the slot
-- goes back into the hands of the pass that reads the reel's work over.
local function setPending(target, sourceID, displayType)
    rolling = true
    target.settled = nil
    C_TransmogOutfitInfo.SetPendingTransmog(target.slot, target.transmogType, SLOT_OPTION, sourceID, displayType)
    rolling = false
end

-- Takes the slot back to what is already applied to it, which is what the
-- transmogrifier does on a right click. A slot the roll cannot find anything for
-- is better left as the player had it than handed a piece chosen by guesswork,
-- and a guess is all a remembered source is once the client has refused one.
local function revertPending(target)
    rolling = true
    C_TransmogOutfitInfo.RevertPendingTransmog(target.slot, target.transmogType, SLOT_OPTION)
    rolling = false
end

-- A piece the slot refuses leaves the pool the way one with no wearable source
-- does, and the draw moves on. Should the pool run out having already put
-- something refused on the slot, the slot is handed back the last piece it took,
-- or what it was showing when the spin began, so a spin never comes to rest on a
-- piece marked in error.
--
-- replacing is for a slot already holding one: the piece to give up is on it
-- before this call, so it has to come off even if no draw is made.
local function rollSlot(target, replacing)
    if locked[target.slot] then return end

    local slotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(target.slot, target.transmogType, SLOT_OPTION)
    if not slotInfo or not slotInfo.canTransmogrify then return end

    local refused = replacing or false
    while true do
        local sourceID, isHidden, index = drawSource(target)
        if not sourceID then
            if refused then
                if target.rolledSourceID then
                    setPending(target, target.rolledSourceID, target.rolledDisplayType)
                else
                    revertPending(target)
                end
            end
            return
        end

        local displayType = isHidden
            and Enum.TransmogOutfitDisplayType.Hidden
            or Enum.TransmogOutfitDisplayType.Assigned

        setPending(target, sourceID, displayType)
        if not slotErrored(target) then
            target.rolledSourceID = sourceID
            target.rolledDisplayType = displayType
            target.rolledVisualID = target.pool[index]
            return
        end

        refused = true
        table.remove(target.pool, index)
    end
end

local function roll()
    for _, target in ipairs(targets) do
        rollSlot(target)
    end
end

local function reapplyRoll()
    for _, target in ipairs(targets) do
        if target.rolledSourceID then
            setPending(target, target.rolledSourceID, target.rolledDisplayType)
        end
    end
end

local function reportStuckSlot(target)
    if not LuckysWardrobe.DevLog then return end
    local S = LuckysWardrobe.Strings.randomiser
    local slotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(
        target.slot, target.transmogType, SLOT_OPTION)
    local before = target.beforeError ~= nil
        and target.beforeError ~= Enum.TransmogOutfitSlotError.Ok
    LuckysWardrobe.DevLog(S.stuckSlot:format(
        target.slotName, tostring(target.rolledVisualID), tostring(target.rolledSourceID),
        tostring(slotInfo and slotInfo.error), slotInfo and slotInfo.errorText or "",
        before and S.stuckBefore or S.stuckFromRoll,
        tostring(slotInfo and slotInfo.canTransmogrify),
        tostring(slotInfo and slotInfo.hasPending), tostring(locked[target.slot] == true)))
end

-- Every slot the reel can reach, read once the spin is over, not only the ones
-- it landed something on: a slot left holding what it already had is the one
-- nothing in the roll's own records would explain.
local function reportStuckSlots()
    if not LuckysWardrobe.DevLog then return end

    for _, target in ipairs(targets or {}) do
        if slotErrored(target) then reportStuckSlot(target) end
    end
end

-- A slot the client has since refused gives the piece up and draws again, which
-- is the same course a draw takes when the check at the call catches it. The
-- visual leaves the pool, so a spin cannot land on it twice.
--
-- The piece comes off before anything else is tried, and by reverting rather
-- than by putting something over it. A slot holding a piece the client has
-- refused does not always answer that it can be transmogrified at all, and every
-- way of setting a slot runs through that answer: asked to draw first, the
-- refused piece would be left sitting there by the very check meant to clear it.
--
-- A piece the player put on locks the slot and is theirs, whatever the client
-- makes of it, so the reel does not take that one off.
--
-- Which errors are read again is what the dead end decides. A slot that has
-- stopped answering that it can be transmogrified has to be freed here or not at
-- all, so it is read on every redraw for as long as it stands in that state.
-- Every other error is read once: the redraw is the client saying it has made
-- its mind up, a redraw that finds the slot clean is that answer, and reading
-- them all for the rest of the visit is what put the reel back on slots nobody
-- had touched. The client marks a slot whose item data is still coming in, so
-- opening a slot's page had several of them reporting an error for as long as
-- the load ran, and every redraw through it took a good piece off and drew
-- another. A slot marked that way is still one a later spin can reach, which is
-- what makes it safe to leave.
local correcting
function correctStuckSlots()
    if correcting or rolling or not targets then return end
    correcting = true

    for _, target in ipairs(targets) do
        if target.pool and not locked[target.slot] then
            local errored, deadEnd = slotErrored(target)
            if not errored then
                target.settled = true
            elseif not target.gaveUp and (deadEnd or not target.settled) then
                reportStuckSlot(target)
                revertPending(target)

                for index, visualID in ipairs(target.pool) do
                    if visualID == target.rolledVisualID then
                        table.remove(target.pool, index)
                        break
                    end
                end
                target.rolledSourceID, target.rolledDisplayType, target.rolledVisualID = nil, nil, nil
                rollSlot(target)

                -- A slot still in error once ours is off it is one nothing the
                -- roll does can clear, so it is left alone from here rather than
                -- drawn at on every redraw.
                if slotErrored(target) then target.gaveUp = true end
            end
        end
    end

    correcting = false
end

local function stop()
    phase = nil
    reportStuckSlots()
    if driver then driver:Hide() end
    -- The reel has put a piece on every slot it touched, and each of those is now
    -- a slot with something worth keeping, so each wants its padlock.
    paintLocks()
end

local function advance(_, delta)
    elapsed = elapsed + delta
    if elapsed < interval then return end
    elapsed = 0

    if phase == SETTLING then
        reapplyRoll()
        stop()
        return
    end

    roll()

    if phase == SLOWING then
        interval = interval * SLOWDOWN
        if interval > SLOWEST_INTERVAL then
            phase = SETTLING
            interval = SETTLE_DELAY
        end
    end
end

-- colourTarget narrows what every slot can land on to the colour lit on the
-- Items tab. Without one the spin is the whole collection, which is the dice's
-- own offer.
local function beginRolling(colourTarget)
    if not targets or #targets == 0 then return end

    for _, target in ipairs(targets) do
        target.rolledSourceID = nil
        target.rolledDisplayType = nil
        target.rolledVisualID = nil
        target.gaveUp = nil
        target.settled = nil

        -- Whether the slot was already in an error before the spin touched it,
        -- which decides whether anything the roll does could clear it.
        local slotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(
            target.slot, target.transmogType, SLOT_OPTION)
        target.beforeError = slotInfo and slotInfo.error

        target.pool = colourTarget
            and inColour(target.visuals, colourTarget, target.hiddenVisual)
            or target.visuals
    end

    phase = HOLDING
    interval = ROLL_INTERVAL
    elapsed = 0
    roll()
    driver:Show()
end

local function releaseRoll()
    if phase ~= HOLDING then return end
    phase = SLOWING
end

local function createButton(preview)
    local strings = LuckysWardrobe.Strings.randomiser

    button = CreateFrame("Button", nil, preview, "SquareIconButtonTemplate")
    button:SetPoint("TOPRIGHT", -23, -92)
    -- The preview's model scene covers the whole frame, so the button has to
    -- sit above it to take the mouse at all.
    button:SetFrameLevel((preview.ModelScene or preview):GetFrameLevel() + 10)
    button:SetAtlas("charactercreate-icon-dice")

    button.tooltipTitle = strings.tooltipTitle
    button.tooltipText = strings.tooltipText
    button.tooltipAnchor = "ANCHOR_RIGHT"

    -- The template owns these scripts, so its own handler runs first and keeps
    -- the icon's depress animation.
    button:SetScript("OnMouseDown", function(self, mouseButton)
        self:OnMouseDown()
        if mouseButton == "LeftButton" then beginRolling() end
    end)
    button:SetScript("OnMouseUp", function(self)
        self:OnMouseUp()
        releaseRoll()
    end)
    button:SetScript("OnHide", stop)

    driver = CreateFrame("Frame", nil, button)
    driver:Hide()
    driver:SetScript("OnUpdate", advance)
end

-- The colour roll, beside the dice it is a narrowed version of. It only stands
-- there while the Items tab's strip has a colour lit, since without one it would
-- offer exactly what the dice beside it already does.
local SWATCH_SIZE = 10

local function pickedTarget()
    local _, target = LuckysWardrobe.TransmogItems.PickedColour()
    return target
end

local function createColourButton(preview)
    colourButton = CreateFrame("Button", nil, preview, "SquareIconButtonTemplate")
    colourButton:SetPoint("RIGHT", button, "LEFT", -4, 0)
    colourButton:SetFrameLevel(button:GetFrameLevel())
    colourButton:SetAtlas("charactercreate-icon-dice")
    colourButton:Hide()

    -- Stamped over the dice rather than beside it, so the button reads as the
    -- same offer in a colour rather than as a second thing to press.
    colourButton.Swatch = colourButton:CreateTexture(nil, "OVERLAY", nil, 1)
    colourButton.Swatch:SetSize(SWATCH_SIZE, SWATCH_SIZE)
    colourButton.Swatch:SetPoint("BOTTOMRIGHT", -2, 2)

    colourButton.tooltipAnchor = "ANCHOR_RIGHT"

    colourButton:SetScript("OnMouseDown", function(self, mouseButton)
        self:OnMouseDown()
        if mouseButton == "LeftButton" then beginRolling(pickedTarget()) end
    end)
    colourButton:SetScript("OnMouseUp", function(self)
        self:OnMouseUp()
        releaseRoll()
    end)
end

-- The strip calls this whenever a swatch is clicked, and the open does it once
-- so a colour still lit from an earlier visit brings the button back.
function Randomiser:OnColourPicked()
    if not colourButton then return end

    local key, _, preset = LuckysWardrobe.TransmogItems.PickedColour()
    colourButton:SetShown(key ~= nil)
    if not key then return end

    LuckysWardrobe.TransmogItems.PaintSwatch(colourButton.Swatch, preset)

    local strings = LuckysWardrobe.Strings
    local S = strings.randomiser
    colourButton.tooltipTitle = preset.unmatched and S.otherTitle
        or S.colourTitle:format(strings.colours[key])
    colourButton.tooltipText = S.colourText
end

function Randomiser:OnTransmogOpen()
    local preview = TransmogFrame and TransmogFrame.CharacterPreview
    if not preview then return end

    if not button then
        createButton(preview)
        createColourButton(preview)
    end
    installLockHooks(preview)
    buildTargets()
    paintLocks()
    Randomiser:OnColourPicked()
end

local function sourceName(visualID)
    for _, sourceID in ipairs(C_TransmogCollection.GetAllAppearanceSources(visualID) or {}) do
        local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
        if sourceInfo then
            local name = sourceInfo.name
            if (not name or name == "") and sourceInfo.itemID then
                name = C_Item.GetItemInfo(sourceInfo.itemID)
            end
            if name and name ~= "" then return name end
        end
    end
    return UNKNOWN
end

-- Every appearance in the client's list for a slot that carries the lit colour,
-- named, with what the roll makes of each. The Items tab draws only what is
-- collected and usable, so anything answering no to either is a piece that is on
-- neither the tab nor the roll, whatever else it looks like.
local function printColourDetail(category, listed, target)
    local S = LuckysWardrobe.Strings.randomiser
    for _, appearance in ipairs(listed) do
        if not appearance.isHideVisual
            and LuckysWardrobe.Colours.Matches(appearance.visualID, target) then
            Utils.Say(S.poolsPiece:format(appearance.visualID,
                tostring(appearance.isCollected), tostring(appearance.isUsable),
                sourceName(appearance.visualID)))
        end
    end
    Utils.Say(S.poolsDetailEnd:format(tostring(category)))
end

-- Dev only. Says which slots a spin can reach and how much each has to draw
-- from, because a slot that never changes and a slot with one thing in it look
-- the same from the outside. With a colour lit it also splits what the colour
-- leaves out: pieces the client lists but the character has not collected, and
-- pieces it has collected but cannot wear. Neither reaches the Items tab either,
-- which draws only what is collected and usable, so a slot showing more on the
-- tab than the roll can use means one of those two counts is not zero.
--
-- category names one to list every matching piece for, which is how a piece that
-- ought to be there gets found.
function Randomiser:PrintPools(wantedCategory)
    local S = LuckysWardrobe.Strings.randomiser
    if not targets then return Utils.Say(S.poolsClosed) end

    local wanted = tonumber(wantedCategory)
    local _, target = LuckysWardrobe.TransmogItems.PickedColour()
    Utils.Say(S.poolsHeader:format(#targets))

    for _, slotEntry in pairs(TRANSMOG_SLOTS) do
        local location = slotEntry.location
        local category = slotEntry.armorCategoryID
        local slot = location and location:GetSlot()
        local name = _G[location and location:GetSlotName() or ""] or tostring(slot)

        local rolled = slot and targetFor(slot)
        if not rolled then
            local why
            if not category then why = S.poolsNoCategory
            elseif location:IsSecondary() then why = S.poolsSecondary
            elseif not location:IsAppearance() then why = S.poolsNotAppearance
            elseif C_TransmogOutfitInfo.IsSlotWeaponSlot(slot) then why = S.poolsWeapon
            else why = S.poolsNothingCollected end
            Utils.Say(S.poolsSkipped:format(name, tostring(category), why))
        else
            local listed = LuckysWardrobe.TransmogItems.CategoryAppearances(
                category, rolled.locationData) or {}

            local slotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(
                slot, rolled.transmogType, SLOT_OPTION)
            Utils.Say(S.poolsSlot:format(name, tostring(category), #listed, #rolled.visuals,
                tostring(slotInfo and slotInfo.canTransmogrify),
                tostring(rolled.hiddenVisual ~= nil)))

            if target then
                local uncollected, unusable = 0, 0
                for _, appearance in ipairs(listed) do
                    if not appearance.isHideVisual
                        and LuckysWardrobe.Colours.Matches(appearance.visualID, target) then
                        if not appearance.isCollected then
                            uncollected = uncollected + 1
                        elseif not appearance.isUsable then
                            unusable = unusable + 1
                        end
                    end
                end
                Utils.Say(S.poolsColour:format(
                    #inColour(rolled.visuals, target, rolled.hiddenVisual),
                    uncollected, unusable))
                if wanted and wanted == category then
                    printColourDetail(category, listed, target)
                end
            end
        end
    end
end

-- Dev only. What every slot the reel can reach is holding right now, and what
-- the client makes of it, for a slot found sitting in an error after a spin.
--
-- The slot's own error is the one the transmogrifier draws its warning from, and
-- it is read here rather than remembered, so a slot that passed its check when
-- the piece landed and fails now is a slot the client changed its mind about
-- afterwards. Beside it goes what the source says about itself, which is every
-- other thing a roll could have asked before putting it on: whether reading any
-- of those would have caught this piece is the whole question.
function Randomiser:PrintSlots()
    local S = LuckysWardrobe.Strings.randomiser
    if not targets then return Utils.Say(S.poolsClosed) end

    Utils.Say(S.slotsHeader:format(#targets))
    for _, target in ipairs(targets) do
        local slotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(
            target.slot, target.transmogType, SLOT_OPTION)
        local sourceID = slotInfo and slotInfo.transmogID
        Utils.Say(S.slotsSlot:format(target.slotName, tostring(sourceID),
            tostring(slotInfo and slotInfo.error), (slotInfo and slotInfo.errorText or ""),
            tostring(slotInfo and slotInfo.displayType)))

        local rolledHere = target.rolledSourceID == sourceID
        Utils.Say(S.slotsRolled:format(tostring(rolledHere),
            tostring(target.rolledVisualID), tostring(target.rolledSourceID)))

        local source = sourceID and C_TransmogCollection.GetSourceInfo(sourceID)
        if source then
            Utils.Say(S.slotsSource:format(source.name or UNKNOWN,
                tostring(source.isCollected), tostring(source.useErrorType),
                tostring(source.useError), tostring(source.isValidSourceForPlayer)))
        end
    end
end

function Randomiser:OnTransmogClose()
    stop()
    targets = nil
    locked = {}
end
