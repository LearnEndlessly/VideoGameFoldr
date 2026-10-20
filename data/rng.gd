# Weighted pick from a table. Entries are either {"weight": n, ...} or a plain number.
static func pick(table: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in table:
		total += _weight(table[k])
	var r := rng.randi_range(1, total)
	for k in table:
		r -= _weight(table[k])
		if r <= 0:
			return k
	return ""

static func _weight(entry) -> int:
	return entry["weight"] if entry is Dictionary else entry
