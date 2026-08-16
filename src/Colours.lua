-- Lucky's Wardrobe: what colour an appearance is.
--
-- Nothing in the API says what colour an appearance is, and Lua cannot read a
-- texture's pixels, so the answer is bundled: Data/AppearanceColours.lua holds
-- the dominant colours of every appearance, read off the textures the game
-- paints it with before the addon shipped.
--
-- Not off its icon, which is the obvious source and the wrong one: 95% of
-- appearances share an icon with a different model, because a set's four
-- difficulty variants are four recolours behind one picture. Read off icons,
-- every variant of every tier set comes out the colour of whichever one the
-- picture was drawn for.
--
-- Naming those colours is the other half. Every name owns a region of colour
-- space outright, so between them the names cover the whole of it: any colour
-- the art can carry is something, and the only pieces left for the unmatched
-- swatch are the ones whose art could not be read at all.
--
-- The space is OKLCh, which is OKLab read as a cylinder: lightness, chroma
-- (how much colour), and hue (which colour, as an angle round the wheel). It
-- is used over CIELAB because Lab bends hue lines near blue, where a navy
-- darkened stays put but a blue brightened drifts violet, and the blue-purple
-- boundary was the one that kept moving. In OKLCh a hue angle names the same
-- colour at every depth, which is the whole trick: a wine red and a pillar-box
-- red share an angle, so darkness never changes what a piece is called.
--
-- The naming asks three questions in order. Is there enough light to see a hue
-- at all: below a floor everything is black, whatever tint the arithmetic
-- finds. Is there enough colour to name: below a chroma floor the piece is
-- white, grey or black by lightness alone. Only then does the hue angle name
-- it, through a wheel of arcs with two carve-outs on top, brown being a dull
-- or dark orange and pink reaching into washed-out red.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.Colours = {}

local Colours = LuckysWardrobe.Colours

-- How much of a piece a colour has to be to put the piece on that colour's page
-- past the first. The piece is always on its primary's page, whatever that
-- colour amounts to, because it has to be somewhere and that is where it most
-- belongs. The two behind it have to earn their place.
--
-- A colour that fails its threshold takes the ones behind it with it, so a piece
-- is never filed under its third colour but not its second. They are in share
-- order, so the alternative is a page holding pieces with less of its colour on
-- them than a page it was kept off.
--
-- Both are round numbers picked to be moved. They sit on the namespace rather
-- than in a local so that a session can try another pair without a reload.
-- Shares are packed in sixteenths, so the working bar is the next sixteenth
-- above each threshold: three for a secondary, two for a third. At 0.20 the
-- secondary bar was really four sixteenths, and a scarf whose carrot half is
-- three of them was missing from the orange page.
Colours.SECONDARY_SHARE = 0.18
Colours.TERTIARY_SHARE = 0.10

-- The colours the strip offers, in the order they appear. The shades paint the
-- swatches and nothing else: which pieces answer to a name is decided by the
-- regions below, not by distance to these. The first shade is the square on
-- the strip; the unmatched swatch carries two because it is painted as a
-- gradient, being the odds and ends rather than a thirteenth colour.
Colours.PRESETS = {
    { key = "red", shades = { { 200, 30, 30 } } },
    { key = "orange", shades = { { 230, 120, 20 } } },
    { key = "yellow", shades = { { 235, 205, 60 } } },
    { key = "green", shades = { { 40, 160, 60 } } },
    { key = "teal", shades = { { 30, 170, 175 } } },
    { key = "blue", shades = { { 30, 105, 215 } } },
    { key = "purple", shades = { { 145, 45, 200 } } },
    { key = "pink", shades = { { 230, 105, 180 } } },
    { key = "brown", shades = { { 110, 75, 45 } } },
    { key = "white", shades = { { 235, 235, 230 } } },
    { key = "grey", shades = { { 150, 150, 155 } } },
    { key = "black", shades = { { 25, 25, 28 } } },
    -- The last swatch is not a colour. With the wheel covering everything, all
    -- it keeps is the pieces the snapshot could not answer for: art that could
    -- not be read, or a patch newer than the snapshot.
    { key = "other", unmatched = true, shades = { { 122, 116, 84 }, { 84, 96, 118 } } },
}

local function toLinear(channel)
    channel = channel / 255
    if channel > 0.04045 then return ((channel + 0.055) / 1.055) ^ 2.4 end
    return channel / 12.92
end

-- sRGB in 0 to 255 to OKLab. Lightness runs 0 to 1; a and b carry the colour,
-- with chroma and hue read off them below.
function Colours.OKLab(red, green, blue)
    local r, g, b = toLinear(red), toLinear(green), toLinear(blue)
    local l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    local m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    local s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    local l_, m_, s_ = l ^ (1 / 3), m ^ (1 / 3), s ^ (1 / 3)
    return 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
end

