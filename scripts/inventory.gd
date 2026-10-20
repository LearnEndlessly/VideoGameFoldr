extends RefCounted

const Loot = preload("res://data/loot.gd")
const SLOTS := 12

signal changed

var slots: Array = []  # each entry is null or {"id": String, "qty": int}

func _init() -> void:
	slots.resize(SLOTS)

# Returns the quantity that did not fit.
func add(id: String, qty: int) -> int:
	var stack: int = Loot.ITEMS[id]["stack"]
	for s in slots:
		if qty > 0 and s != null and s["id"] == id and s["qty"] < stack:
			var n := mini(qty, stack - s["qty"])
			s["qty"] += n
			qty -= n
	for i in SLOTS:
		if qty > 0 and slots[i] == null:
			var n := mini(qty, stack)
			slots[i] = {"id": id, "qty": n}
			qty -= n
	changed.emit()
	return qty

func take_one(i: int) -> void:
	slots[i]["qty"] -= 1
	if slots[i]["qty"] <= 0:
		slots[i] = null
	changed.emit()

func drop(i: int) -> void:
	slots[i] = null
	changed.emit()

func summary() -> String:
	var totals := {}
	for s in slots:
		if s != null:
			totals[s["id"]] = totals.get(s["id"], 0) + s["qty"]
	var parts: PackedStringArray = []
	for k in totals:
		parts.append("%s x%d" % [k, totals[k]])
	return ", ".join(parts) if parts.size() > 0 else "nothing"
