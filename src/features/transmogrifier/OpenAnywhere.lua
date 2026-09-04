-- luacheck: globals C_AddOns C_Transmog HideUIPanel InCombatLockdown ShowUIPanel TransmogFrame

-- Lucky's Wardrobe: Open the transmog window away from a transmog NPC.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.OpenAnywhere = {}

local OpenAnywhere = LuckysWardrobe.OpenAnywhere
local strings = LuckysWardrobe.Strings.openAnywhere

-- Away from an NPC the game will not save an outfit, buy a slot or transmogrify
-- anything, so these parts of the window can do nothing. Taking them off leaves
-- the outfit list, which does work anywhere, and lets the frame shrink to a
-- strip instead of covering the screen with controls that refuse to answer.
local IDLE_FRAME_PARTS = { "HelpPlateButton", "CharacterPreview", "WardrobeCollection", "Bg" }
local IDLE_OUTFIT_PARTS = { "SaveOutfitButton", "MoneyFrame", "PurchaseOutfitButton", "DividerBar" }

-- The outfit list is 312 wide against the frame's left edge, inset by 2.
local COMPACT_WIDTH = 316

local fullWidth
local compacted = false
local hooked = false

local function setIdlePartsShown(shown)
    for _, key in ipairs(IDLE_FRAME_PARTS) do
        local part = TransmogFrame[key]
        if part then part:SetShown(shown) end
    end

    local collection = TransmogFrame.OutfitCollection
    for _, key in ipairs(IDLE_OUTFIT_PARTS) do
        local part = collection and collection[key]
        if part then part:SetShown(shown) end
    end
end

local function restore()
    if not compacted then return end
    compacted = false
    setIdlePartsShown(true)
    TransmogFrame:SetWidth(fullWidth)
end

-- Restoring on hide rather than on the next open keeps the frame at its own size
-- whenever Blizzard shows it at an NPC. ShowUIPanel scales the frame to fit the
-- screen from the size it is at that moment, so it must never find a compacted one.
local function compact()
    if compacted then return end
    compacted = true
    fullWidth = TransmogFrame:GetWidth()
    setIdlePartsShown(false)
    TransmogFrame:SetWidth(COMPACT_WIDTH)

    if not hooked then
        hooked = true
        TransmogFrame:HookScript("OnHide", restore)
    end
end

-- Plumber's own transmog module hooks the same frame and shrinks it the same way.
-- Two addons resizing one frame is worse than a window left at full size, so the
-- compacting stands down and Plumber's hook does it instead.
local function plumberIsShrinkingIt()
    return C_AddOns.DoesAddOnExist("Plumber") and C_AddOns.IsAddOnLoaded("Plumber")
end

function OpenAnywhere:Open()
    if InCombatLockdown() then
        LuckysWardrobe.Utils.Say(strings.inCombat)
        return
    end

    if not C_AddOns.IsAddOnLoaded("Blizzard_Transmog") then
        C_AddOns.LoadAddOn("Blizzard_Transmog")
    end
    if not TransmogFrame then return end

    if C_Transmog.IsAtTransmogNPC() or plumberIsShrinkingIt() then
        restore()
    else
        compact()
    end

    ShowUIPanel(TransmogFrame)
end

function OpenAnywhere:Toggle()
    if TransmogFrame and TransmogFrame:IsShown() then
        HideUIPanel(TransmogFrame)
        return
    end
    self:Open()
end
