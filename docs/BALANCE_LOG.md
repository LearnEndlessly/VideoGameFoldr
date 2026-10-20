# Balance log

One entry per balance pass (see `.claude/skills/balance-pass/SKILL.md`). Newest last. At the start of each pass, judge the previous entry's "Expect" line against the new data first.

```
## <date> version <old> -> <new>
Data: <n raids, which group, the numbers that drove this>
Changes: <value old -> new>, ...
Expect: <measure and direction>
Check next pass: <what to look at once enough raids exist>
```

## 2026-10-20 version 0.4 (baseline, no play data yet)
Data: none. Changes below came from simulation of 150 generated maps and the data tables (`docs/DESIGN_METRICS.md`), not from play.
Changes: repair kit weight -> 0; scrap crafts medkits (10 -> 1); armory ammo x2.0 -> x1.0; scattergun 7x12 -> 8x14, ranges 8/22 -> 10/24 m; fast modifier x1.5 -> x2.4; sight needs line of sight, sprint heard within 14 m; backpack 12 -> 8 slots; jump 0.9 -> 1.3 m; threat clock 180 -> 120 s; armory guarded; group spawn minimum 15 -> 20 m.
Expect: ammo burn ratio rises toward 0.5-0.8 of the ammo available; fewer instant fights (time to first alert up); backpack becomes a real constraint for full sweeps; threat clock reached in a meaningful share of raids.
Check next pass: after about 20 raids at this version: extract rate, duration, threat-clock reach, dry-fire rate, damage taken per kill.

## 2026-10-20 version 0.4: bot baseline (NOT human play)
Data: `tools/playbot.gd`, 40 seeds, one raid each. The bot is cautious and clumsy: it walks (never sprints), loots the zones nearest-first, stands and shoots the nearest alert enemy it can see, heals below half health, has no pathfinding beyond door waypoints and a random sidestep, and never kites. Runs are slightly non-deterministic (one seed extracted on a rerun after timing out). Treat this as a regression signal for rule changes, not as a measure of how humans do.
Result: 14 extracted (35%), 22 dead (55%), 4 timeouts (10%, all bot-stuck: 3 of 3 diagnosed ended far from the extract zone with one waypoint left, two beside a shelter). Median death at 32 s, median extraction at 55 s. First enemy alert at 9.0 s on average. Threat clock reached in 7 of 40 raids.
Notable: 11 of 40 raids ended before any crate was opened (half of all deaths); 17 of 22 deaths had the whole 12-round starting kit spent. Successful raids bring home a lot: on average about 55 ammo, 3.6 medkits, 16 scrap.
Hypotheses (need human play to confirm): the 12-round kit is too thin to get to the ammo, which sits in the guarded armory; extraction (about 55 s) happens long before the 120 s threat clock, so the clock rarely matters to an efficient player; successful raids return far more ammo and medkits than a next raid needs, and nothing can spend them yet.
Check next pass: compare bot extract rate and median death time before and after any rule change (`tools/playbot.gd`, 40 seeds); only trust a change in direction when it is large (more than about 15 points of extract rate).
