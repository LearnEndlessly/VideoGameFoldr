extends Node
# Authoritative raid simulation. Player input asks for things through the request_*
# functions; this node checks them against the raid state and applies them. It also
# owns the extract hold timer and how a raid ends. Persisted loot lives in the
# profile, which this node only touches when a raid ends in a successful extract.

const Tuning = preload("res://data/tuning.gd")
const WeaponData = preload("res://data/weapons.gd")
const Recipes = preload("res://data/recipes.gd")
const Telemetry = preload("res://scripts/telemetry.gd")
const Pickup = preload("res://scripts/pickup.gd")
const Difficulty = preload("res://data/difficulty.gd")

signal picked_up(id: String, qty: int)
signal inventory_full
signal shot_fired(weapon_id: String)
signal dry_fire  # tried to fire with too little ammo in the magazine
signal reload_started(weapon_id: String)
signal reload_done(weapon_id: String)
signal threat_started
signal threat_ended  # wave mode only
signal ended(result: Dictionary)  # {"outcome": "extracted"|"dead", "items": {id: qty}, "saved": bool}

enum State { ACTIVE, ENDED }

var profile  # scripts/profile.gd instance, set by main before the raid starts
var hold_seconds: float = Tuning.EXTRACT_HOLD_SECONDS  # tests shorten this
var state := State.ACTIVE
var extracting := false
var extract_zone := ""  # "A" or "B": the zone the current hold is in
var extract_points := {}  # zone id -> position; set by main
var b_hold_seconds: float = Tuning.EXTRACT_B_HOLD_SECONDS  # main copies its extract_cfg here
var b_noise_radius: float = Tuning.EXTRACT_B_NOISE_RADIUS
var extract_elapsed := 0.0
var brought := {}  # item id -> quantity of the starting kit not yet spent (never counts as loot)
# Threat clock settings; tests change these per raid. See data/tuning.gd for what they mean.
var threat_delay: float = Tuning.THREAT_DELAY_SECONDS
var threat_continuous: bool = Tuning.THREAT_CONTINUOUS
var threat_wave_seconds: float = Tuning.THREAT_WAVE_SECONDS
var threat_active := false
var elapsed := 0.0  # seconds since the raid began
var seed_value := 0  # map seed, only logged; main may set it
var map_info := {}  # the starting map as data, set by main; logged on the first line of the raid's log
var shots := 0  # shots fired this raid
var ammo_spent := 0
var start_ammo: int = Tuning.STARTING_AMMO  # set by main from the raid difficulty
var reward_mult := 1.0  # scales the loot kept and the points earned on an extract (data/difficulty.gd)
var damage_mult := {}  # weapon id -> damage multiplier from the profile's weapon upgrades
var reload_seconds: float = Tuning.RELOAD_SECONDS  # shortened by the Weapon handling attribute
var loaded := {}  # weapon id -> rounds in its magazine; the backpack holds the rest
var reload_weapon := ""  # weapon being reloaded, "" if none
var reload_left := 0.0

var _threat_reached := false
var _drop_rng := RandomNumberGenerator.new()  # enemy drops; seeded per raid so a test can replay them
var _player
var _fire_cooldown := 0.0
var _sample_clock := Telemetry.SAMPLE_SECONDS  # starts full so the first sample is logged at once
var _threat_done := false  # a wave has run; it does not start again
var _wave_left := 0.0

func setup(player) -> void:
	_player = player
	_drop_rng.seed = seed_value
	player.died.connect(_on_player_died)
	if start_ammo > 0:
		brought["ammo"] = start_ammo - player.inventory.add("ammo", start_ammo)
	for id in WeaponData.DATA:
		loaded[id] = mini(WeaponData.DATA[id]["clip"], player.inventory.count(WeaponData.DATA[id]["ammo_item"]))
	Telemetry.start({"seed": seed_value, "start_ammo": start_ammo, "reward_mult": reward_mult, "threat_delay": threat_delay, "map": map_info})

