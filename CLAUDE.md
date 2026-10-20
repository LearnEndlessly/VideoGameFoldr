# VideoGameFoldr (Godot 4.7.2 extraction FPS)

Read README.md (brief, architecture, tests); current state and phase notes are in docs/STATE.md. Open them only when the task needs them.

## Map
- `scripts/main.gd`: scene root; builds the raid, HUD and map in code (map generation is the `_place_*`/`_add_*` block at the bottom).
- `scripts/raid.gd`: raid rules (loot, extract, fire). `player.gd`, `enemy.gd`, `crate.gd`, `inventory*.gd`, `profile.gd`, `telemetry.gd`, `sfx.gd`, `model.gd`.
- `data/*.gd`: all content and tuning numbers. Change numbers here, not in scripts.
- `tests/*.gd`: headless tests, one per system. `tools/`: capture + telemetry summary.
- `docs/`: design research and balance log. Read only when asked.

## Rules
- Scripts reference each other with `preload()` constants, never `class_name`.
- Map generation is seeded; changing generation call order changes every old seed.
- Run tests via the `godot-test` skill; screenshots via `godot-capture`; tuning via `balance-pass`.
- Never open raw telemetry/log files; use `tools/summarize_telemetry.gd`.
- `assets/kenney_*/` are raw asset downloads, ignore them; the organized models live in `assets/weapons`, `assets/props` and `assets/buildings` (see `assets/README.md`).
