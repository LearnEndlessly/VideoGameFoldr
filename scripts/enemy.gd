extends CharacterBody3D

const Sfx = preload("res://scripts/sfx.gd")

const REACH := 1.8
const SIGHT := 18.0         # a patrolling enemy notices the player inside this range
const LOSE := 30.0          # an alert enemy loses the player beyond this range
const GIVE_UP := 4.0        # seconds out of reach before going back to patrol
const PATROL_RADIUS := 8.0
const PATROL_SPEED := 0.4   # fraction of chase speed
const ALERT_COLOR := Color(1.0, 0.9, 0.1)

var stats := {}  # set by the spawner from data/enemies.gd before add_child
var home := Vector3.ZERO
var group_id := 0
var health := 1
var max_health := 1
var alert := false

var _attack_cd := 0.0
var _lost_timer := 0.0
var _repick := 0.0
var _target := Vector3.ZERO
var _mat := StandardMaterial3D.new()
var _label := Label3D.new()
var _bar := Node3D.new()        # faces the camera each frame
var _bar_fill: MeshInstance3D
var _bar_width := 1.0

func _ready() -> void:
	add_to_group("pack_%d" % group_id)
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
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 2.0 * size + 0.6
	add_child(_label)
	_update_label()
	_build_bar(size)

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
	if on:
		Sfx.play("alert", global_position)
	_mat.albedo_color = ALERT_COLOR if on else stats["color"]
	_mat.emission_enabled = on
	_update_label()

# One enemy noticing the player (or being shot) wakes its whole group.
func alert_pack() -> void:
	get_tree().call_group("pack_%d" % group_id, "set_alert", true)

func _update_label() -> void:
	_label.text = ("%s%s %s" % ["! " if alert else "", stats["modifier"], stats["type"]]).replace("  ", " ")

# Returns true if this hit killed the enemy.
func take_damage(amount: int) -> bool:
	if health <= 0:  # already dead this frame (e.g. a later pellet of the same shot)
		return false
	health -= amount
	alert_pack()
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
		# Look away from the camera so the quads' front faces it.
		_bar.look_at(_bar.global_position * 2.0 - cam.global_position)

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

	if not alert and dist < SIGHT:
		alert_pack()

	if alert:
		if dist > LOSE:
			_lost_timer += delta
			if _lost_timer >= GIVE_UP:
				set_alert(false)
		else:
			_lost_timer = 0.0
			if dist > REACH:
				_walk(to_player, float(stats["speed"]))
			else:
				_attack_cd -= delta
				if _attack_cd <= 0.0:
					_attack_cd = 1.0
					player.take_damage(stats["damage"])
	else:
		_repick -= delta
		var to_target := _target - global_position
		to_target.y = 0.0
		if _repick <= 0.0 or to_target.length() < 1.0:
			_repick = randf_range(3.0, 6.0)
			_target = home + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * PATROL_RADIUS
		else:
			_walk(to_target, float(stats["speed"]) * PATROL_SPEED)

	velocity.y = velocity.y - 20.0 * delta if not is_on_floor() else 0.0
	move_and_slide()

func _walk(dir: Vector3, speed: float) -> void:
	var d := dir.normalized() * speed
	velocity.x = d.x
	velocity.z = d.z
