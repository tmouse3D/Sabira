# Godot 4.x - Sabira / HOUSE
class_name ClockFace
extends Control
## Analog 12-hour clock face drawn in code. Used by ui/WatchZoomUI.gd (pocket watch close-up)
## and ui/ClockSetUI.gd (grandfather clock). Hands are drawn from hour + minute, so any time works.
## style "watch": gray metal case texture (props/pocketwatch/pocketwatch_gray.png) + pale dial.
## style "grandfather": dark wood rim + yellowed, stained dial.

const HOUR_LEN := 0.46
const MINUTE_LEN := 0.70

@export var hour: int = 12
@export var minute: int = 0
@export var style: String = "watch"

var case_texture: Texture2D = null
## "hour" / "minute" / "" - drawn in a warmer colour while dragged.
var highlight_hand: String = ""
var solved_tint: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_time(h: int, m: int) -> void:
	hour = h
	minute = m
	queue_redraw()


func face_center() -> Vector2:
	return size * 0.5 + Vector2(0.0, _radius() * 0.08 if style == "watch" else 0.0)


func face_radius() -> float:
	return _radius()


func _radius() -> float:
	var r := minf(size.x, size.y) * 0.5
	if style == "watch":
		r *= 0.84
	return r * 0.96


## Clockwise angle from 12 o'clock, radians.
static func minute_angle(m: int) -> float:
	return float(m) / 60.0 * TAU


static func hour_angle(h: int, m: int) -> float:
	return (float(h % 12) + float(m) / 60.0) / 12.0 * TAU


static func dir_for(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle))


func _draw() -> void:
	var c := face_center()
	var r := _radius()
	var dial_r := r * 0.80
	if style == "watch":
		_draw_watch_case(c, r)
		draw_circle(c, dial_r, Color(0.80, 0.78, 0.72, 0.93))
	else:
		draw_circle(c, r, Color(0.16, 0.11, 0.07, 1.0))
		draw_circle(c, r * 0.93, Color(0.36, 0.28, 0.16, 1.0))
		draw_circle(c, r * 0.86, Color(0.08, 0.07, 0.06, 1.0))
		dial_r = r * 0.82
		draw_circle(c, dial_r, Color(0.80, 0.73, 0.55, 1.0))
	_draw_stains(c, dial_r)
	_draw_ticks(c, dial_r)
	_draw_numerals(c, dial_r)
	_draw_hands(c, dial_r)


func _draw_watch_case(c: Vector2, r: float) -> void:
	var metal := Color(0.55, 0.55, 0.57, 1.0)
	var dark := Color(0.25, 0.25, 0.27, 1.0)
	# bow ring + crown
	draw_arc(c + Vector2(0.0, -r * 1.17), r * 0.13, 0.0, TAU, 28, dark, r * 0.07)
	draw_arc(c + Vector2(0.0, -r * 1.17), r * 0.13, 0.0, TAU, 28, metal, r * 0.04)
	draw_rect(Rect2(c + Vector2(-r * 0.10, -r * 1.08), Vector2(r * 0.20, r * 0.12)), metal)
	draw_rect(Rect2(c + Vector2(-r * 0.10, -r * 1.08), Vector2(r * 0.20, r * 0.12)), dark, false, 2.0)
	if case_texture != null:
		draw_texture_rect(case_texture, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
	else:
		draw_circle(c, r, metal)
		draw_arc(c, r, 0.0, TAU, 64, dark, r * 0.04)


func _draw_stains(c: Vector2, dial_r: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331 if style == "watch" else 1977
	for i in range(9):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.15, 0.85) * dial_r
		var sr := rng.randf_range(0.04, 0.14) * dial_r
		var col := Color(0.35, 0.26, 0.14, rng.randf_range(0.06, 0.16))
		draw_circle(c + dir_for(a) * d, sr, col)
	if style == "watch":
		# hairline crack across the glass
		var p0 := c + dir_for(2.2) * dial_r * 0.95
		var p1 := c + dir_for(2.6) * dial_r * 0.35
		var p2 := c + dir_for(3.3) * dial_r * 0.15
		draw_polyline(PackedVector2Array([p0, p1, p2]), Color(1.0, 1.0, 1.0, 0.35), 1.5)


func _draw_ticks(c: Vector2, dial_r: float) -> void:
	var ink := Color(0.10, 0.09, 0.08, 1.0)
	for i in range(60):
		var d := dir_for(float(i) / 60.0 * TAU)
		var big := i % 5 == 0
		var inner := dial_r * (0.86 if big else 0.92)
		draw_line(c + d * inner, c + d * dial_r * 0.97, ink, maxf(1.0, dial_r * (0.025 if big else 0.010)))


func _draw_numerals(c: Vector2, dial_r: float) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var fs := int(dial_r * 0.19)
	var ink := Color(0.10, 0.09, 0.08, 1.0)
	for n in range(1, 13):
		var t := str(n)
		var p := c + dir_for(float(n) / 12.0 * TAU) * dial_r * 0.70
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, p + Vector2(-w.x * 0.5, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


func _hand_color(which: String) -> Color:
	if solved_tint:
		return Color(0.20, 0.45, 0.18, 1.0)
	if highlight_hand == which:
		return Color(0.55, 0.16, 0.10, 1.0)
	return Color(0.07, 0.06, 0.05, 1.0)


func _draw_hand(c: Vector2, angle: float, length: float, width: float, col: Color) -> void:
	var d := dir_for(angle)
	var n := Vector2(-d.y, d.x)
	var tail := c - d * length * 0.16
	var pts := PackedVector2Array([
		tail + n * width * 0.5,
		c + d * length * 0.72 + n * width,
		c + d * length,
		c + d * length * 0.72 - n * width,
		tail - n * width * 0.5,
	])
	draw_colored_polygon(pts, col)


func _draw_hands(c: Vector2, dial_r: float) -> void:
	_draw_hand(c, hour_angle(hour, minute), dial_r * HOUR_LEN, dial_r * 0.075, _hand_color("hour"))
	_draw_hand(c, minute_angle(minute), dial_r * MINUTE_LEN, dial_r * 0.050, _hand_color("minute"))
	draw_circle(c, dial_r * 0.06, Color(0.30, 0.26, 0.18, 1.0))
	draw_circle(c, dial_r * 0.025, Color(0.07, 0.06, 0.05, 1.0))
