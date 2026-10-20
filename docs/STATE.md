# Project state and notes

Moved out of README.md to keep it short. Current systems, known gaps, and per-phase notes.

## What exists now (all playable, placeholder primitives only)
- **Map:** generated from a seed. The floor is always about 3600 m2 but its shape varies from long and narrow to wide to nearly square (`MAP_*` in `data/tuning.gd`). Contents: perimeter walls, five cover shapes (fat block, tall pillar, thin slab, long low barrier, small block; `data/scenery.gd`), 3 loot areas, 2 shelters, 5 enemy groups, and the extract zone at one end of the long axis. Objects keep at least `PATH_GAP` (3 m) of walkable space between them, and cover that doesn't fit is skipped. Same seed gives the same map and crate contents. Replay one with `-- <seed>` on the command line. Changing any generation code changes what old seeds produce.
- **Loot areas** (`data/loot_zones.gd`): crates exist only inside three walled compounds, one of each per map: Supply Depot (large, 4-5 crates, mostly scrap, quantities x1.5), Armory (medium, 2-3 crates, mostly ammo, x1, guarded by an enemy group near its door), Med Post (small, 2 crates, mostly medkits, x1). Each has its own pool, rolls per crate, and quantity multiplier, plus its own wall and crate colours.
- **Player:** first-person controller (WASD, Shift sprint, Space jump), 100 HP, `E` opens crates, `Tab` toggles the backpack, `1`/`2` switch weapons.
- **Weapons:** Pistol (25 dmg, full damage to 25 m, falls off to 60 m) and Scattergun (7 pellets x 12 dmg, full to 8 m, falls off to 22 m). Damage falls off linearly to 30% at max range. An aim line shows green out to effective range and orange through the falloff zone, with a dot where the aim lands.
- **Inventory:** 8 slots (`BACKPACK_SLOTS`), stackable, drawn symbols per item (gear, bullet, cross, diamond), click to use (medkits heal, a stack of 10+ scrap crafts one medkit), right-click to drop. Crates keep what does not fit.
- **Enemies:** 3 groups of 3-4 (`ENEMY_GROUP_COUNT` in `data/tuning.gd`; set it to 5 for busier maps). Types: grunt and brute. 25% chance of a modifier (armored = 2x health, fast = 1.5x speed). Groups patrol an area, turn yellow when they notice you or are shot (the whole group alerts), and give up after 4 s out of reach. A health bar sits above each one (blue frame = armored).
- **Shelters:** small (3.6 m) nooks coloured like the cover, with no marker or label, door facing a random way, and up to three cover pieces placed in front of the door to hide it. Standing inside makes you invisible to enemies and they lose track of you; the HUD shows `[SAFE]`.
- **Enemy sound by distance:** enemy sounds are 3D: louder and more to the left or right as they get nearer (`SOUND_UNIT_SIZE` in `data/tuning.gd`; smaller = steeper falloff). Footsteps are heard out to 40 m. Stereo or headphones give left/right direction; there is no up/down or front/back cue.
- **Extraction:** stand inside the green zone for `EXTRACT_HOLD_SECONDS` (8 s). The zone turns yellow, and a countdown and progress bar appear at the top of the screen, while the timer runs. Leaving the zone resets it.
- **Results and profile:** a successful extract shows what you kept and adds it to a persisted profile (`user://profile.json`, total count per item type). Dying wipes the backpack, shows what was lost, and saves nothing. A start screen and the results screen both show the stored totals. "One more run" starts a fresh map.
- **Sound:** placeholder effects synthesized in code from `data/sounds.gd` (no audio files): weapon shots, enemy hit/kill/alert, enemy strikes, player hurt, footsteps (yours a soft thud, enemies a heavier clunk that gets lower for bigger ones), pickups, backpack-full, healing, weapon switch, extract countdown ticks, extract and death stingers. Enemy sounds are positional. Master volume is `SFX_VOLUME_DB` in `data/tuning.gd`. No music or ambience.
- **Raid simulation** (`scripts/raid.gd`): loot requests go through `request_loot()`, which checks the raid state and the distance to the crate (`LOOT_REACH`). Extraction goes through `request_extract()` / `cancel_extract()`, called when the player enters or leaves the zone. Shooting goes through `request_fire()`, which checks the raid state, the weapon cooldown and the backpack's ammo, spends the ammo, and resolves every pellet and its damage. The player script only asks.
- **Spawn safety:** enemy groups never spawn within `ENEMY_GROUP_MIN_ORIGIN` (15 m) of the player's start. Fixed in Phase 1; see below.
- **Version control:** git, branch `main`.

