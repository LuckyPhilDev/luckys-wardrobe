"""Draws the save and load icons on the Situations panel.

Writes the PNG originals next to this script and the TGAs the addon loads into
src/Images/icons/. Run from the repo root:

    python images/make_situation_icons.py

The shapes are the Lucide "save" and "download" outlines, traced in their own
24x24 space and stroked white so the addon can tint them.
"""

import math
import struct
import zlib
from pathlib import Path

SIZE = 64
SAMPLES = 4
VIEWBOX = 24.0
STROKE = 2.0
SCALE = SIZE / VIEWBOX


def arc_points(start, end, radius, sweep, steps=8):
    """Points along a circular arc, the SVG way: two endpoints and a radius."""
    (x0, y0), (x1, y1) = start, end
    dx, dy = x1 - x0, y1 - y0
    chord = math.hypot(dx, dy)
    offset = math.sqrt(max(radius * radius - (chord / 2) ** 2, 0.0)) / chord
    direction = 1 if sweep else -1
    cx = (x0 + x1) / 2 - direction * dy * offset
    cy = (y0 + y1) / 2 + direction * dx * offset

    first = math.atan2(y0 - cy, x0 - cx)
    last = math.atan2(y1 - cy, x1 - cx)
    if sweep and last < first:
        last += 2 * math.pi
    if not sweep and last > first:
        last -= 2 * math.pi

    return [
        (cx + radius * math.cos(angle), cy + radius * math.sin(angle))
        for angle in (first + (last - first) * step / steps for step in range(1, steps + 1))
    ]


def trace(*steps):
    """A polyline from a start point, then either (x, y) corners or (end, radius, sweep) arcs."""
    points = [steps[0]]
    for step in steps[1:]:
        if len(step) == 2:
            points.append(step)
        else:
            points.extend(arc_points(points[-1], *step))
    return points


SAVE = [
    trace((15.2, 3), ((16.6, 3.6), 2, 1), (20.4, 7.4), ((21, 8.8), 2, 1),
          (21, 19), ((19, 21), 2, 1), (5, 21), ((3, 19), 2, 1),
          (3, 5), ((5, 3), 2, 1), (15.2, 3)),
    trace((17, 21), (17, 14), ((16, 13), 1, 0), (8, 13), ((7, 14), 1, 0), (7, 21)),
    trace((7, 3), (7, 7), ((8, 8), 1, 0), (15, 8)),
]

LOAD = [
    trace((12, 15), (12, 3)),
    trace((21, 15), (21, 19), ((19, 21), 2, 1), (5, 21), ((3, 19), 2, 1), (3, 15)),
    trace((7, 10), (12, 15), (17, 10)),
]


def segment_distance(x, y, start, end):
    (ax, ay), (bx, by) = start, end
    dx, dy = bx - ax, by - ay
    span = dx * dx + dy * dy
    along = 0.0 if span == 0 else max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / span))
    return math.hypot(x - ax - along * dx, y - ay - along * dy)


def covered(icon, x, y):
    return any(
        segment_distance(x, y, start, end) <= STROKE / 2
        for line in icon
        for start, end in zip(line, line[1:])
    )


def pixel(icon, x, y):
    step = 1.0 / SAMPLES
    hits = sum(
        covered(icon, (x + (sx + 0.5) * step) / SCALE, (y + (sy + 0.5) * step) / SCALE)
        for sy in range(SAMPLES)
        for sx in range(SAMPLES)
    )
    return (255, 255, 255, round(255 * hits / SAMPLES ** 2))


def render(icon):
    return [[pixel(icon, x, y) for x in range(SIZE)] for y in range(SIZE)]


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

    for name, icon in (("save-situation", SAVE), ("load-situation", LOAD)):
        rows = render(icon)
        write_png(root / "images" / f"{name}.png", rows)
        write_tga(icons / f"{name}.tga", rows)
        print(f"wrote {icons / f'{name}.tga'}")


if __name__ == "__main__":
    main()
