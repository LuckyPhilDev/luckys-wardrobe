-- luacheck: globals C_AddOns EventUtil OKAY StaticPopupDialogs StaticPopup_Show

-- Lucky's Wardrobe: Warns at login about the other wardrobe addons that change
-- the same windows this one does. Each conflict is looked for in the state its
-- own fix clears, so doing what the warning asks is what makes it stop.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.AddonConflicts = {}

local AddonConflicts = LuckysWardrobe.AddonConflicts
local S = LuckysWardrobe.Strings.addonConflicts
local POPUP = "LUCKYS_WARDROBE_ADDON_CONFLICT"

local function isInstalled(addon)
    return C_AddOns.DoesAddOnExist(addon)
end

local function isRunning(addon)
    return isInstalled(addon) and C_AddOns.IsAddOnLoaded(addon) and true or false
end

local CONFLICTS = {
    -- Better Wardrobe is somebody else's addon and still maintained, so turning
    -- it off is the whole fix and a copy already turned off is nobody's problem.
    { addon = "BetterWardrobe", conflicts = isRunning, advice = S.betterWardrobe },
    -- Lucky's Better Wardrobe shipped under the same CurseForge project as this
    -- addon, so the update that replaced it left its folder sitting there rather
    -- than removing it. Nothing will clear that folder now except the player, so
    -- a copy merely turned off is still worth asking about.
    { addon = "LuckysBetterWardrobe", conflicts = isInstalled, advice = S.luckysBetterWardrobe },
}

StaticPopupDialogs[POPUP] = {
    preferredIndex = 3,
    button1 = OKAY,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

function AddonConflicts:Advice()
    local advice = {}
    for _, conflict in ipairs(CONFLICTS) do
        if conflict.conflicts(conflict.addon) then
            advice[#advice + 1] = conflict.advice
        end
    end
    return advice
end

-- The body depends on which conflicts turned up, so it is written onto the
-- dialog here rather than declared alongside it.
function AddonConflicts:Warn()
    local advice = self:Advice()
    if #advice == 0 then
        return false
    end

    StaticPopupDialogs[POPUP].text = S.intro .. "\n\n" .. table.concat(advice, "\n\n")
    StaticPopup_Show(POPUP)
    return true
end

function AddonConflicts:Init()
    -- A conflicting addon is enabled or it is not by the time the player is in,
    -- and waiting that long keeps the popup off a half-built screen.
    EventUtil.ContinueOnPlayerLogin(function()
        self:Warn()
    end)
end
