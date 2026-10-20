# assets/

Art files live here. Nothing is required: every enemy and weapon falls back to its placeholder shape when its `model` field is empty or the file is missing.

## Layout
```
assets/
  weapons/kenney_blaster_kit/      weapons and their parts: blaster-a..r, scope-*, silencer-*, clip-*, bullet-foam*, grenade-*, smoke
  props/kenney_blaster_kit/        crate-small / crate-medium / crate-wide, target-*
  props/kenney_prototype_kit/      the Prototype Kit's shapes and props: shape-*, crate*, pipe*, target-*, vehicle*, animal*, number-*, ...
  buildings/kenney_prototype_kit/  its level pieces: wall*, floor*, door*, stairs*, ladder*, column*, indicator-doorway
  kenney_blaster-kit_2.1/          the raw download (FBX, OBJ, previews), for reference only: git-ignored, hidden from Godot
  kenney_prototype-kit/            the same for the Prototype Kit
```
Each organized folder holds `.glb` models, their `Textures/` folder (the models point at `Textures/colormap.png`, so keep it beside them) and the kit's `LICENSE.txt` (CC0). Pick a model with `tools/preview_models.gd`, which renders a row of them to a PNG.

## What the game uses
- Weapons (`data/weapons.gd`): pistol `blaster-k`, scattergun `blaster-a`, sniper rifle `blaster-e`.
- Weapon attachments on the ground (`data/attachments.gd`): `silencer-larger` (Heavy Barrel), `silencer-small` (Compensator), `clip-large` (Speed Loader), `scope-large-a` (Scope).
- Loot crates: `props/kenney_blaster_kit/crate-medium`.
- Cover (`data/scenery.gd`): `shape-cube-rounded`, `column`, `wall`, `shape-cube` stretched over each cover box.
- Map and buildings (`scripts/main.gd`): `wall` for the perimeter and every building and shelter wall, `floor-thick` for the ground and roofs. `scripts/model.gd` `load_fitted()` stretches a piece to the box it replaces and tints it with the box's colour; collision stays the plain box.

## How to use a model
1. Copy the `.glb` (preferred) or `.gltf` into the right folder, with its `Textures/` folder. Godot imports it on its own.
2. Set the path in the data table: `"model": "res://assets/weapons/kenney_blaster_kit/blaster-e.glb"` in `data/weapons.gd`, `"model"` in `data/enemies.gd`, `data/scenery.gd` or `data/attachments.gd`. If it looks too big or small, add `"model_scale": 0.5` (enemies are also scaled by their `size`).
3. Enemy models should have their origin at their feet and face forward (-Z). Weapon models are held at the lower right of the view.
4. **Add a line to `/CREDITS.md`** with the folder, where it came from, its license and the URL. Do this when you add the file, not later.

## Keeping it light
- Low-poly, a few thousand triangles per enemy; textures 1024 px or less, or flat colours.
- Audio as OGG Vorbis.
- Stick to one visual style so assets from different packs look like one game.
- Only add assets whose license allows use in a game; prefer CC0. Avoid non-commercial licenses.
