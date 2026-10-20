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
seed_golden.gd   # 8 seeds: same seed builds the same map twice and matches tests/fixtures/seed_golden.json. After an intended generation change, regenerate with `-- --write`. Exit code 1 on failure.
rebalance.gd     # the design changes below: repair kits never drop, crafting, line of sight and sprint noise, guarded armory, backpack size. Exit code 1 on failure.
telemetry.gd     # event log in a scratch folder: map on the first line, samples, crate events, runs.jsonl, the 100-file cache cap, naming grammar, enabled flag. Exit code 1 on failure.
models.gd        # optional art: model paths replace the placeholder shapes, missing files fall back, alert tint, weapon model. Exit code 1 on failure.
profile_unit.gd  # profile save/load round trip, overwrite, corrupt-file recovery. Exit code 1 on failure.
ammo_threat.gd   # ammo cost, cooldown, empty weapon, starting-kit rule, group count, threat clock (continuous, wave, control). Exit code 1 on failure.
profile_flow.gd  # real raids: extract keeps items in the JSON, death keeps nothing, leaving the zone resets the timer,
                 # far loot requests are refused, and a second process reads the file back. Exit code 1 on failure.
extract.gd       # two extract zones: placement constraints on 40 seeds, determinism, zone B's noise, hold reset, beam reveal radius, threat clock HUD.
layout_isolation.gd  # everything except the extract zones is identical to the pre-extract build (tests/fixtures/layout_golden.json), and extract tuning moves only the zones.
enemy_base.gd    # enemy view cones and suspicion, enemy bases and their respawn beams, ammo drops.
raid_upgrades.gd  # raid upgrades and level-up pauses, powerups (effect, expiry, drops), hold-R reload, the 14-round pistol clip, the launch-reset rule.
progression.gd  # the scoreboard stats (profile, wall board), the end screen choice, and descending: carried loot, extra bases, faster spawns, ammo, reward, map unchanged.
base.gd, difficulty.gd, reload.gd, aim_color.gd  # the base of operations and saves, raid difficulty and the reward multiplier, magazines and reload, laser colours.
```
The profile tests print a JSON parse error once; that is the deliberate corrupt-file case.

## What exists now
- **Base of operations** (`scripts/hub.gd`): a walkable, enemy-free room you start in and return to. Stash, armory (choose the starting weapon), character (attribute points), a map pit showing the next raid's map with shootable `< ? >` controls, and the raid terminal (five difficulty options that scale the rewards), opened by the green play button next to the map pit's `< ? >` buttons rather than by a wall station.
- **Raid**: seeded procedural map whose cover varies a lot from map to map (8 to 37 boxes in 160 seeds, a per-map cover mix and a per-map walkable gap of 2.7 to 4 m, `COVER_*` and `PATH_GAP_RANGE` in `data/tuning.gd`), two loot buildings (an olive armory with a yellow band, roof merlons and painted rounds; a white med post with a red cross on its walls and a big one on its roof), each taller than before (4.6 m / 4.2 m) with two doorways on opposite walls, cover, two safe nooks, enemy patrols with visible view cones and a suspicion meter, four enemy bases that respawn defenders (red beams show the countdown), ammo drops, a threat clock that sends every patrol after you.
- **Extraction: two routes.** Zone A "Safe route" is far from the start with an 8 s hold. Zone B "Fast route" is close to the start with a 12 s hold and is noisy: starting a hold alerts every enemy group within 30 m. Extract beams only show within 25 m, so there is no compass; the map pit in the base shows both. A threat clock countdown (top right) turns amber at 30 s and red at 10 s, and after it fires an arrow points toward the nearest zone.
- **Upgrades in the raid.** Weapon and character upgrades are won during a raid and lost when it ends (extract or death; a descent keeps them). Every 2 kills earns a level-up: the game pauses and offers 3 random upgrades (Heavy rounds, Rapid fire, Vitality, Fleet foot, Quick hands, Plating), pick with a click or 1/2/3. Numbers in `data/upgrades.gd`.
- **Attributes** (speed, constitution, handling) are permanent and spent only at the base's Character station. At most 3 points come home from one raid (`POINTS_PER_RAID_MAX`).
- **Powerups** (`data/powerups.gd`): an enemy kill drops one 17.5% of the time (`POWERUP_DROP_CHANCE`, cut 30% from 25%). It lies on the ground for 5 s (`POWERUP_PICKUP_SECONDS`), blinking at the end; touch it for 10 s of Overdrive (+50% damage), Haste (+40% speed) or Shield (half damage taken).
- **HUD and pause:** the health bar and a blue XP bar under it (kills toward the next level-up, with the raid level as `LV`) are at the bottom left, above the controls hint. Esc pauses the game and shows the controls as key caps; Esc or Resume continues. The depth shown as `DEPTH n` was `LEVEL n`.
- **Reloading** runs only while R is held; letting go cancels it. The pistol's magazine is 14 rounds (45% of the old 30).
- **No saves yet:** a real launch starts with an empty profile (no stash, points, attributes or difficulty choices); the base and raids within one session keep what was earned (`RESET_ON_LAUNCH` in `data/tuning.gd`). Test and tool profiles are never reset.
- **Scoreboard.** The base's north wall carries the RAID LEDGER: runs, extracted, killed in action, survival rate, kills, shots fired, accuracy (shots that hurt something) and deepest level, kept in the profile for every raid (`Profile.record_raid`).
- **Going deeper.** After an extract the end screen offers DESCEND next to RETURN TO BASE. Descending takes the loot just extracted back out of the stash and into the next level's backpack, unbanked and at risk again, on a fresh map (new crates). Each level adds enemy bases (from their own RNG stream), faster base spawns, one more defender per base every two levels, more starting ammo and likelier ammo drops, and +25% to the reward multiplier. Dying loses the carried loot; returning to base banks it. The HUD shows the level.
- **Menu style** (`scripts/ui_kit.gd`): every panel uses one look: dark slabs with a hard accent edge in the station's colour, hazard tape under headers, heavy spaced capitals, big numerals, item and stat tiles, pips for levels, meters for weapon stats, a risk dial for difficulty and one oversized button for the action that matters. The end screen stamps the verdict (EXTRACTED / K.I.A.) and the safe choice has the focus. Design notes and references: `docs/MENU_DESIGN.md`.
- **Saves** (`scripts/profile.gd`): stash, weapon levels, attributes, difficulty choices, stats; versioned and atomically written.
- Playbot baselines before and after the extract work: `docs/baseline_before_extract.md`, `docs/baseline_after_extract.md` (`tools/run_baseline.ps1` makes them).

## Not built yet
- The skill tree (three attributes stand in for it), durability and repair (`repair_kit` never drops), base building.
- Bringing stash items into a raid, a use for most of the stash, more than two weapons, ranged or other enemy types, a reward for destroying an enemy base, rewards that differ between the two extract routes.
- See `docs/DESIGN_REVIEW.md` for the full list of weak spots.

## Tuning values to look at first (extraction)
All in `data/tuning.gd`:
- `EXTRACT_HOLD_SECONDS` (8) and `EXTRACT_B_HOLD_SECONDS` (12): how much longer the fast route costs.
- `EXTRACT_B_NOISE_RADIUS` (30): how many patrols the fast route wakes.
- `EXTRACT_A_MIN_PATH` (32), `EXTRACT_B_MIN_PATH` / `EXTRACT_B_MAX_PATH` (8 / 18), `EXTRACT_MIN_SEPARATION` (35), `EXTRACT_MIN_BASE_DISTANCE` (10): where the zones may go.
- `EXTRACT_BEAM_REVEAL_RADIUS` (25) and `EXTRACT_BEAM_ALWAYS_VISIBLE` (false): flip the second one to compare with the old see-it-from-anywhere beam.
- `THREAT_DELAY_SECONDS` (120), `THREAT_COUNTDOWN_AMBER_SECONDS` (30), `THREAT_COUNTDOWN_RED_SECONDS` (10), `THREAT_EXTRACT_TICK` (true), `THREAT_TICK_RADIUS` (110 px).

## Tuning values to look at first (going deeper)
All in `data/tuning.gd`: `DEPTH_EXTRA_SPAWNERS` (1) and `DEPTH_MAX_EXTRA_SPAWNERS` (4), `DEPTH_INTERVAL_MULT` (0.85 per level) and `DEPTH_MIN_INTERVAL` (4 s), `DEPTH_MAX_ALIVE_EVERY` (2), `DEPTH_AMMO_BONUS` (6), `DEPTH_DROP_BONUS` (0.25), `DEPTH_REWARD_BONUS` (0.25).

## Assumptions made for the menu changes
- "Controller description" is the keyboard and mouse controls list; there is no gamepad support, and the screen says so.
- The XP bar fills with kills toward the next level-up (2 kills each, so it moves in halves); the raid level is 1 + upgrades taken.
- Removing the raid terminal's wall station left the north wall free, so the Raid Ledger moved to its middle.
- The pause menu only resumes; there is no abandon-raid button.

## Assumptions made for the in-raid upgrades and powerups
- "Character and weapon upgrades" became the six raid upgrades above (the old stash-paid weapon upgrades are gone, and old saves' weapon levels are ignored); "attributes" stayed as the permanent base system. Say if you meant something else.
- A descent keeps the run's raid upgrades, because it is the same run; extracting to the base or dying clears them.
- A level-up pauses the whole game (the threat clock too) while you choose. Kills earn picks, nothing else does.
- Powerup effects last 10 s from pickup and picking up the same kind again restarts the 10 s; they do not stack with themselves. Powerups are not kept on descending.
- The 5 s is the time a dropped powerup lies on the ground.
- The reset on launch only wipes the real `profile.json` (the path in `Tuning.PROFILE_PATH`) at the first start of the process; it is written empty immediately so a scene reload cannot read last session's file. That includes your current stash and difficulty choices.
- Not built: saving raid upgrades, rarity, a use for scrap, level-ups from anything but kills.

## Assumptions made for the map variety and buildings
- This changed every old seed (cover count, mix and gap are new draws); `seed_golden.json` and `layout_golden.json` were regenerated, with a scratch profile because the raid difficulty in the real profile changes the enemies in the fingerprint.
- Dense maps could squeeze the extract zones, so `EXTRACT_PAIR_RETRIES` went from 5 to 25 and the tightest gap is 2.7 m; 160 seeds place with no error.
- The second doorway is straight across from the first. Crates now sit only on the two walls without a door, and stay 1.3 m from both doorways; the med post grew from 4 m to 4.6 m so two crates still fit. Roofs, bands, crosses and merlons are visual only (no collision, not in the map pit's miniature).
- The backpack now draws over the ammo bar and crosshair, which no longer take mouse clicks (they were covering the slots).

## Assumptions made for the progression work
- **A descent is part of the run it came from:** "runs" counts once, when the level-1 raid finishes; every level adds its kills, shots and hits; "deepest level" is the highest level finished.
- **Loot is banked first, then taken back out** when you descend (so the extract still counts and pays its attribute points, and a crash mid-descent cannot lose it twice). It then counts as loot again: dying on the next level loses it.
- **A new level is a new map** derived from the old map's number, so a level is never replayed. "Loot reset" means fresh crates on that map. Descent state lives in `Main.depth` and `Main.carry` (static, like `show_start`).
- **"More enemy spawn locations"** means extra enemy bases, one per level up to four extra, never within 10 m of an extract zone. "Higher spawn rates" is the interval multiplier and the extra defender.
- Dying now also saves the profile (the scoreboard has to remember it); the stash is untouched.
- Accuracy counts a shot as a hit if any pellet hurt an enemy or a base.
- Old saves load with zeros for the new stats.
- Not built: a level cap, a depth-based reward curve beyond the linear bonus, a "best run" list.

## Assumptions made for the extraction work
- **Layout stays frozen:** zones come from their own RNG stream (seeded from the map seed) and are placed after everything else. To keep every old seed's terrain, crates and enemies unchanged, the old single-zone draws are still made and its 9 m patch is still kept clear, so each map has an empty patch where the old zone used to be. Regenerating the layout fixtures would let that go.
- **"Path distance"** is walking distance on a 1 m, 4-connected grid around walls, cover, crates and bases (no navmesh), so it is slightly longer than a straight line on diagonals. Separation and base clearance are straight-line metres. The arrow's distance is also a straight line.
- **Numbers I chose** (you gave none): A at least 32 m of path (40 was infeasible on most seeds with the other constraints), B 8 to 18 m, separation 35 m, base clearance 10 m, 6 m zones, 300 draws per zone and 25 pair retries (denser maps needed more than 5). All 120 seeds I tried placed without a failure; on failure it logs a clear error and falls back.
- **Zones may overlap the edges of cover:** only the central 5 x 5 m must be walkable. With strict clearance there was no room for B near the start.
- **"Alerted toward that zone"** means the whole group is alerted (its members then chase the player, who is in the zone); a group counts as nearby if any member is within the radius (flat distance). Starting a hold alerts once; a continued hold does not re-alert.
- **Beam reveal** applies to the extract beams and their labels only; enemy-base beams stay visible. The toggle is `EXTRACT_BEAM_ALWAYS_VISIBLE` (tuning constants are upper case); tests change it through `Main.extract_cfg`, since constants cannot change at run time.
- The old top-left "[PATROLS CONVERGING]" flag is gone; the top-right indicator replaces it.
- Both zones pay out the same. The playbot picks the nearer zone and never weighs hold time or noise, so its baselines do not test the decision itself.
- The baseline seeds are 1 to 40 (the earlier baseline's seed list was not recorded), and the "before" baseline was rerun on the current build.

## Current state
What exists, known gaps, phase notes, rebalance table, telemetry and art hooks: `docs/STATE.md` (read only when the task needs it).

## Project skills (for Claude Code sessions, in `.claude/skills/`)
- `godot-test`: runs the whole headless suite (or named tests) and prints a PASS/FAIL table; handles the path quoting, timeouts and hangs that break hand-run tests.
- `godot-capture`: runs the rendered screenshot tour (`tools/capture.gd`) and reviews the images; the only way Claude can see the game. Clears and caps its own screenshot folder.
- `balance-pass`: reads `runs.jsonl`, groups raids by build and tuning, proposes specific old-to-new changes tied to measures, applies them on request and records each pass in `docs/BALANCE_LOG.md`.
- `game-design-researcher`: researches how Arc Raiders, Path of Exile and Minecraft build their systems, translates mechanisms into this framework, and records dated findings in `docs/RESEARCH.md`. Runs broad topics as tiered background subagents.

