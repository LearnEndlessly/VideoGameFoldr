# Powerups: an enemy kill may drop one (Tuning.POWERUP_DROP_CHANCE). It lies on the ground for only
# Tuning.POWERUP_PICKUP_SECONDS, then vanishes. Walk into it and its effect lasts "seconds".
#   mult: damage or move speed multiplier     taken: multiplier on damage taken
const DATA := {
	"damage": {"name": "OVERDRIVE", "color": Color(1.0, 0.35, 0.1), "seconds": 10.0, "mult": 1.5, "desc": "+50% damage"},
	"haste": {"name": "HASTE", "color": Color(0.3, 0.8, 1.0), "seconds": 10.0, "mult": 1.4, "desc": "+40% move speed"},
	"shield": {"name": "SHIELD", "color": Color(0.65, 0.5, 1.0), "seconds": 10.0, "taken": 0.5, "desc": "half damage taken"},
}
