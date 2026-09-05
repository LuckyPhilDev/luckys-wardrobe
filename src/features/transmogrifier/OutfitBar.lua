-- luacheck: globals C_AddOns C_Transmog C_TransmogOutfitInfo CreateFrame GameTooltip GameTooltip_Hide InCombatLockdown LuckyUI TransmogFrame TransmogOutfitEntryMixin UIParent UISpecialFrames hooksecurefunc tinsert unpack

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
local hookedOutfitRows = false
local borrowedOutfitRows = false

local function tileAnchor(index)
    local row = math.floor((index - 1) / PER_ROW)
    local column = (index - 1) % PER_ROW
    return PADDING + column * (TILE + GAP), -(HEADER + PADDING + row * (TILE + GAP))
end

local function outfitCollection()
    if not TransmogFrame and not C_AddOns.IsAddOnLoaded("Blizzard_Transmog") then
        C_AddOns.LoadAddOn("Blizzard_Transmog")
    end
    return TransmogFrame and TransmogFrame.OutfitCollection
end

-- Locking is protected, so nothing but Blizzard's own row in the transmog window
-- can do it, and a tile reaches the lock only by clicking that row. The row has to
-- exist to be clicked, not to be visible. The list renders about fourteen at a time,
-- so an outfit far enough down one that is scrolled away has none.
local function lockTargetForOutfit(outfitID)
    local collection = outfitCollection()
    local list = collection and collection.OutfitList
    local scrollBox = list and list.ScrollBox
    if not scrollBox then return nil end

    local target
    scrollBox:ForEachFrame(function(row)
        local elementData = row:GetElementData()
        if elementData and elementData.outfitID == outfitID then
            target = row.OutfitIcon
        end
    end)
    return target
end

-- The button for the gear you are wearing belongs to the window rather than the
-- list, so it is there from the moment the window loads and never scrolls away.
local function lockTargetForClear()
    local collection = outfitCollection()
    local spellFrame = collection and collection.ShowEquippedGearSpellFrame
    return spellFrame and spellFrame.Button
end

-- Right-click clicks Blizzard's button where there is one to click. Where there is
-- not, the unqualified type attribute still answers it and the outfit is worn, so a
-- tile out of the list's reach is never a tile that ignores you.
local function setLockTarget(tile, target)
    tile.lockTarget = target
    tile:SetAttribute("type2", target and "click" or nil)
    tile:SetAttribute("clickbutton2", target)
end

-- A row is reused for whichever outfit scrolls into it, so a tile pointed at one
-- has to let go the moment that row is dealt to another outfit. Left alone, its
-- right-click would lock a stranger.
local function aimTilesAtRow(row, outfitID)
    for _, tile in ipairs(tiles) do
        if tile.outfitID and tile.outfitID == outfitID then
            setLockTarget(tile, row)
        elseif tile.lockTarget == row then
            setLockTarget(tile, nil)
        end
    end
end

local function hookOutfitRows()
    if hookedOutfitRows then return end
    if not outfitCollection() or not TransmogOutfitEntryMixin then return end

    hookedOutfitRows = true
    hooksecurefunc(TransmogOutfitEntryMixin, "Init", function(entry, elementData)
        if elementData and not InCombatLockdown() then
            aimTilesAtRow(entry.OutfitIcon, elementData.outfitID)
        end
    end)
end

-- A row exists only once the window's OnShow has built it, and OnShow has to be the
-- one that does: calling the window's own refresh from here would build the rows on
-- this addon's call chain, and a row built that way cannot run the protected call
-- behind a lock. Showing and hiding it in the same breath leaves that to the game and
-- is over before anything draws, at the cost of the window's open and close sounds.
-- Never while it stands open, and never at a transmogrifier, where closing it would
-- end the visit.
local function borrowOutfitRows()
    if borrowedOutfitRows or not outfitCollection() then return end
    if TransmogFrame:IsShown() or C_Transmog.IsAtTransmogNPC() then return end

    borrowedOutfitRows = true
    TransmogFrame:Show()
    TransmogFrame:Hide()
end

