# Weapon table. Full damage out to "effective" metres, then it falls off
# linearly to FALLOFF_MIN of damage at "max", beyond which shots do nothing.
# damage is per pellet; spread is the random cone half-angle in radians.
# Art: "model" is an optional path to a .glb/.gltf/.tscn (e.g. "res://assets/weapons/pistol.glb") held at the
# lower right of the view; "" shows nothing. Add "model_scale" (default 1.0) to correct its size.
# Each shot spends ammo_per_shot of the backpack item ammo_item; with too little the weapon cannot fire.
const DATA := {
	"pistol": {"name": "Pistol", "damage": 25, "pellets": 1, "spread": 0.0, "cooldown": 0.25, "effective": 25.0, "max": 60.0, "sound": "shoot_pistol", "ammo_item": "ammo", "ammo_per_shot": 1, "model": "res://assets/weapons/kenney_blaster_kit/blaster-k.glb", "model_scale": 0.6},
	"scattergun": {"name": "Scattergun", "damage": 14, "pellets": 8, "spread": 0.07, "cooldown": 0.9, "effective": 10.0, "max": 24.0, "sound": "shoot_scatter", "ammo_item": "ammo", "ammo_per_shot": 2, "model": "res://assets/weapons/kenney_blaster_kit/blaster-a.glb", "model_scale": 0.6},
}
const FALLOFF_MIN := 0.3

static func damage_at(w: Dictionary, dist: float) -> int:
	var eff: float = w["effective"]
	var mx: float = w["max"]
	var dmg: int = w["damage"]
	if dist <= eff:
		return dmg
	if dist >= mx:
		return 0
	return int(round(dmg * lerpf(1.0, FALLOFF_MIN, (dist - eff) / (mx - eff))))
