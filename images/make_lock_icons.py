"""Draws the padlock the randomiser puts beside a transmog slot, open and shut.

Writes the PNG originals next to this script and the TGAs the addon loads into
src/Images/icons/. Run from the repo root:

    python images/make_lock_icons.py

The shapes are Lucide's `lock` and `lock-open`, traced from their path data: a
rounded rectangle body with a shackle over it, struck in a 24 unit box. Both are
drawn white with a near-black outline baked in, so the addon can tint them
without losing the outline that keeps them readable over item art.
"""

import math
import struct
import zlib
from pathlib import Path

SIZE = 64
SAMPLES = 4
VIEWBOX = 24.0

# Straight from the two path definitions.
BODY_LEFT, BODY_TOP, BODY_RIGHT, BODY_BOTTOM = 3.0, 11.0, 21.0, 22.0
BODY_CORNER = 2.0
STROKE = 2.0
SHACKLE_RADIUS = 5.0
SHACKLE_FOOT = (7.0, 11.0)
SHACKLE_RISE = (7.0, 7.0)
SHUT_END = (17.0, 7.0)
SHUT_FOOT = (17.0, 11.0)
OPEN_END = (16.9, 6.0)

OUTLINE = 1.6

BODY = (255, 255, 255)
EDGE = (18, 14, 10)


def to_units(value):
    """A pixel coordinate in the 24 unit box the paths are drawn in."""
    return (value + 0.5) * VIEWBOX / SIZE


def segment_distance(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    length_squared = vx * vx + vy * vy
    along = 0.0 if length_squared == 0.0 else (wx * vx + wy * vy) / length_squared
    along = max(0.0, min(1.0, along))
    return math.hypot(wx - along * vx, wy - along * vy)


def rounded_rect_distance(px, py, left, top, right, bottom, corner):
    cx, cy = (left + right) / 2.0, (top + bottom) / 2.0
    hx = (right - left) / 2.0 - corner
    hy = (bottom - top) / 2.0 - corner
    dx, dy = abs(px - cx) - hx, abs(py - cy) - hy
    return math.hypot(max(dx, 0.0), max(dy, 0.0)) + min(max(dx, dy), 0.0) - corner


def arc_centre(ax, ay, bx, by, radius):
    """The centre of the circle of this radius through both ends of the shackle.

    Of the two that fit, this takes the one below the chord, which is the one that
    sends the arc up over the top the way both paths draw it.
    """
    half_chord = math.hypot(bx - ax, by - ay) / 2.0
    offset = math.sqrt(max(radius * radius - half_chord * half_chord, 0.0))

    nx, ny = (by - ay) / (2.0 * half_chord), -(bx - ax) / (2.0 * half_chord)
    if ny < 0.0:
        nx, ny = -nx, -ny

    return (ax + bx) / 2.0 + offset * nx, (ay + by) / 2.0 + offset * ny


def arc_distance(px, py, cx, cy, radius, ends):
    """Distance to the arc, with the ends rounded off the way the paths cap them.

    Angles are read with y running up, so both shackles cover a range either side
    of straight up and neither wraps past zero. Sorting the two ends is enough to
    bound it.
    """
    low, high = sorted(math.atan2(cy - ey, ex - cx) % (2.0 * math.pi) for ex, ey in ends)

    angle = math.atan2(cy - py, px - cx) % (2.0 * math.pi)
    if low <= angle <= high:
        return abs(math.hypot(px - cx, py - cy) - radius)

    return min(math.hypot(px - ex, py - ey) for ex, ey in ends)


def shape_distance(px, py, shut):
    body = abs(
        rounded_rect_distance(px, py, BODY_LEFT, BODY_TOP, BODY_RIGHT, BODY_BOTTOM, BODY_CORNER)
    )

    end = SHUT_END if shut else OPEN_END
    cx, cy = arc_centre(*SHACKLE_RISE, *end, SHACKLE_RADIUS)
    shackle = min(
        segment_distance(px, py, *SHACKLE_FOOT, *SHACKLE_RISE),
        arc_distance(px, py, cx, cy, SHACKLE_RADIUS, (SHACKLE_RISE, end)),
    )
    if shut:
        shackle = min(shackle, segment_distance(px, py, *SHUT_END, *SHUT_FOOT))

    return min(body, shackle) - STROKE / 2.0


def pixel(x, y, shut):
    red = green = blue = alpha = 0.0
    step = 1.0 / SAMPLES
    scale = SIZE / VIEWBOX
    for sy in range(SAMPLES):
        for sx in range(SAMPLES):
            units = shape_distance(
                to_units(x + (sx + 0.5) * step - 0.5),
                to_units(y + (sy + 0.5) * step - 0.5),
                shut,
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


def render(shut):
    return [[pixel(x, y, shut) for x in range(SIZE)] for y in range(SIZE)]


def write_png(path, rows):
    raw = b"".join(b"\x00" + bytes(channel for pixel in row for channel in pixel) for row in rows)

    def chunk(tag, payload):
        body = tag + payload
        return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body))

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def write_tga(path, rows):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    body = bytearray()
    for row in reversed(rows):  # TGA stores the bottom row first.
        for red, green, blue, alpha in row:
            body += bytes((blue, green, red, alpha))
    path.write_bytes(header + bytes(body))


def main():
    root = Path(__file__).resolve().parent.parent
    icons = root / "src" / "Images" / "icons"
    icons.mkdir(parents=True, exist_ok=True)

    for name, shut in (("lock", True), ("lock-open", False)):
        rows = render(shut)
        write_png(root / "images" / f"{name}.png", rows)
        tga = icons / f"{name}.tga"
        write_tga(tga, rows)
        print(f"wrote {tga}")


if __name__ == "__main__":
    main()
