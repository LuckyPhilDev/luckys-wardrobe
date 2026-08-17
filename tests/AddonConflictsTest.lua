-- luacheck: globals C_AddOns C_UI EventUtil LuckyUI LuckysWardrobe UIParent

-- The dialog is the whole feature, so these go through it: what it says, and
-- what its buttons actually do to the addon list.

local loaded = {}
local installed = {}
local disabled = {}
local reloads = 0

C_AddOns = {
    IsAddOnLoaded = function(addon) return loaded[addon] == true end,
    DoesAddOnExist = function(addon) return installed[addon] == true end,
    DisableAddOn = function(addon) disabled[#disabled + 1] = addon end,
}

C_UI = { Reload = function() reloads = reloads + 1 end }

local loginCallback
EventUtil = {
    ContinueOnPlayerLogin = function(callback) loginCallback = callback end,
}

UIParent = {}

-- Text is measured to size the panel, so the stub answers in proportion to the
-- text rather than with zero.
local function FontString()
    local fs = { shown = true, text = "" }
    function fs:SetFont() end
    function fs:SetWidth() end
    function fs:SetJustifyH() end
    function fs:SetWordWrap() end
    function fs:SetPoint() end
    function fs:SetTextColor() end
    function fs:SetText(value) self.text = value or "" end
    function fs:GetText() return self.text end
    function fs:SetShown(shown) self.shown = shown end
    function fs:IsShown() return self.shown end
    function fs:GetStringWidth() return #self.text * 6 end
    function fs:GetStringHeight() return math.ceil(#self.text * 6 / 388) * 14 end
    return fs
end

local panel
local panels = 0

LuckyUI = {
    BODY_FONT = "font",
    C = {
        textLight = { 1, 1, 1 },
        textMuted = { 0.5, 0.5, 0.5 },
        goldAccent = { 0.8, 0.7, 0.3 },
        goldMuted = { 0.5, 0.4, 0.2 },
    },
    CreateHeader = function() end,
    CreatePanel = function()
        panels = panels + 1
        panel = { shown = false, height = 0 }
        function panel:SetPoint() end
        function panel:SetFrameStrata() end
        function panel:SetHeight(value) self.height = value end
        function panel:GetHeight() return self.height end
        function panel:Show() self.shown = true end
        function panel:IsShown() return self.shown end
        function panel:CreateFontString() return FontString() end
        return panel
    end,
    CreateButton = function(_, text, width, height)
        local button = { label = FontString(), width = width, height = height }
        button.label:SetText(text)
        function button:SetText(value) self.label:SetText(value) end
        function button:GetText() return self.label:GetText() end
        function button:SetWidth(value) self.width = value end
        function button:GetWidth() return self.width end
        function button:SetPoint() end
        function button:SetScript(_, handler) self.click = handler end
        return button
    end,
}

dofile("src/Strings.lua")
dofile("src/features/AddonConflicts.lua")

local S = LuckysWardrobe.Strings.addonConflicts
local AddonConflicts = LuckysWardrobe.AddonConflicts

local function enable(addon)
    installed[addon] = true
    loaded[addon] = true
end

local function only(addon)
    loaded, installed = {}, {}
    if addon then enable(addon) end
end

local function found()
    local list = {}
    for index, conflict in ipairs(AddonConflicts:Find()) do list[index] = conflict.addon end
    return table.concat(list, ",")
end

local function click(button)
    disabled, reloads = {}, 0
    button.click()
    return table.concat(disabled, ",")
end

-- A conflict is one that is running rather than one merely installed, because
-- turning an addon off is what the buttons do and a warning has to be one the
-- player can actually answer.
assert(found() == "", "found nothing with no other wardrobe addon around")

installed.BetterWardrobe = true
assert(found() == "", "ignored a Better Wardrobe that is installed but already turned off")

loaded.BetterWardrobe = true
assert(found() == "BetterWardrobe", "found a Better Wardrobe that is running")

enable("LuckysBetterWardrobe")
assert(found() == "BetterWardrobe,LuckysBetterWardrobe", "found both at once")

only(nil)
assert(not AddonConflicts:Warn(), "said nothing with no conflict to report")
assert(panels == 0, "built no dialog before there was anything to say")

-- One conflict: it is named in the headline and on the button that clears it.
only("BetterWardrobe")
assert(AddonConflicts:Warn(), "warned about a Better Wardrobe that is running")
assert(panel and panel:IsShown(), "put the dialog on screen")
assert(panel:GetHeight() > 0, "sized the dialog to the text it holds")
assert(panel.headline:GetText() == S.oneEnabled:format(S.betterWardrobe), "named the addon it found")
assert(panel.explain:GetText() == S.explain, "said why the two cannot both run")
assert(not panel.oldFolder:IsShown(), "left the old folder note off, there being no old folder")
assert(panel.disableThem:GetText() == S.disableOne:format(S.betterWardrobe),
    "offered to turn Better Wardrobe off by name")
assert(panel.disableSelf:GetText() == S.disableSelf, "offered to turn Lucky's Wardrobe off instead")

assert(click(panel.disableThem) == "BetterWardrobe", "turned Better Wardrobe off")
assert(reloads == 1, "reloaded so the choice takes hold")

assert(click(panel.disableSelf) == "Luckys_Wardrobe", "turned Lucky's Wardrobe off instead")
assert(reloads == 1, "reloaded on that choice too")

-- Lucky's Better Wardrobe is the addon this one replaced, so its dialog carries
-- the note about the folder the update left behind.
only("LuckysBetterWardrobe")
assert(AddonConflicts:Warn(), "warned about the addon this one replaced")
assert(panels == 1, "reused the dialog it had already built")
assert(panel.headline:GetText() == S.oneEnabled:format(S.luckysBetterWardrobe), "named the old addon")
assert(panel.oldFolder:IsShown() and panel.oldFolder:GetText() == S.oldFolder,
    "asked for the folder the update left behind to be deleted")
assert(click(panel.disableThem) == "LuckysBetterWardrobe", "turned the old addon off")

-- Both at once is one dialog offering one button that clears the pair.
only("BetterWardrobe")
enable("LuckysBetterWardrobe")
assert(AddonConflicts:Warn(), "warned with both addons running")
assert(panel.headline:GetText() == S.bothEnabled:format(S.betterWardrobe, S.luckysBetterWardrobe),
    "named both addons")
assert(panel.disableThem:GetText() == S.disableBoth, "offered to turn the pair off together")
assert(panel.oldFolder:IsShown(), "still asked for the old folder to be deleted")
assert(click(panel.disableThem) == "BetterWardrobe,LuckysBetterWardrobe", "turned both off")
assert(reloads == 1, "reloaded once, not once per addon")

-- Nothing is shown while the screen is still building.
panel.shown = false
AddonConflicts:Init()
assert(not panel:IsShown(), "held the warning back until the player is in")
loginCallback()
assert(panel:IsShown(), "warned once the player is in")

print("Lucky's Wardrobe addon conflicts test passed")
