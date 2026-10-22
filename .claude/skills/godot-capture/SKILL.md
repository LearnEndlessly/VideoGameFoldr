---
name: godot-capture
description: Takes real screenshots of the Godot game and reviews them, the way a playtester would. Use it whenever the user asks to see, play, look at, screenshot or playtest the game, "how does it look", checking HUD or layout or visuals, verifying a UI or map change, or after any change to scenes, HUD, enemies or map generation in VideoGameFoldr, even if they only say "can you play it?". Computer-control tools cannot see the Godot window, so this is the way to see it.
---

# godot-capture

Claude cannot drive the game window with computer use (the Godot exe is not an installed app, so access is refused) and headless tests cannot show how anything looks. `tools/capture.gd` fills that gap: it runs a scripted tour of one map with rendering on and saves PNGs, which you then read as images. A real bug list came out of the first tour (a controls line running off-screen, a banner covering the HUD, skewed health bars), none of which any test could catch.

## Run it

```
powershell -ExecutionPolicy Bypass -File .claude/skills/godot-capture/scripts/capture.ps1 -Seed 3
```

Warn the user first: a game window appears for about 15 seconds and the mouse is captured. Close the game they may have open if they are mid-play. Different seeds give different maps and layouts; run a second seed when the change is about map generation.

The output folder (`%TEMP%\videogame-capture` by default) is cleared at the start of every run and capped at 24 files, so old screenshots never pile up. Do not copy screenshots into the repo.

## What the tour saves

| File | Shows |
|---|---|
| 01_spawn | the first-person start view and HUD |
| 02_overview | top-down view of the whole map: layout, zones, enemies, shelters |
| 03_building_outside, 04_building_inside | the first building from outside its door and from just inside |
| 05_guard_group | the first enemy group |
| 06_shelter_from_9m, 07_shelter_from_4m | whether shelters are hidden |
| 08_backpack | the inventory panel |
| 09_aim_and_healthbar | aim line, enemy health bars and labels after a shot |
| 10_extracting, 11_threat_banner | extract countdown and the threat warning together |

## Look economically

Each image costs context, so do not read all eleven by default. Start with `02_overview` (layout at a glance) and the one or two shots that match what changed, then read more only if something looks wrong. For HUD work read `11_threat_banner`: it has the most elements on screen at once.

## What to look for

Text cut off at a screen edge, overlapping HUD elements, labels too small to read, objects floating or inside walls, enemies or crates in impossible spots, health bars skewed or hidden, colours that make things hard to tell apart (alert versus normal enemies, crate zones), and anything that looks different from what the README says should exist. Report findings as a short list with the screenshot name for each, fix the clear bugs, and re-run the tour to confirm; say what you could not judge (feel, difficulty, sound) because a stationary tour cannot show it.

## Extending the tour

Add a pose to `tools/capture.gd` with the same pattern: place the player with `_stand(...)`, `await _frames(4)`, then `await _shot("12_name")`. New mechanics with a visible part (a new HUD element, a new enemy) deserve a shot. The tool turns telemetry off so tours do not pollute the real logs.