# Craft one `output` from the backpack (data/recipes.gd). Needs every ingredient and room
# for the result; otherwise nothing changes. The result is announced like a pickup.
func request_craft(output: String) -> bool:
	if state != State.ACTIVE or not Recipes.DATA.has(output):
		return false
	var recipe: Dictionary = Recipes.DATA[output]
	var inv = _player.inventory
	for id in recipe:
		if inv.count(id) < int(recipe[id]):
			return false
	for id in recipe:
		inv.remove(id, int(recipe[id]))
	if inv.add(output, 1) > 0:  # no room for the result: give the ingredients back
		for id in recipe:
			inv.add(id, int(recipe[id]))
		return false
	picked_up.emit(output, 1)
	return true

func loaded_rounds(weapon_id: String) -> int:
	var w: Dictionary = WeaponData.DATA[weapon_id]
	return mini(int(loaded[weapon_id]), _player.inventory.count(w["ammo_item"]))

# Rounds the HUD shows in the magazine: while reloading they fill in one by one.
func shown_rounds(weapon_id: String) -> int:
	if reload_weapon != weapon_id:
		return loaded_rounds(weapon_id)
	var progress := 1.0 - reload_left / reload_seconds
	return int(lerpf(loaded_rounds(weapon_id), _reload_target(weapon_id), progress))

func _reload_target(weapon_id: String) -> int:
	var w: Dictionary = WeaponData.DATA[weapon_id]
	return mini(w["clip"], _player.inventory.count(w["ammo_item"]))

# Start reloading the current weapon from the backpack. False if the magazine is full or
# the backpack has nothing more to put in it.
func request_reload() -> bool:
	var id: String = _player.weapon_id
	if state != State.ACTIVE or reload_weapon != "" or _reload_target(id) <= loaded_rounds(id):
		return false
	reload_weapon = id
	reload_left = reload_seconds
	reload_started.emit(id)
	return true

func cancel_reload() -> void:
	reload_weapon = ""

