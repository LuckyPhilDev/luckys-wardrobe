-- luacheck: globals C_TransmogCollection LuckysWardrobe

-- Covers naming the colours an appearance is painted: the conversion into the
-- space the naming happens in, which name each region of that space answers
-- to, what a piece is made of once its colours are gathered under those names,
-- and which pages that puts it on.

LuckysWardrobe = {}

dofile("src/Colours.lua")

local Colours = LuckysWardrobe.Colours

local function close(actual, expected, tolerance)
    return math.abs(actual - expected) <= (tolerance or 0.01)
end

-- White and black are the two ends of lightness, and neither leans towards any
-- colour, so both are a fixed point the conversion has to land on exactly.

local light, a, b = Colours.OKLab(255, 255, 255)
assert(close(light, 1) and close(a, 0) and close(b, 0), "white is the top of the lightness axis")

light, a, b = Colours.OKLab(0, 0, 0)
assert(close(light, 0) and close(a, 0) and close(b, 0), "black is the bottom of it")

-- Pure blue sits at the blue end of the second colour axis and is a dark
-- colour in its own right. OKLab is used over CIELAB because its hue angles
-- hold still as a colour darkens, which is what the naming leans on.

light, _, b = Colours.OKLab(0, 0, 255)
assert(b < -0.2, "blue sits at the blue end of the yellow to blue axis")
assert(light < 0.5, "and is a dark colour in its own right")

-- Naming. Every name owns a region of the space outright, so every colour is
-- something by construction, and the name is the one a player would give it
-- looking at the piece.

local function name(red, green, blue)
    return Colours.Name(Colours.OKLab(red, green, blue))
end

assert(name(200, 30, 30) == "red", "a red is red")
assert(name(230, 120, 20) == "orange", "an orange is orange")
assert(name(235, 205, 60) == "yellow", "a yellow is yellow")
assert(name(40, 160, 60) == "green", "a green is green")
assert(name(30, 170, 175) == "teal", "a teal is teal")
assert(name(30, 105, 215) == "blue", "a blue is blue")
assert(name(145, 45, 200) == "purple", "a purple is purple")
assert(name(230, 105, 180) == "pink", "a pink is pink")
assert(name(110, 75, 45) == "brown", "a brown is brown")

-- How dark a colour is must not decide which colour it is, which is why hue
-- angle leads the naming. A wine red is as red as a pillar box one.

assert(name(136, 17, 34) == "red", "a wine red is still red")
assert(name(102, 0, 17) == "red", "and so is a crimson dark enough to read as black at a glance")
assert(name(102, 17, 17) == "red", "and a dried blood red")
assert(name(68, 51, 85) == "purple", "a plum is purple")
assert(name(60, 25, 90) == "purple", "and so is a dark purple robe")
assert(name(34, 85, 51) == "green", "a forest green is green")
assert(name(20, 90, 95) == "teal", "a dark teal is teal")

-- The blue-purple line is the one CIELAB could never hold still, pulling a
-- blue towards violet as it brightens. In OKLCh both sit at fixed angles.

assert(name(34, 34, 102) == "blue", "a navy is blue")
assert(name(51, 51, 136) == "blue", "and a royal blue is blue")
assert(name(125, 175, 235) == "blue", "and a sky blue is blue")
assert(name(113, 65, 209) == "purple", "while a violet is purple")

-- Light red against pink is a hue line, not a lightness one: rose and
-- raspberry sit on pink's side of it, a washed-out red crosses over, but a red
-- that is merely light stays red.

assert(name(255, 105, 95) == "red", "a light red is red")
assert(name(245, 70, 115) == "pink", "a rose is pink")
assert(name(200, 50, 90) == "pink", "and so is a raspberry")
assert(name(240, 20, 135) == "pink", "and a hot pink")
assert(name(183, 41, 171) == "pink", "and a deep magenta")
assert(name(200, 145, 155) == "pink", "and a dusty pink barely past neutral")
assert(name(235, 180, 175) == "pink", "a red washed out enough loses its red")
assert(name(153, 119, 119) == "pink", "and so does a dusty mauve, at any depth short of sepia")
assert(name(211, 108, 109) == "pink", "a soft rose is the lit face of painted pink")

