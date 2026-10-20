extends RefCounted
# The look of every 2D menu: a field-terminal style. Near-black slabs with a hard accent edge (each station has
# its own colour), hazard-tape stripes under headers, heavy spaced capitals, big numerals for the numbers that
# matter, tiles for items and stats instead of lines of text, and pips and meters instead of "2/5".
# Helpers only build nodes; menus call them and keep their own state.

const ItemIcon = preload("res://scripts/item_icon.gd")

const BG := Color(0.045, 0.05, 0.065)
const CARD := Color(0.095, 0.105, 0.135)
const TEXT := Color(0.93, 0.94, 0.96)
const DIM := Color(0.55, 0.58, 0.66)
const AMBER := Color(1.0, 0.72, 0.12)
const GOOD := Color(0.35, 0.9, 0.45)
const BAD := Color(1.0, 0.3, 0.25)
const INK := Color(0.05, 0.05, 0.07)  # text on a filled accent

static var _font: FontVariation
static var _stripes: ImageTexture

# Heavy, letter-spaced capitals for titles and numerals.
static func bold() -> FontVariation:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = ThemeDB.fallback_font
		_font.variation_embolden = 0.9
		_font.spacing_glyph = 2
	return _font

# A flat slab: `edge` px of accent down the left, `top` px of accent across the top.
static func slab(bg: Color, accent := Color.TRANSPARENT, edge := 0, pad := 12, top := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_content_margin_all(pad)
	s.content_margin_left = pad + edge
	s.content_margin_top = pad + top
	s.border_color = accent
	s.border_width_left = edge
	s.border_width_top = top
	return s

# Default look of every Label and Button below the node this is set on.
static func theme(accent: Color) -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "Button", slab(Color(0.14, 0.15, 0.2), accent, 3, 9))
	t.set_stylebox("hover", "Button", slab(Color(0.2, 0.22, 0.29), accent, 9, 9))  # the accent edge slides in
	t.set_stylebox("pressed", "Button", slab(accent, accent, 3, 9))
	t.set_stylebox("disabled", "Button", slab(Color(0.09, 0.095, 0.115), Color(1, 1, 1, 0.12), 3, 9))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(0.42, 0.44, 0.5))
	t.set_stylebox("fill", "ProgressBar", slab(accent, Color.TRANSPARENT, 0, 0))
	t.set_stylebox("background", "ProgressBar", slab(Color(1, 1, 1, 0.08), Color.TRANSPARENT, 0, 0))
	return t

# A disabled button that means "this one is chosen" (Equipped, the selected difficulty): filled with the accent.
static func mark_chosen(b: Button, accent: Color) -> void:
	b.add_theme_stylebox_override("disabled", slab(accent, accent, 3, 9))
	b.add_theme_color_override("font_disabled_color", INK)

static func label(text: String, size := 16, color := TEXT, heavy := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if heavy:
		l.add_theme_font_override("font", bold())
	return l

static func _hazard() -> ImageTexture:
	if _stripes == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				img.set_pixel(x, y, Color.WHITE if (x + y) % 16 < 8 else Color(1, 1, 1, 0.12))
		_stripes = ImageTexture.create_from_image(img)
	return _stripes

# A strip of diagonal hazard tape in the accent colour.
static func tape(accent: Color, height := 8) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _hazard()
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.custom_minimum_size = Vector2(0, height)
	t.modulate = accent
	return t

# Title on the left, a quiet line on the right, hazard tape underneath.
static func header(title: String, sub: String, accent: Color, size := 34) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(label(title.to_upper(), size, accent, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var s := label(sub.to_upper(), 13, DIM)
	s.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(s)
	box.add_child(tape(accent))
	return box

# A big number over a small caption.
static func tile(caption: String, value: String, accent: Color, value_color := TEXT, min_width := 110) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", slab(CARD, accent, 0, 10, 3))
	p.custom_minimum_size = Vector2(min_width, 0)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	v.add_child(label(value, 30, value_color, true))
	v.add_child(label(caption.to_upper(), 11, DIM))
	return p

# An item as a square tile: its symbol, the count, and its name.
static func item_tile(id: String, qty: int, accent: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", slab(CARD, accent, 0, 6, 2))
	p.custom_minimum_size = Vector2(92, 0)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var icon := ItemIcon.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.item_id = id
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon)
	var n := label("x%d" % qty, 20, TEXT, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var name := label(id.replace("_", " ").to_upper(), 10, DIM)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name)
	return p

# `level` filled blocks out of `max`.
static func pips(level: int, max: int, accent: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	for i in max:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(20, 10)
		r.color = accent if i < level else Color(1, 1, 1, 0.12)
		row.add_child(r)
	return row

# A thin bar filled to `fraction` (0..1).
static func meter(fraction: float, accent: Color, width := 140) -> Control:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(width, 10)
	b.max_value = 1.0
	b.value = clampf(fraction, 0.0, 1.0)
	b.show_percentage = false
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

# The one button that matters on a screen: tall, filled, heavy text.
static func big_button(text: String, accent: Color, height := 64) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_font_override("font", bold())
	b.add_theme_stylebox_override("normal", slab(accent, accent.lightened(0.5), 10, 10))
	b.add_theme_stylebox_override("hover", slab(accent.lightened(0.25), Color.WHITE, 16, 10))
	b.add_theme_stylebox_override("pressed", slab(accent.darkened(0.2), Color.WHITE, 10, 10))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, INK)
	return b
