# Design review and statistics language

Labels: **[V]** verified by reading code/data. **[C]** computed from the real map generator (150 seeds, `main.gd` run headless, every crate opened) or from the tables. **[H]** hypothesis about player behaviour; there is no playtest data.

## Executive summary
1. The loop has no sink: scrap, repair_kit and banked ammo/medkits are never used anywhere [V]. Extracting only increments a counter, so "risk vs reward" has no reward to weigh yet.
2. Enemy aggro is distance-only (18 m, through walls) [V]; in 74% of generated maps an enemy starts within 18 m of the player [C]. Combat is mostly forced, not chosen.
3. The player outruns every enemy at no cost: sprint 10 m/s with no stamina, enemies 2-4.5 m/s [V]. Kiting means damage taken per kill can approach 0 [H], which would make health, medkits and shelters weak decisions.
4. The 12-slot backpack never overflowed in 150 maps even when looting every crate plus the starting kit (mean need 9.05, max 12) [C]. As tuned, the slot limit is a dead constraint.
5. Ammo is oversupplied: looting everything gives ~119 ammo (Armory alone ~91) versus ~35 pistol shots to kill all ~10 enemies at perfect accuracy [C]. The 12-round kit is about one enemy group [C].
6. Scattergun is nearly dominated by the pistol (equal dps, 3x the range, only 17% cheaper per kill at 8 m or less) [C].
7. All three loot zones are always present, ~20 m from the start and ~37-41 m from extract [C]: zone choice is a contents choice, not a risk choice.
8. Threat clock (180 s) vs a full sweep: the route is roughly 120-160 m, i.e. 15-30 s of travel [C estimate]; the clock probably rarely fires [H].
9. Instrument first: raid outcome/duration, zone visits, ammo burn and dry-fire, item use-through, damage per kill and time to first alert.

## 1. Cut / merge / tune table

| Element | Verdict | Reason (grounded) |
|---|---|---|
| scrap | defer (keep row, give it a sink) | Nothing reads it except the loot table [V]; only banked. Most common drop (weight 50; 60 in depot) with zero function. |
| repair_kit | cut from pools now (weight 0), keep row | No durability system exists [V]; duplicates scrap's "banked, unused" role. Re-add with durability. |
| medkit | keep | Only healing; 3.15 per fully looted raid [C]. Retune after Damage-per-Kill data. |
| ammo | keep, tune supply | Armory ammo mean 91 (p10 56, p90 138) [C] vs ~35 shots to kill everything [C]. Lower armory `qty_mult` 2.0 toward 1.0 if scarcity is wanted. |
| Starting kit (12) | keep | 12 shots = 300 dmg, about one average group (11.8 shots) at 100% accuracy [C]. |
| pistol | keep | 100 dps, 25 dmg per ammo, full damage to 25 m [V][C]. |
| scattergun | tune | 93 dps, 42 dmg per ammo, full damage to 8 m [C]. Needs a real niche (burst damage, cheaper ammo, armor piercing). Do not cut: a second weapon is the choice. |
| second ammo type | defer | Would create choices, but adds slot/loot complexity before any data. |
| grunt | keep | 2 pistol shots, 10 dmg/s, speed 3 [V]. |
| brute | keep | 6 shots, 25 dmg/s, speed 2 [V]; the "spend ammo or avoid" choice. |
| armored | keep | x2 HP doubles shots to kill (grunt 2 -> 4, brute 6 -> 12) [C]; a real ammo decision. |
| fast | tune | Grunt 4.5, brute 3.0 [V] are below the player's walk (6) and sprint (10), so it changes nothing. Needs speed above 6 (mult ~2.2) to matter. |
| Enemy groups (3 x 3-4) | keep | 10.45 enemies, 898 HP mean per map (p10 600, p90 1200) [C]. |
| Aggro rule (distance, no LOS) | tune (not a table row) | `enemy.gd` `_physics_process` calls `alert_pack()` at dist < SIGHT regardless of walls [V]. Makes cover and shelter screens irrelevant for stealth. |
| Cover shapes (5) | merge fat+block, defer the rest | Same colour; cover only blocks walking and bullets, not sight [V]. Count matters more than variety. Low confidence. |
| Loot zones (3) | tune | Always all three, all ~20 m from start [C]. Make one absent per map, or tie one to an enemy group, to create route choice. |
| Shelters (2) | keep, instrument | The only aggro reset; value depends on future healing/inventory systems. 21 m from start on average [C]. |
| Inventory slots (12) | tune | Overflow (full sweep + kit): 0% at 12, 15% at 10, 35% at 9, 65% at 8, 86% at 7 [C]. 8 gives real pressure for sweepers. |
| Extract hold (8 s) | keep | A grunt covers 24 m in 8 s (brute 16 m) [V]; meaningful lever. Damage does not interrupt it [V]. |
| Threat clock (180 s) | tune | See summary item 8. Try 90-120 s once duration data exists. |
| Sprint | tune | No cost, so walking is dominated [V]. Add stamina or make it noisy (detection radius). |
| Jump | cut or defer | Apex = 6^2/(2*20) = 0.9 m, below the lowest "long" cover (1.0 m) [C]; nothing needs it. |
| step_player sound | tune or cut | Implies a noise/stealth system that does not exist [V]. |
| Other sounds (16) | keep | Every one is played by some code path [V]; cost is a table row. |
| Health bars, aim line, enemy label | keep | Cheap information that makes ammo/range decisions informed. |
| Kill counter (HUD) | merge into results | Kills give no reward [V]; showing it implies value. |
| Profile totals | defer | Stores totals only, nothing is brought into a raid [V]. Without a sink, retention metrics mean little. |

