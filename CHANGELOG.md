# Changelog

## [Unreleased]

### Added
- **Tier token needs alongside AllTheThings** A new setting under Who Still Needs a Tier Token keeps that list on a tier token's tooltip even when AllTheThings is loaded, for anyone who wants both. It is off by default. (Thanks for the suggestion 2B, or not 2B)

## [1.13.1] - 2026-10-20

### Fixed
- The character models in the Class Sets window no longer disappear while the dressing room is open. (Thanks for the report 2B, or not 2B)

## [1.13.0] - 2026-10-20

### Added
- **Class Sets in the Adventure Guide** A new button on a raid's page in the Adventure Guide opens every class's set from that raid side by side, each on a model with the pieces you have ticked off and your alts of that class named, so you can see at a glance which alt to send a tier token to. Hover a piece to see which boss drops it, or the token it is made from, shift-click a missing piece to track it, and click a set to try it on in the dressing room. (Thanks for the suggestion 2B, or not 2B)
- **Who Still Needs a Tier Token** A raid tier token's tooltip lists the classes it serves that are still missing the piece it makes, at the token's own difficulty, with your alts of each class beside them. It covers every raid's tokens from Ahn'Qiraj to today, and stays out of the way when All The Things is loaded, since it shows the same.
- **Track pieces from Finish a Set Here** A piece you are tracking carries the tracking crosshair in the Finish a Set Here list, the same as in the Sets tab, so you can see at a glance which of the sets around you hold something you are after. Shift-click a missing piece there to track it or stop tracking it.

### Fixed
- Clicking a set in the Finish a Set Here list during combat no longer causes an error. It now says the collection cannot be opened until the fight is over.
- The Finish a Set Here list in an older raid no longer shows the same set twice, once for this difficulty and once for another. Only the version you can earn on this run is listed.
- The Finish a Set Here list now sits under the world map instead of covering it.

## [1.12.2] - 2026-10-13

### Improved
- **Patch 12.1.5** Updated for the new game patch, so the addon loads without being flagged out of date.

## [1.12.1] - 2026-10-07

### Added
- **More from Lucky Phil** The row at the bottom of the What's New page now includes Lucky's Actionbars and Lucky's Loadouts, with a CurseForge link for each.

## [1.12.0] - 2026-10-05

### Added
- **Outfit Announcements** Whenever your outfit changes, a chat line names the one you are now wearing and the situations it is set for, such as Frost, so a swap a situation made for you is never a mystery.

### Fixed
- Fixed an error with the settings panel.

## [1.11.8] - 2026-09-28

### Fixed
- Choosing a class on the Extra Sets tab after visiting the Items tab no longer throws a Lua error, and now changes the class the sets are listed for.

## [1.11.7] - 2026-09-18

### Added
- **Hide My Gear** A checkbox in the dressing room takes off your own gear and leaves only the items you have previewed, so your shoulders, helm or tabard no longer cover a set that leaves those slots empty. (Thanks for the suggestion Erika)

## [1.11.6] - 2026-09-18

### Improved
- **EllesmereUI - Matching Extra Sets and Custom tabs** The Extra Sets and Custom tabs in the Appearances window, and the pages behind them, take EllesmereUI's skin like the rest of the window. (Thanks for the suggestion Rubyurek)

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
