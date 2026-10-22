extends CharacterBody3D

const Sfx = preload("res://scripts/sfx.gd")
const Tuning = preload("res://data/tuning.gd")
const Model = preload("res://scripts/model.gd")
const Telemetry = preload("res://scripts/telemetry.gd")
const Enemies = preload("res://data/enemies.gd")
const Projectile = preload("res://scripts/projectile.gd")

const REACH := 1.8
const LOSE := 30.0          # an alert enemy loses the player beyond this range
const GIVE_UP := 4.0        # seconds out of reach before going back to patrol
const PATROL_RADIUS := 8.0
const CONVERGE_ARRIVE := 3.0  # metres from the target at which a converging enemy stops
const PATROL_SPEED := 0.4   # fraction of chase speed
const ALERT_COLOR := Color(1.0, 0.9, 0.1)

var stats := {}  # set by the spawner from data/enemies.gd before add_child
var home := Vector3.ZERO
var patrol_radius := PATROL_RADIUS  # how far from home it wanders (a base's garrison stays tight)
var group_id := 0
var health := 1
var max_health := 1
var alert := false
var suspicion := 0.0  # 0..1; fills while the player is seen or heard, full = alert
var detect_seconds: float = Tuning.ENEMY_DETECT_SECONDS  # raised or lowered by the raid difficulty
var last_seen := Vector3.ZERO  # where the player was last seen or heard; a suspicious enemy looks and creeps here
var converging := false          # the threat clock sent this enemy toward converge_target
var converge_target := Vector3.ZERO

var _attack_cd := 0.0
var _shot_cd := 2.0  # seconds until a ranged enemy may fire
var _volley := 0  # which of the ranged patterns fires next
var _hover_y := 0.0  # the height a flyer holds
var _ping := 0.0  # seconds until a scout next raises the alarm
var _whir := 0.0  # seconds until a scout's next rotor sound
var _lost_timer := 0.0
var _repick := 0.0
var _step_dist := 0.0  # metres walked since the last footstep sound
var _target := Vector3.ZERO
var _model_meshes: Array = []  # MeshInstance3D nodes of the art model, if one is used
var _mat := StandardMaterial3D.new()
var _label := Label3D.new()
var _cone_mat := StandardMaterial3D.new()
var _cone: MeshInstance3D
var _bar := Node3D.new()        # faces the camera each frame
var _bar_fill: MeshInstance3D
var _bar_width := 1.0

# An enemy that never entered the scene tree (the base's map preview builds maps off-tree) never parented
# its label and bar; free them with it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for n in [_label, _bar]:
			if is_instance_valid(n) and n.get_parent() == null:
				n.free()

func _ready() -> void:
	add_to_group("pack_%d" % group_id)
	add_to_group("enemy")
	health = stats["health"]
	max_health = health
	_target = home
	var size: float = stats["size"]
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5 * size
	cap.height = 2.0 * size
	var shape := CollisionShape3D.new()
	shape.shape = cap
	shape.position.y = size
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = cap.radius
	cm.height = cap.height
	mesh.mesh = cm
	mesh.position.y = size
	_mat.albedo_color = stats["color"]
	_mat.emission = ALERT_COLOR
	mesh.material_override = _mat
	add_child(mesh)
	if stats.get("zones", true):
		_build_zones(size)
	if stats.get("flying", false):
		_build_wings(size)
		collision_mask = 0  # it flies over walls and cover
		_hover_y = position.y + float(stats["hover"])
		position.y = _hover_y
	var model := Model.load_scene(stats.get("model", ""))
	if model != null:  # an art asset replaces the placeholder capsule (kept, hidden)
		mesh.visible = false
		model.name = "Model"
		model.scale = Vector3.ONE * size * float(stats.get("model_scale", 1.0))
		add_child(model)
		for m in model.find_children("*", "MeshInstance3D", true, false):
			_model_meshes.append(m)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 2.0 * size + 0.6
	add_child(_label)
	_update_label()
	_build_bar(size)
	_build_cone()

# Health bar: the frame is blue for armored enemies, and the fill shrinks and
# shifts from green to red as health drops.
func _build_bar(size: float) -> void:
	_bar_width = 1.2 * size
	_bar.position.y = 2.0 * size + 0.3
	add_child(_bar)
	var frame_color := Color(0.2, 0.35, 0.9) if stats["modifier"] == "armored" else Color(0.1, 0.1, 0.1)
	var frame := _bar_quad(Vector2(_bar_width + 0.08, 0.2), frame_color)
	_bar_fill = _bar_quad(Vector2(_bar_width, 0.12), Color.GREEN)
	_bar_fill.position.z = 0.01
	_bar.add_child(frame)
	_bar.add_child(_bar_fill)

