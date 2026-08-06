-- luacheck: globals C_TransmogCollection CLOSE EventUtil GetLocale IsAltKeyDown LuckysWardrobe StaticPopupDialogs StaticPopup_Show WardrobeCollectionFrame WardrobeSetsDetailsItemMixin

-- The address that lands in the popup is the whole feature, so these go through
-- the popup rather than at the string building underneath it.

CLOSE = "Close"

local locale = "enUS"
local altDown = true
local sources = {}
local popupsShown = 0

function GetLocale() return locale end
function IsAltKeyDown() return altDown end
function StaticPopup_Show() popupsShown = popupsShown + 1 end

StaticPopupDialogs = {}

C_TransmogCollection = {
    GetSourceInfo = function(sourceID) return sources[sourceID] end,
}

EventUtil = {
    ContinueOnAddOnLoaded = function(_, callback) callback() end,
}

-- The details pane stamps its item frames from this mixin after we have wrapped
-- it, so a frame is built here the way the pane builds one.
local stockDetailsClicks = 0
WardrobeSetsDetailsItemMixin = {
    OnMouseDown = function() stockDetailsClicks = stockDetailsClicks + 1 end,
}

-- The appearance models already exist by the time we are asked to claim them,
-- so each carries its own handler rather than reading one off a mixin.
local stockModelClicks = 0
local function AppearanceModel(visualInfo, trackingSource)
    local model = {
        visualInfo = visualInfo,
        scripts = {},
        GetSourceInfoForTracking = function() return trackingSource end,
    }
    function model:GetScript(script) return self.scripts[script] end
    function model:SetScript(script, handler) self.scripts[script] = handler end
    model.scripts.OnMouseDown = function() stockModelClicks = stockModelClicks + 1 end
    return model
end

local HELM_SOURCE, ITEMLESS_SOURCE = 10, 11
sources[HELM_SOURCE] = { itemID = 5678 }
sources[ITEMLESS_SOURCE] = {}

local helmModel = AppearanceModel({ visualID = 1 }, { sourceID = HELM_SOURCE })
local hiddenModel = AppearanceModel({ visualID = 0, isHideVisual = true }, { sourceID = HELM_SOURCE })
local illusionModel = AppearanceModel({ visualID = 2 }, nil)

WardrobeCollectionFrame = {
    ItemsCollectionFrame = {
        Models = { helmModel, hiddenModel, illusionModel },
    },
}

dofile("src/Strings.lua")
dofile("src/WowheadLink.lua")

local WowheadLink = LuckysWardrobe.WowheadLink
local popup = StaticPopupDialogs["LUCKYS_WARDROBE_WOWHEAD_LINK"]

local db = { wowheadLinkOnAltClick = true }
WowheadLink:Init(db)

local function FakeEditBox()
    local editBox = { text = "" }
    function editBox:SetText(value) self.text = value end
    function editBox:GetText() return self.text end
    function editBox:HighlightText() end
    function editBox:SetFocus() end
    return editBox
end

local function ShownURL()
    local editBox = FakeEditBox()
    popup.OnShow({ GetEditBox = function() return editBox end })
    return editBox:GetText()
end

assert(WowheadLink:HandlesClick("LeftButton"), "claimed alt-left-click")
assert(not WowheadLink:HandlesClick("RightButton"), "left alt-right-click alone")

altDown = false
assert(not WowheadLink:HandlesClick("LeftButton"), "left an unmodified click alone")
altDown = true

db.wowheadLinkOnAltClick = false
assert(not WowheadLink:HandlesClick("LeftButton"), "respected the disabled setting")
db.wowheadLinkOnAltClick = true

assert(WowheadLink:ShowForSource(HELM_SOURCE), "found an address for a source with an item")
assert(ShownURL() == "https://www.wowhead.com/item=5678", "showed the item's address")

-- Someone playing in German wants the German page.
locale = "deDE"
assert(WowheadLink:ShowForSource(HELM_SOURCE))
assert(ShownURL() == "https://de.wowhead.com/item=5678", "showed the address for the player's language")

-- Wowhead has no Taiwanese site, so those fall back to the English one.
locale = "zhTW"
assert(WowheadLink:ShowForSource(HELM_SOURCE))
assert(ShownURL() == "https://www.wowhead.com/item=5678", "fell back to the English site")
locale = "enUS"

-- Nothing to look up means no popup rather than an address to nowhere.
local before = popupsShown
assert(not WowheadLink:ShowForSource(ITEMLESS_SOURCE), "refused a source with no item")
assert(not WowheadLink:ShowForSource(nil), "refused a missing source")
assert(popupsShown == before, "showed no popup without an address")

-- The box is a copy target, so typing in it does not change what gets copied.
assert(WowheadLink:ShowForSource(HELM_SOURCE))
local editBox = FakeEditBox()
popup.OnShow({ GetEditBox = function() return editBox end })
editBox:SetText("nonsense")
popup.EditBoxOnTextChanged(editBox)
assert(editBox:GetText() == "https://www.wowhead.com/item=5678", "held the address against typing")

-- A set piece in Blizzard's details pane.
local detailsItem = setmetatable({ sourceID = HELM_SOURCE }, { __index = WardrobeSetsDetailsItemMixin })
before = popupsShown
detailsItem:OnMouseDown("LeftButton")
assert(popupsShown == before + 1, "answered an alt-click on a set piece")
assert(stockDetailsClicks == 0, "left the stock handler out of an alt-click")

altDown = false
detailsItem:OnMouseDown("LeftButton")
assert(stockDetailsClicks == 1, "left ordinary clicks on a set piece alone")
altDown = true

-- An appearance in Blizzard's Items tab.
before = popupsShown
helmModel.scripts.OnMouseDown(helmModel, "LeftButton")
assert(popupsShown == before + 1, "answered an alt-click on an appearance")
assert(stockModelClicks == 0, "left the stock handler out of an alt-click")

-- Hide Helm and its siblings are not items, and illusions come back sourceless,
-- so those clicks are handed back rather than swallowed.
before = popupsShown
hiddenModel.scripts.OnMouseDown(hiddenModel, "LeftButton")
illusionModel.scripts.OnMouseDown(illusionModel, "LeftButton")
assert(popupsShown == before, "showed no popup for an appearance with no item")
assert(stockModelClicks == 2, "handed those clicks back to the dressing room")

print("Lucky's Wardrobe Wowhead link test passed")
