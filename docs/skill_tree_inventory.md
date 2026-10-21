# Skill tree: inventory of what the tree replaces

Written from the code (Phase 1 of the Offense-wedge skill tree). Nothing here is implemented yet.

## The two existing "upgrade" systems (only one is purchased)

| System | Earned | Lasts | Spent where | Replaced by the tree? |
|---|---|---|---|---|
| **Raid upgrades** (`RAID_UPGRADES` in `data/upgrades.gd`: Heavy rounds, Rapid fire, Vitality, Fleet foot, Quick hands, Plating, Moon boots) | XP level-ups during a raid | Until the raid ends (kept on a descent) | Picked on the pause screen, not bought | **No.** They are raid state, not profile data. They stay and stack on top of the tree's numbers. |
| **Attributes** (`ATTRS`, 35 of them in 5 groups, up to 5 levels each, 15 points in all) | `Profile.grant_point()` | Permanent, in the profile | The Character station in the base (`hub.gd`) | **Yes.** |

The stash-paid weapon upgrades from earlier builds are already gone (old saves' weapon levels are ignored on load), so there is no "flat upgrade purchasing" left to remove other than the attributes.

## Every attribute, and where its stat is applied

`Profile.bonus(stat)` sums `level x per-level` over `attrs` and is the single read path. Hooks:

| Group | Attributes (stat) | Applied in |
|---|---|---|
| OFFENSE (13) | Marksman (`damage`), Trigger discipline (`firerate`), Weapon handling (`reload`), Steady hands (`spread`), Long shot (`range`), Eagle eye (`zoom`), Extended mags (`clip`), Thrifty (`ammo_save`), Lethal (`crit`), Sidearm / Close quarters / Long gun (`dmg_pistol`, `dmg_scattergun`, `dmg_sniper`), Ambusher (`dmg_unaware`) | `raid.gd`: `_apply_upgrades` (damage, firerate), `fire` (spread, range, ammo_save, crit, `dmg_<weapon>`, `dmg_unaware`), `clip_size`, zoom; `profile.reload_mult()` -> `main.gd:212` `raid.reload_seconds`, and `hub.gd:625` for the display |
| DEFENSE (6) | Constitution (`hp`, `armor`), Regeneration (`regen`), Bloodlust (`kill_heal`), Field medic (`heal_mult`), Evasion (`dodge`), Last stand (`last_stand`) | `player.gd:apply_profile` (hp, armor, dodge, last_stand, heal_mult); `raid.gd` (regen tick, kill_heal) |
| MOBILITY (5) | Speed (`speed`), Sprinter (`sprint_speed`), Spring legs (`jump_height`), Ghost (`stealth`), Quick exit (`extract_speed`) | `player.gd:apply_profile`; `enemy.gd` reads `player.stealth`; `raid.gd:445` extract hold |
| SCAVENGING (8) | Scavenger (`ammo_drop`), Salvager (`scrap_find`), Prospector (`att_find`), Lucky (`powerup_find`), Lasting power (`powerup_time`), Quartermaster (`start_ammo`), Careful hands (`att_wear`), Tinkerer (`repair_cost`) | `raid.gd` drops and powerups; `main.gd:213` starting ammo; `profile.repair_cost()` |
| MASTERY (3) | Quick study (`xp_gain`), Adrenaline (`combo_time`), Showboat (`combo_score`) | `raid.gd` XP and combo code |

Other readers: `hub.gd:716-718` (the Character station tiles: spent, health, armor), `hub.gd:706-753` (the attribute cards and the `+` buttons), `screen_ui.gd:51` (the "attribute pts" tile on the end screen), `main.gd:244` (the "NEW ATTRIBUTE POINT" banner), `tools/capture_base.gd`.

## How points are earned and saved today (differs from the brief)

- **Points come from clearing a round, not from extracting.** `raid.gd:597-608`: every round (`ATTR_ROUNDS_PER_POINT` is 1; it was 5 until the owner changed it), once every enemy and every enemy base is dead, `profile.grant_point()` adds one point. It is saved at once, so dying afterwards keeps it. The end screen only reports `points_earned`.
- **Hard cap of 15** (`ATTR_TOTAL_MAX`): unspent + spent can never exceed it, and `grant_point()` refuses beyond it. `ATTR_LEVEL_MAX` is 5 per attribute.
- Saved in `profile.json` (`Tuning.PROFILE_PATH`), **version 2**, atomic write via `.tmp` + rename. Fields: `attrs` (id -> level), `points` (unspent). `load_from_disk` clamps levels and trims a hand-edited save to the cap.
- `RESET_ON_LAUNCH` wipes the real profile at launch in a real run (README), so a player's points currently do not survive a restart. Tests use scratch profiles.

## Tests that touch the old system

`tests/attributes.gd` (58 references, nearly all of the 35 hooks), `tests/base.gd` (12), `tests/combo.gd` (4: sets `attrs` for Adrenaline/Showboat), `tests/raid_upgrades.gd` (1: asserts raid upgrades do not leak into `attrs`), `tools/capture_base.gd`. These are ported or deleted in Phase 3, before the old purchasing code goes.

## Proposed migration (save version 2 -> 3)

1. On load, if `version < 3`: copy the file to `profile.json.v2.bak` (never overwritten if it exists), then set `unspent_points = points + sum(attrs levels)`, `allocated_nodes = []`, and drop `attrs`. Everything else (stash, attachments, difficulty, stats) is untouched.
2. Save as version 3 with the same atomic write. Fields added: `allocated_nodes` (array of node ids), `unspent_points`. `points` and `attrs` are no longer written.
3. Refunds are total and free, so no one loses anything. Players re-spend into the tree.

## Wiring plan (Phase 3), to keep the diff small

- Keep `Profile.bonus(stat)` and its ~30 call sites. Change only its body to ask the stat resolver (UI-free script) for the tree's total, so `raid.gd` and `player.gd` need no edits for stats the tree provides.
- Stats no wedge grants return 0 until their wedge exists. That switches off 22+ shipped attribute effects (all of Defense, Mobility except what the spokes give, Scavenging except ammo, Mastery, and the offense attributes the Offense wedge leaves out: `firerate`, `zoom`, `clip`, `crit`, `dmg_sniper`, `dmg_unaware`). See the open decisions in the Phase 1 report.
- The resolver needs a test override (a dict of stat totals) so `combo.gd` and similar tests can set a stat without allocating nodes.
- Raid upgrades keep adding on top inside `raid.gd:_apply_upgrades` (they start from `_base`, which is read from the player after `apply_profile`), so nothing there changes.
- Backpack slots are `Tuning.BACKPACK_SLOTS` read into a constant in `inventory.gd`; no attribute touches it today, and the Offense slice does not need it.