## Known gaps (not built)
A stash UI (the profile only stores totals; nothing is brought *into* a raid yet); weapon durability and repair; a secondary-ability system; skill tree and XP; base building; **repair kits never drop** (weight 0) until a durability system exists, and scrap only crafts medkits; enemy loot drops; enemy pathfinding (they get stuck behind cover); music and ambience (effects are synthesized beeps, written without being heard, so levels are unverified); animation; art; settings or menus; export builds.

## Phase 2 notes
- **Tuning values to look at first** (`data/tuning.gd`): `EXTRACT_HOLD_SECONDS` (8) is the main lever on how risky extracting feels; `LOOT_REACH` (4 m).
- **Assumptions:** (1) standing in the zone is enough to extract, so `request_extract()` is called by the zone's enter event, not by a key press; (2) in Phase 2 the whole backpack counted as this raid's loot (Phase 3 changed that, see below); (3) enemies and the world freeze behind the results screen; (4) being shot or attacked does not interrupt the hold timer; (5) the start screen appears once per launch, then "One more run" goes straight into a raid.
- The profile file lives in Godot's user folder (on Windows, `%APPDATA%\Godot\app_userdata\VideoGame Beta\profile.json`); delete it to reset your totals.

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

## Phase 3 notes: the drain and the clock
- **Ammo:** every shot spends backpack ammo (pistol 1, scattergun 2; `ammo_per_shot` in `data/weapons.gd`). An empty weapon cannot fire (dry-fire click, HUD shows `[NO AMMO]`). The HUD shows ammo for the current weapon.
- **Starting kit:** every raid starts with `STARTING_AMMO` (12) rounds. They are spent before any ammo you loot, and they never count as loot: on extract or death only what you hold *beyond the unspent kit* is kept or lost. This stops a player from farming ammo into the profile by extracting with the free kit. If you drop or use items so you hold less than the unspent kit, nothing is kept for that item.
- **Threat clock:** `THREAT_DELAY_SECONDS` (120) into a raid, every group stops patrolling and heads for the player's position, with a red HUD banner, an alarm sound, and a `[PATROLS CONVERGING]` tag. `THREAT_CONTINUOUS` chooses the style: `true` = they keep tracking your live position for the rest of the raid; `false` = one wave, sent to where you were when it started, ending after `THREAT_WAVE_SECONDS` (60), after which they patrol where they stand. Converging enemies still need to see you to attack and cannot see into shelters, so a sheltered player is camped outside rather than attacked; there is no pathfinding, so some get stuck behind cover.
- **Tuning values to look at first** (`data/tuning.gd`): `STARTING_AMMO` (12), `THREAT_DELAY_SECONDS` (120), `THREAT_CONTINUOUS` (true), `ENEMY_GROUP_COUNT` (3), `EXTRACT_HOLD_SECONDS` (8). Per-weapon ammo cost is in `data/weapons.gd`.
- **Assumptions:** (1) one ammo type is shared by both weapons; (2) the fire cooldown is shared across weapons and lives in the raid, so switching weapons does not skip it; (3) the threat clock counts from raid start and ignores time spent in menus (the world is paused then); (4) the old `GROUP_COUNT` of 5 was replaced, so old seeds make different maps; (5) the unit tests shorten the threat timers per raid through `raid.threat_*` variables rather than changing the tuning file.
- **Tests added:** `ammo_threat.gd` covers ammo cost and cooldown, damage applied by the simulation, empty-weapon refusal, the starting-kit loot rule, the group count, continuous and wave threat behaviour, and a control with no threat. Checked that it fails when ammo is not spent and when the threat order is dropped or stops following the player.

## Rebalance notes (from docs/DESIGN_METRICS.md)
An analysis of the generated maps and data tables (see `docs/DESIGN_METRICS.md`; it has no player data, so behaviour claims there are hypotheses) led to these changes:

