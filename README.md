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

## What exists now (all playable, placeholder primitives only)
- **Map:** 60x60 m arena generated from a seed: perimeter walls, 25 cover blocks, 10 loot crates, 2 shelters, 1 extract zone. Same seed gives the same map and the same crate contents. Replay one with `-- <seed>` on the command line.
- **Player:** first-person controller (WASD, Shift sprint, Space jump), 100 HP, `E` opens crates, `Tab` toggles the backpack, `1`/`2` switch weapons.
- **Weapons:** Pistol (25 dmg, full damage to 25 m, falls off to 60 m) and Scattergun (7 pellets x 12 dmg, full to 8 m, falls off to 22 m). Damage falls off linearly to 30% at max range. An aim line shows green out to effective range and orange through the falloff zone, with a dot where the aim lands.
- **Inventory:** 12 slots, stackable, drawn symbols per item (gear, bullet, cross, diamond), click to use, right-click to drop. Crates keep what does not fit.
- **Enemies:** 5 groups of 3-4. Types: grunt and brute. 25% chance of a modifier (armored = 2x health, fast = 1.5x speed). Groups patrol an area, turn yellow when they notice you or are shot (the whole group alerts), and give up after 4 s out of reach. A health bar sits above each one (blue frame = armored).
- **Shelters:** open-fronted blue huts. Standing inside makes you invisible to enemies and they lose track of you.
- **Run end:** reaching the green zone, or dying, reloads a new random map and shows the last result. (Phase 2 replaces this with a hold-to-extract timer, results screens, and a saved profile.)
- **Spawn safety:** enemy groups never spawn within `ENEMY_GROUP_MIN_ORIGIN` (15 m) of the player's start. Fixed in Phase 1; see below.
- **Version control:** git, branch `main`.

## Known gaps (not built)
Stash, save/load, and extraction keeping loot; weapon durability and repair; ammo consumption (ammo exists as an item but nothing uses it); a secondary-ability system; skill tree and XP; base building; **scrap and repair kits have no use**; enemy loot drops; enemy pathfinding (they get stuck behind cover); audio; animation; art; settings or menus; export builds.

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
```

## Phase 1 report: the "lost 30 HP in 2 seconds" bug
- **Root cause:** `_free_spot()` in `scripts/main.gd` places objects by trying random spots. By the time enemy groups are placed, 38+ cover blocks, crates, and shelters already fill the map, so all 50 tries fail. The old fallback then kept the *last random sample* even when it landed inside the 15 m no-spawn zone around the player's start. Groups ended up 3-10 m from the player and attacked within seconds.
- **Not the cause:** enemy hit range (every hit was at 1.8 m or less, one per second per enemy), damage falloff (that is for player weapons only), or double-applied damage (no frame had two hits from one enemy).
- **Fix:** the spawn-distance limit is now never relaxed; only overlap with other objects is accepted after `SPAWN_TRIES` valid samples.
- **Still true:** because the map is saturated, enemy groups (and some other objects) still spawn overlapping cover or each other. That is a layout-density problem, not fixed here. Cover blocks use large exclusion radii (up to about 4 m each) and 25 of them fill most of the 60x60 area.

## What a game developer needs to weigh in usefully
- **Feel and balance have not been playtested by the builder** (Claude wrote this without seeing a screen). Movement speed, enemy damage, weapon ranges, spawn density, and shelter size are first guesses.
- Enemy groups spawning on top of cover (map density), see the Phase 1 report below.
- **Open design questions:** how the skill-tree stats are named and what they change; how repair works and what scrap is for; what the secondary ability is; whether enemies drop loot; how large a "small" map should be before open-world streaming is needed.
- **Scale risk:** a large 3D open-world FPS needs chunk streaming, navigation meshes, LOD, and likely C# or GDExtension for performance. None of that exists; the current world is one flat scene.
- **Art/audio pipeline:** nothing decided. Everything is colored boxes and capsules.
