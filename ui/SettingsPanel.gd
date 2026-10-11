# Godot 4.x - Sabira / HOUSE
class_name SettingsPanel
extends Control
## Shared settings panel (main menu + pause menu). Master volume, music volume, mouse sensitivity, fullscreen,
## Back. Values live in the Settings autoload (user://settings.cfg). Esc / ui_cancel = Back.

signal closed

const TEXT_COLOR := Color(0.93, 0.91, 0.86)

var _vol: HSlider
var _music: HSlider
var _vhs: CheckButton
var _vhs_k: HSlider
var _sens: HSlider
var _full: CheckButton
var _back: ScratchButton
var _syncing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var sb := ScratchButton.frame_style(1.0)
	sb.content_margin_left = 48
	sb.content_margin_right = 48
	sb.content_margin_top = 36
	sb.content_margin_bottom = 36
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(520, 0)
	panel.add_child(box)
	box.add_child(_label("SETTINGS", 34, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label("Master volume", 22))
	_vol = _slider(0.0, 1.0, 0.01)
	box.add_child(_vol)
	box.add_child(_label("Music volume", 22))
	_music = _slider(0.0, 1.0, 0.01)
	box.add_child(_music)
	box.add_child(_label("Mouse sensitivity", 22))
	_sens = _slider(Settings.SENS_MIN, Settings.SENS_MAX, 0.0001)
	box.add_child(_sens)
	_full = CheckButton.new()
	_full.text = "Fullscreen"
	_full.focus_mode = Control.FOCUS_ALL
	_full.add_theme_font_size_override("font_size", 22)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		_full.add_theme_color_override(c, TEXT_COLOR)
	_full.add_theme_stylebox_override("focus", ScratchButton.frame_style(0.9))
	box.add_child(_full)
	_vhs = CheckButton.new()
	_vhs.text = "VHS effect"
	_vhs.focus_mode = Control.FOCUS_ALL
	_vhs.add_theme_font_size_override("font_size", 22)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		_vhs.add_theme_color_override(c, TEXT_COLOR)
	_vhs.add_theme_stylebox_override("focus", ScratchButton.frame_style(0.9))
	box.add_child(_vhs)
	box.add_child(_label("VHS intensity", 22))
	_vhs_k = _slider(0.0, 1.0, 0.01)
	box.add_child(_vhs_k)
	var row := CenterContainer.new()
	box.add_child(row)
	_back = ScratchButton.new()
	_back.text = "Back"
	row.add_child(_back)
	_vol.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			Settings.set_master_volume(v))
	_music.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			Settings.set_music_volume(v))
	_sens.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			Settings.set_mouse_sensitivity(v))
	_full.toggled.connect(func(on: bool) -> void:
		if not _syncing:
			Settings.set_fullscreen(on))
	_vhs.toggled.connect(func(on: bool) -> void:
		if not _syncing:
			Settings.set_vhs_enabled(on))
	_vhs_k.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			Settings.set_vhs_intensity(v))
	_back.pressed.connect(close)
	# Focus chain: volume -> music -> sensitivity -> fullscreen -> vhs -> vhs intensity -> back.
	var chain: Array[Control] = [_vol, _music, _sens, _full, _vhs, _vhs_k, _back]
	for i in chain.size():
		var c := chain[i]
		var prev := chain[(i - 1 + chain.size()) % chain.size()]
		var nxt := chain[(i + 1) % chain.size()]
		c.focus_neighbor_top = c.get_path_to(prev)
		c.focus_neighbor_bottom = c.get_path_to(nxt)
		c.focus_previous = c.get_path_to(prev)
		c.focus_next = c.get_path_to(nxt)
	hide()


func _label(t: String, size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT_COLOR)
	return l


func _slider(lo: float, hi: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.focus_mode = Control.FOCUS_ALL
	s.custom_minimum_size = Vector2(0, 28)
	var line := StyleBoxFlat.new()
	line.bg_color = Color(TEXT_COLOR, 0.35)
	line.content_margin_top = 2
	line.content_margin_bottom = 2
	s.add_theme_stylebox_override("slider", line)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(TEXT_COLOR, 0.85)
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_stylebox_override("focus", ScratchButton.frame_style(0.9))
	return s


func open() -> void:
	_syncing = true
	_vol.value = Settings.master_volume
	_music.value = Settings.music_volume
	_sens.value = Settings.mouse_sensitivity
	_full.button_pressed = Settings.fullscreen
	_vhs.button_pressed = Settings.vhs_enabled
	_vhs_k.value = Settings.vhs_intensity
	_syncing = false
	show()
	_vol.grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
