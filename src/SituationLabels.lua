-- luacheck: globals C_Timer C_TransmogOutfitInfo CreateFrame EventUtil GRAY_FONT_COLOR GameTooltip GameTooltip_AddHighlightLine GameTooltip_Hide GameTooltip_SetTitle LuckyUI TRANSMOG_SITUATION_CATEGORY_LIST_SEPARATOR TransmogFrame TransmogOutfitEntryMixin UnitGUID hooksecurefunc unpack

-- Lucky's Wardrobe: Show selected situation values on the transmog outfit list.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.SituationLabels = {}

local SituationLabels = LuckysWardrobe.SituationLabels
local strings = LuckysWardrobe.Strings.situationLabels
local db

local values
local reading = false
local restoring = false

-- Fallback only: each scan step normally advances the moment
-- VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED confirms the new outfit is live.
local STEP_TIMEOUT = 0.1
local pendingStep

local function waitForSituations(run)
    local step = { run = run }
    pendingStep = step
    C_Timer.After(STEP_TIMEOUT, function()
        if pendingStep == step then
            pendingStep = nil
            step.run()
        end
    end)
end

local function advanceScan()
    local step = pendingStep
    if not step then return end
    pendingStep = nil
    step.run()
end

local BAR_WIDTH = 360
local BAR_INSET = 2

local scanOverlay

local function createScanOverlay()
    local frame = CreateFrame("Frame", "LuckysWardrobeSituationScanOverlay", TransmogFrame)
    frame:SetAllPoints(TransmogFrame)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:Hide()

    local shade = frame:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.65)

    local panel = LuckyUI.CreatePanel(nil, frame, 440, 170)
    panel:SetPoint("CENTER")

    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFont(LuckyUI.TITLE_FONT, 18)
    title:SetTextColor(unpack(LuckyUI.C.goldPrimary))
    title:SetPoint("TOP", 0, -20)
    title:SetText(strings.scanTitle)

    local message = panel:CreateFontString(nil, "OVERLAY")
    message:SetFont(LuckyUI.BODY_FONT, 13)
    message:SetTextColor(unpack(LuckyUI.C.textLight))
    message:SetPoint("TOP", title, "BOTTOM", 0, -12)
    message:SetWidth(400)
    message:SetJustifyH("CENTER")
    message:SetText(strings.scanMessage)

    local track = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    track:SetSize(BAR_WIDTH, 16)
    track:SetPoint("BOTTOM", 0, 46)
    track:SetBackdrop(LuckyUI.Backdrop)
    track:SetBackdropColor(unpack(LuckyUI.C.bgInput))
    track:SetBackdropBorderColor(unpack(LuckyUI.C.borderDark))

    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", BAR_INSET, -BAR_INSET)
    fill:SetPoint("BOTTOMLEFT", BAR_INSET, BAR_INSET)
    fill:SetColorTexture(unpack(LuckyUI.C.goldAccent))

    local count = panel:CreateFontString(nil, "OVERLAY")
    count:SetFont(LuckyUI.BODY_FONT, 12)
    count:SetTextColor(unpack(LuckyUI.C.textMuted))
    count:SetPoint("BOTTOM", 0, 22)

    function frame:SetProgress(done, total)
        local usable = BAR_WIDTH - BAR_INSET * 2
        fill:SetWidth(math.max(1, usable * (done / math.max(total, 1))))
        count:SetText(strings.scanCount:format(done, total))
    end

    return frame
end

local function showScanOverlay(total)
    scanOverlay = scanOverlay or createScanOverlay()
    scanOverlay:SetProgress(0, total)
    scanOverlay:Show()
end

local function setScanProgress(done, total)
    if scanOverlay then scanOverlay:SetProgress(done, total) end
end

local function hideScanOverlay()
    if scanOverlay then scanOverlay:Hide() end
end

