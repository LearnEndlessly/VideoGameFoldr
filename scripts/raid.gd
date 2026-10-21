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
const Upgrades = preload("res://data/upgrades.gd")
const Powerups = preload("res://data/powerups.gd")
const Powerup = preload("res://scripts/powerup.gd")
const Attachments = preload("res://data/attachments.gd")
const Enemies = preload("res://data/enemies.gd")
const XpOrb = preload("res://scripts/xp_orb.gd")

signal picked_up(id: String, qty: int)
signal inventory_full
signal shot_fired(weapon_id: String)
signal dry_fire  # tried to fire with too little ammo in the magazine
signal reload_started(weapon_id: String)
signal reload_done(weapon_id: String)
signal threat_started
signal bullet_traced(weapon_id: String, end: Vector3, normal: Vector3, kind: String)  # one per pellet, for the bullet visuals
signal attachment_broke(attachment_name: String)
signal combo_kill(count: int)  # a kill joined the combo
signal combo_ended(count: int, bonus: int)  # the combo ran out: `bonus` score was paid
signal zone_hit(zone: String)  # a shot landed on an enemy: "head", "back", "side" or "front"
signal point_earned  # the round was cleared: one attribute point, spendable at the base
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
var shots_hit := 0  # of those, shots that hurt something
var depth := 0  # levels descended before this one (0 = fresh from the base)
var carry := {}  # loot carried down from the last level: it is loot again, at risk
var drop_mult := 1.0  # scales the ammo drop chance (deeper levels drop more)
var ammo_spent := 0
var start_ammo: int = Tuning.STARTING_AMMO  # set by main from the raid difficulty
var reward_mult := 1.0  # scales the loot kept and the points earned on an extract (data/difficulty.gd)
var damage_mult := {}  # weapon id -> extra damage multiplier (tests use it); raid upgrades and powerups apply on top
var reload_seconds: float = Tuning.RELOAD_SECONDS  # shortened by the Weapon handling attribute
var loaded := {}  # weapon id -> rounds in its magazine; the backpack holds the rest
var reload_weapon := ""  # weapon being reloaded, "" if none
var reload_left := 0.0
var upgrades := {}  # raid upgrade id -> level (data/upgrades.gd); set by main before setup, lost when the raid ends
var picks_pending := 0  # level-ups earned and not yet taken
var powerups := {}  # active powerup id -> seconds left
var att_left := {}  # attachment id -> shots left, from the profile; written back when the raid ends
var cooldown_mult := 1.0  # the Rapid fire upgrade shortens the wait between shots
var combo := 0  # kills in the running combo (0 = none)
var combo_left := 0.0  # seconds until it runs out; every kill refills it, to less each time
var combo_total := 0.0  # the window the last kill started, for the meter
var combo_points := 0  # score banked in the running combo, paid (times the multiplier) when it ends
var best_combo := 0
var score := 0
var points_earned := 0  # attribute points earned this raid by clearing a round
var round_cleared := false

var _threat_reached := false
var _drop_rng := RandomNumberGenerator.new()  # enemy drops; seeded per raid so a test can replay them
var _player
var _base := {}  # the player's numbers before raid upgrades and powerups
var _dmg_factor := 1.0
var xp := 0  # experience toward the next level-up
var _power_rng := RandomNumberGenerator.new()
var _loot_rng := RandomNumberGenerator.new()  # scrap and attachment drops
var _fire_cooldown := 0.0
var _cooldown_total := 0.0  # the wait the last shot started, for the ready indicator
var _luck := RandomNumberGenerator.new()  # attribute chances (crit, free shots, wear); drawn only when the attribute is held
var _regen_acc := 0.0
var _xp_extra := 0.0
var _clear_clock := 0.0
var _sample_clock := Telemetry.SAMPLE_SECONDS  # starts full so the first sample is logged at once
var _threat_done := false  # a wave has run; it does not start again
var _wave_left := 0.0

