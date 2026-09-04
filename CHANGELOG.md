# Changelog

## [Unreleased]

### Added
- **Your outfits anywhere** Left-click the minimap button, or type `/lw outfits`, to open your outfit list without walking to a transmog NPC. The parts that need an NPC are left off, so what opens is the list itself.
- **Open Outfits as a Bar** A setting swaps that list for a grid of outfit icons you can drag anywhere and click to wear, with a button on it to clear your transmog.

## [1.10.4] - 2026-09-03

### Improved
- **Addon conflict warning** If another addon hides the warning about a conflicting wardrobe addon, the warning repeats in chat, and `/lw conflicts` brings the dialog back so you can choose which to disable.

## [1.10.3] - 2026-09-01

### Improved
- **Under the hood** A tidy-up of the addon's internals. Nothing changes in how it looks or plays.

## [1.10.2] - 2026-08-25

### Fixed
- The preview screenshot in settings goes away when you move off its row, instead of staying on screen until you reach a setting that has none. (Thanks for the report Tuulani)
- Set names on the Set Completion panel, and the labels at the transmogrifier, show on a Russian client instead of empty boxes. (Thanks for the report Grelle)

## [1.10.1] - 2026-08-20

### Improved
- **Under the hood** A tidy-up of the addon's internals. Nothing changes in how it looks or plays.

## [1.10.0] - 2026-08-18

### Added
- **Colourway tooltip** On the Sets and Extra Sets tabs, hovering the count in the corner of a set row names every colourway the set comes in, with how much of each you have collected. (Thanks for the report Adelie)

### Improved
- **Under the hood** A tidy-up of the addon's internals. Nothing changes in how it looks or plays.
- **Lucky's Utils bundled** The shared library now ships inside the addon, so there is no separate download from CurseForge. If you have the standalone Lucky's Utils installed, you can remove it as long as no other Lucky addon still needs it.

### Fixed
- The colourway count in the corner of a set row on the Sets tab was one short, and a set with only two colourways showed no count at all. (Thanks for the report Adelie)
