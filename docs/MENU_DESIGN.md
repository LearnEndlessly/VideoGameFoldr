# Menu design

One look for every 2D menu, built in code by `scripts/ui_kit.gd`.

## Direction: field terminal
The base is a bunker and the menus are its terminals: near-black slabs, a hard coloured edge down the left, diagonal hazard tape under every header, heavy spaced capitals, and numbers that are big enough to read from across the room. Colour carries meaning instead of decoration: each station owns an accent (raid green, armory orange, character magenta, map ice blue, stash blue), amber means "the number that matters" (points, reward, level), red is danger and loss, green is safety and gain.

## What it borrows, and from whom
- **Escape from Tarkov:** loot as tiles with a count in the corner (the stash and end screen grids) and the sober dark-panel feel.
- **Hades:** one oversized, filled button for the choice that matters (START RAID, DESCEND), a risk dial of chips whose price is on the button (the difficulty rows, "+20%"), and the stat-and-pips weapon cards.
- **Hunt: Showdown:** a ledger of lifetime numbers, here the RAID LEDGER on the wall, and the "go home with it or press on" extract choice.
- **Dead Cells / Vampire Survivors:** flat colour, chunky type, level shown as blocks, a stamped verdict ("EXTRACTED", "K.I.A.") before the stats.

## Rules the kit follows
1. A number is a tile, not a sentence. Text lines are for explanations, in dim grey and small.
2. Levels are pips, comparisons are meters (weapon stats are drawn against the best weapon), so nothing needs reading as "2/5".
3. Each screen has one primary action, filled and tall. Everything else is a flat slab that slides its accent edge in on hover.
4. The chosen option is filled with the accent and disabled (Equipped, the selected difficulty chip), so state is visible without reading.
5. The safe choice has the keyboard focus: Enter on the end screen returns to base; descending is a deliberate click.
6. Escape closes a panel; the hint line is one short row of keys.

## Where it is used
Base panels (`scripts/hub.gd`), the end-of-raid screen (`scripts/screen_ui.gd`), the base's wall ledger (3D labels, same fonts and colours). The in-raid HUD is unchanged apart from a LEVEL counter.

## Not done
No custom font file (the engine's default, emboldened and spaced), no sound on hover, no gamepad navigation check, no animation beyond the hover edge. Seen only in stills from `tools/capture_base.gd`; feel is unverified.
