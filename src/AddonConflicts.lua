-- luacheck: globals C_AddOns C_UI EventUtil UIParent

-- Lucky's Wardrobe: Warns at login about the other wardrobe addons that change
-- the same windows this one does, and offers to turn the loser off. Whichever
-- way the player answers, one of the two stops loading, so the warning is gone
-- by the next screen rather than waiting on a trip to the AddOns list.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.AddonConflicts = {}

local AddonConflicts = LuckysWardrobe.AddonConflicts
local S = LuckysWardrobe.Strings.addonConflicts
local ADDON_NAME = "Luckys_Wardrobe"

-- A conflict is one that is running, not merely installed, since a copy already
-- turned off breaks nothing and there is nothing left to offer about it.
local CONFLICTS = {
    { addon = "BetterWardrobe", name = S.betterWardrobe },
    -- Lucky's Better Wardrobe shipped under the same CurseForge project as this
    -- addon, so the update that replaced it left its folder sitting there.
    -- Turning it off settles the errors, but only the player can clear the
    -- folder, so this one carries a note saying so.
    { addon = "LuckysBetterWardrobe", name = S.luckysBetterWardrobe, note = S.oldFolder },
}

-- Wide enough that the two buttons sit side by side even when both spell out a
-- full addon name, which "Disable Lucky's Better Wardrobe" comes closest to.
local PANEL_WIDTH = 460
local PADDING = 16
local TEXT_WIDTH = PANEL_WIDTH - PADDING * 2
local TEXT_TOP = 45
local LINE_GAP = 8
local TEXT_TO_BUTTON_GAP = 18
local BUTTON_HEIGHT = 26
local BUTTON_GAP = 8
local HINT_HEIGHT = 14
local BOTTOM_PADDING = 12

local dialog

function AddonConflicts:Find()
    local found = {}
    for _, conflict in ipairs(CONFLICTS) do
        if C_AddOns.DoesAddOnExist(conflict.addon) and C_AddOns.IsAddOnLoaded(conflict.addon) then
            found[#found + 1] = conflict
        end
    end
    return found
end

-- Giving each line its own width rather than anchoring both sides lets the
-- wrapped height be read straight after the text goes in, which is what the
-- panel is sized from.
local function addLine(frame, previous, size, color)
    local line = frame:CreateFontString(nil, "OVERLAY")
    line:SetFont(LuckyUI.BODY_FONT, size)
    line:SetWidth(TEXT_WIDTH)
    line:SetJustifyH("LEFT")
    line:SetWordWrap(true)
    line:SetTextColor(color[1], color[2], color[3])
    if previous then
        line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -LINE_GAP)
    else
        line:SetPoint("TOPLEFT", PADDING, -TEXT_TOP)
    end
    return line
end

local function build()
    local frame = LuckyUI.CreatePanel("LuckysWardrobeAddonConflict", UIParent, PANEL_WIDTH, 200)
    frame:SetPoint("CENTER", 0, 120)
    frame:SetFrameStrata("DIALOG")
    LuckyUI.CreateHeader(frame, S.title)

    frame.headline = addLine(frame, nil, 14, LuckyUI.C.textLight)
    frame.explain = addLine(frame, frame.headline, 11, LuckyUI.C.textMuted)
    frame.oldFolder = addLine(frame, frame.explain, 11, LuckyUI.C.goldAccent)

    local hint = frame:CreateFontString(nil, "OVERLAY")
    hint:SetFont(LuckyUI.BODY_FONT, 10)
    hint:SetPoint("BOTTOM", frame, "BOTTOM", 0, BOTTOM_PADDING)
    hint:SetTextColor(LuckyUI.C.goldMuted[1], LuckyUI.C.goldMuted[2], LuckyUI.C.goldMuted[3])
    hint:SetText(S.reloadHint)

    -- Keeping Lucky's Wardrobe is the answer offered first, but the other addon
    -- may well be the one they came for, so leaving is a button rather than a
    -- trip to the AddOns list.
    frame.disableThem = LuckyUI.CreateButton(frame, "", 100, BUTTON_HEIGHT, "primary")
    frame.disableSelf = LuckyUI.CreateButton(frame, S.disableSelf, 100, BUTTON_HEIGHT, "secondary")
    frame.disableSelf:SetScript("OnClick", function()
        C_AddOns.DisableAddOn(ADDON_NAME)
        C_UI.Reload()
    end)

    return frame
end

local function fitToText(button)
    button:SetWidth(button.label:GetStringWidth() + 24)
end

local function layout(frame)
    local height = TEXT_TOP
    for _, line in ipairs({ frame.headline, frame.explain, frame.oldFolder }) do
        if line:IsShown() then
            height = height + line:GetStringHeight() + LINE_GAP
        end
    end
    frame:SetHeight(height - LINE_GAP + TEXT_TO_BUTTON_GAP + BUTTON_HEIGHT
        + LINE_GAP + HINT_HEIGHT + BOTTOM_PADDING)

    fitToText(frame.disableThem)
    fitToText(frame.disableSelf)
    local rowWidth = frame.disableThem:GetWidth() + BUTTON_GAP + frame.disableSelf:GetWidth()
    frame.disableThem:SetPoint("BOTTOMLEFT", frame, "BOTTOM", -rowWidth / 2,
        BOTTOM_PADDING + HINT_HEIGHT + LINE_GAP)
    frame.disableSelf:SetPoint("LEFT", frame.disableThem, "RIGHT", BUTTON_GAP, 0)
end

local function populate(frame, found)
    local oldFolder
    for _, conflict in ipairs(found) do
        oldFolder = oldFolder or conflict.note
    end

    if #found > 1 then
        frame.headline:SetText(S.bothEnabled:format(found[1].name, found[2].name))
        frame.disableThem:SetText(S.disableBoth)
    else
        frame.headline:SetText(S.oneEnabled:format(found[1].name))
        frame.disableThem:SetText(S.disableOne:format(found[1].name))
    end
    frame.explain:SetText(S.explain)
    frame.oldFolder:SetText(oldFolder or "")
    frame.oldFolder:SetShown(oldFolder ~= nil)

    frame.disableThem:SetScript("OnClick", function()
        for _, conflict in ipairs(found) do
            C_AddOns.DisableAddOn(conflict.addon)
        end
        C_UI.Reload()
    end)

    layout(frame)
end

function AddonConflicts:Warn()
    local found = self:Find()
    if #found == 0 then
        return false
    end

    dialog = dialog or build()
    populate(dialog, found)
    dialog:Show()
    return true
end

function AddonConflicts:Init()
    -- A conflicting addon has loaded or it has not by the time the player is in,
    -- and waiting that long keeps the dialog off a half-built screen.
    EventUtil.ContinueOnPlayerLogin(function()
        self:Warn()
    end)
end