# The player pulled the trigger. Checks the raid state, the weapon's cooldown and the
# backpack's ammo; if all allow it, spends the ammo and resolves every pellet against
# the world. `aim` is the camera's transform. Returns true if a shot was fired.
func request_fire(weapon_id: String, aim: Transform3D) -> bool:
	if state != State.ACTIVE or _fire_cooldown > 0.0 or reload_weapon != "" or not WeaponData.DATA.has(weapon_id):
		return false
	var w: Dictionary = WeaponData.DATA[weapon_id]
	_fire_cooldown = w["cooldown"]  # also paces the dry-fire click
	var item: String = w["ammo_item"]
	var cost: int = w["ammo_per_shot"]
	if loaded_rounds(weapon_id) < cost or not _player.inventory.remove(item, cost):
		dry_fire.emit()
		Telemetry.emit("player.fire.weapon", {"id": weapon_id, "outcome": "dry", "hits": 0, "dmg": 0, "ammo_left": _player.inventory.count(item)})
		return false
	if brought.has(item):
		brought[item] = maxi(int(brought[item]) - cost, 0)  # the kit is spent first
	loaded[weapon_id] = int(loaded[weapon_id]) - cost
	shots += 1
	ammo_spent += cost
	shot_fired.emit(weapon_id)
	var hits := 0
	var total_dmg := 0
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var spread: float = w["spread"]
	for i in int(w["pellets"]):
		var dir := -aim.basis.z
		if spread > 0.0:
			dir = (dir + aim.basis.x * randf_range(-spread, spread) + aim.basis.y * randf_range(-spread, spread)).normalized()
		var query := PhysicsRayQueryParameters3D.create(aim.origin, aim.origin + dir * float(w["max"]))
		query.exclude = [_player.get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if hit and hit["collider"].has_method("take_damage"):
			var dmg := int(round(WeaponData.damage_at(w, aim.origin.distance_to(hit["position"])) * float(damage_mult.get(weapon_id, 1.0))))
			hits += 1
			total_dmg += dmg
			var enemy = hit["collider"]
			var kill_info := {}
			if "stats" in enemy:  # only enemies carry type/modifier
				kill_info = {"id": enemy.stats["type"], "mod": enemy.stats["modifier"], "group": enemy.group_id,
					"weapon": weapon_id, "range": aim.origin.distance_to(hit["position"]), "pos": enemy.global_position}
			if enemy.take_damage(dmg) and "stats" in enemy:  # the enemy base dying is not a kill
				_player.kills += 1
				Telemetry.emit("player.kill.enemy", kill_info)
				_drop_ammo(enemy.global_position, enemy.stats)
	Telemetry.emit("player.fire.weapon", {"id": weapon_id, "outcome": "fired", "hits": hits, "dmg": total_dmg, "ammo_left": _player.inventory.count(item)})
	return true

# Rolls an enemy's ammo drop (data/enemies.gd) and, on success, leaves a pickup where it died.
func _drop_ammo(pos: Vector3, stats: Dictionary) -> bool:
	if _drop_rng.randf() >= float(stats.get("drop_chance", 0.0)):
		return false
	var amount: Array = stats["drop"]
	var pickup := Pickup.new()
	pickup.id = "ammo"
	pickup.qty = _drop_rng.randi_range(amount[0], amount[1])
	pickup.position = pos
	get_parent().add_child.call_deferred(pickup)  # a kill happens inside the physics step, where new areas cannot be added
	return true

# The player walked into a pickup: move what fits into the backpack; the rest stays on the ground.
func request_pickup(pickup) -> bool:
	if state != State.ACTIVE or not is_instance_valid(pickup) \
			or _player.global_position.distance_to(pickup.global_position) > Tuning.LOOT_REACH:
		return false
	var left: int = _player.inventory.add(pickup.id, pickup.qty)
	if left == pickup.qty:
		inventory_full.emit()
		return false
	picked_up.emit(pickup.id, pickup.qty - left)
	pickup.qty = left
	if left == 0:
		pickup.queue_free()
	return true

# Seconds the hold in a zone takes. hold_seconds is zone A's; B takes b_hold_seconds / Tuning.EXTRACT_HOLD_SECONDS
# times as long, so a test that shortens hold_seconds shortens both.
func hold_seconds_for(zone_id: String) -> float:
	if zone_id == "B":
		return hold_seconds * b_hold_seconds / Tuning.EXTRACT_HOLD_SECONDS
	return hold_seconds

# The player is standing in extract zone `zone_id`. Starts (or continues) the hold timer. Starting a hold in
# zone B is loud: every enemy group with a member within b_noise_radius of the zone is alerted.
func request_extract(zone_id := "A") -> bool:
	if state != State.ACTIVE:
		return false
	if not extracting:
		Telemetry.emit("player.begin.extract", {"zone": zone_id})
		extract_zone = zone_id
		extract_elapsed = 0.0
		if zone_id == "B":
			_alert_near(extract_points.get("B", _player.global_position))
	extracting = true
	return true

# Alerts every enemy group that has a member within b_noise_radius (flat distance) of `pos`.
func _alert_near(pos: Vector3) -> void:
	var done := {}
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.is_queued_for_deletion() or done.has(e.group_id):
			continue
		var d := Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z).length()
		if d <= b_noise_radius:
			done[e.group_id] = true
			e.alert_pack("extract")

# The player left the extract zone. The timer starts over next time.
func cancel_extract() -> void:
	if extracting:
		Telemetry.emit("player.cancel.extract", {"held": extract_elapsed, "zone": extract_zone})
	extracting = false
	extract_zone = ""
	extract_elapsed = 0.0

func request_loot(crate) -> bool:
	if state != State.ACTIVE or not is_instance_valid(crate):
		return false
	if _player.global_position.distance_to(crate.global_position) > Tuning.LOOT_REACH:
		Telemetry.emit("player.open.crate", {"outcome": "far", "taken": {}, "zone": crate.zone_id, "pos": crate.global_position})
		return false
	var taken: Dictionary = crate.take_into(_player.inventory)
	for id in taken:
		picked_up.emit(id, taken[id])
	if not crate.contents.is_empty():
		inventory_full.emit()
	Telemetry.emit("player.open.crate", {"outcome": "ok" if crate.contents.is_empty() else "full", "taken": taken,
		"left": crate.contents.size(), "zone": crate.zone_id, "pos": crate.global_position})
	return true