Weapon comparison [C]:

| | Pistol | Scattergun (all pellets hit) |
|---|---|---|
| dps | 100 | 93 |
| dmg per ammo | 25 | 42 |
| avg ammo per enemy | 3.375 | 2.81 |
| full-damage range | 25 m | 8 m |

## 2. Vocabulary

### Grammar
`subject.verb.object`, lowercase, dots only. Fields carry ids from the data tables.

- subject: `player`, `enemy`, `raid`
- verb (fixed): `start`, `end`, `enter`, `leave`, `open`, `fire`, `kill`, `hit`, `alert`, `use`, `drop`, `switch`, `toggle`, `begin`, `cancel`, `sample`, `die`
- object (fixed): `raid`, `zone`, `crate`, `weapon`, `enemy`, `group`, `item`, `backpack`, `extract`, `clock`, `state`
- `id` comes from tables, so re-skinning is automatic: item id = `loot.ITEMS` key; weapon id = `weapons.DATA` key; enemy `id`/`mod` = `enemies.TYPES`/`MODIFIERS` keys; `zone` = `loot_zones.DATA` key or `shelter`, `extract`, `open`.
- A test asserts every emitted id exists in its table.

### Common fields (every line)
`ev` (name), `t` (raid seconds, 1 decimal), `pos` ([x, z], 1 decimal), `zone`, `hp`.

### Events (17)

