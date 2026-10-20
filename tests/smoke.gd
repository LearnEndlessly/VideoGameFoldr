# Run: Godot --headless --path <project> -s tests/smoke.gd
# Opens every crate and toggles the backpack to exercise paths a plain boot never reaches.
extends SceneTree

const Main = preload("res://scripts/main.gd")

func _init() -> void:
	Main.show_start = false
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var player = main._player
	for c in main.get_children():
		if c.is_in_group("lootable"):
			player.global_position = c.global_position
			assert(main.raid.request_loot(c), "a crate within reach must be lootable")
	player.global_position = Vector3.ZERO
	assert(player.inventory.summary() != "nothing", "opening crates must fill the backpack")
	player.health = 50
	for i in player.inventory.slots.size():
		player.use_slot(i)
	player.weapon = player.WeaponData.DATA["scattergun"]
	player._shoot()
	for e in get_nodes_in_group("pack_0"):
		e.take_damage(10)
	player.inventory_toggled.emit(true)
	player.inventory_open = true
	for i in 120:
		await physics_frame
	var alerted := 0
	for e in get_nodes_in_group("pack_0"):
		if e.alert:
			alerted += 1
	print("smoke ok. backpack: ", player.inventory.summary(), " hp: ", player.health, " alerted in pack_0: ", alerted)
	quit()
