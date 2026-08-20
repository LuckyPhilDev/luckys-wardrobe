-- luacheck: globals CreateFrame EventUtil LuckysWardrobe MenuResponse MenuUtil WardrobeCollectionFrame hooksecurefunc

-- One saved choice drives every set preview, so these drive the shared module
-- against a stubbed Sets tab: the corner button, the menu behind it, the
-- undressing hook, and the redraw a change earns on the spot.

LuckysWardrobe = {}

LuckyStrings = { New = function(_, tbl) return tbl end }
dofile("src/Strings.lua")
dofile("src/Utils.lua")

local Utils = LuckysWardrobe.Utils
local S = LuckysWardrobe.Strings.previewSlots

-- The game localises slot names into globals; the menu reads them from there.
for slotKey, global in pairs(Utils.SLOT_TOOLTIP_GLOBALS) do
    _G[global] = "Name of " .. slotKey
end

MenuResponse = { Refresh = 1 }

local createdFrames = {}
function CreateFrame(frameType, name, parent, template)
    local frame = {
        frameType = frameType, name = name, parent = parent, template = template,
        points = {},
        Icon = {
            SetAtlas = function(self, atlas) self.atlas = atlas end,
            SetVertexColor = function(self, red, green, blue) self.color = { red, green, blue } end,
        },
    }
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
    createdFrames[#createdFrames + 1] = frame
    return frame
end

function hooksecurefunc(owner, method, hook)
    local original = owner[method]
    owner[method] = function(...)
        original(...)
        hook(...)
    end
end

local collectionsCallback
EventUtil = {
    ContinueOnAddOnLoaded = function(addonName, callback)
        assert(addonName == "Blizzard_Collections", "waited for the collections addon")
        collectionsCallback = callback
    end,
}

local openedMenu
MenuUtil = {
    CreateContextMenu = function(owner, generator)
        openedMenu = { owner = owner, generator = generator }
    end,
}

-- The Sets tab, as much of it as the module touches. Its DisplaySet dresses
-- the model afresh on every call, which is the fact the whole hook leans on.
local FULL_SET = { [1] = "helm", [5] = "chest", [15] = "cloak" }

local model = { worn = {} }
function model:UndressSlot(invSlot)
    self.worn[invSlot] = nil
end

local displayCalls = {}
local dropdown = { points = {} }
function dropdown:ClearAllPoints() self.points = {} end
function dropdown:SetPoint(...) self.points[#self.points + 1] = { ... } end

local setsFrame = {
    Model = model,
    DetailsFrame = { VariantSetsDropdown = dropdown },
    selectedSetID = 11,
    visible = true,
}
function setsFrame:GetSelectedSetID() return self.selectedSetID end
function setsFrame:IsVisible() return self.visible end
function setsFrame:DisplaySet(setID)
    displayCalls[#displayCalls + 1] = setID
    model.worn = {}
    for invSlot, piece in pairs(FULL_SET) do model.worn[invSlot] = piece end
end

WardrobeCollectionFrame = { SetsCollectionFrame = setsFrame }

dofile("src/features/journal/PreviewSlots.lua")

local PreviewSlots = LuckysWardrobe.PreviewSlots

-- The slot lists cannot drift: a slot the pages deal in must be undressable,
-- and no checkbox may be offered for a slot they do not.

for _, slotKey in ipairs(Utils.ARMOUR_SLOTS) do
    assert(PreviewSlots.INV_SLOTS[slotKey], "every armour slot has somewhere to be undressed from: " .. slotKey)
end
local mapped = 0
for _ in pairs(PreviewSlots.INV_SLOTS) do mapped = mapped + 1 end
assert(mapped == #Utils.ARMOUR_SLOTS, "and no slot is mapped that the set pages do not deal in")

local db = { hiddenSetSlots = {} }
PreviewSlots:Init(db)

assert(PreviewSlots:IsSlotShown("HEAD"), "every slot starts shown")
assert(PreviewSlots:IsInvSlotShown(1), "and answers the same by inventory slot")
assert(PreviewSlots:IsInvSlotShown(16), "a slot with no checkbox, a weapon, is always dressed")
assert(not PreviewSlots:AnyHidden(), "nothing is hidden until somebody hides it")

-- The native Sets tab: a corner button, the variant dropdown hung beside it,
-- and the model undressed after every DisplaySet.

collectionsCallback()

local button = createdFrames[1]
assert(button and button.template == "SquareIconButtonTemplate" and button.parent == setsFrame.DetailsFrame,
    "put the corner button on the Sets tab's details pane")
assert(button.Icon.atlas == "transmog-icon-hidden", "wore the game's own hidden-slot eye")
assert(button.tooltipTitle == S.menuTitle and button.tooltipText == S.buttonTooltip,
    "said what the button is for before it is clicked")
local buttonAnchor = button.points[1]
assert(buttonAnchor[1] == "TOPRIGHT" and buttonAnchor[2] == setsFrame.DetailsFrame,
    "took the top corner of the pane")
assert(#dropdown.points == 1, "gave the dropdown a single anchor of its own")
local dropdownAnchor = dropdown.points[1]
assert(dropdownAnchor[2] == button and dropdownAnchor[3] == "LEFT", "hung the variant dropdown off the button")

setsFrame:DisplaySet(11)
assert(model.worn[1] and model.worn[5] and model.worn[15], "an untouched choice leaves the whole set dressed")

-- The menu: one checkbox per armour slot, in the order the pages list pieces,
-- ticked while the slot is dressed.

button.onClickHandler(button)
assert(openedMenu and openedMenu.owner == button, "the button opens its menu on itself")

local menu = { titles = {}, checkboxes = {}, buttons = {}, dividers = 0 }
openedMenu.generator(nil, {
    CreateTitle = function(_, text) menu.titles[#menu.titles + 1] = text end,
    CreateCheckbox = function(_, label, isChecked, toggle)
        menu.checkboxes[#menu.checkboxes + 1] = { label = label, isChecked = isChecked, toggle = toggle }
    end,
    CreateDivider = function() menu.dividers = menu.dividers + 1 end,
    CreateButton = function(_, label, onClick)
        menu.buttons[#menu.buttons + 1] = { label = label, onClick = onClick }
    end,
})

assert(menu.titles[1] == S.menuTitle, "the menu says what it covers")
assert(#menu.checkboxes == #Utils.ARMOUR_SLOTS, "one checkbox per armour slot")
for index, slotKey in ipairs(Utils.ARMOUR_SLOTS) do
    local checkbox = menu.checkboxes[index]
    assert(checkbox.label == _G[Utils.SLOT_TOOLTIP_GLOBALS[slotKey]],
        "labelled with the game's own name for the slot: " .. slotKey)
    assert(checkbox.isChecked(), "every slot starts ticked: " .. slotKey)
end
assert(#menu.buttons == 1 and menu.buttons[1].label == S.showAll, "offered the way back below a divider")
assert(menu.dividers == 1, "kept the way back apart from the slots")

-- Unticking a slot hides it there and then: the set on screen is asked for
-- again, and the hook takes the slot off what Blizzard redressed.

menu.checkboxes[1].toggle()
assert(db.hiddenSetSlots.HEAD == true, "only the slots turned off are stored")
assert(not PreviewSlots:IsSlotShown("HEAD") and not PreviewSlots:IsInvSlotShown(1),
    "a hidden slot answers hidden both ways")
assert(PreviewSlots:AnyHidden(), "something is hidden now")
assert(displayCalls[#displayCalls] == 11, "the visible Sets tab redrew its selected set")
assert(model.worn[1] == nil, "and the helm came off the model")
assert(model.worn[5] and model.worn[15], "while the rest of the set stayed on")
assert(not menu.checkboxes[1].isChecked(), "the checkbox reads unticked while the slot is hidden")
assert(button.Icon.color[1] == 1 and button.Icon.color[2] == 0.82 and button.Icon.color[3] == 0,
    "the corner button turns gold while anything is hidden")

-- A pane that is not on screen is left alone; the choice still lands, so the
-- pane wears it when it next draws.

setsFrame.visible = false
local displaysBefore = #displayCalls
menu.checkboxes[2].toggle()
assert(#displayCalls == displaysBefore, "an off-screen Sets tab is not redrawn")
assert(db.hiddenSetSlots.SHOULDER == true, "but the choice is kept for when it shows")

local stripped = { worn = { [1] = "helm", [3] = "shoulders", [5] = "chest" } }
function stripped:UndressSlot(invSlot) self.worn[invSlot] = nil end
PreviewSlots:UndressHidden(stripped)
assert(stripped.worn[1] == nil and stripped.worn[3] == nil and stripped.worn[5],
    "UndressHidden takes off exactly the hidden slots")

-- Showing a slot again removes it from the store entirely rather than keeping
-- a false, so a slot never touched and a slot shown again read the same.

PreviewSlots:ToggleSlot("SHOULDER")
assert(db.hiddenSetSlots.SHOULDER == nil, "a slot shown again is not stored at all")

-- The way back: one click shows every slot, and asking again changes nothing.

setsFrame.visible = true
assert(menu.buttons[1].onClick() == MenuResponse.Refresh, "the menu refreshes its ticks after the reset")
assert(next(db.hiddenSetSlots) == nil, "every slot is shown again")
assert(not PreviewSlots:AnyHidden(), "and nothing counts as hidden")
assert(model.worn[1], "the redraw dressed the helm again")
assert(button.Icon.color[1] == 1 and button.Icon.color[2] == 1 and button.Icon.color[3] == 1,
    "the corner button goes quiet once nothing is hidden")

local displaysAfterReset = #displayCalls
PreviewSlots:ShowAllSlots()
assert(#displayCalls == displaysAfterReset, "showing everything twice is not a change")

-- A key this build has no slot for, left in the store by another version, is
-- passed over rather than tripped on.

db.hiddenSetSlots = { ELBOW = true }
PreviewSlots:UndressHidden(stripped)
assert(stripped.worn[5], "an unknown stored slot undresses nothing")
assert(PreviewSlots:IsInvSlotShown(1), "and hides nothing the pages dress")

print("Lucky's Wardrobe preview slots tests passed")