-- A dull colour at red's hues is not red at all. Blizzard paints half the
-- game's hoods and straps in sepias and dusty leathers that sit at red's
-- angle with a fraction of its colour, and a page of them is what a red
-- filter must not answer with. Dark they are brown, light they are pink, and
-- only a colour past the dull floor is red.

assert(name(68, 34, 34) == "brown", "a sepia hood is brown")
assert(name(85, 34, 34) == "brown", "and so is a dark brick leather")
assert(name(102, 68, 68) == "brown", "and a warm grey mask")
assert(name(119, 85, 85) == "brown", "and a dusty leather strap")

-- Below the sepia line the dull floor rises with lightness, because what
-- separates a dark red from a shaded brown is colour in proportion to the
-- light on it: the shadow half of an orange scarf is not a red, while a dried
-- blood red at the same chroma is darker and keeps its name.

assert(name(102, 34, 34) == "brown", "the warm shadow of an orange knit is brown")
assert(name(85, 17, 17) == "red", "a dried blood red at the same chroma stays red")
assert(name(119, 34, 34) == "red", "and so does a blood red above it")

-- The red arc stops at 30 degrees: past it sit the lavas, bricks, flames and
-- rusts, which read as orange on a model however the arithmetic leans.

assert(name(170, 34, 17) == "orange", "molten lava is orange")
assert(name(170, 68, 51) == "orange", "and so is a brick mask")
assert(name(220, 60, 30) == "orange", "and a flame")
assert(name(178, 34, 34) == "red", "while a scarlet stays red")

-- And a dark yellow is not a yellow: it is an olive, which a player calls
-- green. Yellow is the one name that only exists in the light.

assert(name(51, 51, 17) == "green", "a dark olive mask cloth is green")
assert(name(160, 130, 30) == "yellow", "while a dark gold keeps enough light to be yellow")

-- Brown is the orange arc gone dull or dark, and it claims both, while the
-- vivid oranges and the pale creams stay out.

assert(name(119, 85, 34) == "brown", "a mid brown is brown")
assert(name(170, 130, 85) == "brown", "a tan is brown")
assert(name(70, 45, 30) == "brown", "a dark leather is brown")
assert(name(85, 68, 51) == "brown", "however dull the dye")
assert(name(139, 69, 19) == "brown", "a saddle brown is brown")
assert(name(222, 196, 176) == "brown", "a beige is a pale one")
assert(name(180, 70, 20) == "orange", "a burnt orange is still orange")
assert(name(165, 60, 30) == "orange", "and so is a rust")
assert(name(240, 150, 125) == "orange", "and a salmon")
assert(name(255, 195, 90) == "yellow", "a gold is yellow")

-- Below a floor on chroma there is no hue worth naming, however the arithmetic
-- leans, and lightness alone tells the neutrals apart.

assert(name(235, 235, 230) == "white", "a white is white")
assert(name(220, 215, 200) == "white", "an ivory is white, Blizzard's whites all being warm")
assert(name(150, 150, 155) == "grey", "a grey is grey")
assert(name(95, 95, 100) == "grey", "a charcoal is grey")
assert(name(95, 95, 112) == "grey", "a slate tint is grey, a tint not being a colour")

-- And below a floor on lightness there is not enough light on a colour for its
-- hue to read at all. A near black with a navy tint is a black.

assert(name(25, 25, 28) == "black", "a black is black")
assert(name(17, 17, 51) == "black", "a near-black navy is black")
assert(name(0, 17, 51) == "black", "however far round the wheel the tint sits")

-- Palettes. The bundled table is keyed by the visualID the wardrobe hands out,
-- and packs each appearance's colours as one hex digit per channel run
-- together. An appearance the snapshot never saw has to say so rather than
-- answer with an empty palette that would match nothing quietly.

-- A colour is three channel digits and then its share of the piece in
-- sixteenths.
local HALF = 8

local function pack(...)
    local packed = ""
    for _, colour in ipairs({ ... }) do
        packed = packed .. string.format("%x%x%x%x",
            math.floor(colour[1] / 16), math.floor(colour[2] / 16), math.floor(colour[3] / 16),
            colour[4] or HALF)
    end
    return packed
end

LuckysWardrobe.AppearanceColours = {
    [1001] = pack({ 45, 90, 210 }, { 200, 30, 30 }),   -- a blue and a red
    [1002] = pack({ 110, 75, 45 }),                    -- one brown
    [1003] = "",                                       -- no colour could be read
}

