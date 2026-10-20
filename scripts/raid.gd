extends Node
# Authoritative raid simulation. Player input asks for things through the request_*
# functions; this node checks them against the raid state and applies them. It also
# owns the extract hold timer and how a raid ends. Persisted loot lives in the
# profile, which this node only touches when a raid ends in a successful extract.

const Tuning = preload("res://data/tuning.gd")
const WeaponData = preload("res://data/weapons.gd")

signal picked_up(id: String, qty: int)
signal inventory_full
signal shot_fired(weapon_id: String)
signal dry_fire  # tried to fire with too little ammo
signal ended(result: Dictionary)  # {"outcome": "extracted"|"dead", "items": {id: qty}, "saved": bool}

enum State { ACTIVE, ENDED }

var profile  # scripts/profile.gd instance, set by main before the raid starts
var hold_seconds: float = Tuning.EXTRACT_HOLD_SECONDS  # tests shorten this
var state := State.ACTIVE
var extracting := false
var extract_elapsed := 0.0
var brought := {}  # item id -> quantity of the starting kit not yet spent (never counts as loot)

var _player
var _fire_cooldown := 0.0

func setup(player) -> void:
	_player = player
	player.died.connect(_on_player_died)
	if Tuning.STARTING_AMMO > 0:
		brought["ammo"] = Tuning.STARTING_AMMO - player.inventory.add("ammo", Tuning.STARTING_AMMO)

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
		return false
	if brought.has(item):
		brought[item] = maxi(int(brought[item]) - cost, 0)  # the kit is spent first
	shot_fired.emit(weapon_id)
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
			if hit["collider"].take_damage(dmg):
				_player.kills += 1
	return true

# The player is standing in the extract zone. Starts (or continues) the hold timer.
func request_extract() -> bool:
	if state != State.ACTIVE:
		return false
	extracting = true
	return true

# The player left the extract zone. The timer starts over next time.
func cancel_extract() -> void:
	extracting = false
	extract_elapsed = 0.0

func request_loot(crate) -> bool:
	if state != State.ACTIVE or not is_instance_valid(crate):
		return false
	if _player.global_position.distance_to(crate.global_position) > Tuning.LOOT_REACH:
		return false
	var taken: Dictionary = crate.take_into(_player.inventory)
	for id in taken:
		picked_up.emit(id, taken[id])
	if not crate.contents.is_empty():
		inventory_full.emit()
	return true

func _physics_process(delta: float) -> void:
	if state != State.ACTIVE:
		return
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
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

func _on_player_died() -> void:
	_finish("dead")

func _finish(outcome: String) -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	extracting = false
	var items := _loot()
	_player.inventory.clear()  # kept loot goes to the profile, lost loot is gone
	var saved := true
	if outcome == "extracted" and profile != null:
		profile.add_items(items)
		saved = profile.save()
	ended.emit({"outcome": outcome, "items": items, "saved": saved})
