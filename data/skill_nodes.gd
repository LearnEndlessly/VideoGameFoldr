# Skill tree nodes, one row per node. Tune the tree by editing rows, never code (thresholds and caps are in data/tuning.gd).
# id, tree, kind (attribute | trunk | minor | notable | gateway), name, pos (x, y screen units, y grows down), links (undirected:
# a link listed on either row counts), requires {attribute: total needed}, effects [{stat, mod "flat" | "increased", value}].
# Stat names are those of data/upgrades.gd STATS (positive is better: reload 0.05 = 5% faster); loot_reach is metres of E reach.
# "attr" on an attribute node says which of ATTRS it adds one of. The hub is not a row: HUB_LINKS are the nodes it touches.
const HUB := "hub"
const HUB_LINKS := ["S1", "D1", "I1", "T1"]
const HUB_POS := Vector2(0, 0)
const ATTRS := ["str", "dex", "int"]
const NODES := [
	{"id": "S1", "tree": "spoke", "kind": "attribute", "attr": "str", "name": "Strength 1", "pos": Vector2(-1.5, 0), "links": ["S2"], "requires": {}, "effects": [{"stat": "hp", "mod": "flat", "value": 4.0}]},
	{"id": "S2", "tree": "spoke", "kind": "attribute", "attr": "str", "name": "Strength 2", "pos": Vector2(-3, 0), "links": ["S1", "S3"], "requires": {}, "effects": [{"stat": "hp", "mod": "flat", "value": 4.0}]},
	{"id": "S3", "tree": "spoke", "kind": "attribute", "attr": "str", "name": "Strength 3", "pos": Vector2(-4.5, 0), "links": ["S2", "S4"], "requires": {}, "effects": [{"stat": "hp", "mod": "flat", "value": 4.0}]},
	{"id": "S4", "tree": "spoke", "kind": "attribute", "attr": "str", "name": "Strength 4", "pos": Vector2(-6, 0), "links": ["S3", "S5"], "requires": {}, "effects": [{"stat": "hp", "mod": "flat", "value": 4.0}]},
	{"id": "S5", "tree": "spoke", "kind": "attribute", "attr": "str", "name": "Strength 5", "pos": Vector2(-7.5, 0), "links": ["S4", "S6"], "requires": {}, "effects": [{"stat": "hp", "mod": "flat", "value": 4.0}]},
	{"id": "S6", "tree": "spoke", "kind": "attribute", "attr": "str", "name": "Strength 6", "pos": Vector2(-9, 0), "links": ["S5", "S7"], "requires": {}, "effects": [{"stat": "hp", "mod": "flat", "value": 4.0}]},
	{"id": "S7", "tree": "spoke", "kind": "attribute", "attr": "str", "name": "Strength 7", "pos": Vector2(-10.5, 0), "links": ["S6", "S8"], "requires": {}, "effects": [{"stat": "hp", "mod": "flat", "value": 4.0}]},
	{"id": "S8", "tree": "spoke", "kind": "attribute", "attr": "str", "name": "Strength 8", "pos": Vector2(-12, 0), "links": ["S7"], "requires": {}, "effects": [{"stat": "hp", "mod": "flat", "value": 4.0}]},
	{"id": "D1", "tree": "spoke", "kind": "attribute", "attr": "dex", "name": "Dexterity 1", "pos": Vector2(0, 1.5), "links": ["D2"], "requires": {}, "effects": [{"stat": "speed", "mod": "increased", "value": 0.006}, {"stat": "reload", "mod": "increased", "value": 0.01}]},
	{"id": "D2", "tree": "spoke", "kind": "attribute", "attr": "dex", "name": "Dexterity 2", "pos": Vector2(0, 3), "links": ["D1", "D3"], "requires": {}, "effects": [{"stat": "speed", "mod": "increased", "value": 0.006}, {"stat": "reload", "mod": "increased", "value": 0.01}]},
	{"id": "D3", "tree": "spoke", "kind": "attribute", "attr": "dex", "name": "Dexterity 3", "pos": Vector2(0, 4.5), "links": ["D2", "D4"], "requires": {}, "effects": [{"stat": "speed", "mod": "increased", "value": 0.006}, {"stat": "reload", "mod": "increased", "value": 0.01}]},
	{"id": "D4", "tree": "spoke", "kind": "attribute", "attr": "dex", "name": "Dexterity 4", "pos": Vector2(0, 6), "links": ["D3", "D5"], "requires": {}, "effects": [{"stat": "speed", "mod": "increased", "value": 0.006}, {"stat": "reload", "mod": "increased", "value": 0.01}]},
	{"id": "D5", "tree": "spoke", "kind": "attribute", "attr": "dex", "name": "Dexterity 5", "pos": Vector2(0, 7.5), "links": ["D4", "D6"], "requires": {}, "effects": [{"stat": "speed", "mod": "increased", "value": 0.006}, {"stat": "reload", "mod": "increased", "value": 0.01}]},
	{"id": "D6", "tree": "spoke", "kind": "attribute", "attr": "dex", "name": "Dexterity 6", "pos": Vector2(0, 9), "links": ["D5", "D7"], "requires": {}, "effects": [{"stat": "speed", "mod": "increased", "value": 0.006}, {"stat": "reload", "mod": "increased", "value": 0.01}]},
	{"id": "D7", "tree": "spoke", "kind": "attribute", "attr": "dex", "name": "Dexterity 7", "pos": Vector2(0, 10.5), "links": ["D6", "D8"], "requires": {}, "effects": [{"stat": "speed", "mod": "increased", "value": 0.006}, {"stat": "reload", "mod": "increased", "value": 0.01}]},
	{"id": "D8", "tree": "spoke", "kind": "attribute", "attr": "dex", "name": "Dexterity 8", "pos": Vector2(0, 12), "links": ["D7"], "requires": {}, "effects": [{"stat": "speed", "mod": "increased", "value": 0.006}, {"stat": "reload", "mod": "increased", "value": 0.01}]},
	{"id": "I1", "tree": "spoke", "kind": "attribute", "attr": "int", "name": "Intelligence 1", "pos": Vector2(1.5, 0), "links": ["I2"], "requires": {}, "effects": [{"stat": "loot_reach", "mod": "flat", "value": 0.25}, {"stat": "extract_speed", "mod": "increased", "value": 0.01}]},
	{"id": "I2", "tree": "spoke", "kind": "attribute", "attr": "int", "name": "Intelligence 2", "pos": Vector2(3, 0), "links": ["I1", "I3"], "requires": {}, "effects": [{"stat": "loot_reach", "mod": "flat", "value": 0.25}, {"stat": "extract_speed", "mod": "increased", "value": 0.01}]},
	{"id": "I3", "tree": "spoke", "kind": "attribute", "attr": "int", "name": "Intelligence 3", "pos": Vector2(4.5, 0), "links": ["I2", "I4"], "requires": {}, "effects": [{"stat": "loot_reach", "mod": "flat", "value": 0.25}, {"stat": "extract_speed", "mod": "increased", "value": 0.01}]},
	{"id": "I4", "tree": "spoke", "kind": "attribute", "attr": "int", "name": "Intelligence 4", "pos": Vector2(6, 0), "links": ["I3", "I5"], "requires": {}, "effects": [{"stat": "loot_reach", "mod": "flat", "value": 0.25}, {"stat": "extract_speed", "mod": "increased", "value": 0.01}]},
	{"id": "I5", "tree": "spoke", "kind": "attribute", "attr": "int", "name": "Intelligence 5", "pos": Vector2(7.5, 0), "links": ["I4", "I6"], "requires": {}, "effects": [{"stat": "loot_reach", "mod": "flat", "value": 0.25}, {"stat": "extract_speed", "mod": "increased", "value": 0.01}]},
	{"id": "I6", "tree": "spoke", "kind": "attribute", "attr": "int", "name": "Intelligence 6", "pos": Vector2(9, 0), "links": ["I5", "I7"], "requires": {}, "effects": [{"stat": "loot_reach", "mod": "flat", "value": 0.25}, {"stat": "extract_speed", "mod": "increased", "value": 0.01}]},
	{"id": "I7", "tree": "spoke", "kind": "attribute", "attr": "int", "name": "Intelligence 7", "pos": Vector2(10.5, 0), "links": ["I6", "I8"], "requires": {}, "effects": [{"stat": "loot_reach", "mod": "flat", "value": 0.25}, {"stat": "extract_speed", "mod": "increased", "value": 0.01}]},
	{"id": "I8", "tree": "spoke", "kind": "attribute", "attr": "int", "name": "Intelligence 8", "pos": Vector2(12, 0), "links": ["I7"], "requires": {}, "effects": [{"stat": "loot_reach", "mod": "flat", "value": 0.25}, {"stat": "extract_speed", "mod": "increased", "value": 0.01}]},
	{"id": "T1", "tree": "offense", "kind": "trunk", "name": "Offense I", "pos": Vector2(0, -1.5), "links": ["T2"], "requires": {}, "effects": [{"stat": "damage", "mod": "increased", "value": 0.03}]},
	{"id": "T2", "tree": "offense", "kind": "trunk", "name": "Offense II", "pos": Vector2(0, -3), "links": ["T1", "GB", "GM", "GO"], "requires": {}, "effects": [{"stat": "damage", "mod": "increased", "value": 0.03}]},
	# Brutality (STR): close-range damage and scattergun power
	{"id": "GB", "tree": "brutality", "kind": "gateway", "name": "Brute Force", "pos": Vector2(-2.5, -4.5), "links": ["T2", "B1"], "requires": {"str": 4}, "effects": [{"stat": "damage", "mod": "increased", "value": 0.04}]},
	{"id": "B1", "tree": "brutality", "kind": "minor", "name": "Heavy Shells", "pos": Vector2(-3.5, -6), "links": ["GB", "B2", "B3"], "requires": {}, "effects": [{"stat": "dmg_scattergun", "mod": "increased", "value": 0.05}]},
	{"id": "B2", "tree": "brutality", "kind": "minor", "name": "Close Work", "pos": Vector2(-5, -5), "links": ["B1", "B4", "BN1"], "requires": {}, "effects": [{"stat": "damage", "mod": "increased", "value": 0.03}, {"stat": "hp", "mod": "flat", "value": 4.0}]},
	{"id": "B3", "tree": "brutality", "kind": "minor", "name": "Stout", "pos": Vector2(-4.5, -7.5), "links": ["B1", "B4", "BN2"], "requires": {}, "effects": [{"stat": "hp", "mod": "flat", "value": 8.0}]},
	{"id": "B4", "tree": "brutality", "kind": "minor", "name": "Packed Charge", "pos": Vector2(-6, -6.5), "links": ["B2", "B3"], "requires": {}, "effects": [{"stat": "dmg_scattergun", "mod": "increased", "value": 0.05}]},
	# Now I would carry the scattergun and clear rooms from the doorway instead of trading pistol shots across the yard.
	{"id": "BN1", "tree": "brutality", "kind": "notable", "name": "Point Blank", "pos": Vector2(-6.5, -3.5), "links": ["B2"], "requires": {"str": 6}, "effects": [{"stat": "dmg_scattergun", "mod": "increased", "value": 0.30}, {"stat": "range", "mod": "increased", "value": -0.15}]},
	# Now I would fire deliberate shots and reload only behind cover instead of topping up the clip mid-fight.
	{"id": "BN2", "tree": "brutality", "kind": "notable", "name": "Hammer Blow", "pos": Vector2(-6, -9), "links": ["B3"], "requires": {"str": 6}, "effects": [{"stat": "damage", "mod": "increased", "value": 0.12}, {"stat": "reload", "mod": "increased", "value": -0.15}]},
	# Marksmanship (DEX): pistol range, spread, reload
	{"id": "GM", "tree": "marksmanship", "kind": "gateway", "name": "Steady Aim", "pos": Vector2(0, -4.5), "links": ["T2", "M1"], "requires": {"dex": 4}, "effects": [{"stat": "spread", "mod": "increased", "value": 0.08}]},
	{"id": "M1", "tree": "marksmanship", "kind": "minor", "name": "Sight Picture", "pos": Vector2(0, -6), "links": ["GM", "M2", "M3"], "requires": {}, "effects": [{"stat": "range", "mod": "increased", "value": 0.05}]},
	{"id": "M2", "tree": "marksmanship", "kind": "minor", "name": "Smooth Draw", "pos": Vector2(-1.5, -7), "links": ["M1", "M4", "MN1"], "requires": {}, "effects": [{"stat": "reload", "mod": "increased", "value": 0.05}]},
	{"id": "M3", "tree": "marksmanship", "kind": "minor", "name": "Hold Breath", "pos": Vector2(1.5, -7), "links": ["M1", "M4", "MN2"], "requires": {}, "effects": [{"stat": "spread", "mod": "increased", "value": 0.08}]},
	{"id": "M4", "tree": "marksmanship", "kind": "minor", "name": "Sidearm Drill", "pos": Vector2(0, -8.5), "links": ["M2", "M3"], "requires": {}, "effects": [{"stat": "dmg_pistol", "mod": "increased", "value": 0.06}]},
	# Now I would hold a lane and shoot from 40 m instead of sprinting to close the distance.
	{"id": "MN1", "tree": "marksmanship", "kind": "notable", "name": "Dead Eye", "pos": Vector2(-1.5, -9.5), "links": ["M2"], "requires": {"dex": 6}, "effects": [{"stat": "range", "mod": "increased", "value": 0.25}, {"stat": "dmg_pistol", "mod": "increased", "value": 0.15}, {"stat": "speed", "mod": "increased", "value": -0.06}]},
	# Now I would reload the moment a fight pauses instead of nursing the last rounds in the clip.
	{"id": "MN2", "tree": "marksmanship", "kind": "notable", "name": "Fast Cycle", "pos": Vector2(1.5, -9.5), "links": ["M3"], "requires": {"dex": 6}, "effects": [{"stat": "reload", "mod": "increased", "value": 0.35}, {"stat": "damage", "mod": "increased", "value": -0.05}]},
	# Ordnance (INT): ammo efficiency, ammo drop, starting ammo
	{"id": "GO", "tree": "ordnance", "kind": "gateway", "name": "Supply Line", "pos": Vector2(2.5, -4.5), "links": ["T2", "O1"], "requires": {"int": 4}, "effects": [{"stat": "ammo_drop", "mod": "increased", "value": 0.06}]},
	{"id": "O1", "tree": "ordnance", "kind": "minor", "name": "Lean Rounds", "pos": Vector2(3.5, -6), "links": ["GO", "O2", "O3"], "requires": {}, "effects": [{"stat": "ammo_save", "mod": "increased", "value": 0.03}]},
	{"id": "O2", "tree": "ordnance", "kind": "minor", "name": "Deep Pockets", "pos": Vector2(5, -5), "links": ["O1", "O4", "ON1"], "requires": {}, "effects": [{"stat": "start_ammo", "mod": "flat", "value": 4.0}]},
	{"id": "O3", "tree": "ordnance", "kind": "minor", "name": "Scrounger", "pos": Vector2(4.5, -7.5), "links": ["O1", "O4", "ON2"], "requires": {}, "effects": [{"stat": "ammo_drop", "mod": "increased", "value": 0.08}]},
	{"id": "O4", "tree": "ordnance", "kind": "minor", "name": "Tight Loads", "pos": Vector2(6, -6.5), "links": ["O2", "O3"], "requires": {}, "effects": [{"stat": "ammo_save", "mod": "increased", "value": 0.03}]},
	# Now I would take the ammo-hungry scattergun (2 rounds a shot) instead of the pistol.
	{"id": "ON1", "tree": "ordnance", "kind": "notable", "name": "Hoarder", "pos": Vector2(6.5, -3.5), "links": ["O2"], "requires": {"int": 6}, "effects": [{"stat": "start_ammo", "mod": "flat", "value": 14.0}, {"stat": "ammo_save", "mod": "increased", "value": 0.06}]},
	# Now I would stay and fight the grunts for their drops instead of heading for the exit early.
	{"id": "ON2", "tree": "ordnance", "kind": "notable", "name": "Salvage Run", "pos": Vector2(6, -9), "links": ["O3"], "requires": {"int": 6}, "effects": [{"stat": "ammo_drop", "mod": "increased", "value": 0.35}, {"stat": "extract_speed", "mod": "increased", "value": -0.10}]},
]
