# Troubleshooting

These report what the addon can see, for working out why something looks wrong. Useful when reporting a problem on [the Discord](https://discord.gg/ptTtYyAjdZ).

`/wardrobe` and `/lw` take the same subcommands.

## Set list and instances

| Command | Action |
|---|---|
| `/lw replay` | Reopen the set list as if you had just walked in, for checking your settings |
| `/lw scan` | Report what the addon can see about the instance you are in |

## Transmog window

| Command | Action |
|---|---|
| `/lw items <expansion>` | Report which appearances the open Items tab dated to an expansion, and where they come from |
| `/lw roll` | Report what each slot has to draw from when the dice spins, and in the lit colour |
| `/lw slots` | Report what every slot is holding and which pieces the dice put there |

## Extra Sets

| Command | Action |
|---|---|
| `/lw extrasets` | Report how many extra sets this client can show, and how many were left out and why |
| `/lw extrasets full` | List the extra sets and the ones left out, with the reason for each |
| `/lw extrasets find <name>` | Look one set up by name: listed, left out and why, or already in the Sets tab |
| `/lw extrasets looks <name>` | Compare the looks behind a set with the ones the Sets tab holds, for checking why a set was folded away |
| `/lw extrasets variants <name>` | Ask the client which sets it already calls colourways of one another |
| `/lw extrasets colours` | List every family of sets grouped as one garment in several colours (`colors` works too) |
| `/lw extrasets pieces` | Report the set selected in the Extra Sets tab piece by piece, for working out why it reads as unwearable |
| `/lw extrasets perf` | Report how long the tab's work takes and how it lands on your frame rate |
| `/lw extrasets perf reset` | Clear those measurements and start again |

## Recolour families

| Command | Action |
|---|---|
| `/lw recolors` | Report how many recolor families this client's appearances form |
| `/lw recolors full` | List every family, its pieces, and every cluster left out |
| `/lw recolors dump` | Save the whole family report to saved variables for reading after a reload |
| `/lw recolors probe` | Report how many appearances in each slot the client can name yet, for when a report comes back short |
