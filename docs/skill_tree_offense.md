# Skill tree: Offense wedge node table

Design for the first vertical slice. Rows go in `data/skill_nodes.gd`, numbers in `data/tuning.gd`. Positions are in screen units (1 unit is about 60 px at zoom 1), hub at (0, 0), **y grows downward**, so Offense is above the hub.

Every stat below already exists in the game (names from `data/upgrades.gd` `STATS`). Sign convention is the game's: positive is better (`reload` +0.05 = 5% faster reloads, `spread` +0.08 = 8% tighter, `extract_speed` +0.01 = 1% shorter hold). A cost on a notable is a negative value. Two stats in the brief do not exist as written; see **Assumptions**.

## Thresholds and costs (all in `data/tuning.gd`)

| Key | Value | Meaning |
|---|---|---|
| `SKILL_GATEWAY_REQ` | 4 | attribute total a gateway needs |
| `SKILL_NOTABLE_REQ` | 6 | attribute total a notable needs |
| `SKILL_NODE_COST` | 1 | points per node |
| `SKILL_REFUND_AMMO` | 10 | ammo spent to refund a node (placeholder, see Assumptions) |

## Layout

```
                  BN2      MN1  MN2      ON2
                    \       |    |       /
               B4 -- B3    M2 -- M3    O3 -- O4        (y -9 .. -6)
                |     \    |  M4  |    /     |
               B2 --- B1   M1        O1 --- O2
                |      \   |        /       |
               BN1      GB GM      GO       ON1
                         \ | /
                          T2
                          T1
   STR S8..S1 ----------- HUB ----------- I1..I8 INT
                          D1
                           :
                          D8 DEX
```

Spokes run straight out from the hub: STR left, INT right, DEX down. The gateway you want is up top, the attribute that unlocks it is a long walk away, which is the point: attributes are paid for separately from the route.

## Fixed nodes

| id | kind | name | pos | links | requires | effects |
|---|---|---|---|---|---|---|
| hub | hub | Hub | (0, 0) | S1, D1, I1, T1 | | none (never allocated, always connected) |
| T1 | trunk | Offense I | (0, -1.5) | hub, T2 | | damage +3% increased |
| T2 | trunk | Offense II | (0, -3) | T1, GB, GM, GO | | damage +3% increased |

## Attribute spokes (24 nodes, 8 each)

Each node gives +1 of its attribute (counted from the allocated attribute nodes, nothing else adds attributes) plus the flat stat below. Chains: hub - S1 - S2 ... S8, and the same for D and I.

| spoke | ids | pos (x, y) | per node |
|---|---|---|---|
| Strength | S1..S8 | (-1.5, 0), (-3, 0) ... (-12, 0) | +4 max hp (flat) |
| Dexterity | D1..D8 | (0, 1.5), (0, 3) ... (0, 12) | +0.6% move speed (increased), +1% reload (increased) |
| Intelligence | I1..I8 | (1.5, 0), (3, 0) ... (12, 0) | +0.25 m crate reach (flat), +1% shorter extract hold (increased) |

At 8 nodes: STR +32 hp; DEX +4.8% speed and +8% reload; INT +2 m crate reach and 8% shorter extract hold.

## Brutality (STR gate): close-range damage and scattergun power

| id | kind | name | pos | links | requires | effects |
|---|---|---|---|---|---|---|
| GB | gateway | Brute Force | (-2.5, -4.5) | T2, B1 | STR 4 | damage +4% |
| B1 | minor | Heavy Shells | (-3.5, -6) | GB, B2, B3 | | dmg_scattergun +5% |
| B2 | minor | Close Work | (-5, -5) | B1, B4, BN1 | | damage +3%, hp +4 |
| B3 | minor | Stout | (-4.5, -7.5) | B1, B4, BN2 | | hp +8 |
| B4 | minor | Packed Charge | (-6, -6.5) | B2, B3 | | dmg_scattergun +5% |
| BN1 | notable | Point Blank | (-6.5, -3.5) | B2 | STR 6 | dmg_scattergun +30%, range -15% |
| BN2 | notable | Hammer Blow | (-6, -9) | B3 | STR 6 | damage +12%, reload -15% |

- **Point Blank:** now I would carry the scattergun and clear rooms from the doorway instead of trading pistol shots across the yard.
- **Hammer Blow:** now I would fire deliberate shots and reload only behind cover instead of topping up the clip mid-fight.

## Marksmanship (DEX gate): pistol range, spread, reload

`range` is global in this game (it scales the "effective" distance of whatever weapon is held), so these help the sniper too.

