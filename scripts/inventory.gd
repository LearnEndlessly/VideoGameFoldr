extends RefCounted

const Loot = preload("res://data/loot.gd")
const SLOTS: int = preload("res://data/tuning.gd").BACKPACK_SLOTS

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

func count(id: String) -> int:
	return totals().get(id, 0)

# Removes qty of an item (from the last slots first). Returns false, changing nothing, if there is less than qty.
func remove(id: String, qty: int) -> bool:
	if count(id) < qty:
		return false
	for i in range(SLOTS - 1, -1, -1):
		var s = slots[i]
		if qty > 0 and s != null and s["id"] == id:
			var n := mini(qty, s["qty"])
			s["qty"] -= n
			qty -= n
			if s["qty"] <= 0:
				slots[i] = null
	changed.emit()
	return true

func take_one(i: int) -> void:
	slots[i]["qty"] -= 1
	if slots[i]["qty"] <= 0:
		slots[i] = null
	changed.emit()

func drop(i: int) -> void:
	slots[i] = null
	changed.emit()

func clear() -> void:
	slots.fill(null)
	changed.emit()

# item id -> total quantity across all slots.
func totals() -> Dictionary:
	var t := {}
	for s in slots:
		if s != null:
			t[s["id"]] = t.get(s["id"], 0) + s["qty"]
	return t

func summary() -> String:
	var t := totals()
	var parts: PackedStringArray = []
	for k in t:
		parts.append("%s x%d" % [k, t[k]])
	return ", ".join(parts) if parts.size() > 0 else "nothing"
