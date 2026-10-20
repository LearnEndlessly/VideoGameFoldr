# Playbot baseline before the extract changes

Playbot, 40 seeds (1..40), one raid each, max 240 game seconds, run on 2026-10-20. Commit: 8867f35.
The bot is cautious and clumsy (see tools/playbot.gd) and not seeded for patrols or pellet spread: use this to compare builds, not to judge human difficulty, and trust only large differences.

| Metric | Value |
|---|---|
| Extract rate | 83% (33 of 40) |
| Death rate | 13% (5 of 40) |
| Timeout / no result | 5% (2 of 40) |
| Median time to extract (s) | 34.4 |
| Median time to death (s) | 140.3 |
| Median kills per raid | 4 |
| Raids where the threat clock started | 6 of 40 |

## Per seed

| Seed | Outcome | Time (s) | Kills | HP | Threat clock | Extract |
|---|---|---|---|---|---|---|
| 1 | dead | 147.2 | 4 | -13 | yes | - |
| 2 | extracted | 28.2 | 1 | 100 | no | - |
| 3 | extracted | 29.8 | 1 | 100 | no | - |
| 4 | dead | 133.2 | 2 | -5 | yes | - |
| 5 | extracted | 24.3 | 3 | 100 | no | - |
| 6 | extracted | 24.2 | 1 | 100 | no | - |
| 7 | extracted | 57.7 | 4 | 85 | no | - |
| 8 | extracted | 46.7 | 6 | 100 | no | - |
| 9 | extracted | 24.4 | 1 | 100 | no | - |
| 10 | extracted | 61.1 | 9 | 85 | no | - |
| 11 | extracted | 94.6 | 6 | 87 | no | - |
| 12 | extracted | 34.4 | 3 | 100 | no | - |
| 13 | timeout | 240.0 | 0 | 100 | yes | - |
| 14 | extracted | 22.3 | 4 | 100 | no | - |
| 15 | extracted | 27.2 | 5 | 100 | no | - |
| 16 | extracted | 62.2 | 6 | 100 | no | - |
| 17 | dead | 143.6 | 6 | -5 | yes | - |
| 18 | extracted | 44.0 | 3 | 100 | no | - |
| 19 | timeout | 240.0 | 6 | 100 | yes | - |
| 20 | extracted | 34.4 | 3 | 100 | no | - |
| 21 | extracted | 59.4 | 4 | 85 | no | - |
| 22 | extracted | 29.9 | 3 | 85 | no | - |
| 23 | extracted | 22.5 | 0 | 100 | no | - |
| 24 | extracted | 103.4 | 6 | 100 | no | - |
| 25 | extracted | 34.2 | 6 | 87 | no | - |
| 26 | extracted | 58.7 | 2 | 100 | no | - |
| 27 | extracted | 60.8 | 6 | 100 | no | - |
| 28 | extracted | 38.7 | 7 | 57 | no | - |
| 29 | extracted | 53.8 | 6 | 64 | no | - |
| 30 | extracted | 17.2 | 2 | 100 | no | - |
| 31 | extracted | 19.4 | 1 | 100 | no | - |
| 32 | dead | 71.9 | 5 | -8 | no | - |
| 33 | extracted | 34.4 | 4 | 100 | no | - |
| 34 | extracted | 21.0 | 2 | 100 | no | - |
| 35 | extracted | 37.2 | 4 | 100 | no | - |
| 36 | extracted | 29.8 | 4 | 100 | no | - |
| 37 | dead | 140.3 | 9 | -5 | yes | - |
| 38 | extracted | 39.8 | 6 | 100 | no | - |
| 39 | extracted | 71.3 | 3 | 100 | no | - |
| 40 | extracted | 22.3 | 0 | 100 | no | - |
