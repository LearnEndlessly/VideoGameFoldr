extends RefCounted
# Sound effects: Sfx.play("name") or Sfx.play("name", world_position).
# Streams are synthesized once from data/sounds.gd and cached. Works from any script
# (no autoload) by parking short-lived players on the scene root.

const Sounds = preload("res://data/sounds.gd")
const Tuning = preload("res://data/tuning.gd")
const RATE := 22050

static var _cache := {}
static var _last_played := {}  # sound name -> msec of the last play, for min_gap

static func play(sound: String, pos = null, pitch := 1.0) -> void:
	var def: Dictionary = Sounds.DATA[sound]
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -100000)) < float(def["min_gap"]) * 1000.0:
		return
	_last_played[sound] = now
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var p  # AudioStreamPlayer or AudioStreamPlayer3D, both expose play() and finished
	if pos != null and def.get("positional", false):
		var p3 := AudioStreamPlayer3D.new()
		p3.position = pos
		p3.max_distance = def.get("max_distance", 60.0)
		p3.pitch_scale = pitch
		p3.stream = stream_for(sound)
		p3.volume_db = Tuning.SFX_VOLUME_DB
		p3.finished.connect(p3.queue_free)
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.pitch_scale = pitch
		p2.stream = stream_for(sound)
		p2.volume_db = Tuning.SFX_VOLUME_DB
		p2.finished.connect(p2.queue_free)
		p = p2
	p.process_mode = Node.PROCESS_MODE_ALWAYS  # still audible behind the paused results screen
	tree.root.add_child.call_deferred(p)
	p.play.call_deferred()

static func stream_for(sound: String) -> AudioStreamWAV:
	if not _cache.has(sound):
		_cache[sound] = _synthesize(Sounds.DATA[sound])
	return _cache[sound]

static func _synthesize(def: Dictionary) -> AudioStreamWAV:
	var n := int(float(def["duration"]) * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1  # same noise every run
	var phase := 0.0
	var noise_mix: float = def["noise"]
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(def["freq"], def["freq_end"], t) / RATE
		var tone := sin(phase)
		if def["wave"] == "square":
			tone = signf(tone)
		var env := pow(1.0 - t, float(def["decay"])) * minf(1.0, t * 200.0)  # short fade-in avoids a click
		var s: float = (tone * (1.0 - noise_mix) + rng.randf_range(-1.0, 1.0) * noise_mix) * env * float(def["volume"])
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	return stream