| Event | Extra fields | Emitted from (not edited) |
|---|---|---|
| `raid.start.raid` | seed, w, d, session, n (raid number in session), enemies {type: n}, mods {mod: n}, tuning {threat_delay, hold, start_ammo} | `raid.gd` `setup()`; map facts from `main.gd` `_build_raid()` |
| `raid.end.raid` | outcome (extracted/dead/quit), loot {id: qty}, kills, shots, ammo_spent, exposed_s, cause | `raid.gd` `_finish()`; quit from a `main.gd` window-close notification |
| `player.enter.zone` / `player.leave.zone` | zone | shelter: `main.gd` `_set_safe()`; extract: `_on_zone_body()`; loot areas: 0.5 s poll in `raid.gd` `_physics_process` using `main.structures` rects |
| `player.open.crate` | zone, outcome (ok/full/far), taken {id: qty}, left {id: qty} | `raid.gd` `request_loot()` |
| `player.fire.weapon` | id, outcome (fired/dry), hits, dmg, range (to first hit), ammo_left | `raid.gd` `request_fire()` |
| `player.kill.enemy` | id=type, mod, group, weapon, range | `raid.gd` `request_fire()` where `take_damage` returns true |
| `enemy.alert.group` | group, cause (sight/shot/threat), dist | `enemy.gd` `alert_pack()` (add cause arg); dedupe per group |
| `enemy.hit.player` | id=type, mod, group, dmg, hp_after | `enemy.gd` `_physics_process` attack branch (needs a source arg on `player.take_damage`) |
| `player.die.raid` | cause (type), mod | `raid.gd` `_on_player_died()` |
| `player.use.item` | id, outcome (ok/none), hp_before | `player.gd` `use_slot()` (should become `raid.request_use()`, like the other intents) |
| `player.drop.item` | id, qty | `inventory_ui.gd` `_on_slot_input()` (should become `raid.request_drop()`) |
| `player.switch.weapon` | id (new), from | `player.gd` `select_weapon()` |
| `player.toggle.backpack` | open (bool), alerted (n enemies alert) | `player.gd` `_unhandled_input`, KEY_TAB |
| `player.begin.extract` | margin_s | `raid.gd` `request_extract()` (margin = nearest alert enemy dist / its speed - hold) |
| `player.cancel.extract` | progress_s | `raid.gd` `cancel_extract()` |
| `raid.start.clock` | alerted | `raid.gd` `_start_threat()` |
| `raid.sample.state` | ammo, slots_used, loot_n, alerted, near_dist, near_alert_dist | `raid.gd` `_physics_process`, every 5 s |

Mandatory for the first five measures: `raid.start/end`, `enter/leave.zone`, `open.crate`, `fire.weapon`, `use.item`, `enemy.hit.player`, `enemy.alert.group`, `begin/cancel.extract`.

### Output
JSON Lines, one object per event, one file per raid: `user://telemetry/raid_<unix>_<seed>.jsonl`. First line is `raid.start.raid`, last is `raid.end.raid`. Buffer in memory, flush every 30 s and at the end (a crash keeps most). Held by a small `scripts/stats.gd` object owned by the raid; tests inject an in-memory sink. `profile.json` is not touched. Cap at ~200 files (delete oldest).

## 3. Metrics

`N(ev)` = count of an event in a raid. Ranges are all [H].

### Decisions

| Metric | Meaning | Formula | Informs | Healthy |
|---|---|---|---|---|
| Effective Choices (EC) | How many options are really used | exp(-sum p_i ln p_i); p_i = share of `fire.weapon` by weapon (also crates by zone, uses by item) | weapons table | >= 0.6 x option count (weapons: >= 1.3 of 2). Near 1 = dominant option. |
| Zone Visit Rate | How often each zone is looted | raids with N(open.crate ok, zone) > 0 / raids | `loot_zones.DATA` | each 40-90%; all ~100% = no routing choice (predicted today). |
| Route Greed | Zones looted per raid | distinct zones in `open.crate ok` | zone count/spacing | median 1.5-2.5 of 3. |
| Range Fit | Weapons used where they are good | fires with range <= effective / fires that hit | weapon `effective` | 60-90% per weapon. |

### Resource pressure

