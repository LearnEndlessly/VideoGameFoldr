extends Node
# Authoritative raid simulation. Player input asks for things through the request_*
# functions; this node checks them against the raid state and applies them. It also
# owns the extract hold timer and how a raid ends. Persisted loot lives in the
# profile, which this node only touches when a raid ends in a successful extract.

const Tuning = preload("res://data/tuning.gd")

signal picked_up(id: String, qty: int)
signal inventory_full
signal ended(result: Dictionary)  # {"outcome": "extracted"|"dead", "items": {id: qty}, "saved": bool}

enum State { ACTIVE, ENDED }

var profile  # scripts/profile.gd instance, set by main before the raid starts
var hold_seconds: float = Tuning.EXTRACT_HOLD_SECONDS  # tests shorten this
var state := State.ACTIVE
var extracting := false
var extract_elapsed := 0.0

var _player

func setup(player) -> void:
	_player = player
	player.died.connect(_on_player_died)

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
	if state != State.ACTIVE or not extracting:
		return
	extract_elapsed += delta
	if extract_elapsed >= hold_seconds:
		_finish("extracted")

func _on_player_died() -> void:
	_finish("dead")

func _finish(outcome: String) -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	extracting = false
	var items: Dictionary = _player.inventory.totals()
	_player.inventory.clear()  # kept loot goes to the profile, lost loot is gone
	var saved := true
	if outcome == "extracted" and profile != null:
		profile.add_items(items)
		saved = profile.save()
	ended.emit({"outcome": outcome, "items": items, "saved": saved})
