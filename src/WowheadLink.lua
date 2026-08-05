-- luacheck: globals C_TransmogCollection CLOSE EventUtil GetLocale IsControlKeyDown StaticPopupDialogs StaticPopup_Show WardrobeCollectionFrame WardrobeSetsDetailsItemMixin

-- Lucky's Wardrobe: Ctrl-clicking an item in Collections hands back its Wowhead
-- address. The game has no clipboard API, so the address arrives in a popup with
-- its text already selected, ready for Ctrl+C.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.WowheadLink = {}

local WowheadLink = LuckysWardrobe.WowheadLink
local S = LuckysWardrobe.Strings.wowheadLink
local POPUP = "LUCKYS_WARDROBE_WOWHEAD_LINK"
local db

-- Wowhead runs a site per language, and the English page is no use to someone
-- playing in German.
local SUBDOMAIN_BY_LOCALE = {
    deDE = "de",
    esES = "es",
    esMX = "es",
    frFR = "fr",
    itIT = "it",
    koKR = "ko",
    ptBR = "pt",
    ruRU = "ru",
    zhCN = "cn",
}

-- The edit box is a copy target rather than an input, so it is held at the
-- address that was put in it.
local shownURL

StaticPopupDialogs[POPUP] = {
    preferredIndex = 3,
    text = S.dialog,
    button1 = CLOSE,
    hasEditBox = 1,
    editBoxWidth = 260,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    OnShow = function(dialog)
        local editBox = dialog:GetEditBox()
        editBox:SetText(shownURL or "")
        editBox:HighlightText()
        editBox:SetFocus()
    end,
    EditBoxOnTextChanged = function(editBox)
        local url = shownURL or ""
        if editBox:GetText() ~= url then
            editBox:SetText(url)
            editBox:HighlightText()
        end
    end,
    EditBoxOnEnterPressed = function(editBox)
        editBox:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(editBox)
        editBox:GetParent():Hide()
    end,
}

-- Stock ctrl-click opens the dressing room, so a click this answers has to be
-- taken off the handler underneath rather than added alongside it. Every place
-- that claims a click asks here, which is also where turning the setting off
-- hands ctrl-click back to the dressing room.
function WowheadLink:HandlesClick(button)
    return button == "LeftButton" and IsControlKeyDown() and db.wowheadLinkOnCtrlClick
end

function WowheadLink:ShowForItem(itemID)
    if not itemID then
        return false
    end

    local subdomain = SUBDOMAIN_BY_LOCALE[GetLocale()] or "www"
    shownURL = ("https://%s.wowhead.com/item=%d"):format(subdomain, itemID)
    StaticPopup_Show(POPUP)
    return true
end

function WowheadLink:ShowForSource(sourceID)
    local sourceInfo = sourceID and C_TransmogCollection.GetSourceInfo(sourceID)
    return self:ShowForItem(sourceInfo and sourceInfo.itemID)
end

-- An appearance several items share links to whichever of them the tooltip is
-- showing, which is the one the player is looking at.
local function showLinkForModel(model)
    local visual = model.visualInfo
    if not visual or visual.isHideVisual then
        return false
    end

    local source = model:GetSourceInfoForTracking()
    return WowheadLink:ShowForSource(source and source.sourceID)
end

local function showLinkForDetailsItem(itemFrame)
    return WowheadLink:ShowForSource(itemFrame.sourceID)
end

-- A click with no address behind it, an illusion or a hidden visual, falls
-- through to the dressing room rather than being swallowed.
local function claimCtrlClick(frame, showLink)
    local stockMouseDown = frame:GetScript("OnMouseDown")
    frame:SetScript("OnMouseDown", function(self, button, ...)
        if WowheadLink:HandlesClick(button) and showLink(self) then
            return
        end
        if stockMouseDown then
            stockMouseDown(self, button, ...)
        end
    end)
end

function WowheadLink:Init(database)
    db = database

    EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", function()
        -- The Sets details pane builds its item frames on demand, so wrapping the
        -- mixin they are stamped from reaches every one of them. The appearance
        -- models are built with the frame around them and already carry their own
        -- copy of their mixin, so each of those is claimed in turn.
        local stockMouseDown = WardrobeSetsDetailsItemMixin.OnMouseDown
        function WardrobeSetsDetailsItemMixin:OnMouseDown(button, ...)
            if WowheadLink:HandlesClick(button) and showLinkForDetailsItem(self) then
                return
            end
            return stockMouseDown(self, button, ...)
        end

        for _, model in ipairs(WardrobeCollectionFrame.ItemsCollectionFrame.Models) do
            claimCtrlClick(model, showLinkForModel)
        end
    end)
end
