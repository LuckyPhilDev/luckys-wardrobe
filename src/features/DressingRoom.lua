-- luacheck: globals DressUpFrame hooksecurefunc GameTooltip GameTooltip_SetTitle GameTooltip_AddNormalLine

LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.DressingRoom = {}

local S = LuckysWardrobe.Strings.dressingRoom
local db

-- Blizzard rebuilds the dressing room model here, always in your own gear, on
-- opening, previewing a whole set and Reset. Single items are tried on after it
-- returns, so they land on the undressed model.
local function undressRebuiltModel(modelScene, _, itemModifiedAppearanceIDs)
    if not db.dressingRoomHideGear or modelScene ~= DressUpFrame.ModelScene then return end
    local actor = modelScene:GetPlayerActor()
    if not actor then return end

    actor:Undress()
    for _, itemModifiedAppearanceID in ipairs(itemModifiedAppearanceIDs or {}) do
        actor:TryOn(itemModifiedAppearanceID)
    end
end

-- ponytail: a preview identical to the piece you wear reads as your gear and is dropped when hiding it.
local function dressAndListPreviews(actor)
    local shown = actor:GetItemTransmogInfoList()
    actor:Dress()
    local worn = actor:GetItemTransmogInfoList()
    local previews = {}
    for slot, info in pairs(shown) do
        if info.appearanceID ~= Constants.Transmog.NoTransmogID and not info:IsEqual(worn[slot]) then
            previews[slot] = info
        end
    end
    return previews
end

local function applyToOpenModel(hideGear)
    local actor = DressUpFrame.ModelScene:GetPlayerActor()
    if not actor then return end

    local previews = dressAndListPreviews(actor)
    if hideGear then actor:Undress() end
    for slot, info in pairs(previews) do
        actor:SetItemTransmogInfo(info, slot)
    end
end

local function createCheckbox()
    local checkbox = CreateFrame("CheckButton", nil, DressUpFrame.ModelScene, "UICheckButtonTemplate")
    checkbox:SetSize(26, 26)
    checkbox:SetPoint("BOTTOMLEFT", 6, 6)
    checkbox.Text:SetText(S.hideGear)
    checkbox:SetScript("OnShow", function(self)
        self:SetChecked(db.dressingRoomHideGear)
    end)
    checkbox:SetScript("OnClick", function(self)
        db.dressingRoomHideGear = self:GetChecked()
        applyToOpenModel(db.dressingRoomHideGear)
    end)
    checkbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, S.hideGear)
        GameTooltip_AddNormalLine(GameTooltip, S.hideGearTooltip)
        GameTooltip:Show()
    end)
    checkbox:SetScript("OnLeave", GameTooltip_Hide)
end

function LuckysWardrobe.DressingRoom:Init(database)
    db = database
    hooksecurefunc("SetupPlayerForModelScene", undressRebuiltModel)
    createCheckbox()
end
