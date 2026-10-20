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
- **Run end:** reaching the green zone, or dying, reloads a new random map and shows the last result.

## Known gaps (not built)
Stash, save/load, and extraction keeping loot; weapon durability and repair; ammo consumption (ammo exists as an item but nothing uses it); a secondary-ability system; skill tree and XP; base building; **scrap and repair kits have no use**; enemy loot drops; enemy pathfinding (they get stuck behind cover); audio; animation; art; settings or menus; export builds.

## Architecture (read this first)
- Godot 4.7.2 at `D:\Godot_v4.7.2-stable_win64.exe`. Open `project.godot`, press F5.
- Almost everything is built **in code at runtime**; `main.tscn` is one empty root node with `scripts/main.gd`.
- **Content is data:** `data/loot.gd` (items), `data/enemies.gd` (types and modifiers), `data/weapons.gd` (weapons and falloff), `data/rng.gd` (weighted pick). Add a new item, enemy, or weapon by adding a table row.
- Scripts reference each other with `preload()` constants, **not** `class_name`, because `class_name` failed to resolve on a fresh project in headless runs.
- Randomness is seeded for generation; patrol movement and pellet spread use unseeded global randomness.
- **No version control.** The folder is not a git repo yet.

## Tests
```
Godot --headless --path <project> -s tests/check.gd    # RNG determinism, loot weights, inventory, damage falloff
Godot --headless --path <project> -s tests/smoke.gd    # opens crates, uses items, shoots, alerts a pack
```

## What a game developer needs to weigh in usefully
- **Feel and balance have not been playtested by the builder** (Claude wrote this without seeing a screen). Movement speed, enemy damage, weapon ranges, spawn density, and shelter size are first guesses.
- One unexplained smoke-test result: the player lost about 30 HP in a 2-second headless run when enemies should have been out of reach.
- **Open design questions:** how the skill-tree stats are named and what they change; how repair works and what scrap is for; what the secondary ability is; whether enemies drop loot; how large a "small" map should be before open-world streaming is needed.
- **Scale risk:** a large 3D open-world FPS needs chunk streaming, navigation meshes, LOD, and likely C# or GDExtension for performance. None of that exists; the current world is one flat scene.
- **Art/audio pipeline:** nothing decided. Everything is colored boxes and capsules.
