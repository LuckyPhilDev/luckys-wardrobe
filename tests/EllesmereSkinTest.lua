-- luacheck: globals EllesmereUI LuckysWardrobe PixelUtil

local registeredName, handOver
local collectionsStyle = "eui"
EllesmereUI = {
    RegisterSkin = function(name, callback) registeredName, handOver = name, callback end,
    GetBlizzWindowStyle = function(winKey) return winKey == "collections" and collectionsStyle end,
}
PixelUtil = { GetPixelToUIUnitFactor = function() return 0.5 end }

dofile("src/features/journal/EllesmereSkin.lua")
local EllesmereSkin = LuckysWardrobe.EllesmereSkin

local painted = {}
local kit = {
    Tab = function(tab, look) painted[#painted + 1] = { tab = tab, dark = look and look.darkActive } end,
}

local function newTab() return { GetEffectiveScale = function() return 0.25 end } end

assert(registeredName == "Luckys_Wardrobe", "registers under the addon's folder name")

-- Before EllesmereUI hands its kit over, nothing is painted and no tab is marked.
local order = {}
EllesmereSkin.Apply(function() order[#order + 1] = "first" end)
local items, extra = newTab(), newTab()
EllesmereSkin.ShowSelectedTab({ items, extra }, extra)
assert(#order == 0 and extra.isSelected == nil, "waits for the kit")

local seatedGap
EllesmereSkin.Tab(extra, function(gap) seatedGap = gap end)
handOver(kit)
assert(order[1] == "first", "the handover paints what was waiting")
assert(painted[1].tab == extra and painted[1].dark, "our tab takes the Items and Sets look")
assert(seatedGap == 2, "the strip closes to one physical pixel at the tab's scale")

EllesmereSkin.Apply(function() order[#order + 1] = "second" end)
assert(order[2] == "second", "once handed over, paints straight away")

-- Choosing our tab marks every tab, and choosing a native one hands the answer back.
painted = {}
EllesmereSkin.ShowSelectedTab({ items, extra }, extra)
assert(items.isSelected == false and extra.isSelected == true, "our tab is the lit one")
assert(#painted == 2, "every tab in the strip is repainted")

EllesmereSkin.ShowSelectedTab({ items, extra }, nil)
assert(items.isSelected == nil and extra.isSelected == nil, "Blizzard's selection decides again")

-- Either of EllesmereUI's styles on the Collections window skins these pages;
-- a window left as Blizzard drew it keeps them as Blizzard draws them too.
for style, skinned in pairs({ modern = true, off = false }) do
    collectionsStyle = style
    dofile("src/features/journal/EllesmereSkin.lua")
    EllesmereSkin = LuckysWardrobe.EllesmereSkin

    local runs = 0
    EllesmereSkin.Apply(function() runs = runs + 1 end)
    handOver(kit)
    EllesmereSkin.Apply(function() runs = runs + 1 end)
    local tab = newTab()
    EllesmereSkin.ShowSelectedTab({ tab }, tab)
    if skinned then
        assert(runs == 2 and tab.isSelected == true, "a " .. style .. " Collections window skins ours")
    else
        assert(runs == 0 and tab.isSelected == nil, "a " .. style .. " Collections window leaves ours stock")
    end
end

print("EllesmereSkinTest passed")
