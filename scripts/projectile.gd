extends Area3D
# A slow glowing shot fired by a super brute. It flies in a straight line at the speed and in the direction it was
# given when fired (it does not follow the player, so it can be dodged), hurts the player on contact, and is gone
# when it touches a wall or cover or has flown for LIFETIME seconds.

const Sfx = preload("res://scripts/sfx.gd")

const LIFETIME := 6.0

var direction := Vector3.FORWARD
var speed := 7.0
var damage := 10
var radius := 0.4
var color := Color(1.0, 0.45, 0.05)
var _age := 0.0

func _ready() -> void:
	add_to_group("projectile")
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	if radius >= 0.3:  # the small volley shots glow through their material only: a light each would be too many
		var glow := OmniLight3D.new()
		glow.light_color = color
		glow.omni_range = 4.0
		add_child(glow)
	body_entered.connect(_on_body)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_age += delta
	if _age >= LIFETIME:
		queue_free()

func _on_body(body: Node3D) -> void:
	if body.is_in_group("player"):
		if not body.safe:  # a shelter keeps shots out too
			body.take_damage(damage)
		Sfx.play("enemy_strike", global_position)
		queue_free()
	elif not body is CharacterBody3D:  # walls, cover and bases stop it; other enemies do not
		queue_free()
