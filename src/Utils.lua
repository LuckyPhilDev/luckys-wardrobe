-- luacheck: globals C_Timer EXPANSION_NAME0 EXPANSION_NAME1 EXPANSION_NAME2 EXPANSION_NAME3 EXPANSION_NAME4 EXPANSION_NAME5 EXPANSION_NAME6 EXPANSION_NAME7 EXPANSION_NAME8 EXPANSION_NAME9 EXPANSION_NAME10 EXPANSION_NAME11

-- Lucky's Wardrobe: data and helpers more than one module needs.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.Utils = {}

local Utils = LuckysWardrobe.Utils

-- The armour slots this addon shows, head to feet, each with the global
-- Blizzard localises its name into. A patch that adds a slot adds it here and
-- nowhere else: the order is the order a set's pieces are listed in, and it is
-- also the order the collection numbers its own armour categories, so category
-- N is ARMOUR_SLOTS[N].
local SLOTS = {
    { key = "HEAD", tooltipGlobal = "HEADSLOT" },
    { key = "SHOULDER", tooltipGlobal = "SHOULDERSLOT" },
    { key = "BACK", tooltipGlobal = "BACKSLOT" },
    { key = "CHEST", tooltipGlobal = "CHESTSLOT" },
    { key = "BODY", tooltipGlobal = "SHIRTSLOT" },
    { key = "TABARD", tooltipGlobal = "TABARDSLOT" },
    { key = "WRIST", tooltipGlobal = "WRISTSLOT" },
    { key = "HANDS", tooltipGlobal = "HANDSSLOT" },
    { key = "WAIST", tooltipGlobal = "WAISTSLOT" },
    { key = "LEGS", tooltipGlobal = "LEGSSLOT" },
    { key = "FEET", tooltipGlobal = "FEETSLOT" },
}

Utils.ARMOUR_SLOTS = {}
Utils.SLOT_TOOLTIP_GLOBALS = {}
for index, slot in ipairs(SLOTS) do
    Utils.ARMOUR_SLOTS[index] = slot.key
    Utils.SLOT_TOOLTIP_GLOBALS[slot.key] = slot.tooltipGlobal
end

--- Prints one line to chat under the addon's name, which is how every command
--- and every alert speaks.
function Utils.Say(line)
    print(("%s %s"):format(LuckysWardrobe.Strings.addon.prefix, line))
end

-- The tint on an icon the addon draws into the game's own frames: lit when
-- whatever it stands for is on, grey when it is not.
Utils.ICON_ON = { 1.0, 0.824, 0.392 }
Utils.ICON_OFF = { 0.35, 0.35, 0.35 }

-- A square icon button stripped to its drawing: the plate is cleared away and
-- the hover glow is the icon added over itself, the way the padlocks read.
-- The template's tooltip, press nudge and click handling all stay.
local GLOW_ALPHA = 0.35

function Utils.BareIcon(button, icon, tint)
    button:ClearNormalTexture()
    button:ClearPushedTexture()
    button:ClearDisabledTexture()
    button:SetIcon(icon)
    button.Icon:SetVertexColor(tint[1], tint[2], tint[3])

    button:SetHighlightTexture(icon, "ADD")
    local glow = button:GetHighlightTexture()
    glow:SetPoint("TOPLEFT", button.Icon, "TOPLEFT")
    glow:SetPoint("BOTTOMRIGHT", button.Icon, "BOTTOMRIGHT")
    glow:SetVertexColor(tint[1], tint[2], tint[3])
    glow:SetAlpha(GLOW_ALPHA)
end

-- How long a burst of collection events is allowed to gather before a page
-- reads the catalogue again. Long enough to collapse a burst, short enough that
-- collecting something still updates the list while you are looking at it.
Utils.REBUILD_DELAY_SECONDS = 0.25

-- How long a page waits for the items behind a set's pieces to arrive before
-- reading them again, and how many times it is willing to wait. Some never
-- arrive, so the waiting ends rather than running until it succeeds.
Utils.ITEM_LOAD_DELAY_SECONDS = 0.5
Utils.ITEM_LOAD_PASSES = 3

--- Wraps an action so a burst of calls runs it once, a moment later. Learning
--- one appearance fires the collection event several times over, and reading
--- every set again costs far more than a frame. The delay is not felt: nothing
--- on screen changes until the pass runs either way.
function Utils.Debounced(seconds, action)
    local queued = false
    return function()
        if queued then return end

        queued = true
        C_Timer.After(seconds, function()
            queued = false
            action()
        end)
    end
