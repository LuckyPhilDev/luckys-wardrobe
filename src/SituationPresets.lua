-- luacheck: globals C_Timer C_TransmogOutfitInfo CANCEL CreateFrame GameTooltip GameTooltip_Hide MenuTemplates MenuUtil MenuVariants NO SAVE StaticPopupDialogs StaticPopup_OnClick StaticPopup_Show TransmogFrame UnitClass YES strtrim

-- Lucky's Wardrobe: Save and load Situation selections at the transmog window.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.SituationPresets = {}

local SituationPresets = LuckysWardrobe.SituationPresets
local strings = LuckysWardrobe.Strings.situationPresets
local db

local OPTION_FIELDS = { "situationID", "specID", "loadoutID", "equipmentSetID" }
local ICONS_PATH = "Interface\\AddOns\\Luckys_Wardrobe\\Images\\icons\\"
local ICON_GOLD = { 1.0, 0.824, 0.392 }

local function optionKey(option)
    local values = {}
    for index, field in ipairs(OPTION_FIELDS) do
        values[index] = option[field] or 0
    end
    return table.concat(values, ":")
end

local function forEachOption(callback)
    for _, category in ipairs(C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions() or {}) do
        for _, group in ipairs(category.groupData or {}) do
            for _, entry in ipairs(group.optionData or {}) do
                callback(entry.option)
            end
        end
    end
end

local function playerClassID()
    return select(3, UnitClass("player"))
end

-- A specialisation only exists on one class, so a preset that selects one is stored
-- against that class and stays hidden from every other character.
local function captureSelections()
    local selections = {}
    local classID
    forEachOption(function(option)
        if C_TransmogOutfitInfo.GetOutfitSituation(option) then
            selections[optionKey(option)] = true
            if (option.specID or 0) ~= 0 then classID = playerClassID() end
        end
    end)
    return selections, classID
end

-- Class scoped presets are keyed apart from shared ones so a druid saving "Raiding"
-- cannot silently overwrite the mage preset of the same name it can never see.
local function presetKey(name, classID)
    return classID and ("class%d:%s"):format(classID, name) or name
end

