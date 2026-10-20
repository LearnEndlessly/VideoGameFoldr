---
name: godot-test
description: Runs this project's headless Godot test suite and reports a PASS/FAIL table. Use it whenever the user says run the tests, verify, check nothing broke, regression, "did that work", or after ANY change to scripts/, data/ or tests/ in the VideoGameFoldr Godot game, even if they don't mention tests. Also use it before committing, and to confirm a new test can fail.
---

# godot-test

The suite lives in `tests/` and runs headless. Running it by hand has gone wrong several times in this project, which is why a script wraps it:

- The project path contains spaces. Godot needs it wrapped in embedded double quotes, otherwise it prints "Invalid project path" and silently tests nothing (a subagent once reported a clean parse check that tested nothing for this reason).
- A script error inside a test can leave Godot hanging forever, so every run needs a timeout and output redirected to a file.
- Pass means exit code 0 and a last line saying `0 failure(s)` (or `checks passed` / `smoke ok`). Reading only the exit code is not enough.

## Run it

All tests:

```
powershell -ExecutionPolicy Bypass -File .claude/skills/godot-test/scripts/run_tests.ps1
```

Some tests (names without `.gd`):

```
powershell -ExecutionPolicy Bypass -File .claude/skills/godot-test/scripts/run_tests.ps1 -Tests check,ammo_threat
```

The full suite takes a few minutes. When it is long, run it in the background and carry on; for a quick check after a small change, pick the tests that cover that area (see below). Godot is expected at `D:\Godot_v4.7.2-stable_win64.exe`; set `GODOT_PATH` or pass `-Godot` if it moves.

## Report

Give the user the table the script prints, then for any FAIL the first error lines. Do not paraphrase a failure into a guess: quote it. `profile_unit` prints a JSON parse error on purpose (a corrupt-file case); the script filters it.

If the script warns that the real telemetry folder changed, a test wrote to the player's real logs; that is a bug to fix (tests must use `Telemetry.dir` pointed at a scratch folder or leave telemetry off).

## Which test covers what

| Test | Covers |
|---|---|
| check | RNG determinism, loot weights and zones, inventory, damage falloff, every sound |
| smoke | opens crates, uses items, shoots, alerts a pack in a real raid |
| spawn_safety | enemies never spawn near the start; no damage in the first 2 s (60 maps) |
| seed_golden | map generation is unchanged for fixed seeds (guard for refactoring main.gd) |
| map_layout | map shapes vary, 3 loot zones, crates only inside them, everything walkable (40 maps) |
| profile_unit, profile_flow | saved profile, extract keeps loot, death keeps none, restart reload |
| ammo_threat | ammo, cooldown, starting-kit rule, group count, threat clock modes |
| rebalance | repair kits never drop, crafting, line of sight and sprint noise, guarded armory |
| telemetry | event log, map snapshot, samples, runs.jsonl, the 100-file cache cap |
| models | optional art: model paths replace placeholders, missing files fall back, alert tint, weapon model |

## Adding or changing a test

A test that has never failed proves little. After writing one, break the behaviour it guards (change a number, comment out a call, mark the edit `MUTATION-TEST`), confirm the test fails with a message that names the problem, then restore the code and grep to confirm no `MUTATION` marker is left. Tests exit with code 1 on failure and always call `quit()`; a test that can crash before `quit()` will hang the run.

New tests go in `tests/NAME.gd`, extend `SceneTree`, set `Main.show_start = false`, instantiate `res://main.tscn` with `main.seed_override`, and `await process_frame` before touching the raid (`_ready` only runs once the tree is processing). Copy `tests/profile_flow.gd` as the pattern.
