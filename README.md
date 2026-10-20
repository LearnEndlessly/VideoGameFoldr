# VideoGame Beta: project brief for collaborators

A single-player, setting-agnostic **extraction FPS framework** in Godot 4.7.2. The loop is the product; the narrative and theme are meant to be swapped by editing data tables, not code.

## Design pillars (from the owner)
1. **Arc Raiders-style RNG**: seeded procedural map, weighted loot crates, random enemy types and modifiers.
2. **Path of Exile-style build identity**: a skill tree built on three stats. *Not built yet; names are placeholders.*
3. **Minecraft-style exploration, building, customization**: play according to your surroundings. *Not built yet; planned as placeable blocks at a hub, with scrap as the material.*

Target loop: **Hub** (build, skill tree, stash) -> **Raid** (small bounded procedural map) -> **Extract or die** -> back to hub.

## Rules decided so far
- **Death penalty:** you lose only the loot gained during that run, not what you brought in.
- **Durability:** items used take *permanent* durability damage unless repaired with repair items. Broken items are lost forever, so players must bring ammo for other weapons or switch to a secondary weapon or ability.
- **Inventory:** limited slots, real-time (the game does not pause). You need a **shelter** to be safe from enemies while managing it.
- **Setting:** deliberately none. Keep names neutral.
- **Single-player first.** Multiplayer is out of scope (it is hard to retrofit, so decide early if that changes).

## Architecture (read this first)
- Godot 4.7.2 at `D:\Godot_v4.7.2-stable_win64.exe`. Open `project.godot`, press F5.
- Almost everything is built **in code at runtime**; `main.tscn` is one empty root node with `scripts/main.gd`.
- **Content is data:** `data/loot.gd` (items), `data/enemies.gd` (types and modifiers), `data/weapons.gd` (weapons and falloff), `data/rng.gd` (weighted pick). Add a new item, enemy, or weapon by adding a table row.
- Scripts reference each other with `preload()` constants, **not** `class_name`, because `class_name` failed to resolve on a fresh project in headless runs.
- Randomness is seeded for generation; patrol movement and pellet spread use unseeded global randomness.
- **Tunable numbers** go in `data/*.gd`. `data/tuning.gd` holds the spawn values so far; many older numbers are still constants inside scripts (map size, counts, enemy sight/reach, player speed) and will move there as those systems are touched.
- Changing map generation changes what every old seed produces (the Phase 1 fix did this).

## Tests
Run each with `Godot --headless --path <project> -s tests/<name>.gd`. Always run them with output redirected to a file; a script error inside a test can leave the process hanging.
```
check.gd         # RNG determinism, loot weights, inventory, damage falloff
smoke.gd         # opens crates, uses items, shoots, alerts a pack
spawn_safety.gd  # 60 maps: no enemy group near the player's start; 20 maps: no damage in the first 2 s. Exit code 1 on failure.
map_layout.gd    # 40 maps: shapes vary, 3 loot areas, crates only inside them, and every key place is walkable from the start. Exit code 1 on failure.
rebalance.gd     # the design changes below: repair kits never drop, crafting, line of sight and sprint noise, guarded armory, backpack size. Exit code 1 on failure.
telemetry.gd     # event log in a scratch folder: map on the first line, samples, crate events, runs.jsonl, the 100-file cache cap, naming grammar, enabled flag. Exit code 1 on failure.
models.gd        # optional art: model paths replace the placeholder shapes, missing files fall back, alert tint, weapon model. Exit code 1 on failure.
profile_unit.gd  # profile save/load round trip, overwrite, corrupt-file recovery. Exit code 1 on failure.
ammo_threat.gd   # ammo cost, cooldown, empty weapon, starting-kit rule, group count, threat clock (continuous, wave, control). Exit code 1 on failure.
profile_flow.gd  # real raids: extract keeps items in the JSON, death keeps nothing, leaving the zone resets the timer,
                 # far loot requests are refused, and a second process reads the file back. Exit code 1 on failure.
```
The profile tests print a JSON parse error once; that is the deliberate corrupt-file case.

## Current state
What exists, known gaps, phase notes, rebalance table, telemetry and art hooks: `docs/STATE.md` (read only when the task needs it).

## Project skills (for Claude Code sessions, in `.claude/skills/`)
- `godot-test`: runs the whole headless suite (or named tests) and prints a PASS/FAIL table; handles the path quoting, timeouts and hangs that break hand-run tests.
- `godot-capture`: runs the rendered screenshot tour (`tools/capture.gd`) and reviews the images; the only way Claude can see the game. Clears and caps its own screenshot folder.
- `balance-pass`: reads `runs.jsonl`, groups raids by build and tuning, proposes specific old-to-new changes tied to measures, applies them on request and records each pass in `docs/BALANCE_LOG.md`.
- `game-design-researcher`: researches how Arc Raiders, Path of Exile and Minecraft build their systems, translates mechanisms into this framework, and records dated findings in `docs/RESEARCH.md`. Runs broad topics as tiered background subagents.