end

-- Every expansion, named as the game names it, for the Expansion submenu both
-- filter menus offer. A new expansion is one name added here.
Utils.EXPANSION_NAMES = {
    EXPANSION_NAME0,
    EXPANSION_NAME1,
    EXPANSION_NAME2,
    EXPANSION_NAME3,
    EXPANSION_NAME4,
    EXPANSION_NAME5,
    EXPANSION_NAME6,
    EXPANSION_NAME7,
    EXPANSION_NAME8,
    EXPANSION_NAME9,
    EXPANSION_NAME10,
    EXPANSION_NAME11,
}

--- Turns every expansion's checkbox on or off. Keyed by Blizzard's expansionID,
--- which counts from 0 for Classic, while the name list is a Lua array counting
--- from 1, so every lookup is index - 1.
function Utils.SetAllExpansions(expansions, shown)
    for index = 1, #Utils.EXPANSION_NAMES do expansions[index - 1] = shown end
end

--- Whether any expansion has been unticked, which is what makes a filtered list
--- differ from the whole of it.
function Utils.AnyExpansionHidden(expansions)
    for index = 1, #Utils.EXPANSION_NAMES do
        if not expansions[index - 1] then return true end
    end
    return false
end

-- The badge counting the colourways behind a set row. Both set lists draw their
-- rows from Blizzard's own template, so both mark them the same way from here.
--
-- The template gives the name the full 190 of its width and lets it wrap onto a
-- second line, so a row carrying the badge hands that width back rather than
-- letting a long name run under it. Both widths are set every time, because the
-- lists pool their rows: a plain set drawn into a row that just held a family
-- would otherwise keep the narrow name.
local ROW_NAME_WIDTH = 190
local ROW_NAME_WIDTH_WITH_BADGE = 168
local VARIANT_BADGE_INSET = 6
-- Bright yellow rather than the addon's own gold, which a row already spends on
-- a completed set's name: the badge counts colourways and says nothing about
-- collecting them, so it must not read as another completion state.
local VARIANT_BADGE_COLOUR = { r = 1, g = 0.95, b = 0.2 }

-- Made once per row and kept on it, because the lists redraw their rows on
-- every scroll.
local function badgeFor(button)
    if not button.luckysVariantCount then
        local badge = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        badge:SetPoint("TOPRIGHT", -VARIANT_BADGE_INSET, -VARIANT_BADGE_INSET)
        badge:SetTextColor(VARIANT_BADGE_COLOUR.r, VARIANT_BADGE_COLOUR.g, VARIANT_BADGE_COLOUR.b)
        button.luckysVariantCount = badge
    end
    return button.luckysVariantCount
end

-- How far through a set its name reads: gold for finished, grey for untouched,
-- green for started. Written out rather than taken from Blizzard's own
-- NORMAL_FONT_COLOR and friends, because IN_PROGRESS_FONT_COLOR is a global
-- only the Sets tab's own file ever names, and a row must not go unpainted on a
-- build that stops defining it.
local NAME_COLOURS = {
    complete = { 1, 0.82, 0 },
    none = { 0.5, 0.5, 0.5 },
    started = { 0.251, 0.753, 0.251 },
}

--- Paints a set row's name for how much of it is collected. Both set lists call
--- this, so a row means the same thing on either.
function Utils.ColourSetName(button, complete, collected)
    local colour = NAME_COLOURS.started
    if complete then
        colour = NAME_COLOURS.complete
    elseif collected == 0 then
        colour = NAME_COLOURS.none
    end
    button.Name:SetTextColor(colour[1], colour[2], colour[3])
end

--- Marks a set row with how many colourways stand behind it. Pass nothing, or
--- one, for a set that is only itself: the badge goes quiet and the name takes
--- the row's full width back.
function Utils.MarkVariantCount(button, colourways)
    local several = colourways and colourways > 1
    button.Name:SetWidth(several and ROW_NAME_WIDTH_WITH_BADGE or ROW_NAME_WIDTH)
    badgeFor(button):SetText(several
        and LuckysWardrobe.Strings.setRow.variantCount:format(colourways) or "")
    return several
end
