"""Draws the crosshair stamped on tracked appearances.

Writes the PNG original next to this script and the TGA the addon loads into
src/Images/icons/. Run from the repo root:

    python images/make_tracked_icon.py

The shape is drawn white with a near-black outline baked in, so the addon can
tint it any colour without losing the outline that keeps it readable against a
bright model.
"""

import math
import struct
import zlib
from pathlib import Path

SIZE = 64
SAMPLES = 4

RING_RADIUS = 17.0
RING_STROKE = 4.5
TICK_INNER = 20.0
TICK_OUTER = 29.5
TICK_WIDTH = 4.5
DOT_RADIUS = 2.6
OUTLINE = 1.6

BODY = (255, 255, 255)
EDGE = (18, 14, 10)

CENTRE = (SIZE - 1) / 2.0


def bar_distance(along, across, inner, outer, width):
    """Signed distance to a bar running from inner to outer along one axis."""
    length_gap = max(inner - along, along - outer)
    width_gap = abs(across) - width / 2.0
    outside = math.hypot(max(length_gap, 0.0), max(width_gap, 0.0))
    return outside + min(max(length_gap, width_gap), 0.0)


def shape_distance(x, y):
    dx, dy = x - CENTRE, y - CENTRE
    radius = math.hypot(dx, dy)

    ring = abs(radius - RING_RADIUS) - RING_STROKE / 2.0
    dot = radius - DOT_RADIUS
    ticks = min(
        bar_distance(dx, dy, TICK_INNER, TICK_OUTER, TICK_WIDTH),
        bar_distance(-dx, dy, TICK_INNER, TICK_OUTER, TICK_WIDTH),
        bar_distance(dy, dx, TICK_INNER, TICK_OUTER, TICK_WIDTH),
        bar_distance(-dy, dx, TICK_INNER, TICK_OUTER, TICK_WIDTH),
    )

    return min(ring, dot, ticks)


def pixel(x, y):
    red = green = blue = alpha = 0.0
    step = 1.0 / SAMPLES
    for sy in range(SAMPLES):
        for sx in range(SAMPLES):
            distance = shape_distance(x + (sx + 0.5) * step - 0.5, y + (sy + 0.5) * step - 0.5)
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


def render():
    return [[pixel(x, y) for x in range(SIZE)] for y in range(SIZE)]


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
    rows = render()
    write_png(root / "images" / "tracked-appearance.png", rows)
    tga = root / "src" / "Images" / "icons" / "tracked-appearance.tga"
    tga.parent.mkdir(parents=True, exist_ok=True)
    write_tga(tga, rows)
    print(f"wrote {tga}")


if __name__ == "__main__":
    main()
