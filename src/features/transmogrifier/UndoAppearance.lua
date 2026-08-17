-- luacheck: globals C_TransmogOutfitInfo Enum EventUtil IsModifiedClick PlaySound SOUNDKIT TransmogItemModelMixin

-- Lucky's Wardrobe: Clicking the appearance a slot is already queued to wear
-- takes it back off. Judging a piece means seeing it on and off one after the
-- other, and the only way to take it off was to find whatever the slot was
-- wearing again, somewhere in a category of hundreds.
--
-- Off means one of two things and a setting says which: back to what the slot
-- is really wearing, or nothing in the slot at all. Either way the page stays
-- where it is, so the click that puts a piece on and the click that takes it
-- off are the same click, twice.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.UndoAppearance = {}

local UndoAppearance = LuckysWardrobe.UndoAppearance
local db

-- Armour slots carry no weapon or sheathe variants, and a weapon slot names its
-- own, so the option comes off the slot the transmogrifier has selected.
local function slotOption(slotData)
    local weaponOption = slotData.currentWeaponOptionInfo
    return weaponOption and weaponOption.weaponOption or Enum.TransmogOutfitSlotOption.None
end

-- Whether clicking this appearance takes the slot back rather than queueing the
-- same change again. Only a queued change can be taken back: an appearance the
-- slot is already wearing has nothing to undo, and one it is not queued for is
-- an ordinary selection.
--
-- The two display types below are the ones where nothing in the list is picked
-- out at all, and they are asked about rather than trusted to differ, since a
-- slot showing nothing still answers with the source it last held.
function UndoAppearance.Undoes(slotInfo, sourceID)
    if not slotInfo or not slotInfo.hasPending then return false end
    if slotInfo.transmogID ~= sourceID then return false end

    local displayType = slotInfo.displayType
    return displayType ~= Enum.TransmogOutfitDisplayType.Unassigned
        and displayType ~= Enum.TransmogOutfitDisplayType.Equipped
end

-- Live glue from here down.

-- The source behind a clicked model, read the way the card's own border reads
-- it: an appearance is several sources and any of them stands for the visual,
-- while an illusion is the one source it carries.
local function clickedSource(model, collection, location)
    local appearanceInfo = model:GetAppearanceInfo()
    if not appearanceInfo then return nil end
    if not location:IsAppearance() then return appearanceInfo.sourceID end

    return collection:GetAnAppearanceSourceFromVisual(appearanceInfo.visualID, nil)
end

-- Modified clicks belong to whoever already claimed them: shift links the item
-- to chat, and the dressing room takes ctrl wherever the card offers it.
local function claimsClick(model, button)
    if button ~= "LeftButton" or not db.undoOnSecondClick then return false end
    if IsModifiedClick("CHATLINK") then return false end

    return not (model:CanCheckDressUpClick() and IsModifiedClick("DRESSUP"))
end

local function undoes(model)
    local collection = model:GetCollectionFrame()
    local slotData = collection and collection:GetSelectedSlotCallback()
    local location = slotData and slotData.transmogLocation
    if not location then return nil end

    local option = slotOption(slotData)
    local slotInfo =
        C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(location:GetSlot(), location:GetType(), option)
    if not UndoAppearance.Undoes(slotInfo, clickedSource(model, collection, location)) then
        return nil
    end

    return collection, location, option
end

-- The card that takes the slot off, out of the list the grid is showing. Every
-- category carries one and no filter of ours takes it away, but Blizzard's own
-- search does, and a category searched down to a word has nothing to hide the
-- slot with.
local function hideSource(collection, location)
    for _, entry in ipairs(collection.itemCollectionEntries or {}) do
        if entry.isHideVisual then
            if not location:IsAppearance() then return entry.sourceID end
            return collection:GetAnAppearanceSourceFromVisual(entry.visualID, nil)
        end
    end
end

-- Taking the slot off asks for the hide card the way any other pick does, so a
-- slot already showing nothing has nothing left to take off. Those clicks put
-- the slot back instead, which is the only thing left for them to mean.
local function takeOff(model, collection, location, option)
    if not db.undoHidesSlot or model:GetAppearanceInfo().isHideVisual then return false end

    local sourceID = hideSource(collection, location)
    if not sourceID then return false end

    PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
    C_TransmogOutfitInfo.SetPendingTransmog(location:GetSlot(), location:GetType(), option,
        sourceID, Enum.TransmogOutfitDisplayType.Hidden)
    return true
end

-- Both answers fire the slot refresh every card and the preview figure listen
-- for, so there is nothing to redraw by hand, and nothing that would page the
-- list away from where the player is reading.
local function undo(model, collection, location, option)
    if takeOff(model, collection, location, option) then return end

    PlaySound(SOUNDKIT.UI_TRANSMOG_REVERTING_GEAR_SLOT)
    C_TransmogOutfitInfo.RevertPendingTransmog(location:GetSlot(), location:GetType(), option)
end

function UndoAppearance:Init(database)
    db = database

    EventUtil.ContinueOnAddOnLoaded("Blizzard_Transmog", function()
        -- The grid stamps its cards from this mixin as pages are turned, so
        -- wrapping it reaches every one of them.
        local stockMouseDown = TransmogItemModelMixin.OnMouseDown
        function TransmogItemModelMixin:OnMouseDown(button, ...)
            if claimsClick(self, button) then
                local collection, location, option = undoes(self)
                if location then return undo(self, collection, location, option) end
            end

            return stockMouseDown(self, button, ...)
        end
    end)
end
