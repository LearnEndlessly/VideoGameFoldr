extends Node
# Authoritative raid simulation. Player input asks for things through the request_*
# functions; this node checks them against the raid state and applies them. It also
# owns the extract hold timer and how a raid ends. Persisted loot lives in the
# profile, which this node only touches when a raid ends in a successful extract.

const Tuning = preload("res://data/tuning.gd")
const WeaponData = preload("res://data/weapons.gd")
const Recipes = preload("res://data/recipes.gd")
const Telemetry = preload("res://scripts/telemetry.gd")

signal picked_up(id: String, qty: int)
signal inventory_full
signal shot_fired(weapon_id: String)
signal dry_fire  # tried to fire with too little ammo
signal threat_started
signal threat_ended  # wave mode only
signal ended(result: Dictionary)  # {"outcome": "extracted"|"dead", "items": {id: qty}, "saved": bool}

enum State { ACTIVE, ENDED }

var profile  # scripts/profile.gd instance, set by main before the raid starts
var hold_seconds: float = Tuning.EXTRACT_HOLD_SECONDS  # tests shorten this
var state := State.ACTIVE
var extracting := false
var extract_elapsed := 0.0
var brought := {}  # item id -> quantity of the starting kit not yet spent (never counts as loot)
# Threat clock settings; tests change these per raid. See data/tuning.gd for what they mean.
var threat_delay: float = Tuning.THREAT_DELAY_SECONDS
var threat_continuous: bool = Tuning.THREAT_CONTINUOUS
var threat_wave_seconds: float = Tuning.THREAT_WAVE_SECONDS
var threat_active := false
var elapsed := 0.0  # seconds since the raid began
var seed_value := 0  # map seed, only logged; main may set it
var shots := 0  # shots fired this raid
var ammo_spent := 0

var _threat_reached := false
var _player
var _fire_cooldown := 0.0
var _threat_done := false  # a wave has run; it does not start again
var _wave_left := 0.0

func setup(player) -> void:
	_player = player
	player.died.connect(_on_player_died)
	if Tuning.STARTING_AMMO > 0:
		brought["ammo"] = Tuning.STARTING_AMMO - player.inventory.add("ammo", Tuning.STARTING_AMMO)
	Telemetry.start({"seed": seed_value, "start_ammo": Tuning.STARTING_AMMO, "threat_delay": threat_delay})

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

# The player pulled the trigger. Checks the raid state, the weapon's cooldown and the
# backpack's ammo; if all allow it, spends the ammo and resolves every pellet against
# the world. `aim` is the camera's transform. Returns true if a shot was fired.
func request_fire(weapon_id: String, aim: Transform3D) -> bool:
	if state != State.ACTIVE or _fire_cooldown > 0.0 or not WeaponData.DATA.has(weapon_id):
		return false
	var w: Dictionary = WeaponData.DATA[weapon_id]
	_fire_cooldown = w["cooldown"]  # also paces the dry-fire click
	var item: String = w["ammo_item"]
	var cost: int = w["ammo_per_shot"]
	if not _player.inventory.remove(item, cost):
		dry_fire.emit()
		Telemetry.emit("player.fire.weapon", {"id": weapon_id, "outcome": "dry", "hits": 0, "dmg": 0, "ammo_left": _player.inventory.count(item)})
		return false
	if brought.has(item):
		brought[item] = maxi(int(brought[item]) - cost, 0)  # the kit is spent first
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
			var dmg := WeaponData.damage_at(w, aim.origin.distance_to(hit["position"]))
			hits += 1
			total_dmg += dmg
			var enemy = hit["collider"]
			var kill_info := {}
			if "stats" in enemy:  # only enemies carry type/modifier
				kill_info = {"id": enemy.stats["type"], "mod": enemy.stats["modifier"], "group": enemy.group_id,
					"weapon": weapon_id, "range": aim.origin.distance_to(hit["position"])}
			if enemy.take_damage(dmg):
				_player.kills += 1
				Telemetry.emit("player.kill.enemy", kill_info)
	Telemetry.emit("player.fire.weapon", {"id": weapon_id, "outcome": "fired", "hits": hits, "dmg": total_dmg, "ammo_left": _player.inventory.count(item)})
	return true

# The player is standing in the extract zone. Starts (or continues) the hold timer.
func request_extract() -> bool:
	if state != State.ACTIVE:
		return false
	if not extracting:
		Telemetry.emit("player.begin.extract")
	extracting = true
	return true

# The player left the extract zone. The timer starts over next time.
func cancel_extract() -> void:
	if extracting:
		Telemetry.emit("player.cancel.extract", {"held": extract_elapsed})
	extracting = false
	extract_elapsed = 0.0

func request_loot(crate) -> bool:
	if state != State.ACTIVE or not is_instance_valid(crate):
		return false
	if _player.global_position.distance_to(crate.global_position) > Tuning.LOOT_REACH:
		Telemetry.emit("player.open.crate", {"outcome": "far", "taken": {}})
		return false
	var taken: Dictionary = crate.take_into(_player.inventory)
	for id in taken:
		picked_up.emit(id, taken[id])
	if not crate.contents.is_empty():
		inventory_full.emit()
	Telemetry.emit("player.open.crate", {"outcome": "ok" if crate.contents.is_empty() else "full", "taken": taken})
	return true

func _physics_process(delta: float) -> void:
	if state != State.ACTIVE:
		return
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	elapsed += delta
	Telemetry.clock = elapsed
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
		if extract_elapsed >= hold_seconds:
			_finish("extracted")

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
	threat_active = false
	var items := _loot()
	_player.inventory.clear()  # kept loot goes to the profile, lost loot is gone
	var saved := true
	if outcome == "extracted" and profile != null:
		profile.add_items(items)
		saved = profile.save()
	Telemetry.emit("raid.end.raid", {"outcome": outcome, "loot": items, "kills": _player.kills, "shots": shots,
		"ammo_spent": ammo_spent, "duration": elapsed, "threat_reached": _threat_reached})
	Telemetry.finish()
	ended.emit({"outcome": outcome, "items": items, "saved": saved, "kills": _player.kills})
