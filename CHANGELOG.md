# Changelog

## [1.11.5] - 2026-09-08

### Fixed
- The Transmog Outfits bar no longer throws Lua errors when its tiles update the outfit cooldown, which filled the screen as soon as you entered combat. (Thanks for the report Tuulani)

## [1.11.4] - 2026-09-08

### Improved
- **Cooldown on the Transmog Outfits bar** Every tile sweeps with the game's own outfit cooldown, so you can see when the next swap is ready instead of clicking a tile that will not take.

### Fixed
- Right-clicking a Transmog Outfits bar tile to lock it now works for outfits far enough down your list that the game has not drawn a row for them. The first right-click wears the outfit and the second locks it, and the tooltip says so. (Thanks for the report Tuulani)

## [1.11.3] - 2026-09-07

### Improved
- **A countdown on the Transmog Outfits bar** The bar drains a gold line along its foot and fades away five seconds after your cursor leaves it, so wearing an outfit takes the window with it. Putting the cursor back on the bar gives the whole five seconds again. (Thanks for the suggestion Tuulani)

### Fixed
- The Transmog Outfits bar no longer opens in combat, where the game will not let it lay out its tiles, and says so instead.

## [1.11.2] - 2026-09-06

### Fixed
- Show a Preview Model no longer throws Lua errors on tooltips the game will not give a position for, which is what filled the screen while looting. (Thanks for the report Bersky)

## [1.11.1] - 2026-09-05

### Added
- **Transmog Quick-switcher** A keybinding of your own in the Key Bindings screen opens your outfits, the bar or the game's own list depending on your setting. (Thanks for the suggestion Tuulani)

### Improved
- **Locking from the Transmog Outfits bar** Right-click a tile to lock it, so no situation swaps it out, whether the tile is an outfit or the gear you are wearing. (Thanks for the suggestion Tuulani)
- **The outfit you are wearing, named** The Transmog Outfits bar puts its name in the header beside the title, and says No outfit while your own gear is on show. (Thanks for the suggestion Tuulani)

### Fixed
- The addon's keybindings sit under a Lucky's Wardrobe heading in the Key Bindings screen, instead of being filed at the bottom under Other.

## [1.11.0] - 2026-09-04

### Added
- **Your outfits anywhere** Left-click the minimap button, or type `/lw outfits`, to open your outfit list without walking to a transmog NPC. The parts that need an NPC are left off, so what opens is the list itself.
- **Open Outfits as a Bar** A setting swaps that list for a grid of outfit icons you can drag anywhere and click to wear, with a button on it to clear your transmog.
- **Overwrite a saved situation** The Load Situation menu gives each saved situation a save button beside its rename and delete buttons, replacing what it stores with the situations ticked now.

### Improved
- **New icons in the Load Situation menu** The rename and delete buttons beside each saved situation take clearer icons, delete in red.
- **Transmog settings split into sections** The Transmog group in settings now sits under Quality of Life and Situations headings, so a long list of toggles is easier to read down.
