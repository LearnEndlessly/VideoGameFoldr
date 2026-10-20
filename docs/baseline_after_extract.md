# Playbot baseline after the extract changes

Playbot, 40 seeds (1..40), one raid each, max 240 game seconds, run on 2026-10-20. Commit: 5f14fb8.
The bot is cautious and clumsy (see tools/playbot.gd) and not seeded for patrols or pellet spread: use this to compare builds, not to judge human difficulty, and trust only large differences.

| Metric | Value |
|---|---|
| Extract rate | 83% (33 of 40) |
| Death rate | 18% (7 of 40) |
| Timeout / no result | 0% (0 of 40) |
| Median time to extract (s) | 27.6 |
| Median time to death (s) | 156.2 |
| Median kills per raid | 3.5 |
| Raids where the threat clock started | 8 of 40 |
| Bot headed for extract A | 16 raids, 14 extracted, median time to extract 25.8 s |
| Bot headed for extract B | 21 raids, 17 extracted, median time to extract 30.8 s |

## Per seed

| Seed | Outcome | Time (s) | Kills | HP | Threat clock | Extract |
|---|---|---|---|---|---|---|
| 1 | dead | 153.7 | 5 | -13 | yes | B |
| 2 | extracted | 24.7 | 5 | 100 | no | B |
| 3 | extracted | 30.8 | 6 | 100 | no | B |
| 4 | extracted | 27.4 | 2 | 100 | no | A |
| 5 | extracted | 24.0 | 1 | 100 | no | A |
| 6 | extracted | 35.4 | 2 | 100 | no | B |
| 7 | extracted | 30.0 | 3 | 85 | no | A |
| 8 | dead | 124.7 | 5 | -5 | yes | - |
| 9 | extracted | 24.5 | 1 | 100 | no | A |
| 10 | extracted | 26.9 | 2 | 100 | no | A |
| 11 | extracted | 13.6 | 3 | 100 | no | - |
| 12 | extracted | 29.3 | 2 | 100 | no | B |
| 13 | extracted | 17.5 | 1 | 100 | no | A |
| 14 | extracted | 21.7 | 3 | 100 | no | B |
| 15 | extracted | 24.7 | 5 | 100 | no | B |
| 16 | extracted | 27.6 | 2 | 100 | no | A |
| 17 | dead | 161.8 | 7 | -29 | yes | B |
| 18 | dead | 156.2 | 7 | -29 | yes | B |
| 19 | dead | 158.0 | 10 | -14 | yes | B |
| 20 | extracted | 27.5 | 4 | 100 | no | B |
| 21 | extracted | 52.9 | 4 | 100 | no | B |
| 22 | extracted | 30.8 | 4 | 100 | no | B |
| 23 | extracted | 19.1 | 1 | 100 | no | A |
| 24 | extracted | 130.7 | 4 | 100 | yes | A |
| 25 | extracted | 35.1 | 4 | 62 | no | B |
| 26 | extracted | 38.3 | 9 | 100 | no | B |
| 27 | extracted | 41.2 | 2 | 100 | no | A |
| 28 | dead | 146.7 | 7 | -37 | yes | A |
| 29 | extracted | 19.9 | 2 | 100 | no | A |
| 30 | extracted | 28.8 | 5 | 100 | no | B |
| 31 | extracted | 19.5 | 1 | 100 | no | A |
| 32 | extracted | 20.5 | 2 | 60 | no | - |
| 33 | extracted | 34.5 | 6 | 100 | no | B |
| 34 | extracted | 31.6 | 3 | 100 | no | B |
| 35 | extracted | 27.9 | 4 | 70 | no | A |
| 36 | extracted | 25.8 | 3 | 100 | no | B |
| 37 | dead | 158.5 | 7 | -5 | yes | A |
| 38 | extracted | 31.1 | 3 | 100 | no | B |
| 39 | extracted | 24.8 | 2 | 100 | no | A |
| 40 | extracted | 29.4 | 4 | 100 | no | B |

## What changed, in plain language

Compared with `docs/baseline_before_extract.md` (same 40 seeds, same bot, run on the build just before the extract work):

- **Extract rate did not change:** 83% (33 of 40) both times. Deaths went from 13% to 18% (5 to 7 raids) and timeouts from 5% to 0% (2 to 0). Those two shifts are mostly the same raids moving between "dead" and "timed out", and the bot is not seeded, so this is within run-to-run noise. By the old rule of thumb (trust more than about 15 points), nothing here is a real change in how often the bot gets out.
- **Getting out is faster:** median time to extract fell from 34.4 s to 27.6 s (about 20%). The closer fast-route zone and a nearer safe-route zone mean the bot walks less before it can leave.
- **Time to death rose slightly** (140 s to 156 s) and the threat clock fired in 8 raids instead of 6. Small differences, not trustworthy on their own.
- **Which route the bot took:** it headed for the safe route (A) in 16 raids and the fast route (B) in 21 (3 raids ended before it chose). A: 14 of 16 extracted, median 25.8 s. B: 17 of 21 extracted, median 30.8 s, and its 12 s hold is part of why that is slower. B had 4 deaths in 21 raids against 2 in 16 for A, which fits the noise it makes, but the sample is far too small to say so.
- **The bot does not make the decision this change is about.** It walks to whichever zone is nearer when it finishes looting and never weighs the hold time or the noise, so this baseline cannot show whether players will weigh the two routes. Only play can.
- Seven seeds changed outcome between the two runs (4, 8, 13, 18, 19, 28, 32), in both directions, which is what bot noise plus a moved extract point looks like.

Nothing was tuned to improve these numbers.
