# Weapon table. Full damage out to "effective" metres, then it falls off
# linearly to FALLOFF_MIN of damage at "max", beyond which shots do nothing.
# damage is per pellet; spread is the random cone half-angle in radians.
# Art: "model" is an optional path to a .glb/.gltf/.tscn (e.g. "res://assets/weapons/pistol.glb") held at the
# lower right of the view; "" shows nothing. Add "model_scale" (default 1.0) to correct its size.
# Each shot spends ammo_per_shot of the backpack item ammo_item; with too little the weapon cannot fire.
# "zoom_fov": the camera's field of view while the right mouse button is held (75 normally); "scope": true shows the
# black scope overlay instead of the weapon and crosshair once zoomed.
# "tracer": how the bullet is drawn (scripts/tracer.gd): color, speed (m/s), size (m), trail (m, how far behind it the trail reaches),
# fade (s the trail lingers), sparks (on impact) and ricochet (m, the streak off a wall). Each weapon looks different.
# "clip" is how many rounds the magazine holds; one press of R reloads a full magazine from the backpack (switching weapon cancels it). The pistol holds 45% of the old 30.
const DATA := {
	"pistol": {"name": "Pistol", "damage": 25, "pellets": 1, "spread": 0.0, "cooldown": 0.25, "effective": 25.0, "max": 60.0, "sound": "shoot_pistol", "ammo_item": "ammo", "ammo_per_shot": 1, "clip": 14, "zoom_fov": 55.0, "tracer": {"color": Color(1.0, 0.85, 0.3), "speed": 90.0, "size": 0.035, "trail": 2.5, "fade": 0.15, "sparks": 5, "ricochet": 1.5}, "model": "res://assets/weapons/kenney_blaster_kit/blaster-k.glb", "model_scale": 0.6},
	"scattergun": {"name": "Scattergun", "damage": 14, "pellets": 8, "spread": 0.07, "cooldown": 0.9, "effective": 10.0, "max": 24.0, "sound": "shoot_scatter", "ammo_item": "ammo", "ammo_per_shot": 2, "clip": 30, "zoom_fov": 62.0, "tracer": {"color": Color(1.0, 0.5, 0.15), "speed": 60.0, "size": 0.028, "trail": 1.2, "fade": 0.18, "sparks": 3, "ricochet": 1.0}, "model": "res://assets/weapons/kenney_blaster_kit/blaster-a.glb", "model_scale": 0.6},
	"sniper": {"name": "Sniper Rifle", "damage": 100, "pellets": 1, "spread": 0.0, "cooldown": 1.4, "effective": 70.0, "max": 140.0, "sound": "shoot_sniper", "ammo_item": "ammo", "ammo_per_shot": 1, "clip": 5, "zoom_fov": 12.0, "tracer": {"color": Color(0.65, 0.9, 1.0), "speed": 220.0, "size": 0.05, "trail": 40.0, "fade": 0.9, "sparks": 9, "ricochet": 3.0}, "scope": true, "model": "res://assets/weapons/kenney_blaster_kit/blaster-k.glb", "model_scale": 0.85},
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
