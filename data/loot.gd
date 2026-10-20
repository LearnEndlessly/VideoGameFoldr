const Rng = preload("res://data/rng.gd")

# Item table. weight = crate chance, min/max = amount per roll, stack = max per slot,
# shape/color = the symbol drawn by item_icon.gd (gear, bullet, cross, diamond), heal = use effect.
# Names are neutral on purpose: re-skin the game by editing this table, not the code.
const ITEMS := {
	"scrap": {"weight": 50, "min": 1, "max": 3, "stack": 20, "shape": "gear", "color": Color(0.7, 0.7, 0.75)},
	"ammo": {"weight": 30, "min": 5, "max": 15, "stack": 30, "shape": "bullet", "color": Color(1.0, 0.8, 0.2)},
	"medkit": {"weight": 12, "min": 1, "max": 1, "stack": 3, "shape": "cross", "color": Color(0.9, 0.15, 0.15), "heal": 40},
	"repair_kit": {"weight": 8, "min": 1, "max": 1, "stack": 3, "shape": "diamond", "color": Color(0.3, 0.6, 1.0)},
}

# Returns [item_id, quantity].
static func roll(rng: RandomNumberGenerator) -> Array:
	var id := Rng.pick(ITEMS, rng)
	return [id, rng.randi_range(ITEMS[id]["min"], ITEMS[id]["max"])]
