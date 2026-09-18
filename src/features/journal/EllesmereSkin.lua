LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.EllesmereSkin = {}

local EllesmereSkin = LuckysWardrobe.EllesmereSkin

-- The look EllesmereUI gives the Items and Sets tabs. Undocumented, but its kit
-- passes options straight through to the tab it paints.
local TAB_LOOK = { darkActive = true }
local COLLECTIONS_WINDOW = "collections"
local BLIZZARD_STYLE = "off"
local BAR_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local BAR_TROUGH = { 0.12, 0.12, 0.12, 0.85 }
local BAR_EXTRA_HEIGHT = 2

local skin
local waiting = EllesmereUI and EllesmereUI.RegisterSkin and {}

--- Runs paint with EllesmereUI's skinning kit, straight away once EllesmereUI
--- has handed it over and on the handover until then. Without EllesmereUI, with
--- this addon's skin turned off in it, or with the Collections window left on
--- Blizzard's style, paint never runs.
function EllesmereSkin.Apply(paint)
    if skin then
        paint(skin)
    elseif waiting then
        waiting[#waiting + 1] = paint
    end
end

--- Paints one of this addon's journal tabs to match Items and Sets. reseat is
--- handed the seam EllesmereUI leaves between those two, one physical pixel,
--- so the strip can close up to it.
function EllesmereSkin.Tab(tab, reseat)
    EllesmereSkin.Apply(function(S)
        S.Tab(tab, TAB_LOOK)
        reseat(PixelUtil.GetPixelToUIUnitFactor() / tab:GetEffectiveScale())
    end)
end

--- EllesmereUI lights whichever tab Blizzard's selection names, and this
--- addon's tabs never join it, so while one of them is chosen every tab in the
--- strip says for itself. Blizzard reads isSelected only off TabSystem buttons,
--- which these are not. A nil chosen hands the answer back to Blizzard.
function EllesmereSkin.ShowSelectedTab(tabs, chosen)
    if not skin then return end
    for _, tab in ipairs(tabs) do
        if chosen then
            tab.isSelected = tab == chosen
        else
            tab.isSelected = nil
        end
        skin.Tab(tab, TAB_LOOK)
    end
end

--- Redraws a collection count bar the way EllesmereUI redraws the Items tab's,
--- which its kit has no single call for. The bar itself is kept out of
--- EllesmereUI's restyling passes, since those would fade the fill with the art.
function EllesmereSkin.ProgressBar(S, bar)
    S.FadeRegions(bar)
    bar:SetStatusBarTexture(BAR_TEXTURE)
    bar:GetStatusBarTexture():SetAlpha(1)
    S.ApplyBarFill(bar)
    S.White(bar.text)
    bar:SetHeight(bar:GetHeight() + BAR_EXTRA_HEIGHT)

    local trough = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    trough:SetColorTexture(unpack(BAR_TROUGH))
    trough:SetAllPoints()

    local edge = CreateFrame("Frame", nil, bar)
    edge:SetAllPoints()
    edge:SetFrameLevel(bar:GetFrameLevel())
    S.Panel(edge, { noBg = true })
end

-- Only while EllesmereUI restyles the Collections window itself, in either of
-- its styles, so these pages never stand out from a window left as Blizzard
-- drew it.
local function collectionsSkinned()
    local style = EllesmereUI.GetBlizzWindowStyle
        and EllesmereUI.GetBlizzWindowStyle(COLLECTIONS_WINDOW)
    return style and style ~= BLIZZARD_STYLE
end

-- EllesmereUI restyles Blizzard's own frames but leaves alone every frame
-- another addon made, so this addon's pages ask for the look themselves.
if waiting then
    EllesmereUI.RegisterSkin("Luckys_Wardrobe", function(S)
        if not collectionsSkinned() then
            waiting = nil
            return
        end
        skin = S
        for _, paint in ipairs(waiting) do paint(S) end
        waiting = nil
    end)
end
