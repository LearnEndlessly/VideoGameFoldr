extends Control
# The kill combo counter: a red skull with the number of kills beside it, a bar that drains with the time left, and
# what the combo would pay if it ended now. Every kill calls bump(): the skull shakes, swells and settles back, and
# the effect restarts with the next kill. A fading "+score" shows when a combo is paid out. main.gd sets `count`,
# `fraction` and `pending` every frame; the skull is drawn with shapes, so it needs no art.

const UIKit = preload("res://scripts/ui_kit.gd")
const PULSE_SECONDS := 0.4
const PEAK_SCALE := 0.7  # how much bigger the skull gets at the top of a bump
const SHAKE := 7.0  # pixels
const SKULL_COLOR := Color(0.92, 0.1, 0.1)

var count := 0
var fraction := 0.0  # combo time left, 0..1
var pending := ""  # "+450  x1.50": what the combo pays now
var paid := ""  # shown for a moment after a combo is paid
var _pulse := 0.0  # 1 at a kill, 0 at rest
var _paid_left := 0.0
var _shake := Vector2.ZERO

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(190, 96)

# A kill: restart the shake-and-swell.
func bump() -> void:
	_pulse = 1.0

func show_paid(text: String) -> void:
	paid = text
	_paid_left = 2.0

func _process(delta: float) -> void:
	_pulse = maxf(_pulse - delta / PULSE_SECONDS, 0.0)
	_paid_left = maxf(_paid_left - delta, 0.0)
	_shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE * _pulse
	visible = count > 0 or _paid_left > 0.0
	queue_redraw()

# How big the counter is right now: 1 at rest, 1 + PEAK_SCALE at a kill, easing back down.
func scale_now() -> float:
	return 1.0 + PEAK_SCALE * _pulse * _pulse

func _draw() -> void:
	var font := UIKit.bold()
	if count > 0:
		var s := scale_now()
		draw_set_transform(Vector2(34, 36) + _shake, 0.0, Vector2(s, s))
		_skull()
		draw_set_transform(Vector2(72, 36) + _shake, 0.0, Vector2(s, s))
		draw_string(font, Vector2(0, 16), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(1, 0.3, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(10, 68, 170, 6), Color(1, 1, 1, 0.15))
		draw_rect(Rect2(10, 68, 170.0 * clampf(fraction, 0.0, 1.0), 6), Color(0.9, 0.15, 0.15))
		draw_string(font, Vector2(10, 90), pending, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIKit.AMBER)
	elif _paid_left > 0.0:
		draw_string(font, Vector2(10, 40), paid, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, clampf(_paid_left, 0.0, 1.0)))

# A skull about 44 px tall around (0, 0): cranium, jaw, eye sockets, nose and teeth.
func _skull() -> void:
	var red := SKULL_COLOR
	var dark := Color(0.12, 0.0, 0.0)
	draw_circle(Vector2(0, -3), 19.0, red)
	draw_rect(Rect2(-11, 8, 22, 15), red)
	draw_circle(Vector2(-8, -2), 6.0, dark)
	draw_circle(Vector2(8, -2), 6.0, dark)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 5), Vector2(-3, 11), Vector2(3, 11)]), dark)
	for x in [-6.0, 0.0, 6.0]:
		draw_line(Vector2(x, 15), Vector2(x, 23), dark, 2.0)