| Metric | Meaning | Formula | Informs | Healthy |
|---|---|---|---|---|
| Ammo Burn Ratio | Share of available ammo spent | sum ammo cost of `fire fired` / (kit + sum ammo in `open.crate taken`) | `STARTING_AMMO`, armory qty | median 0.3-0.8; < 0.15 = ammo irrelevant (predicted today). |
| Dry-Fire Rate | Frustration from empty gun | N(fire dry) / N(fire) | ammo supply | raids with >= 1 dry: 5-25%; per shot < 5%. |
| Damage per Ammo | Efficiency | sum dmg / sum ammo vs theoretical (25 pistol, 42 scatter) | spread, falloff | 50-80% of theoretical. |
| Backpack Peak | Slot pressure | max `slots_used` / 12 from samples; share of `open.crate` with outcome full | slot count, stacks | median peak >= 0.6; full on 15-40% of raids. Predicted 0 today. |
| Min HP | How close raids get to death | min `hp` in the raid | enemy dmg, medkit | median 25-60. |
| Unspent Consumables | Medkits carried out unused | medkits taken - N(use ok), at `raid.end` | medkit value | extracted raids with >= 1 unspent: 20-60%. |

### Risk vs reward

| Metric | Meaning | Formula | Informs | Healthy |
|---|---|---|---|---|
| Exposed Seconds | Time with any enemy alert | `raid.end.exposed_s` (raid counts time with any alert) | sight, enemy count | 15-40% of raid time. |
| Reward per Exposure | Loot value per second at risk | sum(value x qty taken) / (exposed_s + 1); needs a `value` field in `loot.gd` | loot weights, qty | rising with greed; flat = no reward for risk. |
| Extract Margin | Safety when the hold starts | `begin.extract.margin_s` | `EXTRACT_HOLD_SECONDS` | 20-40% of attempts negative, median 0-8 s. |
| Abort Rate | Extract attempts abandoned | N(cancel.extract) / N(begin.extract) | hold time, zone size | 5-25%. |
| Late Loot | Looting after the clock | crates opened after `start.clock` / all crates | threat delay | 5-20%. |

### Pacing

| Metric | Meaning | Formula | Informs | Healthy |
|---|---|---|---|---|
| Time to First Loot | Wait before the first reward | t of first `open.crate ok` | map size, start spacing | 10-40 s. |
| Zone Dwell | Time inside each zone | sum(leave.t - enter.t) per zone | crate counts | depot 15-40 s, armory 10-25 s. |
| Raid Duration | How long raids run | `raid.end.t` | clock, map | median 40-75% of `threat_delay`. |
| Threat Reach Rate | Raids where the clock fires | raids with `start.clock` / raids | `THREAT_DELAY_SECONDS` | 20-50%. |
| Time Under Threat | Time after the clock | max(0, end.t - clock.t) | threat style | when reached, 20-90 s. |

### Dead elements

| Metric | Meaning | Formula | Informs | Healthy |
|---|---|---|---|---|
| Use-Through | Share of obtained items consumed | per item: sum use ok / sum taken | scrap, repair_kit, medkit | consumables 40-90%; ~0 for scrap/repair_kit today by construction. |
| Offered-Unused | Available but never touched | per id: raids where offered and N(use/fire/kill) = 0; flag if > 95% over >= 30 raids | any row | empty list, or deliberate. |
| Shelter Use | Shelters used when pressed | raids with `enter.zone shelter` within 30 s of an alert / raids with an alert | shelters | 10-40%. |
| Encounter-to-Kill | Enemy types actually fought | per type: kills / alerted groups containing it | enemy rows | brute 20-60%; ~0 = always avoided. |

### Difficulty

| Metric | Meaning | Formula | Informs | Healthy |
|---|---|---|---|---|
| Damage per Kill | HP lost per enemy killed | sum(hit dmg) / kills, by type/mod | enemy dmg, speed | grunt 3-15, brute 15-50; ~0 = kiting solves everything. |
| Time to First Alert | How fast trouble starts | t of first `alert.group` | spawn distance, sight | median 8-30 s. Predicted ~0-5 s in ~74% of maps [C]. |
| Alert Cause Mix | Who starts fights | share of cause sight/shot/threat | aggro rule | sight < 60%. |
| Deaths by Cause x Zone | Where and to what players die | count `die` by cause and last zone | placement, balance | no single cell > 40%. |
| Death Rate | Failure rate | deaths / raids | overall balance | 20-50%. |

