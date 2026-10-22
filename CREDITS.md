# Credits

Every third-party asset in this project is listed here with its source and license. Add the line when you add the file.

| File | Source / author | License | URL |
|---|---|---|---|
| `assets/weapons/kenney_blaster_kit/*.glb` (all blasters including the Pistol `blaster-k`, Scattergun `blaster-a` and Sniper Rifle `blaster-e`; scopes, silencers, clips, bullets, grenades) and its `Textures/colormap.png` | Blaster Kit 2.1, Kenney | CC0 1.0 (`LICENSE.txt` beside them) | https://kenney.nl/assets/blaster-kit |
| `assets/props/kenney_blaster_kit/*.glb` (crates, targets) and its `Textures/` | Blaster Kit 2.1, Kenney | CC0 1.0 | https://kenney.nl/assets/blaster-kit |
| `assets/props/kenney_prototype_kit/*.glb` (shapes, crates, pipes, props) and its `Textures/` | Prototype Kit, Kenney | CC0 1.0 | https://kenney.nl/assets/prototype-kit |
| `assets/buildings/kenney_prototype_kit/*.glb` (walls, floors, doors, stairs, columns) and its `Textures/` | Prototype Kit, Kenney | CC0 1.0 | https://kenney.nl/assets/prototype-kit |
| `assets/buildings/kenney_modular_buildings/*.glb` (building cells, doors, windows, roofs) and its `Textures/` | Modular Buildings, Kenney | CC0 1.0 | https://kenney.nl/assets/modular-buildings |

Notes:
- CC0 needs no attribution; Kenney asks for credit ("Kenney" or www.kenney.nl) but does not require it. It is listed here anyway so the origin is traceable.
- The full Kenney downloads (`assets/kenney_blaster-kit_2.1/`, `assets/kenney_prototype-kit/`) are kept for reference only. They are git-ignored and hidden from Godot with `.gdignore`; the models copied out of them into `assets/weapons`, `assets/props` and `assets/buildings` are the ones the game can load (the game uses a subset; see assets/README.md).
- CC-BY assets need attribution: keep the author's name and link here (and in the game's credits screen when one exists).
- Do not add assets under non-commercial or unclear licenses.
- Sound effects in the game are synthesized from `data/sounds.gd`; they are not third-party files.
