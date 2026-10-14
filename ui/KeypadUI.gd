# Godot 4.x - Sabira / HOUSE
extends CanvasLayer
## Tash-bedroom drawer keypad (built in code, spawned by interact/KeypadDrawer.gd).
## Buttons 1-9 in a 3x3 grid like the drawer face (no 0) + the same number keys / keypad keys.
## Backspace clears, Esc closes. Locks the player (group "player" set_input_locked, like BookPage)
## and frees the mouse while open; recaptures it on close.
## Correct 4 digits: green, emits solved, closes. Wrong: red, then resets.

signal solved
signal closed

const DIGITS: PackedStringArray = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
const CODE_LEN := 4
const COL_NORMAL := Color(0.92, 0.88, 0.80, 1.0)
const COL_OK := Color(0.45, 0.95, 0.45, 1.0)
const COL_BAD := Color(1.0, 0.22, 0.18, 1.0)

@export var click_stream: AudioStream
@export var click_volume_db: float = -14.0

var _code: String = ""
var _entry: String = ""
var _open: bool = false
var _busy: bool = false
var _display: Label
var _panel_style: StyleBoxFlat
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
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.08, 0.07, 0.06, 0.96)
	_panel_style.border_color = Color(0.35, 0.30, 0.24, 1.0)
	_panel_style.set_border_width_all(2)
	_panel_style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", _panel_style)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Drawer lock"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.75, 0.70, 0.62, 1.0))
	vb.add_child(title)

	_display = Label.new()
	_display.name = "Display"
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_display.custom_minimum_size = Vector2(240.0, 48.0)
	_display.add_theme_font_size_override("font_size", 36)
	vb.add_child(_display)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for d in DIGITS:
		var b := Button.new()
		b.text = d
		b.custom_minimum_size = Vector2(60.0, 54.0)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(_on_digit_pressed.bind(d))
		grid.add_child(b)

	var hint := Label.new()
	hint.text = "[Backspace] clear    [Esc] close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.65, 0.62, 0.56, 1.0))
	vb.add_child(hint)
	_refresh_display(COL_NORMAL)


func _ensure_click() -> void:
	_click = get_node_or_null("ClickPlayer") as AudioStreamPlayer
	if _click == null:
		_click = AudioStreamPlayer.new()
		_click.name = "ClickPlayer"
		add_child(_click)
	if click_stream == null:
		click_stream = load("res://audio/sfx/ui_soft_click.wav") as AudioStream
	_click.stream = click_stream
	_click.volume_db = click_volume_db
	_click.bus = &"Master"


func _play_click(pitch: float = 1.0) -> void:
	if _click == null:
		_ensure_click()
	if _click and _click.stream:
		_click.pitch_scale = pitch * randf_range(0.97, 1.03)
		_click.play()


func open(code: String) -> void:
	if _open:
		return
	_code = code
	_entry = ""
	_busy = false
	_open = true
	visible = true
	_refresh_display(COL_NORMAL)
	get_tree().call_group("player", "set_input_locked", true)
	get_tree().call_group("interact_prompt", "suppress_for", 999.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not _open:
		return
	_open = false
	_busy = false
	visible = false
	_entry = ""
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().call_group("player", "set_input_locked", false)
	get_tree().call_group("interact_prompt", "suppress_for", 0.05)
	closed.emit()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var key := event as InputEventKey
	if key == null:
		return
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
		return
	get_viewport().set_input_as_handled()
	if _busy:
		return
	if key.keycode == KEY_BACKSPACE or key.physical_keycode == KEY_BACKSPACE:
		_entry = ""
		_play_click(0.9)
		_refresh_display(COL_NORMAL)
		return
	var d := _digit_for_key(key.keycode)
	if d == "":
		d = _digit_for_key(key.physical_keycode)
	if d != "":
		_press(d)


func _digit_for_key(code: Key) -> String:
	match code:
		KEY_1, KEY_KP_1:
			return "1"
		KEY_2, KEY_KP_2:
			return "2"
		KEY_3, KEY_KP_3:
			return "3"
		KEY_4, KEY_KP_4:
			return "4"
		KEY_5, KEY_KP_5:
			return "5"
		KEY_6, KEY_KP_6:
			return "6"
		KEY_7, KEY_KP_7:
			return "7"
		KEY_8, KEY_KP_8:
			return "8"
		KEY_9, KEY_KP_9:
			return "9"
	return ""


func _on_digit_pressed(d: String) -> void:
	if not _open or _busy:
		return
	_press(d)


func _press(d: String) -> void:
	if _entry.length() >= CODE_LEN:
		return
	_entry += d
	_play_click(1.0)
	_refresh_display(COL_NORMAL)
	if _entry.length() >= CODE_LEN:
		_check_entry()


func _check_entry() -> void:
	_busy = true
	if _code.length() == CODE_LEN and _entry == _code:
		_refresh_display(COL_OK)
		_play_click(1.25)
		solved.emit()
		await get_tree().create_timer(0.5).timeout
		if _open:
			close()
		return
	_refresh_display(COL_BAD)
	_set_border(COL_BAD)
	_play_click(0.6)
	await get_tree().create_timer(0.8).timeout
	_set_border(Color(0.35, 0.30, 0.24, 1.0))
	if not _open:
		return
	_entry = ""
	_busy = false
	_refresh_display(COL_NORMAL)


func _set_border(col: Color) -> void:
	if _panel_style:
		_panel_style.border_color = col


func _refresh_display(col: Color) -> void:
	if _display == null:
		return
	var parts: PackedStringArray = []
	for i in range(CODE_LEN):
		if i < _entry.length():
			parts.append(_entry[i])
		else:
			parts.append("_")
	_display.text = " ".join(parts)
	_display.add_theme_color_override("font_color", col)