### The loop

| Metric | Meaning | Formula | Informs | Healthy |
|---|---|---|---|---|
| Extract Rate | Raids ending extracted | extracted / raids | overall difficulty | 50-75%. |
| Raids per Session | Raids before the app closes | `raid.start` count per `session` | retention | median >= 4. |
| Quit-after-Death | Leaving on a loss | sessions whose last raid ended dead / sessions | death penalty | < 50%. |
| Kept Value per Raid | What a raid is worth | sum(value x qty in extracted loot) / raids | economy | rising with raid number. |

### Instrument first (5)
1. **Extract Rate + Raid Duration + Threat Reach Rate**: one `raid.end` line shows whether clock and difficulty matter at all.
2. **Zone Visit Rate / Route Greed**: shows whether routing is a choice or a full sweep (predicted: full sweep).
3. **Ammo Burn Ratio + Dry-Fire Rate**: tests the 3x ammo oversupply prediction.
4. **Use-Through** per item: confirms dead items and whether medkits get used.
5. **Damage per Kill + Time to First Alert**: tests the kiting and instant-aggro predictions.

## 4. Minimal implementation plan

| # | Step | Files | Test |
|---|---|---|---|
| 1 | `stats.gd`: `emit(name, fields)`, buffer, JSONL writer, in-memory sink | new `scripts/stats.gd` | write 3 events, read back, parse each line |
| 2 | Raid owns a stats object; emit `raid.start.raid`, `raid.end.raid` | `raid.gd`, `main.gd` | extend `profile_flow.gd`: first/last lines present, outcome matches |
| 3 | Emit `open.crate`, `fire.weapon`, `kill.enemy` in existing request functions | `raid.gd` | `ammo_threat.gd`: shots and ammo_left match inventory |
| 4 | Id validation: every emitted id exists in its table | new `tests/stats_ids.gd` | fails on a bad id |
| 5 | Route `use_slot` and drop through `raid.request_use/request_drop`, emit | `player.gd`, `inventory_ui.gd`, `raid.gd` | smoke: medkit use emits outcome ok |
| 6 | Damage source: `take_damage(amount, source)`; emit `hit.player`, `die.raid` | `player.gd`, `enemy.gd`, `raid.gd` | scripted enemy hit logged with type/mod |
| 7 | Alert cause, zone enter/leave, extract begin/cancel, clock | `enemy.gd`, `main.gd`, `raid.gd` | wave/continuous threat tests still pass |
| 8 | 5 s state sample incl. exposure counter | `raid.gd` | 60 s raid yields ~12 samples |
| 9 | Headless aggregator over `user://telemetry/*.jsonl` printing the metrics | new `tools/metrics.gd` | run on a synthetic folder |
| 10 | Add `value` to `loot.gd`; `session`/`n` to `raid.start` | `data/loot.gd`, `main.gd` | `check.gd` still passes |

Steps 1-4 already give metrics 1-3 of the first five.

## 5. What I could not determine
- Any real player behaviour: whether players kite, sprint, sweep every zone, or how long raids take.
- Raid duration: path lengths use straight-line zone distances (start-zone 20 m, zone-extract ~38 m); cover and aggro detours were not simulated.
- Enemy getting stuck behind cover (no pathfinding): not simulated, could make raids harder than the speed numbers suggest.
- Scattergun hit rate beyond ~8 m (random spread, no hit model run).
- Item value: `loot.gd` has no value field, so cross-item loot value cannot be compared yet.
- Quit/crash detection: only possible via a window-close notification.
- Whether the enemy-HP spread per map (p10 600 to p90 1200) is acceptable; that is a design call.
- Sound levels (README says synthesized without being heard).