-- The wheel: where each name's slice of hue ends, in degrees, scanned in
-- order. Pink wraps round nought, so it opens the list and closes it.
--
-- The boundaries were placed by probing colours either side of each: rose and
-- raspberry sit at 10 degrees and wine red at 21, so pink ends at 15; navy at
-- 277 against violet at 293 puts blue-purple at 284, which is the line Lab
-- could never hold still. Red is held short at 30: pure red sits at 29 and
-- everything past 30 that carries any colour, molten lava at 31, brick masks
-- at 32, flames at 33, rust and salmon at 36, reads as orange on a model. On
-- the namespace so a session can move one and redraw without a reload.
Colours.WHEEL = {
    { 15, "pink" },
    { 30, "red" },
    { 74, "orange" },
    { 113, "yellow" },
    { 165, "green" },
    { 235, "teal" },
    { 284, "blue" },
    { 330, "purple" },
    { 360, "pink" },
}

-- Below this lightness no hue reads at all and everything is black. It sits
-- well under the dark tier sets: a wine red or a night-elf navy keeps its
-- name, and only the genuinely near-black falls in.
local BLACK_L = 0.26

-- Below this chroma there is no colour worth naming and the piece is a
-- neutral, told apart by lightness alone. Set between the true greys, which
-- carry almost none, and the tint Blizzard washes most dark surfaces with.
local NEUTRAL_C = 0.033

-- A neutral is white above one line and black below another, grey between.
-- White may carry a little warmth, since Blizzard's whites are all ivory.
local WHITE_L, WHITE_C = 0.85, 0.055
local DARK_NEUTRAL_L = 0.38

-- Below this chroma a warm colour is dull: too little colour to be the name
-- its hue points at, and named instead for what a player sees on the model.
-- Set between the sepia hoods and dusty leathers Blizzard paints half the
-- game's headgear in, none past 0.08, and the true dark reds: dried blood at
-- 0.10, crimson at 0.13, wine at 0.15.
local DULL_C = 0.09

-- Brown is not on the wheel because brown is not a hue: it is the orange arc
-- gone dull or dark. Dull claims it at any depth; dark claims it too unless
-- the colour is vivid enough to still read as burnt orange, and above the pale
-- line a dull orange is cream and left to the arc.
local BROWN_FROM, BROWN_TO = 30, 95
local BROWN_DARK_L, BROWN_DARK_C = 0.50, 0.13
local BROWN_PALE_L = 0.85

-- A dull colour at red's own hues is never red, and lightness says what it is
-- instead: below the line it is the sepia of a leather hood, which is a brown;
-- above it a rose, which is what pink means. A light red has to carry real
-- colour to be red, and the bar is higher on the pink side than the dull
-- floor: a soft rose at 0.13 of chroma is the lit face of painted pink, while
-- a light red carries 0.18 and up, and that gap is what keeps them apart.
local SEPIA_L = 0.55
local ROSE_C = 0.135

-- Below the sepia line the dull floor also rises with lightness, because what
-- separates a dark red from a shaded brown is colour in proportion to the
-- light on it. An artist's warm shadow sits at red's hue carrying a fraction
-- of the colour its lit paint does, so the shadow half of an orange scarf
-- must not be a red; a dried blood red at the same chroma is darker, carries
-- more colour for its light, and stays red.
local RED_SHADOW = 0.30

-- And a dark yellow is not a yellow: past brown's reach round the wheel it is
-- an olive, which a player looking at a mask's cloth calls green. Yellow is
-- the one name that only exists in the light.
local OLIVE_L = 0.50
local YELLOW_TO = 113

local function chromaOf(a, b)
    return math.sqrt(a * a + b * b)
end

-- The client runs Lua 5.1, where the two argument arctangent is its own
-- function; the test runner is a newer Lua, where it is not.
local arctangent = math.atan2 or math.atan

local function hueOf(a, b)
    return math.deg(arctangent(b, a)) % 360
end

-- The name one colour answers to. Region rules rather than nearest-swatch
-- distance, so every colour is something by construction and the line between
-- two names is a number that can be read, moved and drawn.
function Colours.Name(light, a, b)
    local chroma = chromaOf(a, b)

    if light < BLACK_L then return "black" end
    if light >= WHITE_L and chroma < WHITE_C then return "white" end
    if chroma < NEUTRAL_C then
        return light < DARK_NEUTRAL_L and "black" or "grey"
    end

    local hue = hueOf(a, b)
    if hue >= 15 and hue < BROWN_FROM then
        if light < SEPIA_L then
            if chroma < math.max(DULL_C, RED_SHADOW * light) then return "brown" end
        elseif chroma < ROSE_C then
            return "pink"
        end
    end
    if hue >= BROWN_FROM and hue < BROWN_TO and light < BROWN_PALE_L then
        if chroma < DULL_C then return "brown" end
        if light < BROWN_DARK_L and chroma < BROWN_DARK_C then return "brown" end
    end
    if hue >= BROWN_TO and hue < YELLOW_TO and light < OLIVE_L then return "green" end

    for _, arc in ipairs(Colours.WHEEL) do
        if hue < arc[1] then return arc[2] end
    end
    return "pink"
end

