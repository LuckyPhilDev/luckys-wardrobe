-- luacheck: globals C_Timer C_TransmogOutfitInfo CANCEL CreateFrame LuckysWardrobe NO SAVE StaticPopupDialogs StaticPopup_Show UnitClass YES strtrim

LuckysWardrobe = {}

-- The icon palette Utils carries, shared with the padlocks beside the slots.
LuckysWardrobe.Utils = {
    ICON_ON = { 1.0, 0.824, 0.392 },
    ICON_OFF = { 0.35, 0.35, 0.35 },
}

LuckyStrings = { New = function(_, tbl) return tbl end }
dofile("src/Strings.lua")

function CreateFrame()
    return {
        RegisterEvent = function() end,
        SetScript = function() end,
    }
end

C_Timer = { After = function(_, callback) callback() end }
SAVE, CANCEL, YES, NO = "Save", "Cancel", "Yes", "No"
StaticPopupDialogs = {}
strtrim = function(value) return value:match("^%s*(.-)%s*$") end

local playerClassID = 8
function UnitClass() return "Mage", "MAGE", playerClassID end

local shownPopup
function StaticPopup_Show(name, textArg, _, data)
    shownPopup = { name = name, textArg = textArg, data = data }
end

local selected = {
    ["3:0:0:0"] = true,
    ["13:0:0:0"] = true,
}

local options = {
    {
        name = "Zone",
        groupData = {
            { optionData = {
                { name = "Rested Areas", option = { situationID = 3, specID = 0, loadoutID = 0, equipmentSetID = 0 } },
                { name = "Cities", option = { situationID = 4, specID = 0, loadoutID = 0, equipmentSetID = 0 } },
            } },
        },
    },
    {
        name = "Combat",
        groupData = {
            { optionData = {
                { name = "In Combat", option = { situationID = 13, specID = 0, loadoutID = 0, equipmentSetID = 0 } },
            } },
        },
    },
    {
        name = "Specialisation",
        groupData = {
            { optionData = {
                { name = "Fire", option = { situationID = 0, specID = 62, loadoutID = 0, equipmentSetID = 0 } },
            } },
        },
    },
}

local function optionKey(option)
    return table.concat({ option.situationID, option.specID, option.loadoutID, option.equipmentSetID }, ":")
end