# A flat wedge on the ground showing where this enemy is looking: faint white, reddening as suspicion
# fills. Its shape is rebuilt as the enemy moves so walls and cover cut it short, like its sight.
func _build_cone() -> void:
	_cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone = MeshInstance3D.new()
	_cone.mesh = ArrayMesh.new()
	_cone.material_override = _cone_mat
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cone)
	_update_cone_shape()
	_refresh_cone()

const CONE_STEPS := 16

func _update_cone_shape() -> void:
	var half := deg_to_rad(Tuning.ENEMY_FOV_DEGREES / 2.0)
	var pts := PackedVector3Array([Vector3(0, 0.05, 0)])
	for i in CONE_STEPS + 1:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, lerpf(half, -half, float(i) / CONE_STEPS))
		var p := dir * _ray_reach(dir)
		pts.append(Vector3(p.x, 0.05, p.z))
	var idx := PackedInt32Array()
	for i in CONE_STEPS:
		idx.append_array([0, i + 1, i + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = _cone.mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

# How far (m, up to the sight range) this enemy can see along `local_dir`, a flat direction in its own
# frame, before a wall or cover stops it. Cast at eye height, like _has_line_of_sight.
func _ray_reach(local_dir: Vector3) -> float:
	var reach: float = Tuning.ENEMY_SIGHT_RANGE
	var from := global_position + Vector3(0, 1.4 * float(stats["size"]), 0)
	var hit := _first_solid(from, from + global_transform.basis * local_dir * reach)
	return reach if hit.is_empty() else from.distance_to(hit["position"])

func _refresh_cone() -> void:
	_cone.visible = not alert and not stats.get("flying", false)
	_cone_mat.albedo_color = Color(1, 1, 1, 0.12).lerp(Color(1, 0.25, 0.1, 0.4), suspicion)

func _bar_quad(quad_size: Vector2, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = quad_size
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	return m

func _refresh_bar() -> void:
	var frac := clampf(float(health) / max_health, 0.0, 1.0)
	_bar_fill.scale.x = maxf(frac, 0.001)
	_bar_fill.position.x = -(1.0 - frac) * _bar_width / 2.0
	_bar_fill.material_override.albedo_color = Color.RED.lerp(Color.GREEN, frac)

func set_alert(on: bool) -> void:
	if on == alert:
		return
	alert = on
	_lost_timer = 0.0
	suspicion = 0.0
	if _cone != null:
		_refresh_cone()
	if on:
		Sfx.play("alert", global_position)
	_mat.albedo_color = ALERT_COLOR if on else stats["color"]
	_mat.emission_enabled = on
	for m in _model_meshes:  # a model keeps its own look until alert, then takes the alert colour
		m.material_override = _mat if on else null
	_update_label()

# Threat clock (see raid.gd): head for `target` instead of patrolling, until end_converge().
func set_converge(target: Vector3) -> void:
	converging = true
	converge_target = target

# Back to patrolling, around wherever the enemy is now.
func end_converge() -> void:
	converging = false
	home = global_position
	_target = home

# Raid difficulty (data/difficulty.gd): scale the damage this enemy deals and set its alarm time.
# The round's toughening (Enemies.round_scale). Called before the enemy joins the tree (a spawner's) or after (the
# map's), so health is re-read from the stats when it already exists.
func apply_depth(health_mult: float, speed_mult: float, damage_mult: float) -> void:
	stats["health"] = int(round(stats["health"] * health_mult))
	stats["speed"] = float(stats["speed"]) * speed_mult
	stats["damage"] = int(round(stats["damage"] * damage_mult))
	if max_health > 1:
		max_health = stats["health"]
		health = max_health

func apply_difficulty(damage_mult: float, detect: float) -> void:
	stats["damage"] = int(round(stats["damage"] * damage_mult))
	detect_seconds = detect

# One enemy noticing the player (or being shot) wakes its whole group.
func alert_pack(cause: String = "sight") -> void:
	if not alert:  # the first enemy to notice reports for the group
		var p = get_tree().get_first_node_in_group("player")
		Telemetry.emit("enemy.alert.group", {"group": group_id, "cause": cause,
			"dist": global_position.distance_to(p.global_position) if p != null else -1.0})
	get_tree().call_group("pack_%d" % group_id, "set_alert", true)

func _update_label() -> void:
	_label.text = ("%s%s %s" % ["! " if alert else "", stats["modifier"], str(stats["type"]).replace("_", " ")]).replace("  ", " ")

# Returns true if this hit killed the enemy.
func take_damage(amount: int) -> bool:
	if health <= 0:  # already dead this frame (e.g. a later pellet of the same shot)
		return false
	health -= amount
	alert_pack("shot")
	if health <= 0:
		Sfx.play("kill", global_position)
		queue_free()
		return true
	Sfx.play("hit", global_position)
	_refresh_bar()
	return false

func _process(_d: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_bar.global_basis = cam.global_basis  # parallel to the screen: faces the camera without skewing

func _physics_process(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	var player = get_tree().get_first_node_in_group("player")
	var to_player := Vector3.ZERO
	var dist := INF  # stays INF while the player is sheltered, so enemies lose them
	if player != null and not player.safe:
		to_player = player.global_position - global_position
		to_player.y = 0.0
		dist = to_player.length()

	if not alert:
		_update_suspicion(player, dist, delta)
		if not stats.get("flying", false):
			_update_cone_shape()

	if alert:
		if dist > LOSE:
			_lost_timer += delta
			if _lost_timer >= GIVE_UP:
				set_alert(false)
		else:
			_lost_timer = 0.0
			_try_shoot(delta, player, dist)
			if stats.get("flying", false):
				_scout_hover(delta, player, to_player, dist)
			elif dist > REACH or absf(player.global_position.y - global_position.y) > 2.5:  # a player up a tower cannot be reached
				_walk(to_player, float(stats["speed"]))
			else:
				_attack_cd -= delta
				if _attack_cd <= 0.0:
					_attack_cd = 1.0
					Sfx.play("enemy_strike", global_position)
					player.take_damage(stats["damage"])
					Telemetry.emit("enemy.hit.player", {"id": stats["type"], "mod": stats["modifier"], "group": group_id,
						"dmg": stats["damage"], "hp_after": player.health})
	elif converging:
		var to_c := converge_target - global_position
		to_c.y = 0.0
		if to_c.length() > CONVERGE_ARRIVE:
			_walk(to_c, float(stats["speed"]))
	elif suspicion > 0.0:
		_investigate(delta)
	else:
		_repick -= delta
		var to_target := _target - global_position
		to_target.y = 0.0
		if _repick <= 0.0 or to_target.length() < 1.0:
			_repick = randf_range(3.0, 6.0)
			_target = home + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * patrol_radius
		else:
			_walk(to_target, float(stats["speed"]) * PATROL_SPEED)

	if stats.get("flying", false):
		velocity.y = clampf((_hover_y - global_position.y) * 3.0, -4.0, 4.0)  # holds its height
	else:
		velocity.y = velocity.y - 20.0 * delta if not is_on_floor() else 0.0
	move_and_slide()
	_turn(to_player if alert else Vector3(velocity.x, 0, velocity.z), delta)
	_footsteps(delta, player)

# A patrolling enemy perceives the player by hearing them sprint (through walls, close range) or by
# seeing them (inside its view cone, in range, with a clear line of sight). dist is INF when the
# player is sheltered, so neither works then. Perceiving is not alerting: see _update_suspicion.
func _notices(player, dist: float) -> bool:
	return _hears(player, dist) or _sees(player, dist)

func _hears(player, dist: float) -> bool:
	return player.sprinting and dist < Tuning.SPRINT_NOISE_RANGE

func _sees(player, dist: float) -> bool:
	if dist >= float(stats.get("sight", Tuning.ENEMY_SIGHT_RANGE)):  # a scout looks down from high up and sees far
		return false
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var forward := -global_transform.basis.z
	forward.y = 0.0
	var cos_half := cos(deg_to_rad(Tuning.ENEMY_FOV_DEGREES / 2.0))
	var in_cone := dist < Tuning.ENEMY_NEAR_SENSE or bool(stats.get("scout", false)) or forward.normalized().dot(to_player.normalized()) >= cos_half
	return in_cone and _has_line_of_sight(player)

# Seen or heard: the meter fills over detect_seconds (Tuning.ENEMY_DETECT_SECONDS unless the difficulty changes it; never under
# ENEMY_MIN_GAZE_SECONDS); otherwise it drains.
# A full meter alerts the whole group.
func _update_suspicion(player, dist: float, delta: float) -> void:
	var gain := -1.0 / Tuning.ENEMY_DETECT_DECAY_SECONDS
	var cause := "sight"
	if player != null and _sees(player, dist):
		gain = (1.0 - (player.stealth if "stealth" in player else 0.0)) / _detect()  # Ghost
		last_seen = player.global_position
	elif player != null and _hears(player, dist):
		gain = (1.0 - (player.stealth if "stealth" in player else 0.0)) / _detect()
		cause = "noise"
		last_seen = player.global_position
	suspicion = clampf(suspicion + gain * delta, 0.0, 1.0)
	_refresh_cone()
	if suspicion >= 1.0:
		alert_pack(cause)

# Suspicious: stop patrolling, keep facing where the player was last seen or heard, and creep toward it.
# The meter drains while the player stays out of sight, which ends this and resumes the patrol.
func _investigate(delta: float) -> void:
	var to_spot := last_seen - global_position
	to_spot.y = 0.0
	_turn(to_spot, delta)
	if to_spot.length() > Tuning.ENEMY_INVESTIGATE_STOP:
		_walk(to_spot, float(stats["speed"]) * Tuning.ENEMY_INVESTIGATE_SPEED)

# Turn toward `aim` (a flat direction) so the view cone points where the enemy is going or looking.
func _turn(aim: Vector3, delta: float) -> void:
	if aim.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-aim.x, -aim.z), 6.0 * delta)

# True if nothing solid is between this enemy's eyes and the player's chest. Walls and cover block it;
# other enemies in the way do not.
func _has_line_of_sight(player) -> bool:
	var from := global_position + Vector3(0, 1.4 * float(stats["size"]), 0)
	return _first_solid(from, player.global_position + Vector3(0, 1.2, 0)).is_empty()

# The first wall or cover hit by a ray from `from` to `to`, or {} if it is clear. Characters
# (enemies, the player) do not stop it.
func _first_solid(from: Vector3, to: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var skip: Array[RID] = [get_rid()]
	for i in 5:
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = skip
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or not hit["collider"] is CharacterBody3D:
			return hit
		skip.append(hit["rid"])
	return {"position": to}  # five characters in a row: treat as blocked

# Heavier enemies take longer strides and sound lower.
func _footsteps(delta: float, player) -> void:
	if stats.get("flying", false):  # a scout has no feet: its rotors whir instead
		_whir -= delta
		if _whir <= 0.0:
			_whir = Tuning.SCOUT_WHIR_INTERVAL
			if player != null and global_position.distance_to(player.global_position) < Tuning.ENEMY_STEP_HEAR_DISTANCE:
				Sfx.play("scout_whir", global_position)
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.1 or not is_on_floor():
		return
	_step_dist += speed * delta
	var size: float = stats["size"]
	if _step_dist < Tuning.ENEMY_STRIDE * size:
		return
	_step_dist = 0.0
	if player != null and global_position.distance_to(player.global_position) < Tuning.ENEMY_STEP_HEAR_DISTANCE:
		Sfx.play("step_enemy", global_position, 1.0 / size)

func _walk(dir: Vector3, speed: float) -> void:
	var d := dir.normalized() * speed
	velocity.x = d.x
	velocity.z = d.z

# Seconds in view before this enemy raises the alarm: a scout needs only a fraction of the usual time, but nobody alarms a
# whole group on less than Tuning.ENEMY_MIN_GAZE_SECONDS.
func _detect() -> float:
	return maxf(detect_seconds * (Enemies.SCOUT_DETECT_MULT if stats.get("scout", false) else 1.0), Tuning.ENEMY_MIN_GAZE_SECONDS)

# --- hit zones ---

# Where a shot at world `point` from world `from` landed: "head" (the top of the body, from any side), or by where the
# shooter stands: "back", "front" (the armor) or "side". "" for an enemy with no zones (the scout).
func zone_at(point: Vector3, from: Vector3) -> String:
	if not Enemies.zones_enabled or not stats.get("zones", true):
		return ""
	var size: float = stats["size"]
	if to_local(point).y > Enemies.HEAD_HEIGHT * 2.0 * size:
		return "head"
	var d := to_local(from)
	d.y = 0.0
	if d.length() < 0.01:
		return "side"
	d = d.normalized()
	if d.z > 0.3:  # the enemy looks along -Z, so +Z is its back
		return "back"
	return "front" if d.z < -0.3 else "side"

# The damage multiplier of a zone ("" = 1): data/enemies.gd ZONE_MULT, changed by the type's own "zone_mult".
func zone_mult(zone: String) -> float:
	if zone == "":
		return 1.0
	return float(stats.get("zone_mult", {}).get(zone, Enemies.ZONE_MULT[zone]))

# Paints the zones on the body: armor plates (steel blue) on the front, weak points (orange, glowing) on the head
# and the back. The capsule collider does not change; zone_at decides where a shot counts.
func _build_zones(size: float) -> void:
	var r := 0.5 * size
	var front := _zone_box(Vector3(1.7 * r, 1.1 * size, 0.14 * size), Vector3(0, 0.95 * size, -0.95 * r), Enemies.STRONG_COLOR, false)
	front.name = "ArmorFront"
	var back := _zone_box(Vector3(1.0 * r, 0.8 * size, 0.1 * size), Vector3(0, size, 0.97 * r), Enemies.WEAK_COLOR, true)
	back.name = "WeakBack"
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3 * size
	sm.height = 0.6 * size
	head.mesh = sm
	head.position.y = 1.78 * size
	head.material_override = _zone_material(Enemies.WEAK_COLOR, true)
	head.name = "WeakHead"
	add_child(head)

func _zone_box(box_size: Vector3, pos: Vector3, color: Color, glow: bool) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	m.mesh = bm
	m.position = pos
	m.material_override = _zone_material(color, glow)
	add_child(m)
	return m

func _zone_material(color: Color, glow: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.5
	else:
		mat.metallic = 0.6
		mat.roughness = 0.35
	return mat

# --- the scout ---

# Two flat wings, so a scout reads as a small flyer.
func _build_wings(size: float) -> void:
	for s in [-1.0, 1.0]:
		var w := _zone_box(Vector3(1.4 * size, 0.04, 0.5 * size), Vector3(s * 0.9 * size, size, 0), Enemies.TYPES["scout"]["color"].darkened(0.3), false)
		w.name = "Wing"

# Alerted scout: stays 6-10 m from the player, in the air, and every SCOUT_PING_SECONDS raises the alarm.
func _scout_hover(delta: float, player, to_player: Vector3, dist: float) -> void:
	if dist > 10.0:
		_walk(to_player, float(stats["speed"]))
	elif dist < 6.0:
		_walk(-to_player, float(stats["speed"]) * 0.6)
	_ping -= delta
	if _ping <= 0.0:
		_ping = Enemies.SCOUT_PING_SECONDS
		raise_alarm(player.global_position)

# Every enemy within SCOUT_ALERT_RADIUS of this one learns where the player is: those near the player turn alert, the
# rest head for that spot.
func raise_alarm(player_pos: Vector3) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or e.is_queued_for_deletion() or e.global_position.distance_to(global_position) > Enemies.SCOUT_ALERT_RADIUS:
			continue
		e.last_seen = player_pos
		if Vector2(e.global_position.x - player_pos.x, e.global_position.z - player_pos.z).length() <= LOSE:
			e.alert_pack("scout")
		else:
			e.set_converge(player_pos)

# --- ranged attack (the super brute) ---

# Fires at where the player is now, when one is in range, in the open, and the gun is ready: one slow projectile, or (with
# "patterns") the next volley in turn, every shot parallel so the volley keeps its shape. Shots fly straight and can be dodged.
func _try_shoot(delta: float, player, dist: float) -> void:
	var r: Dictionary = stats.get("ranged", {})
	if r.is_empty():
		return
	_shot_cd -= delta
	if _shot_cd > 0.0 or dist < float(r["min"]) or dist > float(r["range"]) or not _has_line_of_sight(player):
		return
	_shot_cd = float(r["cooldown"])
	var origin := global_position + Vector3(0, 1.5 * float(stats["size"]), 0)
	var dir: Vector3 = (player.global_position + Vector3(0, 1.2, 0) - origin).normalized()
	var offsets: Array = [Vector2.ZERO]
	if r.has("patterns"):
		offsets = r["patterns"][_volley % r["patterns"].size()]["offsets"]
		_volley += 1
	var right: Vector3 = dir.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(dir).normalized()
	for o in offsets:
		var p := Projectile.new()
		p.direction = dir
		p.speed = float(r["speed"])
		p.damage = int(round(float(stats["damage"]) * float(r["damage_mult"])))
		p.radius = float(r["radius"])
		p.color = r.get("color", p.color)
		p.position = origin + right * o.x + up * o.y
		get_parent().add_child(p)
	Sfx.play("enemy_strike", global_position)
