-- luacheck: globals C_Timer C_TransmogOutfitInfo CANCEL CreateFrame LuckysWardrobe NO SAVE StaticPopupDialogs StaticPopup_Show UnitClass YES strtrim

LuckysWardrobe = {}

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
        groupData = {
            { optionData = {
                { option = { situationID = 3, specID = 0, loadoutID = 0, equipmentSetID = 0 } },
                { option = { situationID = 4, specID = 0, loadoutID = 0, equipmentSetID = 0 } },
            } },
        },
    },
    {
        groupData = {
            { optionData = {
                { option = { situationID = 13, specID = 0, loadoutID = 0, equipmentSetID = 0 } },
            } },
        },
    },
    {
        groupData = {
            { optionData = {
                { option = { situationID = 0, specID = 62, loadoutID = 0, equipmentSetID = 0 } },
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

dofile("src/SituationPresets.lua")

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

print("Lucky's Wardrobe situation presets test passed")