local calls = {}
local situationsEnabled = false
C_TransmogOutfitInfo = {
    GetUISituationCategoriesAndOptions = function() return options end,
    GetOutfitSituationsEnabled = function() return situationsEnabled end,
    SetOutfitSituationsEnabled = function(value)
        calls[#calls + 1] = "enable"
        situationsEnabled = value
    end,
    GetOutfitSituation = function(option) return selected[optionKey(option)] end,
    UpdatePendingSituation = function(option, value)
        calls[#calls + 1] = "update"
        selected[optionKey(option)] = value
    end,
    CommitPendingSituations = function() calls[#calls + 1] = "commit" end,
}

dofile("src/features/transmogrifier/SituationPresets.lua")

local presets = LuckysWardrobe.SituationPresets
local db = { situationPresets = {} }
presets:Init(db)

local loadEnabled
presets.loadButton = {
    SetEnabled = function(_, enabled) loadEnabled = enabled end,
}
presets:UpdateLoadButton()
assert(not loadEnabled, "disabled the load button with no presets")

presets:Save("Rest Area")
assert(db.situationPresets["Rest Area"].selections["3:0:0:0"], "captured a selected option")
assert(not db.situationPresets["Rest Area"].selections["4:0:0:0"], "skipped an unselected option")
assert(loadEnabled, "enabled the load button after saving")

selected["3:0:0:0"] = false
selected["4:0:0:0"] = true
assert(not presets:Save("Rest Area"), "refused to overwrite without confirmation")
assert(shownPopup.name == "LUCKYS_WARDROBE_REPLACE_SITUATION", "asked before replacing")
assert(shownPopup.textArg == "Rest Area", "named the preset in the replace prompt")
assert(db.situationPresets["Rest Area"].selections["3:0:0:0"], "kept the stored preset until confirmed")

StaticPopupDialogs["LUCKYS_WARDROBE_REPLACE_SITUATION"].OnAccept(nil, "Rest Area")
assert(db.situationPresets["Rest Area"].selections["4:0:0:0"], "replaced the preset on confirmation")
assert(not db.situationPresets["Rest Area"].selections["3:0:0:0"], "dropped stale selections on replace")

selected["3:0:0:0"] = true
selected["4:0:0:0"] = false
local refreshed = false
presets:Apply(db.situationPresets["Rest Area"], {
    Refresh = function() refreshed = true end,
})
assert(selected["4:0:0:0"], "applied a preset selection")
assert(not selected["3:0:0:0"], "cleared a selection outside the preset")
assert(situationsEnabled, "enabled situations before applying")
assert(refreshed, "refreshed the situations frame")
assert(table.concat(calls, ",") == "enable,update,update,commit", "cleared before setting, then committed once")

StaticPopupDialogs["LUCKYS_WARDROBE_DELETE_SITUATION"].OnAccept(nil, "Rest Area")
assert(not db.situationPresets["Rest Area"], "deleted the preset")
assert(not loadEnabled, "disabled the load button after the last delete")

-- A preset that selects a specialisation belongs to the class that saved it.
selected["0:62:0:0"] = true
assert(presets:Save("Raiding"), "saved a class scoped preset")
local magePreset = db.situationPresets["class8:Raiding"]
assert(magePreset.name == "Raiding", "stored the display name")
assert(magePreset.classID == 8, "stored the owning class")
assert(magePreset.selections["0:62:0:0"], "captured the specialisation option")
assert(loadEnabled, "listed the preset for its own class")

-- Another class neither sees it nor overwrites it by reusing the name.
playerClassID = 1
presets:UpdateLoadButton()
assert(not loadEnabled, "hid another class's preset")
shownPopup = nil
assert(presets:Save("Raiding"), "let another class reuse the name")
assert(not shownPopup, "did not treat the reused name as a duplicate")
assert(db.situationPresets["class1:Raiding"].classID == 1, "scoped the new preset to its class")
assert(db.situationPresets["class8:Raiding"] == magePreset, "left the original preset untouched")

-- Presets without a specialisation stay shared with every character.
selected["0:62:0:0"] = false
assert(presets:Save("Anywhere"), "saved a shared preset")
assert(not db.situationPresets["Anywhere"].classID, "left the shared preset unscoped")
playerClassID = 5
presets:UpdateLoadButton()
assert(loadEnabled, "listed the shared preset on any class")

StaticPopupDialogs["LUCKYS_WARDROBE_DELETE_SITUATION"].OnAccept(nil, "Anywhere")
presets:UpdateLoadButton()
assert(not loadEnabled, "hid class scoped presets from other classes after the shared delete")

-- Renaming moves a preset under its new name, keeping what it selects and who sees it.
selected["0:62:0:0"] = true
assert(presets:Save("Raid Night"), "saved a preset to rename")
local renamed = db.situationPresets["class5:Raid Night"]
assert(presets:Rename("class5:Raid Night", "  Mythic Night  "), "renamed the preset")
assert(not db.situationPresets["class5:Raid Night"], "dropped the old name")
assert(db.situationPresets["class5:Mythic Night"] == renamed, "kept the preset itself")
assert(renamed.name == "Mythic Night", "trimmed the new display name")
assert(renamed.classID == 5, "kept the class scope")
assert(renamed.selections["0:62:0:0"], "kept what the preset selects")
assert(not presets:Rename("class5:Mythic Night", "   "), "ignored a blank rename")
assert(not presets:Rename("no such preset", "Anything"), "ignored a rename of a missing preset")

-- Renaming onto a name already taken asks before replacing it.
selected["0:62:0:0"] = false
assert(presets:Save("Anywhere"), "saved a shared preset to collide with")
selected["0:62:0:0"] = true
assert(presets:Save("Raid Night"), "saved a second class scoped preset")
shownPopup = nil
assert(presets:Rename("class5:Raid Night", "Anywhere"), "left a shared name free for a class scoped preset")
assert(not shownPopup, "did not treat a differently scoped name as a duplicate")
assert(presets:Save("Raid Night"), "saved the preset again to rename onto a taken name")
assert(presets:Rename("class5:Raid Night", "Mythic Night") == false, "refused to replace without confirmation")
assert(shownPopup.name == "LUCKYS_WARDROBE_REPLACE_RENAMED_SITUATION", "asked before replacing on rename")
assert(shownPopup.textArg == "Mythic Night", "named the target preset in the replace prompt")
assert(db.situationPresets["class5:Raid Night"], "kept the preset until confirmed")

StaticPopupDialogs["LUCKYS_WARDROBE_REPLACE_RENAMED_SITUATION"].OnAccept(nil, shownPopup.data)
assert(not db.situationPresets["class5:Raid Night"], "moved the preset on confirmation")
assert(db.situationPresets["class5:Mythic Night"].name == "Mythic Night", "replaced the preset it was renamed onto")

StaticPopupDialogs["LUCKYS_WARDROBE_DELETE_SITUATION"].OnAccept(nil, "class5:Mythic Night")
StaticPopupDialogs["LUCKYS_WARDROBE_DELETE_SITUATION"].OnAccept(nil, "class5:Anywhere")
StaticPopupDialogs["LUCKYS_WARDROBE_DELETE_SITUATION"].OnAccept(nil, "Anywhere")
selected["0:62:0:0"] = false

-- An outfit is named after a preset by comparing the values the two would show, so
-- the outfit list can match what it has cached without storing option keys.
assert(presets:Save("Everywhere"), "saved a preset to match against")
local outfitValues = { Zone = "Cities", Combat = "In Combat", Specialisation = "" }
assert(presets:NameFor(outfitValues) == "Everywhere", "named an outfit matching a saved situation")
assert(not presets:NameFor({ Zone = "Cities", Combat = "", Specialisation = "" }), "left a partly matching outfit unnamed")
assert(not presets:NameFor(nil), "left an outfit with nothing cached unnamed")
assert(not presets:NameFor({ Zone = "Cities", Combat = "In Combat", Specialisation = "Fire" }),
    "ignored another class's preset")

-- An outfit may carry values of its own on top of the saved situation, up to the
-- allowance the caller passes.
local withExtra = { Zone = "Rested Areas+Cities", Combat = "In Combat", Specialisation = "" }
assert(presets:NameFor(withExtra, 1) == "Everywhere + Rested Areas", "listed the extra value after the name")
assert(not presets:NameFor(withExtra, 0), "left a near match unnamed without an allowance")
local withTwoExtras = { Zone = "Rested Areas+Cities", Combat = "In Combat", Specialisation = "Fire" }
assert(not presets:NameFor(withTwoExtras, 1), "held a near match to the allowance")
assert(presets:NameFor(withTwoExtras, 2) == "Everywhere + Rested Areas, Fire", "listed both extra values")
assert(not presets:NameFor({ Zone = "Rested Areas", Combat = "In Combat" }, 2),
    "left an outfit missing one of the saved values unnamed")

-- The closest saved situation wins, whatever order the names sort in.
selected["13:0:0:0"] = false
assert(presets:Save("City"), "saved a narrower preset")
selected["13:0:0:0"] = true
assert(presets:NameFor(outfitValues, 2) == "Everywhere", "named the outfit after the exact match")
assert(presets:NameFor(withExtra, 2) == "Everywhere + Rested Areas", "named the outfit after the fewest extras")
assert(presets:NameFor({ Zone = "Rested Areas+Cities", Combat = "" }, 2) == "City + Rested Areas",
    "fell back to the narrower preset the outfit still covers")
StaticPopupDialogs["LUCKYS_WARDROBE_DELETE_SITUATION"].OnAccept(nil, "City")

StaticPopupDialogs["LUCKYS_WARDROBE_DELETE_SITUATION"].OnAccept(nil, "Everywhere")
assert(not presets:NameFor(outfitValues), "forgot the name once the preset was deleted")

selected["4:0:0:0"], selected["13:0:0:0"] = false, false
assert(presets:Save("Nothing"), "saved a preset selecting nothing")
assert(not presets:NameFor({ Zone = "", Combat = "", Specialisation = "" }),
    "left an outfit with no situations unnamed")

print("Lucky's Wardrobe situation presets test passed")
