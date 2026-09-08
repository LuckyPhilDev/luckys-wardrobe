-- luacheck: globals C_AddOns C_Spell Constants CooldownFrame_Clear CooldownFrame_Set C_Transmog C_TransmogOutfitInfo CreateFrame GameTooltip GameTooltip_Hide InCombatLockdown LuckyUI ScrollBoxListMixin TransmogFrame UIParent UISpecialFrames tinsert unpack

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

-- Long enough to read the grid and pick, short enough that wearing an outfit takes
-- the window away with it.
local HIDE_AFTER = 5

-- The header's title inset, its close button, and a gap between the two.
local HEADER_CHROME = 46
local NAME_GAP = 10
local NAME_MAX_WIDTH = 140

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
-- tile out of the list's reach is never a tile that ignores you. Use change so a
-- second click before its row arrives cannot take the outfit off again.
local function setLockTarget(tile, target)
    tile.lockTarget = target
    tile:SetAttribute("type2", target and "click" or nil)
    tile:SetAttribute("clickbutton2", target)
    tile:SetAttribute("action2", not target and tile.outfitID and "change" or nil)
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
    local collection = outfitCollection()
    local list = collection and collection.OutfitList
    local scrollBox = list and list.ScrollBox
    if not scrollBox then return end

    hookedOutfitRows = true
    -- Existing rows already copied their Init method, so a mixin hook misses them.
    scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(_, entry, elementData)
        if elementData and not InCombatLockdown() then
            aimTilesAtRow(entry.OutfitIcon, elementData.outfitID)
        end
    end, OutfitBar)
    scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnReleasedFrame, function(_, entry)
        if not InCombatLockdown() then aimTilesAtRow(entry.OutfitIcon, nil) end
    end, OutfitBar)
end

-- A row exists only once the window's OnShow has built it, and OnShow has to be the
-- one that does: calling the window's own refresh from here would build the rows on
-- this addon's call chain, and a row built that way cannot run the protected call
-- behind a lock. Showing and hiding it in the same breath leaves that to the game and
-- is over before anything draws, at the cost of the window's open and close sounds.
-- Never while it stands open, and never at a transmogrifier, where closing it would
-- end the visit.
local function borrowOutfitRows(retry)
    if (borrowedOutfitRows and not retry) or not outfitCollection() then return end
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

    tile.cooldown = CreateFrame("Cooldown", nil, tile, "CooldownFrameTemplate")
    tile.cooldown:SetAllPoints()
    tile.cooldown:SetDrawBling(false)
    tile.cooldown:SetHideCountdownNumbers(false)

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
        if self.lockTarget then
            GameTooltip:AddLine(strings.lockHint, 0.54, 0.49, 0.42, true)
        elseif self.outfitID then
            GameTooltip:AddLine(strings.lockPrepareHint, 0.54, 0.49, 0.42, true)
        end
        GameTooltip:Show()
    end)
    tile:SetScript("OnLeave", GameTooltip_Hide)
    tile:SetScript("PostClick", function(self, _, down)
        if down or InCombatLockdown() or not self.outfitID then return end
        if C_TransmogOutfitInfo.GetActiveOutfitID() ~= self.outfitID then return end
        if lockTargetForOutfit(self.outfitID) then return end

        -- ponytail: two clicks for an offscreen outfit; OnShow selects it without rebuilding its handler in addon code.
        borrowOutfitRows(true)
    end)

    tiles[index] = tile
    return tile
end

local function refreshCooldowns()
    local cooldown = C_Spell.GetSpellCooldown(Constants.TransmogOutfitDataConsts.EQUIP_TRANSMOG_OUTFIT_MANUAL_SPELL_ID)
    for _, tile in ipairs(tiles) do
        if cooldown then
            CooldownFrame_Set(tile.cooldown, cooldown.startTime, cooldown.duration, cooldown.isEnabled)
        else
            CooldownFrame_Clear(tile.cooldown)
        end
    end
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

