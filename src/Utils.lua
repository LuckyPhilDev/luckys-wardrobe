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