-- A real secure button, not the insecure one: clicking Blizzard's row runs a
-- protected action, and only a click arriving through a secure button carries the
-- trust to do it. The cost is a tile that cannot be built or re-pointed in combat,
-- which is what holds a refresh until the fight is over.
local function createTile(index)
    local tile = CreateFrame("Button", "LuckysWardrobeOutfitTile" .. index, panel, "SecureActionButtonTemplate")
    tile:SetSize(TILE, TILE)
    -- Both halves of every click, and useOnKeyDown off. Without the attribute the
    -- button falls back to the ActionButtonUseKeyDown CVar, which is on, and then it
    -- acts on the press it was never registered for and every click does nothing.
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
        -- Not GameTooltip:SetOutfit, whose text names actions the bar has no answer
        -- for, dragging an outfit onto an action bar among them.
        if self.outfitID then
            GameTooltip:SetText(self.outfitName, 1, 1, 1)
            GameTooltip:AddLine(strings.wearHint, 0.54, 0.49, 0.42, true)
        else
            GameTooltip:SetText(strings.clear, 1, 1, 1)
            GameTooltip:AddLine(strings.clearHint, nil, nil, nil, true)
        end
        -- Promised only where a right-click can keep the promise.
        if self.lockTarget then
            GameTooltip:AddLine(strings.lockHint, 0.54, 0.49, 0.42, true)
        end
        GameTooltip:Show()
    end)
    tile:SetScript("OnLeave", GameTooltip_Hide)

    tiles[index] = tile
    return tile
end

local function setLocked(tile, locked)
    tile.locked:SetShown(locked)
    tile.locked:ShowAutoCastEnabled(locked)
end

local function setClearTile(tile)
    tile.outfitID = nil
    tile.outfitName = nil
    tile.icon:SetTexture(CLEAR_ICON)
    tile.icon:SetDesaturated(false)
    tile.icon:SetVertexColor(1, 0.75, 0.75)
    tile.active:SetShown(C_TransmogOutfitInfo.IsEquippedGearOutfitDisplayed())
    setLocked(tile, C_TransmogOutfitInfo.IsEquippedGearOutfitLocked())
    tile:SetAttribute("type", "outfit")
    tile:SetAttribute("action", "clear")
    tile:SetAttribute("outfit-index", nil)
    setLockTarget(tile, lockTargetForClear())
    tile:Show()
end

local function setOutfitTile(tile, outfit, activeOutfitID)
    tile.outfitID = outfit.outfitID
    tile.outfitName = outfit.name
    tile.icon:SetTexture(outfit.icon)
    tile.icon:SetDesaturated(outfit.isDisabled)
    tile.icon:SetVertexColor(1, 1, 1)
    tile.active:SetShown(outfit.outfitID == activeOutfitID)
    setLocked(tile, C_TransmogOutfitInfo.IsLockedOutfit(outfit.outfitID))
    tile:SetAttribute("type", "outfit")
    tile:SetAttribute("action", "toggle")
    -- The secure action takes the player-facing index, which skips the gaps that
    -- outfit IDs leave behind, so the two are never interchangeable.
    tile:SetAttribute("outfit-index", outfit.playerFacingOutfitIndex)
    setLockTarget(tile, lockTargetForOutfit(outfit.outfitID))
    tile:Show()
end

local function retireTile(tile)
    tile.outfitID = nil
    setLockTarget(tile, nil)
    tile:Hide()
end

local function refresh()
    -- Every tile is a secure frame, so none of what follows is allowed mid-fight.
    -- PLAYER_REGEN_ENABLED brings the bar up to date the moment the fight ends.
    if not panel or InCombatLockdown() then return end

    hookOutfitRows()
    borrowOutfitRows()

    local outfits = C_TransmogOutfitInfo.GetOutfitsInfo() or {}
    local activeOutfitID = C_TransmogOutfitInfo.GetActiveOutfitID()
    local used = #outfits + 1

    setClearTile(tiles[1] or createTile(1))
    for position, outfit in ipairs(outfits) do
        local index = position + 1
        setOutfitTile(tiles[index] or createTile(index), outfit, activeOutfitID)
    end
    for index = used + 1, #tiles do
        retireTile(tiles[index])
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
    panel:RegisterEvent("PLAYER_REGEN_ENABLED")
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
