[Join the Discord](https://discord.gg/ptTtYyAjdZ)

# Lucky's Wardrobe

Find the sets you can still finish, hear about it the moment a piece drops, and get more out of Blizzard's collection journal.

Lucky's Wardrobe takes over from Lucky's Better Wardrobe. It is a ground-up rebuild that adds to the collection journal instead of replacing it, so it is much lighter and far less likely to break when a patch lands.

## Features

- **Extra Sets tab**: A third tab in Collections, Appearances listing the armour sets Blizzard defines but never shows in the Sets tab. It lists only what one class could wear, and shares the Sets tab's class selector, so both tabs always show the same class. Search the list, narrow it by expansion or by what you have collected, preview any set on your character, and shift-click to track the pieces you are missing.
  - **One row per set.** Sets listed twice under two names are folded into a single row, and a set that comes in several colourways is one row with a picker in the details pane to switch between them, the same way the Sets tab handles its variants. A folded name still finds the row that holds it.
  - **Sets you can buy.** The sets an ensemble teaches are listed too, close to two thousand of them, and open a set to see which ensemble to go after. Search for "ensemble" to list every set there is one for.
  - **One garment, every colour.** The Trading Post sells the same outfit in eighteen colours as eighteen separate sets. Those come together into one row with the colours behind a picker, so a page of sweatsuits is a single line again.
- **Item tooltips**: Hover an item anywhere in the game and its tooltip names the set the piece belongs to and how far along that set is, as in "From set: Glyphed Garb 7/8". Sets that only appear on the Extra Sets tab are named too, so a world drop nobody would guess was part of anything still says what it belongs to.
- **Wowhead addresses**: Ctrl-click any item in your appearance collection, in the Appearances tab, in a set's details, or in the Extra Sets tab, to bring up its Wowhead address in a box ready to copy.
- **Settings access**: Open the addon settings with `/wardrobe`.

### Collection Journal

- **Sort by completion**: Order the Sets list by how close each one is, ascending to work on the nearest first or descending to see what you have most of. Favourites stay at the top.
- **Filter by expansion and source**: Narrow the list to the expansions you are working through, or to where the sets come from, covering Raid, PvP, Covenants, Heritage, Cosmetic, Trading Post, and Miscellaneous. The count reflects what the filters actually left on screen.
- **Track a whole set, or one piece of it**: Shift-click a set to start tracking every appearance you are still missing from it, or open the set and shift-click one of its pieces to track just that one. Shift-click a piece you are already tracking to call it off.
- **See what you are hunting**: Open a set and the pieces you are tracking carry a crosshair in the corner, in the Sets tab and the Extra Sets tab alike, so a set says what you are still out after. Hover one and its tooltip says so too.

### Set Tracker

- **Finish a set here**: Enter a dungeon or raid and a list opens showing the sets you are close to completing whose missing pieces drop there, closest to done first. Each entry names the pieces still to find and where each one comes from. Click a set to open it in your appearances.
- **Loot alerts**: Loot a piece of a set you are close to finishing, anywhere in the world, and the addon says so with a sound, a chat line, or both. Items the catalyst could turn into an appearance you are missing get a quieter alert of their own.
- **Pieces you already hold the makings of**: A piece you are missing is stamped with a catalyst mark when you are carrying or wearing something the catalyst would turn into it, so a set reads as closer to done than the collected count alone says. Hover the piece to see which item would make it. Requires: Transmog Upgrade Master.
- **Set how close counts**: Choose how incomplete a set can be and still count, so the list and the alerts stay as narrow or as thorough as you like. Sets from the tier you are currently raiding are left out, since you will finish that one by turning up, and you can ask for them back. Other classes' sets can be brought in too, picking out just the alts you collect for.

### Transmog Window

- **Only the sets you can wear**: The Sets tab at the transmog NPC lists a set as soon as one piece of it would fit, and a cloak fits anybody, so it fills up with armour your character cannot wear. Those are hidden, leaving what you could actually dress in. Sets in your own armour type stay whichever class they were built for. Turn it off from the tab's own Filter button, or in settings, to browse the lot again.
- **Extra Sets tab**: A tab beside Sets at the transmog NPC showing the hidden sets your class can wear, drawn as the same preview cards as the Sets tab. Click a set to apply every piece you have collected, shift-click to track what you are missing, and right-click for its Wowhead address. The cards run from closest to complete down to untouched, with search and a collected filter to narrow them.
- **Set names on the cards**: Every set card at the transmog NPC carries its name across the top, on the Sets, Custom Sets and Extra Sets tabs alike, so you can tell one little model from another without hovering each in turn. A set you have not finished is named in the same colour its border carries. Turn the names off from the filter menu on either sets tab, or from settings.
- **Random outfit**: Hold the dice button to spin every armour slot through appearances you own, then let go and watch it settle. Weapons are left alone, and nothing is bought until you press Apply.
- **Situation presets**: Save the situations you have picked for an outfit under a name, then apply the whole lot to another outfit in one click. Delete them from the same menu.
- **Situation detail on outfits**: Show the values you have chosen on each outfit in the list, and hover an outfit for a tooltip with its full situation breakdown.
- **Keep your active tab**: Switching outfits at the transmog NPC no longer throws you back to Items. Clicking a slot still opens Items.

## Installation

Extract the release zip into `World of Warcraft/_retail_/Interface/AddOns/`.

Lucky's Utils is required. Release packages include it automatically.

Lucky's Wardrobe changes the same collection and transmog windows that Better Wardrobe and Lucky's Better Wardrobe do, so they cannot run alongside it. If one of them is still enabled you get a dialog at login offering to turn either it or Lucky's Wardrobe off, whichever you would rather keep, and reloading for you.

Lucky's Better Wardrobe is the addon Lucky's Wardrobe replaced, and the update leaves its old folder behind. Delete `Interface/AddOns/LuckysBetterWardrobe` to be rid of it for good.

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
| `/wardrobe welcome` | Show the welcome note again, with the Discord address |
| `/wardrobe welcome reset` | Owe the welcome note again, so it arrives at the next login |
| `/wardrobe replay` | Reopen the set list as if you had just walked in, for checking your settings |
| `/wardrobe scan` | Report what the addon can see about the instance you are in, for troubleshooting |
| `/wardrobe extrasets` | Report how many extra sets this client can show, and how many were left out and why |
| `/wardrobe extrasets full` | List the extra sets and the ones left out, with the reason for each |
| `/wardrobe extrasets find <name>` | Look one set up by name: listed, left out and why, or already in the Sets tab |
| `/wardrobe extrasets looks <name>` | Compare the looks behind a set with the ones the Sets tab holds, for checking why a set was folded away |
| `/wardrobe extrasets pieces` | Report the set selected in the Extra Sets tab piece by piece, for working out why it reads as unwearable |
| `/wardrobe extrasets perf` | Report how long the tab's work takes and how it lands on your frame rate |
| `/wardrobe extrasets perf reset` | Clear those measurements and start again |
| `/wardrobe recolors` | Report how many recolor families this client's appearances form |
| `/wardrobe recolors dump` | Save the whole family report to saved variables for reading after a reload |
| `/wardrobe recolors full` | List every family, its pieces, and every cluster left out |
| `/wardrobe recolors probe` | Report how many appearances in each slot the client can name yet, for when a report comes back short |

A keybinding for the set list is available under **Sets You Can Finish Here** in the game's Key Bindings screen.

## Minimap Button

Shift-click the minimap button for the sets you can finish where you are standing, or right-click it for settings. Drag it to reposition it.

## Settings

Open settings with `/wardrobe` or **Options > AddOns > Lucky's Wardrobe**.

- **General**: Turn on dev mode for troubleshooting, and see version info.
- **Appearances**: Turn shift-click tracking on or off, choose whether tracked pieces carry a crosshair, and turn ctrl-click Wowhead addresses on or off.
- **Tooltips**: Choose whether an item's tooltip names the set the piece belongs to and your progress through it.
- **Transmog**: Hide the sets your character cannot wear from the Sets tab, keep your active tab at the transmog NPC when switching outfits, choose whether set cards carry their names, and choose how much situation detail appears on saved outfits.
- **Set Tracker**: Choose how many pieces a set can still be missing and count as close to done, whether to include the tier you are currently raiding and other classes' sets, and whether missing pieces carry the catalyst mark. Set whether the list opens by itself in a dungeon or raid and how long it holds the middle of the screen, and whether looting a piece alerts you with a sound, a chat line, or both.

## Roadmap

- More of Better Wardrobe's collection journal and transmog vendor features, rebuilt on the lighter foundation.

## A note on AI

My addons are made by one person who plays the game and wants them to work properly. I use AI tools to move faster, mostly on code, bug hunting, and docs, but every change is reviewed and tested in game before release. If a feature feels off or something breaks, that's mine to fix, and the Discord is the fastest way to reach me.

## Author

Lucky Phil