-- Nothing matches while your own gear is on show, and nothing matches either in the
-- moment between an outfit being deleted and another taking over.
local function showActiveOutfitName(outfits, activeOutfitID)
    local name
    for _, outfit in ipairs(outfits) do
        if outfit.outfitID == activeOutfitID then name = outfit.name end
    end
    panel.activeName:SetText(name or strings.noOutfit)
    panel.activeName:SetTextColor(unpack(name and LuckyUI.C.goldAccent or LuckyUI.C.textMuted))
end

local function refresh()
    if not panel then return end

    local outfits = C_TransmogOutfitInfo.GetOutfitsInfo() or {}
    local activeOutfitID = C_TransmogOutfitInfo.GetActiveOutfitID()
    -- Ahead of the combat check, because a situation swapping outfits as a fight
    -- starts is the swap you are least likely to have made yourself.
    showActiveOutfitName(outfits, activeOutfitID)

    -- Every tile is a secure frame, so none of what follows is allowed mid-fight.
    -- PLAYER_REGEN_ENABLED brings the bar up to date the moment the fight ends.
    if InCombatLockdown() then return end

    hookOutfitRows()
    -- The equip can finish after PostClick; its event must prepare the next lock click too.
    borrowOutfitRows(panel:IsShown() and activeOutfitID and activeOutfitID ~= 0
        and not lockTargetForOutfit(activeOutfitID))

    local used = #outfits + 1

    setClearTile(tiles[1] or createTile(1))
    for position, outfit in ipairs(outfits) do
        local index = position + 1
        setOutfitTile(tiles[index] or createTile(index), outfit, activeOutfitID)
    end
    for index = used + 1, #tiles do
        retireTile(tiles[index])
    end

    refreshCooldowns()
    panel.empty:SetShown(#outfits == 0)

    local columns = math.min(used, PER_ROW)
    local rows = math.ceil(used / PER_ROW)
    -- A handful of outfits makes a grid narrower than the header, and both the title
    -- and the outfit's name move with the locale, so they are measured rather than
    -- assumed to fit. A long name stops widening the window and truncates instead.
    local gridWidth = PADDING * 2 + columns * TILE + (columns - 1) * GAP
    local headerWidth = panel.titleText:GetStringWidth() + HEADER_CHROME + NAME_GAP
        + math.min(panel.activeName:GetStringWidth(), NAME_MAX_WIDTH)
    panel:SetSize(
        math.max(gridWidth, headerWidth),
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

    panel.activeName = panel.header:CreateFontString(nil, "OVERLAY")
    panel.activeName:SetFont(LuckyUI.BODY_FONT, 12)
    panel.activeName:SetPoint("LEFT", panel.titleText, "RIGHT", NAME_GAP, 0)
    -- Clear of the close button, which the header hangs 8 in from its right edge.
    panel.activeName:SetPoint("RIGHT", -34, 0)
    panel.activeName:SetJustifyH("RIGHT")
    panel.activeName:SetWordWrap(false)

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
    panel:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    panel:SetScript("OnEvent", function(_, event)
        if event == "SPELL_UPDATE_COOLDOWN" then
            refreshCooldowns()
        else
            refresh()
        end
    end)
    -- Clicking an outfit is the whole reason the window is open, so it sees itself
    -- out rather than waiting to be closed.
    LuckyUI.EnableAutoHide(panel, HIDE_AFTER)
    panel:SetScript("OnShow", function(self)
        refresh()
        self:StartAutoHide()
    end)

    tinsert(UISpecialFrames, panel:GetName())
    return panel
end

function OutfitBar:Toggle()
    if panel and panel:IsShown() then
        panel:Hide()
        return
    end
    -- Every tile is a secure frame, so a fight is not somewhere the grid can be laid
    -- out at all. Opening then would open it empty or a fight out of date.
    if InCombatLockdown() then
        LuckysWardrobe.Utils.Say(strings.inCombat)
        return
    end
    (panel or buildPanel()):Show()
end

function OutfitBar:Init(database)
    db = database
end
