"""Draws the edit and delete icons on the Load Situation menu.

Writes the PNG originals next to this script and the TGAs the addon loads into
src/Images/icons/. Run from the repo root:

    python images/make_menu_icons.py

The shapes are Lucide's `square-pen` and `trash`, traced from their path data
and stroked white so the addon can tint them.
"""

from pathlib import Path

from make_situation_icons import render, trace, write_png, write_tga

# The pen's back cap asks for a radius smaller than the span it spans, so SVG
# grows it to half the chord before drawing. Traced at the grown radius.
PEN_CAP = 2.1213

SQUARE_PEN = [
    trace((12, 3), (5, 3), ((3, 5), 2, 0), (3, 19), ((5, 21), 2, 0),
          (19, 21), ((21, 19), 2, 0), (21, 12)),
    trace((18.375, 2.625), ((21.375, 5.625), PEN_CAP, 1), (12.362, 14.639),
          ((11.509, 15.144), 2, 1), (8.636, 15.984), ((8.016, 15.364), 0.5, 1),
          (8.856, 12.491), ((9.362, 11.639), 2, 1), (18.375, 2.625)),
]

TRASH = [
    trace((10, 11), (10, 17)),
    trace((14, 11), (14, 17)),
    trace((19, 6), (19, 20), ((17, 22), 2, 1), (7, 22), ((5, 20), 2, 1), (5, 6)),
    trace((3, 6), (21, 6)),
    trace((8, 6), (8, 4), ((10, 2), 2, 1), (14, 2), ((16, 4), 2, 1), (16, 6)),
]


def main():
    root = Path(__file__).resolve().parent.parent
    icons = root / "src" / "Images" / "icons"
    icons.mkdir(parents=True, exist_ok=True)

    for name, icon in (("edit", SQUARE_PEN), ("delete", TRASH)):
        rows = render(icon)
        write_png(root / "images" / f"{name}.png", rows)
        write_tga(icons / f"{name}.tga", rows)
        print(f"wrote {icons / f'{name}.tga'}")


if __name__ == "__main__":
    main()
