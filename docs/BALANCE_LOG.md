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
