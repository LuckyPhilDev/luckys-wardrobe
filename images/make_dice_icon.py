"""Draws the pair of dice on the randomiser's buttons.

Writes the PNG original next to this script and the TGA the addon loads into
src/Images/icons/. Run from the repo root:

    python images/make_dice_icon.py

The shape is Lucide's `dices`, traced from its path data: one die face on,
one tilted behind it with two rounded corners in view, and four pips struck
as the round caps of zero-length strokes. Drawn white with the same baked
outline as the padlocks, so the addon tints it without losing the edge.
"""

import math
from pathlib import Path

from make_lock_icons import (
    BODY,
    EDGE,
    OUTLINE,
    SAMPLES,
    SIZE,
    STROKE,
    VIEWBOX,
    rounded_rect_distance,
    segment_distance,
    to_units,
    write_png,
    write_tga,
)

# Straight from the path definitions: the face-on die, then the tilted one as
# the corners its outline passes through, ends of straights and arcs in turn.
FACE = (2.0, 10.0, 14.0, 22.0, 2.0)
TILTED = [(17.92, 14.0), (21.42, 10.5), (21.42, 7.5), (16.42, 2.58), (13.42, 2.58), (10.0, 6.0)]
CORNER_RADIUS = 2.24
PIPS = ((6.0, 18.0), (10.0, 14.0), (15.0, 6.0), (18.0, 9.0))

# Roughly the tilted die's middle. Each corner arc bows away from it, which is
# what picks the right centre of the two that fit a chord.
TILTED_MIDDLE = (16.8, 7.2)


def arc_centre(a, b, radius):
    (ax, ay), (bx, by) = a, b
    half_chord = math.hypot(bx - ax, by - ay) / 2.0
    offset = math.sqrt(max(radius * radius - half_chord * half_chord, 0.0))
    nx, ny = (by - ay) / (2.0 * half_chord), -(bx - ax) / (2.0 * half_chord)

    mx, my = (ax + bx) / 2.0, (ay + by) / 2.0
    one = (mx + offset * nx, my + offset * ny)
    two = (mx - offset * nx, my - offset * ny)
    if math.hypot(one[0] - TILTED_MIDDLE[0], one[1] - TILTED_MIDDLE[1]) \
            < math.hypot(two[0] - TILTED_MIDDLE[0], two[1] - TILTED_MIDDLE[1]):
        return one
    return two


def minor_arc_distance(px, py, cx, cy, radius, ends):
    """Distance to the shorter arc between the ends, capped at the ends."""
    (ax, ay), (bx, by) = ends
    mx, my = (ax + bx) / 2.0 - cx, (ay + by) / 2.0 - cy
    length = math.hypot(mx, my)
    ux, uy = mx / length, my / length
    half = math.acos(max(-1.0, min(1.0, (ux * (ax - cx) + uy * (ay - cy)) / radius)))

    dx, dy = px - cx, py - cy
    reach = math.hypot(dx, dy)
    if reach > 0.0:
        swept = math.acos(max(-1.0, min(1.0, (dx * ux + dy * uy) / reach)))
        if swept <= half:
            return abs(reach - radius)
    return min(math.hypot(px - ex, py - ey) for ex, ey in ends)


def shape_distance(px, py):
    nearest = abs(rounded_rect_distance(px, py, *FACE))

    for start in (0, 2, 4):
        a, b = TILTED[start], TILTED[start + 1]
        nearest = min(nearest, segment_distance(px, py, *a, *b))
    for start in (1, 3):
        a, b = TILTED[start], TILTED[start + 1]
        cx, cy = arc_centre(a, b, CORNER_RADIUS)
        nearest = min(nearest, minor_arc_distance(px, py, cx, cy, CORNER_RADIUS, (a, b)))

    for pip_x, pip_y in PIPS:
        nearest = min(nearest, math.hypot(px - pip_x, py - pip_y))

    return nearest - STROKE / 2.0


def pixel(x, y):
    red = green = blue = alpha = 0.0
    step = 1.0 / SAMPLES
    scale = SIZE / VIEWBOX
    for sy in range(SAMPLES):
        for sx in range(SAMPLES):
            units = shape_distance(
                to_units(x + (sx + 0.5) * step - 0.5),
                to_units(y + (sy + 0.5) * step - 0.5),
            )
            distance = units * scale
            if distance <= 0.0:
                sample = BODY
            elif distance <= OUTLINE:
                sample = EDGE
            else:
                continue
            red += sample[0]
            green += sample[1]
            blue += sample[2]
            alpha += 1.0

    if alpha == 0.0:
        return (0, 0, 0, 0)

    total = SAMPLES * SAMPLES
    return (
        round(red / alpha),
        round(green / alpha),
        round(blue / alpha),
        round(255 * alpha / total),
    )


def main():
    root = Path(__file__).resolve().parent.parent
    icons = root / "src" / "Images" / "icons"
    icons.mkdir(parents=True, exist_ok=True)

    rows = [[pixel(x, y) for x in range(SIZE)] for y in range(SIZE)]
    write_png(root / "images" / "dice.png", rows)
    tga = icons / "dice.tga"
    write_tga(tga, rows)
    print(f"wrote {tga}")


if __name__ == "__main__":
    main()