func setup(player) -> void:
	_player = player
	_drop_rng.seed = seed_value
	_power_rng.seed = seed_value + 3
	_loot_rng.seed = seed_value + 5
	_luck.seed = seed_value + 7
	if profile != null:
		for w in profile.attached:
			att_left[profile.attached[w]] = profile.shots_left(profile.attached[w])
	_base = {"hp": player.max_health, "armor": player.armor, "speed": player.speed_mult, "reload": reload_seconds}
	player.died.connect(_on_player_died)
	for id in carry:
		player.inventory.add(id, int(carry[id]))
	if start_ammo > 0:
		brought["ammo"] = start_ammo - player.inventory.add("ammo", start_ammo)
	for id in WeaponData.DATA:
		loaded[id] = mini(clip_size(id), player.inventory.count(WeaponData.DATA[id]["ammo_item"]))
	Telemetry.start({"seed": seed_value, "start_ammo": start_ammo, "reward_mult": reward_mult, "threat_delay": threat_delay, "depth": depth, "map": map_info})
	_apply_upgrades()

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
	return mini(clip_size(weapon_id), _player.inventory.count(w["ammo_item"]))

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

# What the character's attributes add to `stat` (data/upgrades.gd), 0 with no profile.
func _bonus(stat: String) -> float:
	return profile.bonus(stat) if profile != null else 0.0

# Rounds a magazine of `weapon_id` holds: its clip, plus the Extended mags attribute.
func clip_size(weapon_id: String) -> int:
	return maxi(int(round(float(WeaponData.DATA[weapon_id]["clip"]) * (1.0 + _bonus("clip")))), 1)

# The attachment fitted to a weapon that still works (not broken): its id, or "".
func _attachment_id(weapon_id: String) -> String:
	if profile == null:
		return ""
	var id: String = profile.attached.get(weapon_id, "")
	return id if id != "" and int(att_left.get(id, 0)) > 0 else ""

func _att(weapon_id: String) -> Dictionary:
	var id := _attachment_id(weapon_id)
	return Attachments.DATA[id] if id != "" else {}

# What the weapon's working attachment does to its zoom: 1.0 with none, 0.5 for a Scope.
func zoom_mult(weapon_id: String) -> float:
	return float(_att(weapon_id).get("zoom", 1.0))

# The field of view multiplier while zoomed: the attachment's, and the Eagle eye attribute's (never past 0.4).
func fov_mult(weapon_id: String) -> float:
	return zoom_mult(weapon_id) * clampf(1.0 - _bonus("zoom"), 0.4, 1.0)

# The player changed weapon: its attachment changes the reload time.
func weapon_changed() -> void:
	if _player != null:
		_apply_upgrades()

# One shot of wear for the attachment on `weapon_id`; at 0 it breaks and stops helping.
func _wear_attachment(weapon_id: String) -> void:
	var id := _attachment_id(weapon_id)
	if id == "" or (_bonus("att_wear") > 0.0 and _luck.randf() < _bonus("att_wear")):
		return
	att_left[id] = int(att_left[id]) - 1
	if att_left[id] <= 0:
		attachment_broke.emit(Attachments.DATA[id]["name"])
		_apply_upgrades()

# "HEAVY BARREL 87" for the HUD (the current weapon's attachment), "" with none or "HEAVY BARREL BROKEN".
func attachment_text() -> String:
	if profile == null:
		return ""
	var id: String = profile.attached.get(_player.weapon_id, "")
	if id == "":
		return ""
	var left := int(att_left.get(id, 0))
	return "%s %s" % [Attachments.DATA[id]["name"].to_upper(), str(left) if left > 0 else "BROKEN"]

