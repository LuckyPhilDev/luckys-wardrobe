-- luacheck: globals C_AddOns EventUtil LuckysWardrobe OKAY StaticPopupDialogs StaticPopup_Show

-- What matters here is which state each addon is judged on. Better Wardrobe is
-- judged on whether it is running, because turning it off is the fix. Lucky's
-- Better Wardrobe is judged on whether its folder is there, because deleting it
-- is the fix.

OKAY = "Okay"
StaticPopupDialogs = {}

local loaded = {}
local installed = {}

C_AddOns = {
    IsAddOnLoaded = function(addon) return loaded[addon] end,
    DoesAddOnExist = function(addon) return installed[addon] == true end,
}

local loginCallback
EventUtil = {
    ContinueOnPlayerLogin = function(callback) loginCallback = callback end,
}

local shownPopup
function StaticPopup_Show(which) shownPopup = which end

dofile("src/Strings.lua")
dofile("src/AddonConflicts.lua")

local S = LuckysWardrobe.Strings.addonConflicts
local POPUP = "LUCKYS_WARDROBE_ADDON_CONFLICT"

local function warn()
    shownPopup = nil
    StaticPopupDialogs[POPUP].text = nil
    return LuckysWardrobe.AddonConflicts:Warn()
end

local function body()
    return StaticPopupDialogs[POPUP].text or ""
end

local function mentions(text, advice)
    return text:find(advice, 1, true) ~= nil
end

assert(not warn(), "said nothing with no other wardrobe addon around")
assert(shownPopup == nil, "showed no popup with nothing to warn about")

-- Better Wardrobe installed but turned off is already settled, so it is left
-- alone rather than nagged about.
installed.BetterWardrobe = true
assert(not warn(), "said nothing about a Better Wardrobe that is turned off")

loaded.BetterWardrobe = true
assert(warn(), "warned about a Better Wardrobe that is running")
assert(shownPopup == POPUP, "showed the conflict popup")
assert(mentions(body(), S.intro), "explained why the two clash")
assert(mentions(body(), S.betterWardrobe), "asked for Better Wardrobe to be turned off")
assert(not mentions(body(), S.luckysBetterWardrobe), "said nothing about an addon that is not there")

loaded.BetterWardrobe = nil
installed.BetterWardrobe = nil

-- Lucky's Better Wardrobe is asked about on the folder alone, since the folder
-- is what the player is being asked to remove.
installed.LuckysBetterWardrobe = true
assert(warn(), "warned about a Lucky's Better Wardrobe folder that is only sitting there")
assert(mentions(body(), S.luckysBetterWardrobe), "asked for the old folder to be deleted")
assert(not mentions(body(), S.betterWardrobe), "said nothing about an addon that is not there")

loaded.LuckysBetterWardrobe = true
assert(warn(), "still warned once the old addon is actually running")

-- Both at once is one popup, not two, and it carries both fixes.
installed.BetterWardrobe = true
loaded.BetterWardrobe = true
assert(warn(), "warned with both addons present")
assert(mentions(body(), S.betterWardrobe) and mentions(body(), S.luckysBetterWardrobe),
    "gave both fixes in the one popup")

-- Nothing is shown while the screen is still building.
shownPopup = nil
LuckysWardrobe.AddonConflicts:Init()
assert(shownPopup == nil, "held the warning back until the player is in")
loginCallback()
assert(shownPopup == POPUP, "warned once the player is in")

print("Lucky's Wardrobe addon conflicts test passed")
