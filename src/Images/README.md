# Images

Screenshots shown in the About rail of the settings panel, plus the icons the
addon draws in the game's own frames.

## Layout and naming

One folder per settings group, named after the group in `Settings.lua`, and
`icons/` for artwork the addon draws itself:

```
Images/
├── icons/
│   └── tracked-appearance.tga
├── tooltips/
│   ├── show-a-preview-model.tga
│   └── show-set-information.tga
└── transmog/
    ├── show-situation-values.tga
    └── show-situation-tooltips.tga
```

Files are `<setting-label>.tga`, kebab-cased.

## Format

- **TGA, 32-bit uncompressed.** WoW does not load PNG at runtime.
- Native screenshot dimensions are fine, no power-of-two padding needed.
- Trim to the feature itself and keep the dark UI backdrop, the About rail behind it is near black.

## Referencing one

Pass the path without the extension, relative to this folder, plus the source pixel size so the aspect ratio is preserved:

```lua
transmog:Toggle({
    image     = "transmog/show-situation-values",
    imageSize = { 571, 222 },
})
```

The panel resolves it against `addonFolder` and `imagesRoot`, both set in `Settings.lua`.

## Icons

Icons are drawn white with a dark outline baked in, so `SetVertexColor` can tint
them without losing the outline that keeps them readable over item art.
Reference one by its full path:

```lua
local CROSSHAIR = "Interface\\AddOns\\Luckys_Wardrobe\\Images\\icons\\tracked-appearance"
```

## Sources

PNG originals live in `images/` at the repo root. They are excluded from release packages and exist so a TGA can be re-exported if the UI changes. `images/make_tracked_icon.py` redraws the tracked-appearance crosshair and writes both files:

```
python images/make_tracked_icon.py
```
