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
