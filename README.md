# Lucky's Wardrobe

Find the sets you can still finish, and hear about it the moment a piece drops.

[Join the Discord](https://discord.gg/ptTtYyAjdZ)

## At a Glance

- Two new tabs in Appearances: the sets Blizzard hides, and the outfits you saved at the transmogrifier.
- Walk into a dungeon and a list says which sets you could finish there, closest to done first.
- Filter the transmog window by colour, by expansion, and down to what your class can actually wear.
- It adds to the collection journal instead of replacing it, so it stays light and is far less likely to break when a patch lands.

## Features

### Collection Journal

- **Extra Sets tab** A third tab in Appearances holding the armour sets Blizzard defines but never shows, filtered to one class and sharing the Sets tab's class selector.
  - Sets listed twice, or sold in eighteen Trading Post colours, fold into one row with a colourway picker. The corner says how many it holds.
  - The sets an ensemble teaches are listed too, close to two thousand of them. Search "ensemble" to see the lot.
  - Sort by name, completion, piece count or number of colours, and narrow by expansion or by what you have collected.
- **Custom Sets tab** A fourth tab listing the outfits you saved at the transmogrifier, so you can look through them without standing at one.
- **Colourways counted on the Sets tab** A tier's count, name colour and progress bar now cover every colourway it comes in, not just the difficulty you are furthest through.
- **Sort by completion** Order the Sets list by how close each one is, either direction. Favourites stay at the top.
- **Filter by expansion and source** Narrow to the expansions you are working through, or to Raid, PvP, Covenants, Heritage, Cosmetic, Trading Post and Miscellaneous.
- **Search by expansion and source** Type `tww`, `mn`, `df` or `bfa` into any set search box to cut the list to that expansion, and add `raid`, `pvp` or `pve` to narrow it again.
- **Track a whole set, or one piece** Shift-click a set to hunt every appearance you are missing from it, or open it and shift-click a single piece.
- **See what you are hunting** A tracked piece carries a crosshair, and a set you are hunting all of carries the mark on its own row.
- **Choose which slots the previews dress** A button on every set pane offers the armour slots as checkboxes, so a set can be looked at without the helm your character never shows.
- **Preview one piece on its own** Ctrl-click a piece in the Extra Sets or Custom tab to open just that piece in the dressing room.

### Set Tracker

- **Finish a set here** Enter a dungeon or raid and a list opens with the sets you are close to completing whose missing pieces drop there, closest to done first.
- **Loot alerts** Loot a piece of a set you are close to finishing, anywhere in the world, and the addon says so with a sound, a chat line, or both.
- **Catalyst marks** A missing piece is stamped when you are carrying something the catalyst would turn into it, so a set reads as closer to done than the count alone says. Requires Transmog Upgrade Master.
- **Set how close counts** Choose how incomplete a set can be and still count. The tier you are currently raiding is left out by default, and other classes' sets can be brought in.

### Transmog Window

- **Only the sets you can wear** The Sets tab lists any set with one piece that would fit, and a cloak fits anybody. Those are hidden, leaving what you could actually dress in.
- **Extra Sets tab** A tab beside Sets showing the hidden sets your class can wear, drawn as the same preview cards. Click one to apply every piece you have collected.
- **Set names on the cards** Every set card carries its name across the top, so you can tell one little model from another without hovering each in turn.
- **Filter the Sets tab by expansion** An Expansion submenu on the tab's own Filter button cuts a wall of cards down to the expansion you are working through.
- **Filter the Items tab by expansion** The Items button holds the source boxes in a submenu of their own beside a new Expansion one, and shop pieces get a No Expansion box rather than being filed as Classic.
- **Filter the Items tab by colour** Twelve swatches above the appearance grid leave only the pieces carrying that colour, which is how you find a belt to go with a tabard. A piece is filed under the colour most of it is painted, and joins a second or third colour's page when it carries enough of those too. A thirteenth swatch holds anything with no colour yet.
- **Random outfit** Hold the dice button to spin every armour slot through appearances you own, then let go and watch it settle. Weapons are left alone and nothing is bought until you press Apply.
  - A padlock shuts on any slot you set yourself, so that slot sits out every later spin. Click a padlock to lock or unlock it by hand.
  - Light a colour swatch and a second dice appears wearing it, spinning the same slots through only the pieces you own in that colour.
- **Situation presets** Save the situations you picked for an outfit under a name, then apply the whole lot to another outfit in one click. Each saved situation can be renamed, deleted, or written over with whatever you have ticked now.
- **Situation detail on outfits** Show the values you chose on each outfit in the list, and hover one for the full breakdown. An outfit matching a saved preset is named after it.
- **Click an appearance again to undo** Clicking an appearance the slot already wears puts it back to what you had on, so a piece can be clicked on and off to judge it.
- **Keep your active tab** Switching outfits at the transmog NPC no longer throws you back to Items.

### Everywhere Else

- **Your outfits anywhere** Left-click the minimap button, or type `/lw outfits`, to open the outfits you saved at the transmogrifier without standing at one. The parts that need an NPC are left off.
- **Outfits as a bar** A setting opens those outfits as a grid of icons instead, movable anywhere on screen. Click one to wear it, click it again to take it off, right-click to lock it, and a button on the bar clears your transmog. The header names whichever outfit you are wearing, and the bar counts itself down and closes five seconds after your cursor leaves it.
- **Item tooltips** Hover an item anywhere in the game and its tooltip names the set the piece belongs to and how far along you are, as in "From set: Glyphed Garb 7/8".
- **Preview models on tooltips** Hover a piece of gear and the piece itself appears beside the tooltip, close up and framed on the slot it sits in, so you can see it without the dressing room.
- **Wowhead addresses** Alt-click any item in your appearance collection to bring up its Wowhead address in a box ready to copy.
- **Minimap button** Left-click for your saved outfits, shift-click for the sets you can finish where you are standing, right-click for settings, drag to reposition. It also lists itself in panel addons such as Titan Panel.
- **A welcome note** A hello at your first login with the Discord address. `/wardrobe welcome` brings it back any time.

## Installation

Install from [CurseForge](https://www.curseforge.com/wow/addons/luckys-wardrobe), or place the `Luckys_Wardrobe` folder in `World of Warcraft/_retail_/Interface/AddOns/`.

Lucky's Utils ships inside the addon, so there is nothing else to install.

## Usage

1. Open the **Collections Journal** (Shift+P) and go to **Appearances > Sets**.
2. Use **Filter** to sort by completion and narrow the list by expansion or source.
3. Shift-click a set to track every appearance you are still missing from it.
4. Walk into a dungeon or raid and the set list opens with what you can finish there.

<details>
<summary><strong>Slash commands</strong></summary>

| Command | Action |
|---|---|
| `/wardrobe` | Open settings |
| `/lw` | Short form of `/wardrobe` |
| `/lw sets` | Show the sets you can finish where you are standing |
| `/lw outfits` | Open your saved outfits away from a transmog NPC |
| `/lw welcome` | Bring back the welcome note |
| `/lw conflicts` | Bring back the addon conflict warning |

The set list and your outfits also have keybindings, under **Sets You Can Finish Here** and **Transmog Quick-switcher** in the game's Key Bindings screen.

Diagnostic commands are in [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

</details>

<details>
<summary><strong>Settings</strong></summary>

Open with `/lw` or **Options > AddOns > Lucky's Wardrobe**.

- **What's New** The settings added in recent releases, each one clicking through to where it lives.
- **Appearances** Shift-click tracking, whether tracked pieces carry a crosshair, and alt-click Wowhead addresses.
- **Tooltips** Whether a tooltip names the set and your progress, whether a preview model appears beside it, and whether that preview covers gear you already have.
- **Transmog** Split into Quality of Life and Situations. Hiding sets your character cannot wear, keeping your active tab, whether set cards carry names, whether outfits open as a bar, and how much situation detail shows on saved outfits.
- **Set Tracker** How many pieces a set can be missing and still count, whether to include your current tier and other classes' sets, catalyst marks, whether the list opens by itself, and how loot alerts sound.

</details>

## Known Issues

- The Extra Sets catalogue is read from your client the first time you open Appearances. On a cold client it takes a moment, and the tab says so while it works.
- Some pieces are not on every client build. A set holding one says how many it cannot show, and those pieces cannot be previewed or applied.
- Catalyst marks and catalyst loot alerts need Transmog Upgrade Master. Without it those two options stay off, and the settings panel says why.

## A note on AI

My addons are made by one person who plays the game and wants them to work properly. I use AI tools to move faster, mostly on code, bug hunting, and docs, but every change is reviewed and tested in game before release. If a feature feels off or something breaks, that's mine to fix, and the Discord is the fastest way to reach me.

## Author

Lucky Phil