local function availablePresets()
    local classID = playerClassID()
    local presets = {}
    for key, preset in pairs(db.situationPresets) do
        if not preset.classID or preset.classID == classID then
            presets[#presets + 1] = { key = key, name = preset.name, preset = preset }
        end
    end
    table.sort(presets, function(left, right) return left.name < right.name end)
    return presets
end

-- An outfit is matched to a preset by the situation values the two would display,
-- so the outfit list can match what it already has cached without a second scan
-- reading option keys per outfit.
local matches

local function categoryValues(category, isSelected)
    local selected = {}
    for _, group in ipairs(category.groupData or {}) do
        for _, entry in ipairs(group.optionData or {}) do
            if isSelected(entry.option) then selected[#selected + 1] = entry.name end
        end
    end
    return table.concat(selected, "+")
end

local function signature(categories, valuesFor)
    local parts = {}
    for _, category in ipairs(categories) do
        parts[#parts + 1] = category.name .. "=" .. (valuesFor(category) or "")
    end
    return table.concat(parts, "\n")
end

-- A preset that selects nothing is left out, so an outfit with no situations set
-- is never named after it.
local function buildMatches()
    local categories = C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions() or {}
    local bySignature = {}
    for _, entry in ipairs(availablePresets()) do
        local selections = entry.preset.selections
        if next(selections) then
            bySignature[signature(categories, function(category)
                return categoryValues(category, function(option) return selections[optionKey(option)] end)
            end)] = entry.name
        end
    end
    return { categories = categories, bySignature = bySignature }
end

function SituationPresets:NameFor(values)
    if not values then return end
    matches = matches or buildMatches()
    return matches.bySignature[signature(matches.categories, function(category)
        return values[category.name]
    end)]
end

function SituationPresets:UpdateLoadButton()
    -- Every path that changes which presets exist comes through here, so the
    -- matching is rebuilt from the same point.
    matches = nil
    if self.loadButton then
        self.loadButton:SetEnabled(#availablePresets() > 0)
    end
end

function SituationPresets:Save(name, overwrite)
    name = strtrim(name)
    if name == "" then return end

    local selections, classID = captureSelections()
    local key = presetKey(name, classID)
    if not overwrite and db.situationPresets[key] then
        StaticPopup_Show("LUCKYS_WARDROBE_REPLACE_SITUATION", name, nil, name)
        return false
    end

    db.situationPresets[key] = { name = name, classID = classID, selections = selections }
    self:UpdateLoadButton()
    return true
end

function SituationPresets:Delete(key)
    db.situationPresets[key] = nil
    self:UpdateLoadButton()
end

function SituationPresets:Apply(preset, situationsFrame)
    if not C_TransmogOutfitInfo.GetOutfitSituationsEnabled() then
        C_TransmogOutfitInfo.SetOutfitSituationsEnabled(true)
    end

    -- Clear first so mutually exclusive options never compete while staging.
    forEachOption(function(option)
        if C_TransmogOutfitInfo.GetOutfitSituation(option) and not preset.selections[optionKey(option)] then
            C_TransmogOutfitInfo.UpdatePendingSituation(option, false)
        end
    end)
    forEachOption(function(option)
        if preset.selections[optionKey(option)] and not C_TransmogOutfitInfo.GetOutfitSituation(option) then
            C_TransmogOutfitInfo.UpdatePendingSituation(option, true)
        end
    end)
    C_TransmogOutfitInfo.CommitPendingSituations()
    situationsFrame:Refresh()
end

StaticPopupDialogs["LUCKYS_WARDROBE_SAVE_SITUATION"] = {
    preferredIndex = 3,
    text = strings.saveDialog,
    button1 = SAVE,
    button2 = CANCEL,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    hasEditBox = 1,
    maxLetters = 31,
    OnAccept = function(dialog)
        SituationPresets:Save(dialog:GetEditBox():GetText())
    end,
    OnShow = function(dialog)
        dialog:GetButton1():Disable()
        dialog:GetEditBox():SetFocus()
    end,
    OnHide = function(dialog)
        dialog:GetEditBox():SetText("")
    end,
    EditBoxOnEnterPressed = function(editBox)
        if editBox:GetParent():GetButton1():IsEnabled() then
            StaticPopup_OnClick(editBox:GetParent(), 1)
        end
    end,
    EditBoxOnTextChanged = function(editBox)
        editBox:GetParent():GetButton1():SetEnabled(strtrim(editBox:GetText()) ~= "")
    end,
    EditBoxOnEscapePressed = function(editBox)
        editBox:GetParent():Hide()
    end,
}

StaticPopupDialogs["LUCKYS_WARDROBE_REPLACE_SITUATION"] = {
    preferredIndex = 3,
    text = strings.replaceDialog,
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    OnAccept = function(_dialog, name)
        SituationPresets:Save(name, true)
    end,
}

StaticPopupDialogs["LUCKYS_WARDROBE_DELETE_SITUATION"] = {
    preferredIndex = 3,
    text = strings.deleteDialog,
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    OnAccept = function(_dialog, key)
        SituationPresets:Delete(key)
    end,
}

local function createIconButton(parent, icon, tooltipText)
    local texture = ICONS_PATH .. icon
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(20, 20)
    button:SetNormalTexture(texture)
    button:SetHighlightTexture(texture, "ADD")
    button:SetDisabledTexture(texture)
    button:GetNormalTexture():SetVertexColor(unpack(ICON_GOLD))
    button:GetHighlightTexture():SetVertexColor(unpack(ICON_GOLD))
    button:GetHighlightTexture():SetAlpha(0.35)
    button:GetDisabledTexture():SetVertexColor(0.35, 0.35, 0.35)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltipText)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

local function installButtons()
    if SituationPresets.loadButton then return end
    local wardrobe = TransmogFrame and TransmogFrame.WardrobeCollection
    local situationsFrame = wardrobe and wardrobe.TabContent and wardrobe.TabContent.SituationsFrame
    if not situationsFrame or not situationsFrame.Situations then return end

    local loadButton = createIconButton(situationsFrame, "load-situation", strings.load)
    loadButton:SetPoint("BOTTOMRIGHT", situationsFrame.Situations, "TOPRIGHT", 0, 10)
    loadButton:SetScript("OnClick", function()
        MenuUtil.CreateContextMenu(loadButton, function(_owner, rootDescription)
            for _, entry in ipairs(availablePresets()) do
                local presetButton = rootDescription:CreateButton(entry.name, function()
                    SituationPresets:Apply(entry.preset, situationsFrame)
                end)
                presetButton:AddInitializer(function(menuButton, _description, menu)
                    local deleteButton = MenuTemplates.AttachBasicButton(menuButton)
                    deleteButton:SetPoint("RIGHT", menuButton, "RIGHT", -3, 0)
                    local deleteIcon = deleteButton:AttachTexture()
                    deleteIcon:SetAllPoints()
                    deleteIcon:SetTexture(MenuVariants.CancelButtonTexture)
                    deleteButton:SetScript("OnClick", function()
                        StaticPopup_Show("LUCKYS_WARDROBE_DELETE_SITUATION", entry.name, nil, entry.key)
                        menu:Close()
                    end)
                    MenuUtil.HookTooltipScripts(deleteButton, function(tooltip)
                        tooltip:SetText(strings.deleteTooltip)
                    end)
                end)
            end
        end)
    end)

    local saveButton = createIconButton(situationsFrame, "save-situation", strings.save)
    saveButton:SetPoint("RIGHT", loadButton, "LEFT", -6, 0)
    saveButton:SetScript("OnClick", function()
        StaticPopup_Show("LUCKYS_WARDROBE_SAVE_SITUATION")
    end)

    SituationPresets.loadButton = loadButton
end

function SituationPresets:Init(database)
    db = database

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("TRANSMOGRIFY_OPEN")
    eventFrame:SetScript("OnEvent", function()
        C_Timer.After(0.1, function()
            installButtons()
            SituationPresets:UpdateLoadButton()
        end)
    end)
end