| Change | Old -> new |
|---|---|
| Repair kits | drop weight 8/5/15/25 -> 0 everywhere (item row kept for future durability) |
| Scrap sink | none -> a stack of 10+ scrap, clicked in the backpack, crafts 1 medkit (`data/recipes.gd`, `Raid.request_craft()`) |
| Ammo supply | Armory x2.0 -> x1.0; Depot ammo weight 25 -> 15 |
| Scattergun | 7x12 dmg, full to 8 m, max 22 m -> 8x14 dmg, full to 10 m, max 24 m (about 2.2x the pistol's damage per ammo up close, under half its range) |
| "fast" modifier | speed x1.5 -> x2.4 (a fast grunt at 7.2 m/s outruns a walking player, not a sprinting one) |
| Aggro | distance only, through walls -> sight (18 m) needs a clear line of sight (walls and tall cover block it; other enemies do not); sprinting is heard through walls within 14 m |
| Backpack | 12 -> 8 slots |
| Jump | 0.9 m -> 1.3 m (tuned rather than cut, so it clears low barriers) |
| Threat clock | 180 -> 120 s |
| Armory | now guarded: enemy group 0 spawns 8-12 m from its door (about 29 of 30 maps) |
| Kill counter | removed from the HUD, shown on the results screen |
| Group spawn distance | 15 -> 20 m (needed: a fast grunt could otherwise reach the player within the 2 s start grace) |

Not done, on purpose: merging cover shapes (low confidence), a second ammo type, stamina. Loot-area doors now face the middle of the map.

**Data collection** (`scripts/telemetry.gd`, small on purpose; the file's header says how to extend it when you build a mechanic). Everything is written to `user://telemetry` (on Windows `%APPDATA%\Godot\app_userdata\VideoGame Beta\telemetry`) and is off in headless runs, so tests never touch your real logs:
- `raid_<time>_<seed>.jsonl`, one per raid, one JSON object per line. The first line (`raid.start.raid`) holds the map (size, extract zone, shelters, the three loot zones, every crate with its zone, every enemy with type/modifier/group/position), the tuning values, the game version and the schema number. Then come events (fire, kill, crate open with zone and position and what was taken, extract begin/cancel, threat clock, group alert with cause, enemy hit on player, item use) and a `raid.sample.state` line every 2 s with position, health, backpack contents, distance to the nearest enemy, enemies alert, safe and sprinting flags. Only the newest 100 raid files are kept; older ones are deleted automatically.
- `runs.jsonl`: one summary line per finished raid (outcome, duration, loot, kills, shots, ammo spent, threat reached) plus seed, game version and tuning. It is never pruned and is the long-term record for comparing raids across balance changes.
- To summarise: `Godot --headless --path <project> -s tools/summarize_telemetry.gd -- <file or folder>` prints extract rate, duration, threat-clock reach, ammo burn, dry-fire rate, item use-through, damage taken per kill and time to first alert.
- **Bot playtest** (`tools/playbot.gd`): a simple bot plays one raid on the real game code and prints a `RESULT {json}` line (outcome, time, kills, shots, loot, first alert, where it ended). Run it headless with `--fixed-fps 60` so simulated time is not tied to the clock (a raid takes about a second): `Godot --headless --fixed-fps 60 --path <project> -s tools/playbot.gd -- <seed>`. It does not write telemetry (headless). It is a cautious, clumsy bot with no pathfinding, so use it to catch rule regressions, not to judge human difficulty; baseline in `docs/BALANCE_LOG.md`.
- When you add a mechanic: log it with `Telemetry.emit("player.verb.object", {...})` where the simulation applies it, add new tuning constants to `Telemetry.tuning()`, add new map facts to `Main._map_info()`, and bump `GAME_VERSION`. Gaps: no pos/zone/hp on every line (samples cover that), and the `threat` alert cause is never emitted.

**Assumptions to check when playtesting:** (1) 8 slots and the 120 s clock are guesses from simulation, not play; (2) sprint noise at 14 m and sight at 18 m are first values; (3) one medkit per 10 scrap may make healing too cheap or too dear; (4) the guarded armory, sprint noise and line of sight together may make the first minute much harder, so look at damage per kill and time to first alert first.

## Art assets
Everything is still placeholder shapes, but the hooks for real art exist and nothing is downloaded yet. Enemy types (`data/enemies.gd`) and weapons (`data/weapons.gd`) have an optional `"model"` path to a `.glb`/`.gltf`/`.tscn` (plus an optional `"model_scale"`); an empty or missing path keeps the capsule or shows no weapon, so missing art never breaks the game. An enemy model replaces the capsule and turns the alert colour when the group is alerted; a weapon model is held at the lower right of the view. Put files under `assets/` (see `assets/README.md`) and record each one's source and license in `CREDITS.md`. Suggested free sources: Kenney (CC0, confirmed), Quaternius and Poly Pizza (check each license), all low-poly and glTF friendly. In use: the Pistol and Scattergun hold Kenney Blaster Kit models (CC0; `blaster-k` and `blaster-a`, about 120 KB plus a 10 KB shared texture, see `CREDITS.md`). Enemies still use capsules (the character pack was set aside for now). The raw Kenney downloads in the project root (`kenney_*/`) are git-ignored and hidden from Godot; the Prototype Kit in there (walls, floors, doors, props; no characters) is not used yet. After cloning the repo, open it in Godot once (or run `Godot --headless --path <project> --import`) so the models import; until then `tests/check.gd` reports missing models.

