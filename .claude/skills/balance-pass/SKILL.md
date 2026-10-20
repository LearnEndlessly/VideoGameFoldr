---
name: balance-pass
description: Studies the game's recorded play data and proposes specific tuning changes (old value to new value), then applies them on request. Use whenever the user says balance, tune, difficulty, "is it too easy or hard", "what should we change", look at the logs or runs or telemetry, results over time, or has just played some raids in VideoGameFoldr, even if they never say "balance". Also use it before changing any number in data/*.gd so the change is tied to a measure.
---

# balance-pass

The game records every raid (see the header of `scripts/telemetry.gd`). This skill turns those records into a small number of specific, evidence-backed tuning changes, and keeps a log so the results of each change can be checked later. The point is to stop tuning by feel and by simulation guesses: every balance number in the README so far is a guess until real raids say otherwise.

Raids are only comparable if they were played under the same build and tuning, so the first job is always to separate them.

## 1. Find the data

Real play writes to `%APPDATA%\Godot\app_userdata\VideoGame Beta\telemetry`: `runs.jsonl` (one summary line per raid, never pruned) and `raid_*.jsonl` (full event streams, newest 100). Headless runs, tests and the screenshot tour write nothing there, so every line is from the user actually playing. If there is no `runs.jsonl`, say so and ask the user to play a few raids in the normal game window; do not invent data.

## 2. Summarise

```
python .claude/skills/balance-pass/scripts/runs_by_version.py
python .claude/skills/balance-pass/scripts/runs_by_version.py <folder or runs.jsonl>
```

It groups raids by game version and exact tuning and prints extract rate, duration, kills, shots, ammo spent, threat-clock reach and loot per group, flagging groups with fewer than 20 raids. For event-level questions (time to first alert, damage taken per kill, dry fires, item use) run the second tool on the raid files:

```
Godot --headless --path <project> -s tools/summarize_telemetry.gd -- <telemetry folder>
```

(use the path in `docs/DESIGN_METRICS.md`'s notes if Godot is not on PATH: `D:\Godot_v4.7.2-stable_win64.exe`, and wrap the project path in embedded quotes when launching from PowerShell.)

For route and position questions read the `raid.sample.state` lines (position every 2 s) together with the map on the first line of the raid file (zones, crates, enemies, shelters, extract).

## 3. Judge against the design's intent

Read the "Metrics" section of `docs/DESIGN_METRICS.md`: each measure there has a hypothesised healthy range and the element it informs. Compare the current group's numbers with those ranges, but treat the ranges as hypotheses too; if the data contradicts one, say so and update the doc rather than forcing the data to fit.

Sample size decides how confident to be. Under about 20 raids in a group, rates (extract rate, threat reach) are noise: report them as "early signal" and say how many more raids would settle it. Never compare groups with different tuning as if they were one population; the "tuning that differs" lines show what changed between them.

## 4. Propose specific changes

Each proposal is one line: which value, old to new, which measure it should move and in which direction, and a confidence (n raids, strength of signal). Prefer the smallest change that tests the idea; change one or two things per pass so the next data set can attribute the result. Tunable numbers live in `data/tuning.gd`, `data/weapons.gd`, `data/enemies.gd`, `data/loot.gd`, `data/loot_zones.gd`, `data/scenery.gd`, `data/recipes.gd`; never hardcode a number in a script. If the evidence points at something a number cannot fix (a missing mechanic, an element nobody uses), say that plainly instead of forcing a tuning change.

Present the proposals and wait for the user, unless they have already said to apply them.

## 5. Apply and record

When applying: edit the data files, bump `GAME_VERSION` in `scripts/telemetry.gd` (so new raids land in a new group), add any new tuning constant to `Telemetry.tuning()`, run the godot-test skill, commit with the old and new numbers in the message, and append an entry to `docs/BALANCE_LOG.md`:

```
## <date> version <old> -> <new>
Data: <n raids, which group, the numbers that drove this>
Changes: <value old -> new>, ...
Expect: <measure and direction>
Check next pass: <what to look at once enough raids exist>
```

At the start of each later pass, read the log first and judge the previous entry's "Expect" line against the new data before proposing anything new; that is how results are studied over time rather than each pass starting from scratch.
