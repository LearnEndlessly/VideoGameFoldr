extends PanelContainer
# Backpack grid. The game keeps running while it is open.

const Inventory = preload("res://scripts/inventory.gd")
const ItemIcon = preload("res://scripts/item_icon.gd")

var _player
var _title := Label.new()
var _icons: Array = []
var _qtys: Array = []
var _buttons: Array = []

func setup(player) -> void:
	_player = player
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	add_child(box)
	box.add_child(_title)
	var grid := GridContainer.new()
	grid.columns = 4
	box.add_child(grid)
	for i in Inventory.SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(72, 72)
		b.focus_mode = Control.FOCUS_NONE  # keeps Tab free to close the backpack
		b.gui_input.connect(_on_slot_input.bind(i))
		grid.add_child(b)
		var icon := ItemIcon.new()
		b.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var qty := Label.new()
		qty.position = Vector2(48, 50)
		qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(qty)
		_buttons.append(b)
		_icons.append(icon)
		_qtys.append(qty)
	player.inventory.changed.connect(_refresh)
	player.inventory_toggled.connect(func(open: bool): visible = open)
	_refresh()

func _refresh() -> void:
	var used := 0
	for i in Inventory.SLOTS:
		var s = _player.inventory.slots[i]
		_icons[i].item_id = "" if s == null else s["id"]
		_qtys[i].text = "" if s == null else str(s["qty"])
		_buttons[i].tooltip_text = "" if s == null else s["id"].replace("_", " ")
		if s != null:
			used += 1
	_title.text = "Backpack %d/%d   click: use   right-click: drop   (the game keeps running)" \
		% [used, Inventory.SLOTS]

func _on_slot_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_player.use_slot(i)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_player.inventory.drop(i)
