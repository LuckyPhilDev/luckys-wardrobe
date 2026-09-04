-- luacheck: globals C_TransmogOutfitInfo CreateFrame GameTooltip GameTooltip_Hide LuckyUI UIParent UISpecialFrames tinsert unpack

-- Lucky's Wardrobe: A movable grid of your outfits, worn with one click.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.OutfitBar = {}

local OutfitBar = LuckysWardrobe.OutfitBar
local strings = LuckysWardrobe.Strings.outfitBar
local db

local PER_ROW = 8
local TILE = 36
local GAP = 4
local PADDING = 10
local HEADER = 32

local CLEAR_ICON = 7539422 -- Ui_transmog_showequippedgear

local panel
local tiles = {}

local function tileAnchor(index)
    local row = math.floor((index - 1) / PER_ROW)
    local column = (index - 1) % PER_ROW
    return PADDING + column * (TILE + GAP), -(HEADER + PADDING + row * (TILE + GAP))
end

-- InsecureActionButtonTemplate runs the same secure action as an action bar
-- button but is an ordinary frame, so the grid can be rebuilt and re-pointed at
-- any time. The trade is that a click in combat does nothing, which is the right
-- way round for a wardrobe.
local function createTile(index)
    local tile = CreateFrame("Button", "LuckysWardrobeOutfitTile" .. index, panel, "InsecureActionButtonTemplate")
    tile:SetSize(TILE, TILE)
    -- Both buttons wear the outfit. The type attribute is unqualified, so every
    -- registered button reaches the same action, and there is nothing else for a
    -- right-click to do: locking is protected and only Blizzard's own list can offer it.
    tile:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonDown", "RightButtonUp")
    tile:SetAttribute("useOnKeyDown", false)
    tile:SetPoint("TOPLEFT", tileAnchor(index))

    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetAllPoints()

    tile:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    tile:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

    -- The outfit list marks the one you are wearing with a gold frame and a locked
    -- one with the pet-autocast shimmer. Borrowing both keeps the two states apart
    -- when an outfit is in either or both, in the vocabulary players already read.
    tile.active = tile:CreateTexture(nil, "OVERLAY")
    tile.active:SetAtlas("transmog-outfit-spellframe-active", true)
    tile.active:SetPoint("CENTER")
    tile.active:Hide()

    tile.locked = CreateFrame("Frame", nil, tile, "AutoCastOverlayTemplate")
    tile.locked:SetSize(TILE, TILE)
    tile.locked:SetPoint("CENTER")
    tile.locked:Hide()

    tile:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.outfitID then
            GameTooltip:SetOutfit(self.outfitID)
        else
            GameTooltip:SetText(strings.clear, 1, 1, 1)
            GameTooltip:AddLine(strings.clearHint, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    tile:SetScript("OnLeave", GameTooltip_Hide)

    tiles[index] = tile
    return tile
end

local function setClearTile(tile)
    tile.outfitID = nil
    tile.icon:SetTexture(CLEAR_ICON)
    tile.icon:SetDesaturated(false)
    tile.icon:SetVertexColor(1, 0.75, 0.75)
    tile.active:Hide()
    tile.locked:Hide()
    tile:SetAttribute("type", "outfit")
    tile:SetAttribute("action", "clear")
    tile:SetAttribute("outfit-index", nil)
    tile:Show()
end

local function setOutfitTile(tile, outfit, activeOutfitID)
    tile.outfitID = outfit.outfitID
    tile.icon:SetTexture(outfit.icon)
    tile.icon:SetDesaturated(outfit.isDisabled)
    tile.icon:SetVertexColor(1, 1, 1)
    tile.active:SetShown(outfit.outfitID == activeOutfitID)

    local locked = C_TransmogOutfitInfo.IsLockedOutfit(outfit.outfitID)
    tile.locked:SetShown(locked)
    tile.locked:ShowAutoCastEnabled(locked)
    tile:SetAttribute("type", "outfit")
    tile:SetAttribute("action", "toggle")
    -- The secure action takes the player-facing index, which skips the gaps that
    -- outfit IDs leave behind, so the two are never interchangeable.
    tile:SetAttribute("outfit-index", outfit.playerFacingOutfitIndex)
    tile:Show()
end

local function refresh()
    if not panel then return end

    local outfits = C_TransmogOutfitInfo.GetOutfitsInfo() or {}
    local activeOutfitID = C_TransmogOutfitInfo.GetActiveOutfitID()
    local used = #outfits + 1

    setClearTile(tiles[1] or createTile(1))
    for position, outfit in ipairs(outfits) do
        local index = position + 1
        setOutfitTile(tiles[index] or createTile(index), outfit, activeOutfitID)
    end
    for index = used + 1, #tiles do
        tiles[index]:Hide()
    end

    panel.empty:SetShown(#outfits == 0)

    local columns = math.min(used, PER_ROW)
    local rows = math.ceil(used / PER_ROW)
    panel:SetSize(
        PADDING * 2 + columns * TILE + (columns - 1) * GAP,
        HEADER + PADDING * 2 + rows * TILE + (rows - 1) * GAP + (panel.empty:IsShown() and 20 or 0))
end

local function buildPanel()
    panel = LuckyUI.CreatePanel("LuckysWardrobeOutfitBar", UIParent, 100, 100)
    panel:SetFrameStrata("HIGH")
    panel:Hide()
    LuckyUI.CreateHeader(panel, strings.title)
    LuckyUI.EnableDrag(panel, { db = db, key = "outfitBarPosition" })

    panel.empty = panel:CreateFontString(nil, "OVERLAY")
    panel.empty:SetFont(LuckyUI.BODY_FONT, 12)
    panel.empty:SetTextColor(unpack(LuckyUI.C.textMuted))
    panel.empty:SetPoint("BOTTOMLEFT", PADDING, PADDING)
    panel.empty:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
    panel.empty:SetText(strings.empty)
    panel.empty:Hide()

    panel:RegisterEvent("TRANSMOG_OUTFITS_CHANGED")
    panel:RegisterEvent("TRANSMOG_DISPLAYED_OUTFIT_CHANGED")
    panel:SetScript("OnEvent", refresh)
    panel:SetScript("OnShow", refresh)

    tinsert(UISpecialFrames, panel:GetName())
    return panel
end

function OutfitBar:Toggle()
    local frame = panel or buildPanel()
    frame:SetShown(not frame:IsShown())
end

function OutfitBar:Init(database)
    db = database
end
