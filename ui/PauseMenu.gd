# Godot 4.x - Sabira / HOUSE
class_name PauseMenu
extends CanvasLayer
## Esc pause menu. Spawned by Player._ready. Opens only when GameState.can_open_pause() (free play:
## no KeypadUI / ClockSetUI / WatchZoomUI / BookPage / photos / stab card / ending card, since all
## of those lock the player's input; those UIs also consume Esc themselves in _input).
## Pauses the tree, frees the mouse. Resume / Settings / Restart / Main Menu / Exit.

const TEXT_COLOR := Color(0.93, 0.91, 0.86)

var _root: Control
var _buttons: Array[ScratchButton] = []
var _settings: SettingsPanel
var _col: VBoxContainer


func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ui/menu/menu_bg.gdshader") as Shader
	mat.set_shader_parameter("base_color", Color(0.02, 0.018, 0.018, 0.86))
	bg.material = mat
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)
	_col = col
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	col.add_child(title)
	for spec in [["Resume", resume], ["Settings", _on_settings], ["Restart", _on_restart], ["Main Menu", _on_menu], ["Exit", _on_exit]]:
		var b := ScratchButton.new()
		b.text = spec[0]
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(spec[1])
		col.add_child(b)
		_buttons.append(b)
	for i in _buttons.size():
		var c := _buttons[i]
		var prev := _buttons[(i - 1 + _buttons.size()) % _buttons.size()]
		var nxt := _buttons[(i + 1) % _buttons.size()]
		c.focus_neighbor_top = c.get_path_to(prev)
		c.focus_neighbor_bottom = c.get_path_to(nxt)
		c.focus_previous = c.get_path_to(prev)
		c.focus_next = c.get_path_to(nxt)
	_settings = (load("res://ui/SettingsPanel.tscn") as PackedScene).instantiate() as SettingsPanel
	_root.add_child(_settings)
	_settings.closed.connect(func() -> void:
		_col.show()
		_buttons[1].grab_focus())
	_root.hide()


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if not GameState.can_open_pause():
		return
	GameState.pause_open = true
	get_tree().paused = true
	MusicManager.set_ducked(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_group("interact_prompt", "suppress_for", 0.2)
	_root.show()
	_buttons[0].grab_focus()


func resume() -> void:
	if not _root.visible:
		return
	_settings.hide()
	_col.show()
	_root.hide()
	GameState.pause_open = false
	MusicManager.set_ducked(false)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var esc: bool = event is InputEventKey and event.pressed and not event.echo \
		and ((event as InputEventKey).keycode == KEY_ESCAPE or (event as InputEventKey).physical_keycode == KEY_ESCAPE)
	if not esc and not event.is_action_pressed("ui_cancel"):
		return
	if _root.visible:
		if _settings.visible:
			return
		get_viewport().set_input_as_handled()
		resume()
	elif esc and GameState.can_open_pause():
		get_viewport().set_input_as_handled()
		open()


func _on_settings() -> void:
	_col.hide()
	_settings.open()


func _on_restart() -> void:
	GameState.restart_game()


func _on_menu() -> void:
	GameState.go_to_main_menu()


func _on_exit() -> void:
	get_tree().quit()
