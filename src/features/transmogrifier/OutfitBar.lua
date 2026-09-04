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

-- The header's title inset, its close button, and a gap between the two.
local HEADER_CHROME = 46

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
        -- Not GameTooltip:SetOutfit, whose text describes the transmog window's own
        -- right-click actions. Nothing here answers a right-click.
        if self.outfitID then
            GameTooltip:SetText(self.outfitName, 1, 1, 1)
            GameTooltip:AddLine(strings.wearHint, 0.54, 0.49, 0.42, true)
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
    tile.outfitName = nil
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
    tile.outfitName = outfit.name
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
    -- A handful of outfits makes a grid narrower than the title, and the title's
    -- width moves with the locale, so it is measured rather than assumed to fit.
    local gridWidth = PADDING * 2 + columns * TILE + (columns - 1) * GAP
    panel:SetSize(
        math.max(gridWidth, panel.titleText:GetStringWidth() + HEADER_CHROME),
        HEADER + PADDING * 2 + rows * TILE + (rows - 1) * GAP + (panel.empty:IsShown() and 20 or 0))
end

local function buildPanel()
    panel = LuckyUI.CreatePanel("LuckysWardrobeOutfitBar", UIParent, 100, 100)
    -- MEDIUM, matching the Loot Wishlist browser, rather than the DIALOG the style
    -- guide gives a popup. The cursor ring draws between MEDIUM and HIGH, so anything
    -- above MEDIUM cuts through it, and this is a window you leave open, not a modal.
    panel:SetFrameStrata("MEDIUM")
    panel:SetFrameLevel(20)
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
