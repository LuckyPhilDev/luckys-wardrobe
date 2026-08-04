# Lucky's Wardrobe

A focused transmog collection planner and outfit companion for World of Warcraft.

Lucky's Wardrobe is in early development. The first release establishes its settings and command entry point while the collection browser is built.

## Features

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
| `/wardrobe extrasets` | Report which extra sets this client exposes, and how many candidates were left out and why |
| `/wardrobe extrasets full` | List every extra set and every candidate left out, with its reason |
| `/wardrobe extrasets find <name>` | Look one set up by name: listed, left out and why, or already in the Sets tab |
| `/wardrobe extrasets sweep <name>` | Search this client for a set name, ignoring which ones the addon lists |

## Settings

Open **Options > AddOns > Lucky's Wardrobe** or enter `/wardrobe`.

## Roadmap

- Browse official sets by completion, source, expansion, and favourite status.
- Build personal ensembles from appearances you want to collect.
- See where missing appearances come from and what can be finished nearby.
- Preview ensembles and get optional vendor assistance without replacing Blizzard's interface.

## Author

Lucky Phil
