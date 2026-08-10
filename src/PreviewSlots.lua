-- luacheck: globals CreateFrame EventUtil MenuResponse MenuUtil WardrobeCollectionFrame hooksecurefunc

-- Lucky's Wardrobe: which slots the set previews dress. Plenty of characters
-- never show a helm, and a set judged with one on is not the set that would be
-- worn, so a button in the corner of every set pane offers the armour slots as
-- checkboxes and the previews dress only the ones left ticked. One saved choice
-- covers all three set tabs in the Appearances journal: Blizzard's Sets tab by
-- undressing what its model was given, the addon's own two by never putting the
-- piece on. Only the preview changes; pieces, counts and tracking carry on.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.PreviewSlots = {}

local PreviewSlots = LuckysWardrobe.PreviewSlots
local Utils = LuckysWardrobe.Utils

local db

-- Where a model wears each slot the addon's set pages deal in, as the
-- character's own inventory slot numbers, which are what UndressSlot takes and
-- what a saved outfit keys its looks by.
PreviewSlots.INV_SLOTS = {
    HEAD = 1,
    SHOULDER = 3,
    BODY = 4,
    CHEST = 5,
    WAIST = 6,
    LEGS = 7,
    FEET = 8,
    WRIST = 9,
    HANDS = 10,
    BACK = 15,
    TABARD = 19,
}

local SLOT_KEYS_BY_INV_SLOT = {}
for slotKey, invSlot in pairs(PreviewSlots.INV_SLOTS) do
    SLOT_KEYS_BY_INV_SLOT[invSlot] = slotKey
end

-- The panes that carry a preview, told when the choice changes so the set on
-- screen is redressed there and then, and the buttons, so every pane's corner
-- says at once that something is being left off.
local listeners = {}
local buttons = {}

function PreviewSlots:OnChanged(listener)
    listeners[#listeners + 1] = listener
end

function PreviewSlots:IsSlotShown(slotKey)
    return not db.hiddenSetSlots[slotKey]
end

--- The same answer for the pages that dress by inventory slot rather than by
--- slot name. A slot with no checkbox, a weapon in a saved outfit say, is
--- always dressed: the choice is about armour a character can decline to show.
function PreviewSlots:IsInvSlotShown(invSlot)
    local slotKey = SLOT_KEYS_BY_INV_SLOT[invSlot]
    return not (slotKey and db.hiddenSetSlots[slotKey])
end

function PreviewSlots:AnyHidden()
    return next(db.hiddenSetSlots) ~= nil
end

-- The corner buttons say when the previews are being narrowed, the way the
-- filter buttons say a list is: gold while anything is hidden, quiet otherwise.
local function refreshButtons()
    for _, button in ipairs(buttons) do
        if PreviewSlots:AnyHidden() then
            button.Icon:SetVertexColor(1, 0.82, 0)
        else
            button.Icon:SetVertexColor(1, 1, 1)
        end
    end
end

local function notify()
    refreshButtons()
    for _, listener in ipairs(listeners) do listener() end
end

function PreviewSlots:ToggleSlot(slotKey)
    -- Only the slots turned off are stored, so a slot never touched stays a
    -- slot the previews dress.
    db.hiddenSetSlots[slotKey] = not db.hiddenSetSlots[slotKey] or nil
    notify()
end

function PreviewSlots:ShowAllSlots()
    if not self:AnyHidden() then return end
    db.hiddenSetSlots = {}
    notify()
end

--- Takes the hidden slots off a model something else has already dressed,
--- which is how the Sets tab's preview obeys a choice its own code has never
--- heard of.
function PreviewSlots:UndressHidden(model)
    for slotKey in pairs(db.hiddenSetSlots) do
        local invSlot = PreviewSlots.INV_SLOTS[slotKey]
        if invSlot then model:UndressSlot(invSlot) end
    end
end

local function openMenu(owner)
    local S = LuckysWardrobe.Strings.previewSlots
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle(S.menuTitle)
        for _, slotKey in ipairs(Utils.ARMOUR_SLOTS) do
            rootDescription:CreateCheckbox(
                _G[Utils.SLOT_TOOLTIP_GLOBALS[slotKey]],
                function() return PreviewSlots:IsSlotShown(slotKey) end,
                function() PreviewSlots:ToggleSlot(slotKey) end
            )
        end
        rootDescription:CreateDivider()
        rootDescription:CreateButton(S.showAll, function()
            PreviewSlots:ShowAllSlots()
            return MenuResponse.Refresh
        end)
    end)
end

--- The corner control itself, one per set pane, so the choice is offered where
--- its effect is looked at. The caller anchors it; everything else about it is
--- the same on every pane.
function PreviewSlots:CreateButton(parent)
    local S = LuckysWardrobe.Strings.previewSlots
    local button = CreateFrame("Button", nil, parent, "SquareIconButtonTemplate")
    button:SetSize(24, 24)
    button.Icon:SetAtlas("transmog-icon-hidden")
    button.tooltipTitle = S.menuTitle
    button.tooltipText = S.buttonTooltip
    button.onClickHandler = openMenu
    buttons[#buttons + 1] = button
    refreshButtons()
    return button
end

function PreviewSlots:Init(database)
    db = database

    -- The addon's own panes wire themselves up as they are built; Blizzard's
    -- Sets tab has to be met where it is. Its DisplaySet dresses the model
    -- afresh on every call, so undressing after each call is the whole hook,
    -- and re-showing a slot is nothing but asking for the set again.
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", function()
        local setsFrame = WardrobeCollectionFrame.SetsCollectionFrame
        local detailsFrame = setsFrame.DetailsFrame

        local button = PreviewSlots:CreateButton(detailsFrame)
        button:SetPoint("TOPRIGHT", detailsFrame, "TOPRIGHT", -6, -6)

        -- The button takes the corner the variant dropdown held, and the
        -- dropdown hangs off it, so the pane reads the same as the addon's own.
        local dropdown = detailsFrame.VariantSetsDropdown
        dropdown:ClearAllPoints()
        dropdown:SetPoint("RIGHT", button, "LEFT", -4, 0)

        hooksecurefunc(setsFrame, "DisplaySet", function(frame)
            PreviewSlots:UndressHidden(frame.Model)
        end)

        PreviewSlots:OnChanged(function()
            if setsFrame:IsVisible() then
                setsFrame:DisplaySet(setsFrame:GetSelectedSetID())
            end
        end)
    end)
end