local palette = Colours.Palette(1001)
assert(#palette == 2, "an appearance with two colours unpacks into two")
assert(close(palette[1][1], select(1, Colours.OKLab(34, 85, 221)), 0.001),
    "the first is the blue it packed, rounded to a digit a channel")
assert(#Colours.Palette(1002) == 1, "and one colour unpacks into one")
assert(Colours.Palette(9999) == false, "an appearance with no entry says so")
assert(#Colours.Palette(1003) == 0, "an empty entry is a palette with nothing in it")

-- A digit per channel is only ever a sixteenth out, which must not be enough to
-- change what a colour is called.

assert(name(45, 90, 210) == name(34, 85, 221), "packing does not rename a colour")

-- What a piece is made of. Its colours are gathered under the swatch each is
-- named for, most of the piece first, and two colours with one name are that
-- much of it between them.

local function madeOf(visualID)
    local made, out = Colours.MadeOf(visualID), {}
    for _, colour in ipairs(made or {}) do
        out[#out + 1] = string.format("%s %.2f", colour.key, colour.share)
    end
    return table.concat(out, ", ")
end

-- A white plate chest with gold on it and a dark underlay: white, then yellow,
-- then grey, in that order and no other.
LuckysWardrobe.AppearanceColours[2001] =
    pack({ 235, 235, 230, 10 }, { 230, 180, 60, 4 }, { 150, 150, 155, 2 })
assert(madeOf(2001) == "white 0.62, yellow 0.25, grey 0.12", "a white and gold piece is made of both")

-- Two greens are one green, and together they are more of the piece than the
-- red that is larger than either.
LuckysWardrobe.AppearanceColours[2002] =
    pack({ 200, 30, 30, 6 }, { 40, 160, 60, 5 }, { 34, 85, 51, 5 })
assert(madeOf(2002) == "green 0.62, red 0.38", "a highlight and the shade under it are one colour")

assert(Colours.MadeOf(9999) == false, "an appearance with no entry is made of nothing")
assert(Colours.MadeOf(1003) == false, "and so is one whose colours could not be read")

-- The pages a piece lands on. It is always on its primary's, whatever that
-- colour amounts to, because it has to be somewhere. The colours behind it have
-- to cover enough of the piece to earn their place.

local target = {}
for _, preset in ipairs(Colours.PRESETS) do
    target[preset.key] = Colours.Target(preset)
end

assert(Colours.Matches(2001, target.white), "a piece is on its primary colour's page")
assert(Colours.Matches(2001, target.yellow), "and its secondary's, that being a quarter of it")
assert(Colours.Matches(2001, target.grey), "and its tertiary's, that clearing the lower bar")
assert(not Colours.Matches(2001, target.red), "and no others")

-- A piece is on its primary's page however little of it that colour is.
LuckysWardrobe.AppearanceColours[2003] =
    pack({ 200, 30, 30, 3 }, { 40, 160, 60, 2 }, { 30, 105, 215, 2 })
assert(Colours.Matches(2003, target.red), "the largest colour always counts")

-- A colour too small for its place does not, and takes the ones behind it with
-- it: they are smaller still, and a page holding pieces with less of its colour
-- on them than a page they were kept off is the wrong way round.

LuckysWardrobe.AppearanceColours[2004] = pack({ 30, 105, 215, 13 }, { 200, 30, 30, 2 })
assert(Colours.Matches(2004, target.blue), "a piece mostly blue is on the blue page")
assert(not Colours.Matches(2004, target.red), "a red eighth of it is not enough to be red")

LuckysWardrobe.AppearanceColours[2005] =
    pack({ 30, 105, 215, 8 }, { 200, 30, 30, 2 }, { 235, 205, 60, 2 })
assert(not Colours.Matches(2005, target.red), "a second colour short of its own bar is out")
assert(not Colours.Matches(2005, target.yellow), "and the third goes with it, being no larger")

-- A page is ordered by how much of a piece is that colour and by nothing else,
-- so the pieces that really are yellow lead the yellow page.

assert(Colours.Rank(2001, target.white) < Colours.Rank(2001, target.yellow),
    "a piece ranks ahead under the colour more of it is")
assert(Colours.Rank(2001, target.yellow) < Colours.Rank(2001, target.grey),
    "and behind under the colour less of it is")
assert(Colours.Rank(2001, target.white) < Colours.Rank(2003, target.red),
    "a page leads with the pieces most of that colour")

-- Which of the three a colour is says whether the piece is on the page at all,
-- and nothing about where. A piece a quarter yellow as its second colour is more
-- yellow than one a fifth yellow as its first, and comes first for it.

LuckysWardrobe.AppearanceColours[2006] = pack({ 25, 25, 28, 12 }, { 235, 205, 60, 4 })
LuckysWardrobe.AppearanceColours[2007] =
    pack({ 235, 205, 60, 3 }, { 200, 30, 30, 2 }, { 30, 105, 215, 2 })
assert(Colours.Rank(2006, target.yellow) < Colours.Rank(2007, target.yellow),
    "the piece with more yellow on it comes first whichever of its colours yellow is")

-- The last swatch is not a colour. It keeps what could not be read at all,
-- which is a piece from a patch newer than the snapshot or one whose art could
-- not be read, and nothing else: the regions cover the space, so every colour
-- that could be read has a name.

local unmatched
for _, preset in ipairs(Colours.PRESETS) do
    if preset.unmatched then unmatched = Colours.Target(preset) end
end

assert(unmatched, "the strip carries a swatch for the pieces with no colour")
assert(Colours.Matches(5001, unmatched), "an appearance the snapshot has nothing for is left over")
assert(Colours.Matches(1003, unmatched), "so is one whose palette came out empty")
assert(not Colours.Matches(2001, unmatched), "a piece with colours on it is not")
assert(Colours.Rank(5001, unmatched) == 0 and Colours.Rank(1003, unmatched) == 0,
    "everything left over ranks the same, there being nothing to measure")

-- A palette is unpacked once and kept, and so is what a piece is made of,
-- because the tab asks about every appearance it lists on every redraw and a
-- category runs to hundreds.

local unpacked = 0
local packedBlue = LuckysWardrobe.AppearanceColours[1001]
setmetatable(LuckysWardrobe.AppearanceColours, {
    __index = function(_, key)
        if key ~= 3001 then return nil end
        unpacked = unpacked + 1
        return packedBlue
    end,
})

assert(Colours.Matches(3001, target.blue), "an appearance not seen before is read from the snapshot")
assert(unpacked == 1, "which costs one read")
assert(Colours.Matches(3001, target.blue), "and asking again gives the same answer")
assert(unpacked == 1, "off what was already unpacked")

local named = 0
local realName = Colours.Name
Colours.Name = function(...)
    named = named + 1
    return realName(...)
end

LuckysWardrobe.AppearanceColours[3002] = pack({ 145, 45, 200 })
assert(Colours.Matches(3002, target.purple), "a piece is named on the first ask")
assert(named > 0, "which costs a naming")
named = 0
assert(Colours.Matches(3002, target.purple), "and answers the same on the next")
assert(named == 0, "off what it was already made of")

Colours.Name = realName

-- The same has to hold for an appearance the snapshot has nothing for, or every
-- redraw would go looking for a piece the file will never hold.

assert(not Colours.Matches(4001, target.blue), "an appearance with no entry matches nothing")
assert(not Colours.Matches(4001, target.blue), "and is not looked up again to find that out twice")

-- The real bundled table, to catch a generator that wrote something the addon
-- cannot read: keys have to be the visualIDs the wardrobe hands out, and every
-- value has to unpack to whole colours.

LuckysWardrobe.AppearanceColours = nil
dofile("src/Data/AppearanceColours.lua")

local rows, colours = 0, 0
for visualID, entry in pairs(LuckysWardrobe.AppearanceColours) do
    assert(type(visualID) == "number" and visualID > 0, "keyed by a visualID")
    assert(#entry % 4 == 0 and #entry > 0, "packed as whole colours")
    assert(#entry <= 16, "and no more of them than the generator keeps")
    rows = rows + 1
    colours = colours + #entry / 4
end
assert(rows > 40000, "the snapshot covers the collection rather than a corner of it")
assert(colours / rows > 1.5, "and most appearances carry more than a single colour")

print("Lucky's Wardrobe colours tests passed")
