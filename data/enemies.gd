const Rng = preload("res://data/rng.gd")

# Ammo drops: when the player kills one, it leaves a pickup of "drop" [min, max] ammo with "drop_chance", and
# scrap ("scrap" [min, max] with "scrap_chance"), which repairs weapon attachments at the base.
# Art: "model" is an optional path to a .glb/.gltf/.tscn (e.g. "res://assets/enemies/grunt.glb")
# that replaces the placeholder capsule; "" keeps the capsule. Add "model_scale" (default 1.0)
# to correct a model's size; it is multiplied by "size". Models should have their origin at their feet.
const TYPES := {
	"grunt": {"weight": 75, "health": 50, "speed": 3.0, "damage": 15, "size": 1.0, "color": Color.RED, "model": "", "drop_chance": 0.5, "drop": [3, 6], "scrap_chance": 0.35, "scrap": [1, 2]},
	"brute": {"weight": 25, "health": 150, "speed": 2.0, "damage": 38, "size": 1.4, "color": Color.PURPLE, "model": "", "drop_chance": 0.8, "drop": [6, 12], "scrap_chance": 0.7, "scrap": [2, 4]},
}

const MODIFIER_CHANCE := 0.25
const MODIFIERS := {
	"armored": {"weight": 1, "health_mult": 2.0},
	"fast": {"weight": 1, "speed_mult": 2.4},  # a fast grunt (7.2 m/s) outruns a walking player
}

# Returns a stats dictionary: the type's stats plus a "type" and "modifier" name.
static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var type := Rng.pick(TYPES, rng)
	var e: Dictionary = TYPES[type].duplicate()
	e["type"] = type
	e["modifier"] = ""
	if rng.randf() < MODIFIER_CHANCE:
		var m := Rng.pick(MODIFIERS, rng)
		e["modifier"] = m
		e["health"] = int(e["health"] * MODIFIERS[m].get("health_mult", 1.0))
		e["speed"] = e["speed"] * MODIFIERS[m].get("speed_mult", 1.0)
	return e
