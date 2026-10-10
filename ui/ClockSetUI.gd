# Godot 4.x - Sabira / HOUSE
extends CanvasLayer
## Grandfather clock "Set the clock" zoom (spawned by interact/GrandfatherClock.gd).
## Drag a hand with the left mouse button (the hand nearest the cursor angle is picked),
## or use keys: A/D or Left/Right = minutes -/+5, W/S or Up/Down = hours +/-1.
## Minutes snap to 5. Esc closes. Locks the player and frees the mouse like ui/KeypadUI.gd,
## recaptures it on close. When hour + minute match the target (12-hour), the hands turn
## green, solved is emitted and the UI closes.

signal time_changed(h: int, m: int)
signal solved
signal closed

const ClockFaceScript := preload("res://ui/ClockFace.gd")
const OPEN_GUARD_MS := 200
const UNLOCK_DELAY := 0.15

@export var click_stream: AudioStream
@export var click_volume_db: float = -12.0

var _open: bool = false
var _busy: bool = false
var _opened_ms: int = 0
var _hour: int = 12
var _minute: int = 0
var _target_hour: int = 12
var _target_minute: int = 0
var _drag: String = ""
var _face: Control
var _click: AudioStreamPlayer


func _ready() -> void:
	layer = 40
	visible = false
	_build()
	_ensure_click()


func is_open() -> bool:
	return _open


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	center.add_child(vb)

	_face = ClockFaceScript.new()
	_face.name = "ClockFace"
	_face.style = "grandfather"
	_face.custom_minimum_size = Vector2(500.0, 500.0)
	vb.add_child(_face)

	var hint := Label.new()
	hint.text = "Drag a hand    [A/D] minutes    [W/S] hours    [Esc] close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.65, 0.62, 0.56, 1.0))
	vb.add_child(hint)


func _ensure_click() -> void:
	_click = AudioStreamPlayer.new()
	_click.name = "ClickPlayer"
	add_child(_click)
	if click_stream == null:
		click_stream = load("res://audio/sfx/ui_soft_click.wav") as AudioStream
	_click.stream = click_stream
	_click.volume_db = click_volume_db
	_click.bus = &"Master"


func _play_click(pitch: float = 1.0) -> void:
	if _click and _click.stream:
		_click.pitch_scale = pitch * randf_range(0.97, 1.03)
		_click.play()


func open(h: int, m: int, target_h: int, target_m: int) -> void:
	if _open:
		return
	_hour = _norm_hour(h)
	_minute = posmod(m, 60)
	_target_hour = _norm_hour(target_h)
	_target_minute = posmod(target_m, 60)
	_busy = false
	_drag = ""
	_open = true
	_opened_ms = Time.get_ticks_msec()
	visible = true
	_face.set("solved_tint", false)
	_face.set("highlight_hand", "")
	_face.call("set_time", _hour, _minute)
	get_tree().call_group("player", "set_input_locked", true)
	get_tree().call_group("interact_prompt", "suppress_for", 999.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not _open:
		return
	_open = false
	_drag = ""
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().call_group("interact_prompt", "suppress_for", UNLOCK_DELAY + 0.05)
	await get_tree().create_timer(UNLOCK_DELAY).timeout
	get_tree().call_group("player", "set_input_locked", false)
	closed.emit()


static func _norm_hour(h: int) -> int:
	var v := posmod(h, 12)
	return 12 if v == 0 else v


func _set_time(h: int, m: int) -> void:
	h = _norm_hour(h)
	m = posmod(m, 60)
	if h == _hour and m == _minute:
		return
	_hour = h
	_minute = m
	_face.call("set_time", _hour, _minute)
	_play_click(1.0 if _drag != "hour" else 0.85)
	time_changed.emit(_hour, _minute)
	_check()


func _check() -> void:
	if _busy:
		return
	if _hour != _target_hour or _minute != _target_minute:
		return
	_busy = true
	_drag = ""
	_face.set("highlight_hand", "")
	_face.set("solved_tint", true)
	_face.queue_redraw()
	solved.emit()
	await get_tree().create_timer(0.6).timeout
	if _open:
		close()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or _busy:
			return
		if mb.pressed:
			_drag = _pick_hand(mb.position)
			_face.set("highlight_hand", _drag)
			_face.queue_redraw()
			if _drag != "":
				_drag_to(mb.position)
		else:
			_drag = ""
			_face.set("highlight_hand", "")
			_face.queue_redraw()
		return
	if event is InputEventMouseMotion:
		if _drag != "" and not _busy:
			get_viewport().set_input_as_handled()
			_drag_to((event as InputEventMouseMotion).position)
		return
	var key := event as InputEventKey
	if key == null:
		return
	get_viewport().set_input_as_handled()
	if not key.pressed:
		return
	var k := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if k == KEY_ESCAPE or key.keycode == KEY_ESCAPE:
		if not key.echo:
			close()
		return
	if _busy or Time.get_ticks_msec() - _opened_ms < OPEN_GUARD_MS:
		return
	match k:
		KEY_A, KEY_LEFT:
			_set_time(_hour, _minute - 5)
		KEY_D, KEY_RIGHT:
			_set_time(_hour, _minute + 5)
		KEY_W, KEY_UP:
			_set_time(_hour + 1, _minute)
		KEY_S, KEY_DOWN:
			_set_time(_hour - 1, _minute)


## Screen position -> face-local angle (clockwise from 12) and distance.
func _polar(screen_pos: Vector2) -> Vector2:
	var local: Vector2 = _face.get_global_transform_with_canvas().affine_inverse() * screen_pos
	var v: Vector2 = local - (_face.call("face_center") as Vector2)
	var ang := atan2(v.x, -v.y)
	if ang < 0.0:
		ang += TAU
	return Vector2(ang, v.length())


func _pick_hand(screen_pos: Vector2) -> String:
	var p := _polar(screen_pos)
	var r: float = _face.call("face_radius")
	if p.y > r:
		return ""
	var dm := absf(angle_difference(p.x, ClockFaceScript.minute_angle(_minute)))
	var dh := absf(angle_difference(p.x, ClockFaceScript.hour_angle(_hour, _minute)))
	if absf(dm - dh) < deg_to_rad(12.0):
		# Hands overlap: inner half grabs the hour hand, outer the minute hand.
		return "hour" if p.y < r * 0.42 else "minute"
	return "minute" if dm < dh else "hour"


func _drag_to(screen_pos: Vector2) -> void:
	var ang := _polar(screen_pos).x
	var steps := ang / TAU * 12.0
	if _drag == "minute":
		_set_time(_hour, int(roundf(steps)) * 5)
	elif _drag == "hour":
		_set_time(int(roundf(steps - float(_minute) / 60.0)), _minute)