-- How finely a colour's share of a piece is recorded, matching the generator.
local SHARE_STEPS = 16

-- The bundled palette for an appearance, worked out once and kept: each colour
-- in OKLab with the share of the piece it covers. False for an appearance the
-- snapshot has no entry for, which is a piece from a patch newer than the
-- snapshot, or one of the few the art could not be read for.
--
-- Each colour is packed as four hex digits: one per channel, then its share. A
-- channel digit stands for the whole of its sixteenth, so 0 reads back as 0 and
-- f as 255. The eighth of a channel that rounds away is far inside any region,
-- and a share is only ever weighed or compared against a threshold.
local palettes = {}

function Colours.Palette(visualID)
    local known = palettes[visualID]
    if known ~= nil then return known end

    local packed = LuckysWardrobe.AppearanceColours[visualID]
    if not packed then
        palettes[visualID] = false
        return false
    end

    local palette = {}
    for offset = 1, #packed - 3, 4 do
        local red = tonumber(packed:sub(offset, offset), 16) * 17
        local green = tonumber(packed:sub(offset + 1, offset + 1), 16) * 17
        local blue = tonumber(packed:sub(offset + 2, offset + 2), 16) * 17
        local light, a, b = Colours.OKLab(red, green, blue)
        local share = tonumber(packed:sub(offset + 3, offset + 3), 16) / SHARE_STEPS
        palette[#palette + 1] = { light, a, b, share = share }
    end
    palettes[visualID] = palette
    return palette
end

-- What a swatch on the strip asks about: its name, or, for the unmatched
-- swatch, the pieces no name could be read for. The regions do the matching,
-- so a target carries no colours of its own.
function Colours.Target(preset)
    if preset.unmatched then return { unmatched = true } end
    return { key = preset.key }
end

-- What a piece is made of: the swatches its colours are named for with the share
-- of the piece each covers, most of it first. Two colours named for one swatch
-- are that much of the piece between them, a highlight and the shade under it
-- being the same paint twice.
--
-- Worked out once per appearance and kept, because the same pieces are asked
-- about over and over: a redraw asks about the page, and an outfit roll asks
-- about every piece the reel could land on, on every slot, as it spins.
local madeOf = {}

function Colours.MadeOf(visualID)
    local known = madeOf[visualID]
    if known ~= nil then return known end

    local palette = Colours.Palette(visualID)
    if not palette or #palette == 0 then
        madeOf[visualID] = false
        return false
    end

    local shares, made = {}, {}
    for _, colour in ipairs(palette) do
        local key = Colours.Name(colour[1], colour[2], colour[3])
        if not shares[key] then
            shares[key] = { key = key, share = 0 }
            made[#made + 1] = shares[key]
        end
        shares[key].share = shares[key].share + colour.share
    end

    table.sort(made, function(one, two) return one.share > two.share end)
    madeOf[visualID] = made
    return made
end

-- How much of the character a piece paints, from the bundled coverage table:
-- a robe runs to six body sections, a tunic to three, and a piece absent from
-- the table paints one thing, a belt, a weapon, a helm. Guarded because the
-- tests load this file without the data behind it.
function Colours.Coverage(visualID)
    local coverage = LuckysWardrobe.AppearanceCoverage
    return coverage and coverage[visualID] or 1
end

-- Whether a colour covers enough of a piece for the place it comes in. The
-- thresholds are read fresh rather than kept, so moving one and redrawing the
-- page is enough to see what it does.
local function earns(tier, share)
    if tier == 1 then return true end
    if tier == 2 then return share >= Colours.SECONDARY_SHARE end
    if tier == 3 then return share >= Colours.TERTIARY_SHARE end
    return false
end

-- How well an appearance answers to the colour being looked for, smaller being
-- better, or nil for one that is not made of it.
function Colours.Rank(visualID, target)
    local made = Colours.MadeOf(visualID)

    -- The unmatched swatch keeps what could not be read at all: a piece from
    -- a patch newer than the snapshot, or one of the few whose art could not be
    -- read. There is nothing to measure against a swatch that is not a colour,
    -- so every piece it keeps ranks the same.
    if target.unmatched then
        if made then return nil end
        return 0
    end

    if not made then return nil end

    for tier, colour in ipairs(made) do
        -- A colour short of what its place asks takes the ones behind it with
        -- it, they being smaller still.
        if not earns(tier, colour.share) then return nil end

        -- Which of the three it is decides whether the piece is on the page at
        -- all; how much of the colour the piece shows decides where. That is
        -- the share of the piece times how much of the character the piece
        -- paints, so a robe half red sits ahead of a vest that is all red,
        -- there being more red on it, and a trim never leads a page.
        if colour.key == target.key then return -(colour.share * Colours.Coverage(visualID)) end
    end
    return nil
end

function Colours.Matches(visualID, target)
    return Colours.Rank(visualID, target) ~= nil
end

-- There is no live glue below this. The wardrobe hands out visualIDs and the
-- snapshot is keyed by them, so a colour is answered without asking the client
-- anything.
