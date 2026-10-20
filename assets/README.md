# assets/

Art files live here. Nothing is required: every enemy and weapon falls back to its placeholder shape when its `model` field is empty or the file is missing.

Layout (create folders as you need them): `enemies/`, `weapons/`, `props/`, `textures/`, `audio/`.

## How to use a model
1. Copy the `.glb` (preferred) or `.gltf` into the right folder. Godot imports it on its own.
2. Set the path in the data table: `"model": "res://assets/enemies/grunt.glb"` in `data/enemies.gd` or `"model": "res://assets/weapons/pistol.glb"` in `data/weapons.gd`. If it looks too big or small, add `"model_scale": 0.5` (enemies are also scaled by their `size`).
3. Enemy models should have their origin at their feet and face forward (-Z). Weapon models are held at the lower right of the view.
4. **Add a line to `/CREDITS.md`** with the file, where it came from, its license and the URL. Do this when you add the file, not later.

## Keeping it light
- Low-poly, a few thousand triangles per enemy; textures 1024 px or less, or flat colours.
- Audio as OGG Vorbis.
- Stick to one visual style so assets from different packs look like one game.
- Only add assets whose license allows use in a game; prefer CC0. Avoid non-commercial licenses.
