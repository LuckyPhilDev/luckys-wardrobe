-- luacheck: globals C_AddOns C_Timer C_UI EventUtil UIParent

-- Lucky's Wardrobe: Warns at login about the other wardrobe addons that change
-- the same windows this one does, and offers to turn the loser off. Whichever
-- way the player answers, one of the two stops loading, so the warning is gone
-- by the next screen rather than waiting on a trip to the AddOns list.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.AddonConflicts = {}

local AddonConflicts = LuckysWardrobe.AddonConflicts
local S = LuckysWardrobe.Strings.addonConflicts
local say = LuckysWardrobe.Utils.Say
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

-- Long enough after the dialog is shown for anything taking it off screen on a
-- timer of its own to have run.
local SETTLE_SECONDS = 1

local dialog
-- The methods as this file published them, filled in once they are defined.
local published
-- Sticky once seen, so every showing after carries the line, not only the one
-- that caught it.
local interference = false

local function findConflicts()
    local found = {}
    for _, conflict in ipairs(CONFLICTS) do
        if C_AddOns.DoesAddOnExist(conflict.addon) and C_AddOns.IsAddOnLoaded(conflict.addon) then
            found[#found + 1] = conflict
        end
    end
    return found
end

function AddonConflicts:Find()
    return findConflicts()
end

local function entryPointsReplaced()
    for name, method in pairs(published) do
        if AddonConflicts[name] ~= method then return true end
    end
    return false
end

-- A frame's methods come from its metatable, so one sitting on the frame itself
-- was put there by a hook.
local function dialogHooked(frame)
    return rawget(frame, "Show") ~= nil or rawget(frame, "Hide") ~= nil
        or rawget(frame, "SetShown") ~= nil
end

-- Shown is not the same as on screen: a parent hidden, an alpha zeroed or an
-- anchor cleared all leave IsShown true.
local function offScreen(frame)
    return not frame:IsVisible() or frame:GetEffectiveAlpha() == 0
        or frame:GetParent() ~= UIParent or frame:GetNumPoints() == 0
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

CreateFrame("Frame", "LuckysWardrobeAddonConflict", UIParent)

local function build()
    local frame = LuckyUI.CreatePanel(nil, UIParent, PANEL_WIDTH, 200)
    frame:SetPoint("CENTER", 0, 120)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    LuckyUI.CreateHeader(frame, S.title)
    -- The header's close button is the one way the player takes the dialog off
    -- screen without reloading, so it is told apart from anything else that does.
    local closeButton = frame.header:GetChildren()
    closeButton:HookScript("OnClick", function() frame.dismissed = true end)

    frame.headline = addLine(frame, nil, 14, LuckyUI.C.textLight)
    frame.explain = addLine(frame, frame.headline, 11, LuckyUI.C.textMuted)
    frame.oldFolder = addLine(frame, frame.explain, 11, LuckyUI.C.goldAccent)
    frame.interfered = addLine(frame, frame.oldFolder, 11, LuckyUI.C.danger)
    frame.interfered:SetText(S.interfered)

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
    for _, line in ipairs({ frame.headline, frame.explain, frame.oldFolder, frame.interfered }) do
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

local function headline(found)
    if #found > 1 then
        return S.bothEnabled:format(found[1].name, found[2].name)
    end
    return S.oneEnabled:format(found[1].name)
end

local function populate(frame, found)
    local oldFolder
    for _, conflict in ipairs(found) do
        oldFolder = oldFolder or conflict.note
    end

    frame.headline:SetText(headline(found))
    frame.disableThem:SetText(#found > 1 and S.disableBoth or S.disableOne:format(found[1].name))
    frame.explain:SetText(S.explain)
    frame.oldFolder:SetText(oldFolder or "")
    frame.oldFolder:SetShown(oldFolder ~= nil)
    frame.interfered:SetShown(interference)
    -- Hangs off whichever line above it is showing.
    frame.interfered:ClearAllPoints()
    frame.interfered:SetPoint("TOPLEFT", oldFolder and frame.oldFolder or frame.explain,
        "BOTTOMLEFT", 0, -LINE_GAP)

    frame.disableThem:SetScript("OnClick", function()
        for _, conflict in ipairs(found) do
            C_AddOns.DisableAddOn(conflict.addon)
        end
        C_UI.Reload()
    end)

    layout(frame)
end

local function warn()
    local found = findConflicts()
    if #found == 0 then
        return false
    end

    dialog = dialog or build()
    interference = interference or entryPointsReplaced() or dialogHooked(dialog)
    populate(dialog, found)
    dialog.dismissed = false
    dialog:Show()

    -- Chat is the one place the warning cannot be taken back from, so it goes
    -- there too once anything has been seen in the way of the dialog.
    C_Timer.After(SETTLE_SECONDS, function()
        if not dialog.dismissed and offScreen(dialog) then
            interference = true
        end
        if interference then
            say(headline(found) .. " " .. S.explain)
            say(S.interfered .. " " .. S.chatHint)
        end
    end)
    return true
end

function AddonConflicts:Warn()
    return warn()
end

function AddonConflicts:Init()
    -- Built here, during this addon's own load, so the panel is standing before
    -- anything that loads after it has run.
    dialog = dialog or build()
    -- A conflicting addon has loaded or it has not by the time the player is in,
    -- and waiting that long keeps the dialog off a half-built screen. The call is
    -- bound to the local now rather than looked up on the table then.
    EventUtil.ContinueOnPlayerLogin(warn)
end

published = { Warn = AddonConflicts.Warn, Find = AddonConflicts.Find, Init = AddonConflicts.Init }