| id | kind | name | pos | links | requires | effects |
|---|---|---|---|---|---|---|
| GM | gateway | Steady Aim | (0, -4.5) | T2, M1 | DEX 4 | spread +8% |
| M1 | minor | Sight Picture | (0, -6) | GM, M2, M3 | | range +5% |
| M2 | minor | Smooth Draw | (-1.5, -7) | M1, M4, MN1 | | reload +5% |
| M3 | minor | Hold Breath | (1.5, -7) | M1, M4, MN2 | | spread +8% |
| M4 | minor | Sidearm Drill | (0, -8.5) | M2, M3 | | dmg_pistol +6% |
| MN1 | notable | Dead Eye | (-1.5, -9.5) | M2 | DEX 6 | range +25%, dmg_pistol +15%, speed -6% |
| MN2 | notable | Fast Cycle | (1.5, -9.5) | M3 | DEX 6 | reload +35%, damage -5% |

- **Dead Eye:** now I would hold a lane and shoot from 40 m instead of sprinting to close the distance.
- **Fast Cycle:** now I would reload the moment a fight pauses instead of nursing the last rounds in the clip.

## Ordnance (INT gate): ammo efficiency, ammo drop, starting ammo

`ammo_drop` in this game is the chance a kill drops ammo (x`1 + value`), not the amount in the drop; see Assumptions.

| id | kind | name | pos | links | requires | effects |
|---|---|---|---|---|---|---|
| GO | gateway | Supply Line | (2.5, -4.5) | T2, O1 | INT 4 | ammo_drop +6% |
| O1 | minor | Lean Rounds | (3.5, -6) | GO, O2, O3 | | ammo_save +3% |
| O2 | minor | Deep Pockets | (5, -5) | O1, O4, ON1 | | start_ammo +4 |
| O3 | minor | Scrounger | (4.5, -7.5) | O1, O4, ON2 | | ammo_drop +8% |
| O4 | minor | Tight Loads | (6, -6.5) | O2, O3 | | ammo_save +3% |
| ON1 | notable | Hoarder | (6.5, -3.5) | O2 | INT 6 | start_ammo +14, ammo_save +6% |
| ON2 | notable | Salvage Run | (6, -9) | O3 | INT 6 | ammo_drop +35%, extract_speed -10% |

- **Hoarder:** now I would take the ammo-hungry scattergun (2 rounds a shot) instead of the pistol.
- **Salvage Run:** now I would stay and fight the grunts for their drops instead of heading for the exit early.

## Counts and cost to reach things

Per subordinate tree: 1 gateway, 4 minor (57%), 2 notable (29%). Allocatable nodes in the slice: 24 attribute + 2 trunk + 21 subtree = 47.

| goal | points |
|---|---|
| a gateway (4 attribute + 2 trunk + gateway) | 7 |
| a whole subtree (6 attribute + 2 trunk + 7) | 15 |
| a whole subtree plus one more attribute node | 16 |

So the three Phase 5 builds (about 16 points) each finish their subtree and have one point left over. Within a subtree there is no scarcity at 16 points: the real decision is which subtree, and how many STR/DEX/INT to buy beyond the thresholds. If you want in-tree choices, widen each subtree (more nodes than the budget) or raise the notable threshold; both are row/tuning edits.

## Stat limits (`data/tuning.gd`, `SKILL_STAT_LIMITS`)

| stat | min | max |
|---|---|---|
| hp (flat total) | 0 | 300 |
| speed | -30% | +40% |
| reload | -50% | +100% |
| spread | 0 | +60% |
| range | -50% | +100% |
| damage, dmg_pistol, dmg_scattergun | -50% | +200% |
| ammo_save | 0 | +50% |
| ammo_drop | 0 | +200% |
| start_ammo (flat) | 0 | 60 |
| extract_speed | -50% | +50% (hold never under 50% of base) |
| crate reach (flat metres) | 0 | 2 |

## Assumptions in this table (please confirm or edit)

1. **Crate detection range does not exist.** Nothing in the game detects crates; the closest thing is how far E reaches a crate (3 m in `player.gd`, with a 4 m server check `LOOT_REACH`). I wrote "crate reach" at +0.25 m per INT point (+1 m per point would make 8 points = +8 m, more than twice the base reach). It needs one new stat and one hook. Alternative: drop it and give INT only the extract hold.
2. **Pistol range does not exist per weapon.** `range` is global, so Marksmanship's range nodes help every weapon.
3. **"Ammo drop amount" is a chance today.** `ammo_drop` raises the drop chance. The amount is the enemy's `drop [min, max]`. I used the chance. A true amount stat would be new.
4. **"Close-range damage"** is `damage` plus the scattergun-specific stat; there is no distance-based damage stat.
5. **Refund cost** is 10 ammo taken from the stash, a placeholder in tuning. There is no gold or scrap sink I should assume; scrap is reserved for attachment repair.
6. **Trunk nodes give +3% damage each** so the connectors are not dead weight. Set the value to 0 if you want pure routing.
7. **Costs on notables** (negative range, speed, reload, damage, extract hold) are what makes each a decision. They use the same stats and caps; no new mechanic.
8. Positions are a straight cross for spokes and a mirrored Brutality/Ordnance with Marksmanship centered. They are a starting layout, easy to nudge in the rows.
