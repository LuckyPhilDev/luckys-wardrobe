# Lucky's Wardrobe

A focused transmog collection planner and outfit companion for World of Warcraft.

Lucky's Wardrobe is in early development. The first release establishes its settings and command entry point while the collection browser is built.

## Features

- **Extra Sets tab**: A third tab in Collections, Appearances listing the armour sets Blizzard defines but never shows in the Sets tab. It lists only what one class could wear, and shares the Sets tab's class selector, so both tabs always show the same class. Search the list, narrow it by expansion or by what you have collected, preview any set on your character, and shift-click to track the pieces you are missing.
- **Settings access**: Open the addon settings with `/wardrobe`.

## Installation

1. Place `Luckys_Wardrobe` in `World of Warcraft/_retail_/Interface/AddOns`.
2. Install **Lucky's Utils** alongside it. Release packages will include the shared dependency.
3. Restart World of Warcraft or reload the interface.

## Usage

1. Log in and enter `/wardrobe`.
2. Use the General page to configure development logging while the first features are built.

## Slash Commands

| Command | Action |
|---|---|
| `/wardrobe` | Open addon settings |
| `/lw` | Short form of `/wardrobe` |
| `/wardrobe extrasets` | Report how many extra sets this client can show, and how many were left out and why |
| `/wardrobe extrasets full` | List the extra sets and the ones left out, with the reason for each |
| `/wardrobe extrasets find <name>` | Look one set up by name: listed, left out and why, or already in the Sets tab |
| `/wardrobe extrasets perf` | Report how long the tab's work takes and how it lands on your frame rate |
| `/wardrobe extrasets perf reset` | Clear those measurements and start again |
| `/wardrobe recolors` | Report how many recolor families this client's appearances form |
| `/wardrobe recolors dump` | Save the whole family report to saved variables for reading after a reload |
| `/wardrobe recolors full` | List every family, its pieces, and every cluster left out |

## Settings

Open **Options > AddOns > Lucky's Wardrobe** or enter `/wardrobe`.

## Roadmap

- Browse official sets by completion, source, expansion, and favourite status.
- Build personal ensembles from appearances you want to collect.
- See where missing appearances come from and what can be finished nearby.
- Preview ensembles and get optional vendor assistance without replacing Blizzard's interface.

## Author

Lucky Phil