-- The tooltip lists the same values the entry subtitle can show, so the cache is
-- worth building whenever either surface is on.
local function valuesNeeded()
    return db.showSituationValues or db.showSituationTooltips
end

-- Situation selections reference class specialisations and equipment sets, so the
-- cache belongs to the character that read it.
local function storedValues()
    local guid = UnitGUID("player")
    db.situationLabels[guid] = db.situationLabels[guid] or {}
    return db.situationLabels[guid]
end

local function saveValues()
    local keep = {}
    for _, outfit in ipairs(C_TransmogOutfitInfo.GetOutfitsInfo() or {}) do
        keep[outfit.outfitID] = true
    end
    for outfitID in pairs(values) do
        if not keep[outfitID] then values[outfitID] = nil end
    end
    db.situationLabels[UnitGUID("player")] = values
end

local function readValues()
    local result = {}
    for _, category in ipairs(C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions() or {}) do
        local selected = {}
        for _, group in ipairs(category.groupData or {}) do
            for _, entry in ipairs(group.optionData or {}) do
                if C_TransmogOutfitInfo.GetOutfitSituation(entry.option) then
                    selected[#selected + 1] = entry.name
                end
            end
        end
        result[category.name] = table.concat(selected, "+")
    end
    return result
end

local function selectedValues(outfitID, categoryName)
    values = values or storedValues()
    local outfitValues = values[outfitID]
    local categoryValues = outfitValues and outfitValues[categoryName]
    if categoryValues ~= "" then return categoryValues end
end

-- The outfit list rebuilds its element data from the API on every refresh, so the
-- override has to be reapplied per entry rather than stored on the element data.
local function situationText(elementData)
    local summary = {}
    local details = {}
    local showValues = db.showSituationValues
    for _, categoryName in ipairs(elementData.situationCategories or {}) do
        local categoryValues = selectedValues(elementData.outfitID, categoryName)
        summary[#summary + 1] = (showValues and categoryValues) or categoryName
        details[#details + 1] = { name = categoryName, values = categoryValues }
    end
    elementData.situationDetails = details
    return table.concat(summary, TRANSMOG_SITUATION_CATEGORY_LIST_SEPARATOR)
end

local function readableValues(text)
    return (text:gsub("%+", ", "))
end

local function tooltipLine(detail)
    if not detail.values then return detail.name end

    local label = GRAY_FONT_COLOR:WrapTextInColorCode(detail.name .. ":")
    return ("%s %s"):format(label, readableValues(detail.values))
end

local function tooltipDetails(elementData)
    if elementData.situationDetails then return elementData.situationDetails end

    local details = {}
    for _, categoryName in ipairs(elementData.situationCategories or {}) do
        details[#details + 1] = { name = categoryName }
    end
    return details
end

local function showSituationTooltip(entry)
    if not db.showSituationTooltips then return end

    local elementData = entry:GetElementData()
    if not elementData or not entry.OutfitButton.TextContent.SituationInfo:IsShown() then return end

    GameTooltip:SetOwner(entry.OutfitButton, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPLEFT", entry.OutfitButton, "TOPRIGHT", 4, 0)
    GameTooltip_SetTitle(GameTooltip, elementData.name)
    for _, detail in ipairs(tooltipDetails(elementData)) do
        GameTooltip_AddHighlightLine(GameTooltip, tooltipLine(detail))
    end
    GameTooltip:Show()
end

local function installSituationTooltip(entry)
    if entry.luckySituationTooltip then return end
    entry.luckySituationTooltip = true

    entry.OutfitButton:HookScript("OnEnter", function() showSituationTooltip(entry) end)
    entry.OutfitButton:HookScript("OnLeave", GameTooltip_Hide)
end

local function applyEntry(entry, elementData)
    installSituationTooltip(entry)

    elementData = elementData or entry:GetElementData()
    if not elementData then return end

    local text = situationText(elementData)
    local content = entry.OutfitButton.TextContent
    content.SituationInfo:SetShown(text ~= "")
    content.SituationInfo:SetText(text)
    content:Layout()
end

local function applyValues()
    if not TransmogFrame or not TransmogFrame.OutfitCollection then return end
    TransmogFrame.OutfitCollection.OutfitList.ScrollBox:ForEachFrame(applyEntry)
end

local function cacheValues()
    if not valuesNeeded() or reading or not TransmogFrame or not TransmogFrame:IsShown() then return end
    if C_TransmogOutfitInfo.HasPendingOutfitSituations() or C_TransmogOutfitInfo.HasPendingOutfitTransmogs() then return end

    local outfits = C_TransmogOutfitInfo.GetOutfitsInfo()
    if not outfits or #outfits == 0 then return end

    values = values or storedValues()
    local viewedOutfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
    local missing = {}
    for _, outfit in ipairs(outfits) do
        if not values[outfit.outfitID] then
            if #(outfit.situationCategories or {}) == 0 then
                values[outfit.outfitID] = {}
            elseif outfit.outfitID == viewedOutfitID then
                values[outfit.outfitID] = readValues()
            else
                missing[#missing + 1] = outfit
            end
        end
    end
    if #missing == 0 then
        applyValues()
        saveValues()
        return
    end

    reading = true
    showScanOverlay(#missing)
    local index = 0
    local function finish()
        pendingStep = nil
        restoring = true
        C_TransmogOutfitInfo.ChangeViewedOutfit(viewedOutfitID)
        if valuesNeeded() then
            applyValues()
            saveValues()
        end
        reading = false
        hideScanOverlay()
        C_Timer.After(0.25, function() restoring = false end)
    end
    local function nextOutfit()
        if not valuesNeeded() then
            finish()
            return
        end
        index = index + 1
        local outfit = missing[index]
        if not outfit then
            finish()
            return
        end

        setScanProgress(index - 1, #missing)
        waitForSituations(function()
            values[outfit.outfitID] = readValues()
            nextOutfit()
        end)
        C_TransmogOutfitInfo.ChangeViewedOutfit(outfit.outfitID)
    end
    nextOutfit()
end

-- Closing the window mid-scan keeps what was already read; the rest is picked up
-- on the next open.
local function abortScan()
    if not reading then return end
    pendingStep = nil
    reading = false
    restoring = false
    hideScanOverlay()
    saveValues()
end

function SituationLabels:Refresh()
    if not TransmogFrame or not TransmogFrame:IsShown() then return end
    applyValues()
    cacheValues()
end

-- Entry frames copy their methods from the mixin when the list's pool creates them,
-- so the hook must land before Blizzard_Transmog builds its first outfit entry.
local function installEntryHook()
    hooksecurefunc(TransmogOutfitEntryMixin, "Init", applyEntry)
end

local function onSituationEvent(event)
    if reading then
        if event == "VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED" then advanceScan() end
        return
    end
    if restoring then return end
    if event == "VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED" and values and valuesNeeded() then
        values[C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()] = readValues()
        saveValues()
        applyValues()
    elseif TransmogFrame and TransmogFrame:IsShown() then
        cacheValues()
    end
end

function SituationLabels:Init(database)
    db = database

    EventUtil.ContinueOnAddOnLoaded("Blizzard_Transmog", installEntryHook)

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("TRANSMOGRIFY_OPEN")
    eventFrame:RegisterEvent("TRANSMOGRIFY_CLOSE")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "TRANSMOGRIFY_OPEN" then
            eventFrame:RegisterEvent("TRANSMOG_OUTFITS_CHANGED")
            eventFrame:RegisterEvent("VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED")
            C_Timer.After(0.1, cacheValues)
        elseif event == "TRANSMOGRIFY_CLOSE" then
            eventFrame:UnregisterEvent("TRANSMOG_OUTFITS_CHANGED")
            eventFrame:UnregisterEvent("VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED")
            abortScan()
        else
            onSituationEvent(event)
        end
    end)
end
