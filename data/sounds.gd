# Sound table. Every sound is synthesized from these numbers (no audio files), so
# tuning a sound means editing a row. Played through scripts/sfx.gd.
#   freq -> freq_end: pitch in Hz, swept over the sound's length
#   noise: 0 = pure tone, 1 = pure noise      wave: "sine" or "square"
#   decay: how fast it fades out (higher = shorter punch)
#   volume: 0-1 before SFX_VOLUME_DB          min_gap: seconds before the same sound may replay
#   positional: true = heard from where it happened in the world
const DATA := {
	"shoot_pistol": {"freq": 600.0, "freq_end": 120.0, "duration": 0.14, "noise": 0.5, "wave": "sine", "decay": 3.0, "volume": 0.5, "min_gap": 0.05},
	"shoot_scatter": {"freq": 300.0, "freq_end": 60.0, "duration": 0.3, "noise": 0.85, "wave": "sine", "decay": 2.5, "volume": 0.7, "min_gap": 0.05},
	"switch": {"freq": 300.0, "freq_end": 450.0, "duration": 0.06, "noise": 0.3, "wave": "sine", "decay": 2.0, "volume": 0.3, "min_gap": 0.05},
	"hit": {"freq": 220.0, "freq_end": 110.0, "duration": 0.08, "noise": 0.3, "wave": "square", "decay": 2.5, "volume": 0.4, "min_gap": 0.04, "positional": true},
	"kill": {"freq": 160.0, "freq_end": 40.0, "duration": 0.25, "noise": 0.4, "wave": "sine", "decay": 2.0, "volume": 0.6, "min_gap": 0.1, "positional": true},
	"alert": {"freq": 400.0, "freq_end": 800.0, "duration": 0.2, "noise": 0.0, "wave": "square", "decay": 1.5, "volume": 0.35, "min_gap": 0.5, "positional": true},
	"hurt": {"freq": 120.0, "freq_end": 60.0, "duration": 0.2, "noise": 0.6, "wave": "sine", "decay": 2.0, "volume": 0.6, "min_gap": 0.15},
	"enemy_strike": {"freq": 250.0, "freq_end": 80.0, "duration": 0.18, "noise": 0.5, "wave": "square", "decay": 2.5, "volume": 0.6, "min_gap": 0.1, "positional": true},
	"step_player": {"freq": 140.0, "freq_end": 70.0, "duration": 0.07, "noise": 0.35, "wave": "sine", "decay": 2.5, "volume": 0.3, "min_gap": 0.0},
	"step_enemy": {"freq": 90.0, "freq_end": 55.0, "duration": 0.1, "noise": 0.2, "wave": "square", "decay": 2.0, "volume": 0.45, "min_gap": 0.0, "positional": true, "max_distance": 25.0},
	"pickup": {"freq": 700.0, "freq_end": 1100.0, "duration": 0.1, "noise": 0.0, "wave": "sine", "decay": 1.5, "volume": 0.4, "min_gap": 0.05},
	"heal": {"freq": 500.0, "freq_end": 900.0, "duration": 0.25, "noise": 0.0, "wave": "sine", "decay": 1.2, "volume": 0.4, "min_gap": 0.1},
	"deny": {"freq": 150.0, "freq_end": 150.0, "duration": 0.15, "noise": 0.0, "wave": "square", "decay": 1.5, "volume": 0.3, "min_gap": 0.3},
	"extract_tick": {"freq": 900.0, "freq_end": 900.0, "duration": 0.05, "noise": 0.0, "wave": "sine", "decay": 2.0, "volume": 0.3, "min_gap": 0.2},
	"extract_done": {"freq": 500.0, "freq_end": 1000.0, "duration": 0.5, "noise": 0.0, "wave": "sine", "decay": 1.2, "volume": 0.5, "min_gap": 0.5},
	"death": {"freq": 200.0, "freq_end": 40.0, "duration": 0.8, "noise": 0.5, "wave": "sine", "decay": 1.5, "volume": 0.7, "min_gap": 0.5},
}
