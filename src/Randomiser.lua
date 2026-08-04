-- luacheck: globals C_TransmogCollection C_TransmogOutfitInfo Constants CreateFrame Enum TRANSMOG_SLOTS TransmogFrame

-- Lucky's Ensemble: Spin every armour slot through appearances you already own.
LuckysEnsemble = LuckysEnsemble or {}
LuckysEnsemble.Randomiser = {}

local Randomiser = LuckysEnsemble.Randomiser

-- Held rolls run fast enough to blur into a spin. Letting go stretches each
-- wait by SLOWDOWN until the next one would outlast a reel coming to rest.
local ROLL_INTERVAL = 0.08
local SLOWDOWN = 1.55
local SLOWEST_INTERVAL = 0.6
-- The model redresses a frame or two behind a burst of pending changes, so the
-- final selection is sent again once the reel has been still this long.
local SETTLE_DELAY = 0.15

local HOLDING, SLOWING, SETTLING = "holding", "slowing", "settling"

-- Armour slots carry no weapon or sheathe variants.
local SLOT_OPTION = Enum.TransmogOutfitSlotOption.None

local button
local driver
local targets
local phase
local interval
local elapsed

local function collectedVisuals(category, locationData)
    local visuals = {}
    local appearances = C_TransmogCollection.GetCategoryAppearances(category, locationData)
    if not appearances then return visuals end

    for _, appearance in ipairs(appearances) do
        if appearance.isCollected and appearance.isUsable then
            table.insert(visuals, appearance.visualID)
        end
    end

    return visuals
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
                local visuals = collectedVisuals(category, locationData)
                if #visuals > 0 then
                    table.insert(targets, {
                        slot = slot,
                        transmogType = location:GetType(),
                        category = category,
                        locationData = locationData,
                        visuals = visuals,
                    })
                end
            end
        end
    end
end

-- Prefers a source this character may transmogrify to, and falls back to any
-- collected one so the "hide this slot" entries, whose lone source is not
-- always flagged valid, stay rollable.
local function collectedSource(visualID, target)
    local sources = C_TransmogCollection.GetAppearanceSources(visualID, target.category, target.locationData)
    if not sources then return nil end

    local fallbackID
    for _, source in ipairs(sources) do
        if source.isCollected then
            if source.isValidSourceForPlayer then return source.sourceID end
            fallbackID = fallbackID or source.sourceID
        end
    end

    return fallbackID
end

local function rollSlot(target)
    local slotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(target.slot, target.transmogType, SLOT_OPTION)
    if not slotInfo or not slotInfo.canTransmogrify then return end

    local visualID = target.visuals[math.random(#target.visuals)]
    local sourceID = collectedSource(visualID, target)
    if not sourceID then return end

    -- The hidden check reads the visual, not the source it resolved to.
    local displayType = C_TransmogCollection.IsAppearanceHiddenVisual(visualID)
        and Enum.TransmogOutfitDisplayType.Hidden
        or Enum.TransmogOutfitDisplayType.Assigned

    C_TransmogOutfitInfo.SetPendingTransmog(target.slot, target.transmogType, SLOT_OPTION, sourceID, displayType)
    target.rolledSourceID = sourceID
    target.rolledDisplayType = displayType
end

local function roll()
    for _, target in ipairs(targets) do
        rollSlot(target)
    end
end

local function reapplyRoll()
    for _, target in ipairs(targets) do
        if target.rolledSourceID then
            C_TransmogOutfitInfo.SetPendingTransmog(target.slot, target.transmogType, SLOT_OPTION,
                target.rolledSourceID, target.rolledDisplayType)
        end
    end
end

local function stop()
    phase = nil
    if driver then driver:Hide() end
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

local function beginRolling()
    if not targets or #targets == 0 then return end

    for _, target in ipairs(targets) do
        target.rolledSourceID = nil
        target.rolledDisplayType = nil
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
    local strings = LuckysEnsemble.Strings.randomiser

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

function Randomiser:OnTransmogOpen()
    local preview = TransmogFrame and TransmogFrame.CharacterPreview
    if not preview then return end

    if not button then createButton(preview) end
    buildTargets()
end

function Randomiser:OnTransmogClose()
    stop()
    targets = nil
end