# The player pulled the trigger. Checks the raid state, the weapon's cooldown and the
# backpack's ammo; if all allow it, spends the ammo and resolves every pellet against
# the world. `aim` is the camera's transform. Returns true if a shot was fired.
func request_fire(weapon_id: String, aim: Transform3D) -> bool:
	if state != State.ACTIVE or _fire_cooldown > 0.0 or reload_weapon != "" or not WeaponData.DATA.has(weapon_id):
		return false
	var w: Dictionary = WeaponData.DATA[weapon_id]
	var att := _att(weapon_id)
	var range_mult := 1.0 + _bonus("range")  # Long shot
	if range_mult != 1.0:
		w = w.duplicate()
		w["effective"] = float(w["effective"]) * range_mult
		w["max"] = float(w["max"]) * range_mult
	_cooldown_total = w["cooldown"] * cooldown_mult * float(att.get("cooldown", 1.0))
	_fire_cooldown = _cooldown_total  # also paces the dry-fire click
	var item: String = w["ammo_item"]
	var cost: int = w["ammo_per_shot"]
	var free := _bonus("ammo_save") > 0.0 and _luck.randf() < _bonus("ammo_save")  # Thrifty: this shot costs nothing
	if loaded_rounds(weapon_id) < cost or (not free and not _player.inventory.remove(item, cost)):
		dry_fire.emit()
		Telemetry.emit("player.fire.weapon", {"id": weapon_id, "outcome": "dry", "hits": 0, "dmg": 0, "ammo_left": _player.inventory.count(item)})
		return false
	var spent := 0 if free else cost
	if brought.has(item):
		brought[item] = maxi(int(brought[item]) - spent, 0)  # the kit is spent first
	loaded[weapon_id] = int(loaded[weapon_id]) - spent
	shots += 1
	ammo_spent += spent
	shot_fired.emit(weapon_id)
	var hits := 0
	var total_dmg := 0
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var spread: float = float(w["spread"]) * float(att.get("spread", 1.0)) * maxf(1.0 - _bonus("spread"), 0.0)
	var weapon_mul := float(damage_mult.get(weapon_id, 1.0)) * _dmg_factor * float(att.get("damage", 1.0)) * (1.0 + _bonus("dmg_" + weapon_id))
	var crit := _bonus("crit")
	var unaware_mul := 1.0 + _bonus("dmg_unaware")
	for i in int(w["pellets"]):
		var dir := -aim.basis.z
		if spread > 0.0:
			dir = (dir + aim.basis.x * randf_range(-spread, spread) + aim.basis.y * randf_range(-spread, spread)).normalized()
		var query := PhysicsRayQueryParameters3D.create(aim.origin, aim.origin + dir * float(w["max"]))
		query.exclude = [_player.get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		var end: Vector3 = hit["position"] if hit else aim.origin + dir * minf(float(w["max"]), 90.0)
		bullet_traced.emit(weapon_id, end, hit.get("normal", Vector3.ZERO), "enemy" if hit and hit["collider"].has_method("take_damage") else ("wall" if hit else "none"))
		if hit and hit["collider"].has_method("take_damage"):
			var dmg_f := weapon_mul
			if "alert" in hit["collider"] and not hit["collider"].alert:
				dmg_f *= unaware_mul  # Ambusher
			if crit > 0.0 and _luck.randf() < crit:
				dmg_f *= 2.0  # Lethal
			var zone := ""
			if hit["collider"].has_method("zone_at"):  # armor in front, weak points on the head and back
				zone = hit["collider"].zone_at(hit["position"], aim.origin)
				dmg_f *= hit["collider"].zone_mult(zone)
				if zone != "":
					zone_hit.emit(zone)
			var dmg := int(round(WeaponData.damage_at(w, aim.origin.distance_to(hit["position"])) * dmg_f))
			hits += 1
			total_dmg += dmg
			var enemy = hit["collider"]
			var kill_info := {}
			if "stats" in enemy:  # only enemies carry type/modifier
				kill_info = {"id": enemy.stats["type"], "mod": enemy.stats["modifier"], "group": enemy.group_id,
					"weapon": weapon_id, "zone": zone, "range": aim.origin.distance_to(hit["position"]), "pos": enemy.global_position}
			if enemy.take_damage(dmg) and "stats" in enemy:  # the enemy base dying is not a kill
				_player.kills += 1
				_combo_add(enemy.stats)
				var heal := int(round(_bonus("kill_heal")))  # Bloodlust
				if heal > 0:
					_player.health = mini(_player.health + heal, _player.max_health)
				Telemetry.emit("player.kill.enemy", kill_info)
				_drop_ammo(enemy.global_position, enemy.stats)
				_on_kill(enemy.global_position, enemy.stats)
	_wear_attachment(weapon_id)
	if hits > 0:
		shots_hit += 1
	Telemetry.emit("player.fire.weapon", {"id": weapon_id, "outcome": "fired", "hits": hits, "dmg": total_dmg, "ammo_left": _player.inventory.count(item)})
	return true

# --- raid upgrades and powerups ---

func _lvl(id: String) -> int:
	return int(upgrades.get(id, 0))

# Recomputes the player's numbers from the base values, the raid upgrades and the active powerups.
func _apply_upgrades() -> void:
	var up: Dictionary = Upgrades.RAID_UPGRADES
	var t := {}  # each upgrade's levels counted in full levels (every 3 levels the next ones add less)
	for id in up:
		t[id] = Upgrades.total(_lvl(id))
	_dmg_factor = (1.0 + float(up["damage"]["per_level"]) * t["damage"] + _bonus("damage")) * (float(Powerups.DATA["damage"]["mult"]) if powerups.has("damage") else 1.0)
	cooldown_mult = maxf(1.0 - float(up["firerate"]["per_level"]) * t["firerate"] - _bonus("firerate"), 0.25)
	reload_seconds = float(_base["reload"]) * maxf(1.0 - float(up["hands"]["per_level"]) * t["hands"], 0.25) * float(_att(_player.weapon_id).get("reload", 1.0))
	_player.max_health = int(_base["hp"]) + int(round(float(up["vitality"]["hp"]) * t["vitality"]))
	_player.health = mini(_player.health, _player.max_health)
	var armor := minf(float(_base["armor"]) + float(up["plating"]["per_level"]) * t["plating"], 0.8)
	if powerups.has("shield"):
		armor = 1.0 - (1.0 - armor) * float(Powerups.DATA["shield"]["taken"])
	_player.armor = armor
	_player.speed_mult = (float(_base["speed"]) + float(up["sprint"]["per_level"]) * t["sprint"]) * (float(Powerups.DATA["haste"]["mult"]) if powerups.has("haste") else 1.0)
	_player.gravity_mult = maxf(1.0 - float(up["jump"]["per_level"]) * t["jump"], 0.3)  # lower gravity, higher jumps

# A kill leaves one XP orb per point of the enemy's difficulty, and may drop scrap, an attachment or a powerup.
func _on_kill(pos: Vector3, stats := {}) -> void:
	if not stats.is_empty():
		for i in Enemies.xp_value(stats):
			var orb := XpOrb.new()
			orb.position = pos + Vector3(_loot_rng.randf_range(-1.2, 1.2), 0, _loot_rng.randf_range(-1.2, 1.2))
			get_parent().add_child.call_deferred(orb)
	if not stats.is_empty() and _loot_rng.randf() < float(stats.get("scrap_chance", 0.0)) * (1.0 + _bonus("scrap_find")):  # scrap repairs attachments
		var amount: Array = stats["scrap"]
		_spawn_pickup("scrap", _loot_rng.randi_range(amount[0], amount[1]), pos + Vector3(0.7, 0, 0))
	if _loot_rng.randf() < Tuning.ATTACHMENT_DROP_CHANCE * (1.0 + _bonus("att_find")):  # super rare
		_spawn_pickup(Attachments.DATA.keys()[_loot_rng.randi_range(0, Attachments.DATA.size() - 1)], 1, pos + Vector3(-0.7, 0, 0))
	if _power_rng.randf() < Tuning.POWERUP_DROP_CHANCE * (1.0 + _bonus("powerup_find")):
		var p := Powerup.new()
		p.id = Powerups.DATA.keys()[_power_rng.randi_range(0, Powerups.DATA.size() - 1)]
		p.position = pos
		get_parent().add_child.call_deferred(p)

func _spawn_pickup(id: String, qty: int, pos: Vector3) -> void:
	var pickup := Pickup.new()
	pickup.id = id
	pickup.qty = qty
	pickup.position = pos
	get_parent().add_child.call_deferred(pickup)

# XP the next level needs: more for each level already won.
func xp_needed() -> int:
	return Upgrades.RAID_XP_BASE + Upgrades.RAID_XP_GROWTH * (raid_level() - 1)

# Adds experience; each full level earns a pick.
func add_xp(amount: int) -> void:
	_xp_extra += amount * _bonus("xp_gain")  # Quick study: the fractions add up to whole points
	var extra := int(_xp_extra)
	_xp_extra -= extra
	xp += amount + extra
	while xp >= xp_needed():
		xp -= xp_needed()
		picks_pending += 1

# The player walked into an XP orb.
func collect_xp(orb) -> bool:
	if state != State.ACTIVE or not is_instance_valid(orb) or orb.is_queued_for_deletion():
		return false
	add_xp(orb.amount)
	orb.queue_free()
	return true

# RAID_PICK_CHOICES random upgrades (there is no top level, so there is always something to offer).
func pick_choices() -> Array:
	var open: Array = Upgrades.RAID_UPGRADES.keys()
	open.shuffle()
	return open.slice(0, Upgrades.RAID_PICK_CHOICES)

# Spends a pending level-up on upgrade `id`. False (nothing changes) with none pending.
func choose_upgrade(id: String) -> bool:
	if state != State.ACTIVE or picks_pending <= 0 or not Upgrades.RAID_UPGRADES.has(id):
		return false
	picks_pending -= 1
	upgrades[id] = _lvl(id) + 1
	_apply_upgrades()
	if id == "vitality":
		_player.health = mini(_player.health + int(round(float(Upgrades.RAID_UPGRADES[id]["hp"]) * Upgrades.step_factor(_lvl(id) - 1))), _player.max_health)
	Telemetry.emit("player.pick.upgrade", {"id": id, "level": _lvl(id)})
	return true

# The player walked into a powerup: its effect starts (or restarts) for its full duration.
func collect_powerup(p) -> bool:
	if state != State.ACTIVE or not is_instance_valid(p) or p.is_queued_for_deletion():
		return false
	powerups[p.id] = float(Powerups.DATA[p.id]["seconds"]) * (1.0 + _bonus("powerup_time"))
	p.queue_free()
	_apply_upgrades()
	return true

# The raid level (1 + the upgrades taken and waiting) and how far the kills are toward the next one (0..1), for the XP bar.
func raid_level() -> int:
	var taken := 0
	for id in upgrades:
		taken += int(upgrades[id])
	return 1 + taken + picks_pending

func xp_fraction() -> float:
	return float(xp) / float(xp_needed())

# "OVERDRIVE 8s  HASTE 3s" for the HUD, "" with none active.
func powerup_text() -> String:
	var parts: Array = []
	for id in powerups:
		parts.append("%s %ds" % [Powerups.DATA[id]["name"], ceili(powerups[id])])
	return "  ".join(parts)

# Rolls an enemy's ammo drop (data/enemies.gd) and, on success, leaves a pickup where it died.
func _drop_ammo(pos: Vector3, stats: Dictionary) -> bool:
	if _drop_rng.randf() >= float(stats.get("drop_chance", 0.0)) * drop_mult * (1.0 + _bonus("ammo_drop")):
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
	var quick := maxf(1.0 - _bonus("extract_speed"), 0.3)  # Quick exit
	if zone_id == "B":
		return hold_seconds * b_hold_seconds / Tuning.EXTRACT_HOLD_SECONDS * quick
	return hold_seconds * quick

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
	_regen(delta)
	_tick_combo(delta)
	_clear_clock += delta
	if _clear_clock >= 0.5:
		_clear_clock = 0.0
		check_round_clear()
	for id in powerups.keys():
		powerups[id] -= delta
		if powerups[id] <= 0.0:
			powerups.erase(id)
			_apply_upgrades()
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

# Regeneration: the fractions of a point add up to whole health.
func _regen(delta: float) -> void:
	var rate := _bonus("regen")
	if rate <= 0.0 or _player.health >= _player.max_health:
		return
	_regen_acc += rate * delta
	var whole := int(_regen_acc)
	_regen_acc -= whole
	_player.health = mini(_player.health + whole, _player.max_health)

# --- kill combo ---

# Seconds a combo of `count` kills lasts after its last kill: COMBO_WINDOW, less COMBO_WINDOW_SHRINK for every
# kill after the first (never under COMBO_WINDOW_MIN), then Adrenaline.
func combo_window(count: int) -> float:
	return maxf(Tuning.COMBO_WINDOW - Tuning.COMBO_WINDOW_SHRINK * (count - 1), Tuning.COMBO_WINDOW_MIN) * (1.0 + _bonus("combo_time"))

# The score multiplier a combo of `count` kills pays: 1 for the first, COMBO_MULT_STEP more for every kill after.
func combo_mult(count: int) -> float:
	return 1.0 + Tuning.COMBO_MULT_STEP * (count - 1)

# What the running combo pays if it ended now.
func combo_payout() -> int:
	return int(round(combo_points * combo_mult(combo) * (1.0 + _bonus("combo_score"))))

func _combo_add(stats: Dictionary) -> void:
	combo += 1
	best_combo = maxi(best_combo, combo)
	combo_points += Enemies.xp_value(stats) * Tuning.COMBO_KILL_SCORE  # a tougher enemy is worth more
	combo_total = combo_window(combo)
	combo_left = combo_total
	combo_kill.emit(combo)

func _tick_combo(delta: float) -> void:
	if combo > 0:
		combo_left -= delta
		if combo_left <= 0.0:
			end_combo()

# The combo runs out (or the raid ends): the multiplied score is paid and the counter starts over.
func end_combo() -> void:
	if combo <= 0:
		return
	var bonus := combo_payout()
	score += bonus
	var count := combo
	combo = 0
	combo_points = 0
	combo_left = 0.0
	combo_ended.emit(count, bonus)

# --- rounds ---

# Round number of this level: 1 at the base's first raid, then one more for every descent.
func round_number() -> int:
	return depth + 1

# Every ATTR_ROUNDS_PER_POINT rounds, once no enemy and no enemy base is left alive the round is cleared and the
# player earns an attribute point (saved at once, so dying afterwards keeps it). True the moment that happens.
func check_round_clear() -> bool:
	if state != State.ACTIVE or round_cleared or round_number() % Upgrades.ATTR_ROUNDS_PER_POINT != 0:
		return false
	for group in ["enemy", "spawner"]:
		for n in get_tree().get_nodes_in_group(group):
			if not n.is_queued_for_deletion():
				return false
	round_cleared = true
	if profile != null and profile.grant_point():
		points_earned += 1
		profile.save()
		point_earned.emit()
	return true

# --- the ready indicator ---

# True when the next trigger pull would fire: no wait between shots, no reload, and rounds in the magazine.
func shot_ready(weapon_id: String) -> bool:
	return state == State.ACTIVE and _fire_cooldown <= 0.0 and reload_weapon == "" and loaded_rounds(weapon_id) >= int(WeaponData.DATA[weapon_id]["ammo_per_shot"])

# How far the wait between shots has got, 0..1 (1 = the weapon is ready).
func shot_progress() -> float:
	return 1.0 if _cooldown_total <= 0.0 else clampf(1.0 - _fire_cooldown / _cooldown_total, 0.0, 1.0)

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
# Seconds until the threat clock fires, or -1 once it has (or if this raid never has one).
func threat_countdown() -> float:
	if _threat_reached or threat_delay <= 0.0 or threat_delay >= 1.0e6:
		return -1.0
	return maxf(threat_delay - elapsed, 0.0)

# True once the threat clock has fired, even if a wave has since ended.
func threat_fired() -> bool:
	return _threat_reached

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
	end_combo()
	var items := _loot()
	if outcome == "extracted":  # the raid difficulty scales what is kept (what is lost stays as it was)
		for id in items:
			if not id.begins_with("att_"):  # a super rare attachment is not multiplied
				items[id] = Difficulty.scale(int(items[id]), reward_mult)
	_player.inventory.clear()  # kept loot goes to the profile, lost loot is gone
	var saved := true
	if profile != null:
		for id in att_left:  # wear counts whether the raid was won or lost
			profile.set_wear(id, att_left[id])
		if outcome == "extracted":
			profile.add_items(items)
			profile.record_extract()
		profile.record_raid(outcome == "extracted", _player.kills, shots, shots_hit, depth + 1)
		saved = profile.save()
	var end_info := {"outcome": outcome, "loot": items, "kills": _player.kills, "shots": shots, "hits": shots_hit,
		"ammo_spent": ammo_spent, "duration": elapsed, "threat_reached": _threat_reached, "depth": depth}
	Telemetry.emit("raid.end.raid", end_info)
	Telemetry.finish()
	Telemetry.record_run(end_info)
	ended.emit({"outcome": outcome, "items": items, "saved": saved, "kills": _player.kills, "points": points_earned, "reward_mult": reward_mult, "score": score, "best_combo": best_combo,
		"shots": shots, "hits": shots_hit, "duration": elapsed, "depth": depth})
