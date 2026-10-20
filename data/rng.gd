# Weighted pick from a table shaped {key: {"weight": int, ...}}.
static func pick(table: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in table:
		total += table[k]["weight"]
	var r := rng.randi_range(1, total)
	for k in table:
		r -= table[k]["weight"]
		if r <= 0:
			return k
	return ""
