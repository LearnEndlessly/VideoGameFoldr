const Rng = preload("res://data/rng.gd")

# Item table. (Crafting recipes live in data/recipes.gd.) repair_kit has weight 0 (never drops) until a durability system gives it a use.
# weight = crate chance, min/max = amount per roll, stack = max per slot,
# shape/color = the symbol drawn by item_icon.gd (gear, bullet, cross, diamond), heal = use effect.
# Names are neutral on purpose: re-skin the game by editing this table, not the code.
const ITEMS := {
	"ammo": {"weight": 30, "min": 5, "max": 15, "stack": 30, "shape": "bullet", "color": Color(1.0, 0.8, 0.2)},
	"medkit": {"weight": 12, "min": 1, "max": 1, "stack": 3, "shape": "cross", "color": Color(0.9, 0.15, 0.15), "heal": 40},
	"scrap": {"weight": 0, "min": 1, "max": 1, "stack": 30, "shape": "gear", "color": Color(0.6, 0.62, 0.66)},  # enemy drops only; repairs attachments
	"att_heavy_barrel": {"weight": 0, "min": 1, "max": 1, "stack": 1, "shape": "diamond", "color": Color(0.8, 0.4, 1.0)},  # attachments: see data/attachments.gd
	"att_compensator": {"weight": 0, "min": 1, "max": 1, "stack": 1, "shape": "diamond", "color": Color(0.8, 0.4, 1.0)},
	"att_scope": {"weight": 0, "min": 1, "max": 1, "stack": 1, "shape": "diamond", "color": Color(0.8, 0.4, 1.0)},
	"att_speed_loader": {"weight": 0, "min": 1, "max": 1, "stack": 1, "shape": "diamond", "color": Color(0.8, 0.4, 1.0)},
	"repair_kit": {"weight": 0, "min": 1, "max": 1, "stack": 3, "shape": "diamond", "color": Color(0.3, 0.6, 1.0)},
}

# Returns [item_id, quantity]. pool = which items can drop and how likely (default: the
# weights above); qty_mult scales the stack size (at least 1).
static func roll(rng: RandomNumberGenerator, pool: Dictionary = ITEMS, qty_mult: float = 1.0) -> Array:
	var id := Rng.pick(pool, rng)
	var qty: int = rng.randi_range(ITEMS[id]["min"], ITEMS[id]["max"])
	return [id, maxi(1, int(round(qty * qty_mult)))]
