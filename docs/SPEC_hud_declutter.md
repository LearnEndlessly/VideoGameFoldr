# Spec: HUD declutter and aim-laser fix

Status: **approved and implemented** (health top-left, no weapon name, one-colour laser).

## 1. Layout changes

| Element | Now | After |
|---|---|---|
| Health bar | bottom-center panel | **top-left**, with `KILLS n  SHOTS n` in small text beside or under it |
| Ammo slots + count | bottom-center, full size | **just under the crosshair**, much smaller (slots about 5 x 10 px, small count `11 / 18`) |
| "R to reload" tip | under the crosshair | stays, moves just below the small ammo row |
| Extract countdown | top-center | unchanged (health bar is top-left, so they do not collide) |
| Threat banner | below countdown | unchanged |
| Controls hint | bottom-left | unchanged |

## 2. Remove from the HUD

- Seed and map size (`Seed 3  Map 60x60 m`).
- The `Loot: ...` line (the Tab backpack already shows it).
- The weapon line: weapon name, `AMMO n (uses n)`, damage `25x1`, and falloff text (`full to 25m, falls off to 60m`).
- Keep only the status flags `[SAFE]` and `[PATROLS CONVERGING]`, top-left under the health bar.

Seed stays available for replays (`-- <seed>` on the command line and in telemetry). It is only hidden on screen.
`Player.weapon_text()` becomes unused; delete it if no test or tool needs it.

## 3. Laser shows range instead of text

The laser already has a green near segment, an orange far segment, and a hit dot. Falloff text is removed, so the laser alone has to say it:

- One beam, coloured by **where the target is**: green if the hit is within the weapon's `effective` range (full damage), orange if in the falloff band, grey/dim if nothing is hit within `max`.
- The hit dot uses the same colour.
- Both weapons use it automatically (ranges come from `data/weapons.gd`).

## 4. Laser lag fix

Cause (confirmed in `scripts/player.gd`): the laser is positioned in `_physics_process`, which runs at 60 Hz. Mouse look rotates the camera every rendered frame, so the laser is always one or more frames behind where you are aiming.

Fix: move `_update_aim()` from `_physics_process` to `_process`, so it runs after the camera rotates and every rendered frame. The beam meshes are already `top_level`, so no other change is needed. Shooting itself stays in physics.

## 5. Tests and verification

- Existing tests do not touch the HUD layout. Re-run `reload`, `smoke`, `ammo_threat`, `models`, and `seed_golden`.
- New test: laser colour is green inside `effective`, orange between `effective` and `max` (place a target at known distances).
- Re-run `godot-capture` and check `11_threat_banner` for overlaps. Laser smoothness cannot be judged from stills, so you would need to play it.

## Open questions

1. **Health bar corner:** top-left (proposed) or top-center?
2. **No weapon name on screen:** with the weapon line gone, only the crosshair shape (cross vs circle) shows which gun is equipped. OK, or show a tiny weapon name beside the ammo count?
3. **Laser colour:** is one colour for the whole beam (proposed) what you want, or keep the current two-segment green-then-orange look?
