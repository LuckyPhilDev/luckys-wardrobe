[Join the Discord](https://discord.gg/87HRHcAYP)

# Lucky's Wardrobe

Find the sets you can still finish, hear about it the moment a piece drops, and get more out of Blizzard's collection journal.

Lucky's Wardrobe takes over from Lucky's Better Wardrobe. It is a ground-up rebuild that adds to the collection journal instead of replacing it, so it is much lighter and far less likely to break when a patch lands.

## Features

- **Extra Sets tab**: A third tab in Collections, Appearances listing the armour sets Blizzard defines but never shows in the Sets tab. It lists only what one class could wear, and shares the Sets tab's class selector, so both tabs always show the same class. Search the list, narrow it by expansion or by what you have collected, preview any set on your character, and shift-click to track the pieces you are missing.
  - **One row per set.** Sets listed twice under two names are folded into a single row, and a set that comes in several colourways is one row with a picker in the details pane to switch between them, the same way the Sets tab handles its variants. A folded name still finds the row that holds it.
- **Wowhead addresses**: Ctrl-click any item in your appearance collection, in the Appearances tab, in a set's details, or in the Extra Sets tab, to bring up its Wowhead address in a box ready to copy.
- **Settings access**: Open the addon settings with `/wardrobe`.

### Collection Journal

- **Sort by completion**: Order the Sets list by how close each one is, ascending to work on the nearest first or descending to see what you have most of. Favourites stay at the top.
- **Filter by expansion and source**: Narrow the list to the expansions you are working through, or to where the sets come from, covering Raid, PvP, Covenants, Heritage, Cosmetic, Trading Post, and Miscellaneous. The count reflects what the filters actually left on screen.
- **Track a whole set**: Shift-click a set to start tracking every appearance you are still missing from it, the way shift-clicking an item on the Items tab tracks that one.

### Set Tracker

- **Finish a set here**: Enter a dungeon or raid and a list opens showing the sets you are close to completing whose missing pieces drop there, closest to done first. Each entry names the pieces still to find and where each one comes from. Click a set to open it in your appearances.
- **Loot alerts**: Loot a piece of a set you are close to finishing, anywhere in the world, and the addon says so with a sound, a chat line, or both. Items the catalyst could turn into an appearance you are missing get a quieter alert of their own.
- **Pieces you already hold the makings of**: A piece you are missing is stamped with a catalyst mark when you are carrying or wearing something the catalyst would turn into it, so a set reads as closer to done than the collected count alone says. Hover the piece to see which item would make it. Requires: Transmog Upgrade Master.
- **Set how close counts**: Choose how incomplete a set can be and still count, so the list and the alerts stay as narrow or as thorough as you like. Sets from the tier you are currently raiding are left out, since you will finish that one by turning up, and you can ask for them back. Other classes' sets can be brought in too, picking out just the alts you collect for.

### Transmog Window

- **Extra Sets tab**: A tab beside Sets at the transmog NPC showing the hidden sets your class can wear, drawn as the same preview cards as the Sets tab. Click a set to apply every piece you have collected, shift-click to track what you are missing, and right-click for its Wowhead address. The cards run from closest to complete down to untouched, with search and a collected filter to narrow them.
- **Random outfit**: Hold the dice button to spin every armour slot through appearances you own, then let go and watch it settle. Weapons are left alone, and nothing is bought until you press Apply.
- **Situation presets**: Save the situations you have picked for an outfit under a name, then apply the whole lot to another outfit in one click. Delete them from the same menu.
- **Situation detail on outfits**: Show the values you have chosen on each outfit in the list, and hover an outfit for a tooltip with its full situation breakdown.
- **Keep your active tab**: Switching outfits at the transmog NPC no longer throws you back to Items. Clicking a slot still opens Items.

## Installation

Extract the release zip into `World of Warcraft/_retail_/Interface/AddOns/`.

Lucky's Utils is required. Release packages include it automatically.

Lucky's Wardrobe changes the same collection and transmog windows that Better Wardrobe does, so the two cannot run together. Turn Better Wardrobe off in the AddOns list. If you were running Lucky's Better Wardrobe, delete its `LuckysBetterWardrobe` folder, since the update to Lucky's Wardrobe leaves the old one behind.

## Usage

1. Open the **Collections Journal** (Shift+P) and go to **Appearances > Sets**.
2. Use **Filter** to sort by completion and narrow the list by expansion or source.
3. Shift-click a set to track every appearance you are still missing from it.
4. Walk into a dungeon or raid and the set list opens with what you can finish there.
5. Adjust everything via `/wardrobe` or **Options > AddOns > Lucky's Wardrobe**.

## Slash Commands

| Command | Action |
|---|---|
| `/wardrobe` | Open addon settings |
| `/lw` | Short form of `/wardrobe` |
| `/wardrobe sets` | Show the sets you can finish where you are standing |
| `/wardrobe replay` | Reopen the set list as if you had just walked in, for checking your settings |
| `/wardrobe scan` | Report what the addon can see about the instance you are in, for troubleshooting |
| `/wardrobe extrasets` | Report how many extra sets this client can show, and how many were left out and why |
| `/wardrobe extrasets full` | List the extra sets and the ones left out, with the reason for each |
| `/wardrobe extrasets find <name>` | Look one set up by name: listed, left out and why, or already in the Sets tab |
| `/wardrobe extrasets perf` | Report how long the tab's work takes and how it lands on your frame rate |
| `/wardrobe extrasets perf reset` | Clear those measurements and start again |
| `/wardrobe recolors` | Report how many recolor families this client's appearances form |
| `/wardrobe recolors dump` | Save the whole family report to saved variables for reading after a reload |
| `/wardrobe recolors full` | List every family, its pieces, and every cluster left out |

A keybinding for the set list is available under **Sets You Can Finish Here** in the game's Key Bindings screen.

## Minimap Button

Shift-click the minimap button for the sets you can finish where you are standing, or right-click it for settings. Drag it to reposition it.

## Settings

Open settings with `/wardrobe` or **Options > AddOns > Lucky's Wardrobe**.

- **General**: Turn on dev mode for troubleshooting, and see version info.
- **Appearances**: Turn shift-click set tracking on or off.
- **Transmog**: Keep your active tab at the transmog NPC when switching outfits, and choose how much situation detail appears on saved outfits.
- **Set Tracker**: Choose how many pieces a set can still be missing and count as close to done, whether to include the tier you are currently raiding and other classes' sets, and whether missing pieces carry the catalyst mark. Set whether the list opens by itself in a dungeon or raid and how long it holds the middle of the screen, and whether looting a piece alerts you with a sound, a chat line, or both.

## Roadmap

- More of Better Wardrobe's collection journal and transmog vendor features, rebuilt on the lighter foundation.

## A note on AI

My addons are made by one person who plays the game and wants them to work properly. I use AI tools to move faster, mostly on code, bug hunting, and docs, but every change is reviewed and tested in game before release. If a feature feels off or something breaks, that's mine to fix, and the Discord is the fastest way to reach me.

## Author

Lucky Phil
