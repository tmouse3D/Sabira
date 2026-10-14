# Godot 4.x - Sabira / HOUSE
extends CanvasLayer
## Lower-room letter lock: 6 brass dials, A-Z each (built in code, spawned by
## interact/LowerBoxLock.gd). House style of ui/KeypadUI.gd (dark panel, worn border, soft
## click) with Metal Mania letters. Up/Down (mouse wheel, the ^ / v buttons) turn the
## selected dial, Left/Right (Tab, click) pick a dial, typing a letter sets it and moves on.
## Opens by itself the moment the dials read the code (GameState.LOWER_BOX_CODE): green, emits
## solved, closes. Esc closes. Locks the player and frees the mouse while open.

signal solved
signal closed

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const DIALS := 6
const FONT_PATH := "res://fonts/MetalMania-Regular.ttf"
const COL_NORMAL := Color(0.92, 0.88, 0.80, 1.0)
const COL_SEL := Color(1.0, 0.82, 0.45, 1.0)
const COL_OK := Color(0.45, 0.95, 0.45, 1.0)
const COL_BORDER := Color(0.35, 0.30, 0.24, 1.0)

var _code: String = ""
var _idx: PackedInt32Array = []
var _sel: int = 0
var _open: bool = false
var _done: bool = false
var _labels: Array[Label] = []
var _dial_styles: Array[StyleBoxFlat] = []
var _panel_style: StyleBoxFlat
var _click: AudioStreamPlayer
var _font: Font


func _ready() -> void:
	layer = 40
	visible = false
	_font = load(FONT_PATH) as Font
	_build()
	_click = AudioStreamPlayer.new()
	_click.name = "ClickPlayer"
	_click.stream = load("res://audio/sfx/ui_soft_click.wav") as AudioStream
	_click.volume_db = -14.0
	_click.bus = &"Master"
	add_child(_click)


func is_open() -> bool:
	return _open


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.08, 0.07, 0.06, 0.96)
	_panel_style.border_color = COL_BORDER
	_panel_style.set_border_width_all(2)
	_panel_style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", _panel_style)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var title := Label.new()
	title.text = String(GameState.STORY_LINES["lower_box_title"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.75, 0.70, 0.62, 1.0))
	vb.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	for i in DIALS:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		row.add_child(col)
		var up := _arrow_button("^", i, 1)
		col.add_child(up)
		var box := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.20, 0.15, 0.08, 1.0)
		st.border_color = COL_BORDER
		st.set_border_width_all(2)
		st.set_content_margin_all(4.0)
		box.add_theme_stylebox_override("panel", st)
		_dial_styles.append(st)
		box.gui_input.connect(_on_dial_input.bind(i))
		col.add_child(box)
		var lab := Label.new()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.custom_minimum_size = Vector2(54.0, 64.0)
		if _font != null:
			lab.add_theme_font_override("font", _font)
		lab.add_theme_font_size_override("font_size", 44)
		box.add_child(lab)
		_labels.append(lab)
		var down := _arrow_button("v", i, -1)
		col.add_child(down)
	var hint := Label.new()
	hint.text = "[Up/Down] turn    [Left/Right] dial    type letters    [Esc] close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.65, 0.62, 0.56, 1.0))
	vb.add_child(hint)


func _arrow_button(txt: String, dial: int, step: int) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(54.0, 30.0)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func() -> void:
		_sel = dial
		_turn(step))
	return b


func open(code: String) -> void:
	if _open:
		return
	_code = code.to_upper()
	_done = false
	_open = true
	visible = true
	_sel = 0
	if _idx.size() != DIALS:
		# Start on a scrambled row that never reads the code.
		_idx.resize(DIALS)
		for i in DIALS:
			var c := randi() % LETTERS.length()
			if i < _code.length() and LETTERS[c] == _code[i]:
				c = (c + 7) % LETTERS.length()
			_idx[i] = c
	_set_border(COL_BORDER)
	_refresh(COL_NORMAL)
	get_tree().call_group("player", "set_input_locked", true)
	get_tree().call_group("interact_prompt", "suppress_for", 999.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().call_group("player", "set_input_locked", false)
	get_tree().call_group("interact_prompt", "suppress_for", 0.05)
	closed.emit()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and not _done:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_turn(1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_turn(-1)
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	get_viewport().set_input_as_handled()
	var kc := key.keycode
	if kc == KEY_ESCAPE:
		if not key.echo:
			close()
		return
	if _done:
		return
	match kc:
		KEY_UP:
			_turn(1)
			return
		KEY_DOWN:
			_turn(-1)
			return
		KEY_LEFT:
			_select(_sel - 1)
			return
		KEY_RIGHT, KEY_TAB:
			_select(_sel + 1)
			return
		KEY_BACKSPACE:
			_select(_sel - 1)
			return
	if key.echo:
		return
	var ch := String.chr(key.unicode).to_upper() if key.unicode > 0 else ""
	var li := LETTERS.find(ch) if ch.length() == 1 else -1
	if li >= 0:
		_idx[_sel] = li
		_play_click(1.0)
		var at := _sel
		_refresh(COL_NORMAL)
		if not _check():
			_select(mini(at + 1, DIALS - 1))


func _on_dial_input(event: InputEvent, dial: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_select(dial)


func _select(i: int) -> void:
	_sel = wrapi(i, 0, DIALS)
	_refresh(COL_NORMAL)


func _turn(step: int) -> void:
	if not _open or _done:
		return
	_idx[_sel] = wrapi(_idx[_sel] + step, 0, LETTERS.length())
	_play_click(1.0 + 0.04 * float(step))
	_refresh(COL_NORMAL)
	_check()


func _reading() -> String:
	var s := ""
	for i in DIALS:
		s += LETTERS[_idx[i]]
	return s


func _check() -> bool:
	if _code.length() != DIALS or _reading() != _code:
		return false
	_done = true
	_refresh(COL_OK)
	_set_border(COL_OK)
	_play_click(1.25)
	solved.emit()
	_close_later()
	return true


func _close_later() -> void:
	await get_tree().create_timer(0.6).timeout
	if _open:
		close()


func _play_click(pitch: float) -> void:
	if _click != null and _click.stream != null:
		_click.pitch_scale = pitch * randf_range(0.97, 1.03)
		_click.play()


func _set_border(col: Color) -> void:
	if _panel_style:
		_panel_style.border_color = col


func _refresh(col: Color) -> void:
	for i in DIALS:
		if i >= _labels.size() or i >= _idx.size():
			continue
		_labels[i].text = LETTERS[_idx[i]]
		var c := col
		if col == COL_NORMAL and i == _sel:
			c = COL_SEL
		_labels[i].add_theme_color_override("font_color", c)
		_dial_styles[i].border_color = COL_SEL if (i == _sel and not _done) else COL_BORDER