func _physics_process(delta: float) -> void:
	if state != State.ACTIVE:
		return
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	if reload_weapon != "":
		reload_left -= delta
		if reload_left <= 0.0:
			var id := reload_weapon
			loaded[id] = _reload_target(id)
			reload_weapon = ""
			reload_done.emit(id)
	elapsed += delta
	Telemetry.clock = elapsed
	_sample_clock += delta
	if _sample_clock >= Telemetry.SAMPLE_SECONDS:
		_sample_clock = 0.0
		_sample()
	if not threat_active and not _threat_done and elapsed >= threat_delay:
		_start_threat()
	if threat_active:
		if threat_continuous:
			get_tree().call_group("enemy", "set_converge", _player.global_position)
		else:
			_wave_left -= delta
			if _wave_left <= 0.0:
				_end_threat()
	if extracting:
		extract_elapsed += delta
		if extract_elapsed >= hold_seconds_for(extract_zone):
			_finish("extracted")

# A snapshot of where the player is and what they hold, for studying routes and resource use.
func _sample() -> void:
	var near := -1.0  # distance to the nearest enemy, -1 if none are left
	var alerted := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		var d: float = e.global_position.distance_to(_player.global_position)
		near = d if near < 0.0 else minf(near, d)
		if e.alert:
			alerted += 1
	Telemetry.emit("raid.sample.state", {"pos": _player.global_position, "hp": _player.health,
		"pack": _player.inventory.totals(), "near": near, "alert": alerted, "safe": _player.safe,
		"sprint": _player.sprinting, "extracting": extracting})

# What the player holds beyond the unspent starting kit: the loot at stake.
func _loot() -> Dictionary:
	var loot := {}
	var held: Dictionary = _player.inventory.totals()
	for id in held:
		var qty: int = held[id] - int(brought.get(id, 0))
		if qty > 0:
			loot[id] = qty
	return loot

# Every enemy heads for the player's position. In continuous mode _physics_process keeps
# updating the target to the live position; in wave mode it is the position right now and
# the wave ends after threat_wave_seconds.
func _start_threat() -> void:
	threat_active = true
	_threat_reached = true
	Telemetry.emit("raid.start.clock")
	_wave_left = threat_wave_seconds
	get_tree().call_group("enemy", "set_converge", _player.global_position)
	threat_started.emit()

func _end_threat() -> void:
	threat_active = false
	_threat_done = true
	get_tree().call_group("enemy", "end_converge")
	threat_ended.emit()

func _on_player_died() -> void:
	_finish("dead")

func _finish(outcome: String) -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	extracting = false
	extract_zone = ""
	threat_active = false
	var items := _loot()
	if outcome == "extracted":  # the raid difficulty scales what is kept (what is lost stays as it was)
		for id in items:
			items[id] = Difficulty.scale(int(items[id]), reward_mult)
	_player.inventory.clear()  # kept loot goes to the profile, lost loot is gone
	var saved := true
	var points := 0  # attribute points earned (successful extracts only)
	if outcome == "extracted" and profile != null:
		profile.add_items(items)
		points = profile.record_extract(_player.kills, reward_mult)
		saved = profile.save()
	var end_info := {"outcome": outcome, "loot": items, "kills": _player.kills, "shots": shots,
		"ammo_spent": ammo_spent, "duration": elapsed, "threat_reached": _threat_reached}
	Telemetry.emit("raid.end.raid", end_info)
	Telemetry.finish()
	Telemetry.record_run(end_info)
	ended.emit({"outcome": outcome, "items": items, "saved": saved, "kills": _player.kills, "points": points, "reward_mult": reward_mult})
