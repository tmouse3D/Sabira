# Godot 4.x - Sabira / HOUSE
extends Control
## Main menu (run/main_scene). Illustration panel + title + Play / Settings / Exit.
## Swap the art: replace ui/menu/menu_illustration.png, or set `illustration` on the MainMenu
## node in ui/MainMenu.tscn (any Texture2D).

const HOUSE_SCENE := "res://world/House.tscn"
const CARDS_SCENE := "res://ui/ChoiceCards.tscn"
const TEXT_COLOR := Color(0.93, 0.91, 0.86)

@export var illustration: Texture2D
@export var title_text: String = "The White Scarf"

var _buttons: Array[ScratchButton] = []
var _settings: SettingsPanel
var _main_box: Control
var _diff_root: Control
var _diff_buttons: Array[ScratchButton] = []
var _endings_label: Label


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MusicManager.set_ducked(false)
	MusicManager.play_menu()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ui/menu/menu_bg.gdshader") as Shader
	bg.material = mat
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	add_child(margin)
	_main_box = margin
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 64)
	margin.add_child(row)
	# Illustration panel (scratchy frame around a TextureRect).
	var frame := PanelContainer.new()
	var sb := ScratchButton.frame_style(1.0)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	frame.add_theme_stylebox_override("panel", sb)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 1.6
	row.add_child(frame)
	var art := TextureRect.new()
	art.name = "Illustration"
	art.texture = illustration if illustration else load("res://ui/menu/menu_illustration.png") as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.clip_contents = true
	frame.add_child(art)
	# Title + buttons.
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 22)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	col.add_child(title)
	_add_title_glitch(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	col.add_child(gap)
	for spec in [["Play", _on_play], ["Settings", _on_settings], ["Exit", _on_exit]]:
		var b := ScratchButton.new()
		b.text = spec[0]
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(spec[1])
		col.add_child(b)
		_buttons.append(b)
	_link_focus(_buttons)
	# "Endings found: N / 19" under the buttons (global theme font, small, muted).
	_endings_label = Label.new()
	_endings_label.name = "EndingsFound"
	_endings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_endings_label.add_theme_font_size_override("font_size", 18)
	_endings_label.add_theme_color_override("font_color", Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, 0.45))
	_endings_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_endings_label)
	_refresh_endings_label()
	_main_box.visibility_changed.connect(_refresh_endings_label)
	_settings = (load("res://ui/SettingsPanel.tscn") as PackedScene).instantiate() as SettingsPanel
	add_child(_settings)
	_settings.closed.connect(func() -> void:
		_main_box.show()
		_buttons[1].grab_focus())
	_build_difficulty()
	_buttons[0].grab_focus.call_deferred()


## Unlocked endings from user://endings.cfg (GameState.unlocked_endings; 0 if missing).
func _refresh_endings_label() -> void:
	if _endings_label == null:
		return
	var found := 0
	var total := 19
	if GameState != null:
		found = GameState.unlocked_endings().size()
		total = GameState.ENDINGS_TOTAL
	_endings_label.text = "Endings found: %d / %d" % [mini(found, total), total]


## Difficulty selector shown after Play. Saved in Settings (settings.cfg) and GameState.
func _build_difficulty() -> void:
	_diff_root = CenterContainer.new()
	_diff_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_diff_root.hide()
	add_child(_diff_root)
	var panel := PanelContainer.new()
	var sb := ScratchButton.frame_style(1.0)
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 36)
	panel.add_theme_stylebox_override("panel", sb)
	_diff_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := Label.new()
	title.text = "DIFFICULTY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	box.add_child(title)
	for spec in [["Realistic", "realistic", "He's sober, sharp-eyed and he never stops pacing."], ["Easy", "easy", "He's been drinking all day. Slower, half-blind, mostly in his office."]]:
		var b := ScratchButton.new()
		b.text = spec[0]
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var mode: String = spec[1]
		b.pressed.connect(func() -> void: _start_game(mode))
		box.add_child(b)
		_diff_buttons.append(b)
		var d := Label.new()
		d.text = spec[2]
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.add_theme_font_size_override("font_size", 19)
		d.add_theme_color_override("font_color", Color(0.7, 0.68, 0.63))
		box.add_child(d)
	var back := ScratchButton.new()
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		_diff_root.hide()
		_main_box.show()
		_buttons[0].grab_focus())
	box.add_child(back)
	_diff_buttons.append(back)
	_link_focus(_diff_buttons)


func _start_game(mode: String) -> void:
	Settings.set_difficulty(mode)
	GameState.reset_for_new_game()
	GameState.difficulty = Settings.difficulty
	print("[MENU] new game, difficulty=", GameState.difficulty)
	MusicManager.start_game()
	get_tree().change_scene_to_file(CARDS_SCENE if ResourceLoader.exists(CARDS_SCENE) else HOUSE_SCENE)


static func _link_focus(list: Array) -> void:
	for i in list.size():
		var c: Control = list[i]
		var prev: Control = list[(i - 1 + list.size()) % list.size()]
		var nxt: Control = list[(i + 1) % list.size()]
		c.focus_neighbor_top = c.get_path_to(prev)
		c.focus_neighbor_bottom = c.get_path_to(nxt)
		c.focus_previous = c.get_path_to(prev)
		c.focus_next = c.get_path_to(nxt)


func _on_play() -> void:
	_main_box.hide()
	_diff_root.show()
	_diff_buttons[1 if Settings.difficulty == "easy" else 0].grab_focus()


func _on_settings() -> void:
	_main_box.hide()
	_settings.open()


func _on_exit() -> void:
	get_tree().quit()


# --- Title glitch (always on, independent of the VHS setting) ---------------------------
const TITLE_GLITCH_SHADER := "res://ui/menu/title_glitch.gdshader"
var _glitch_mat: ShaderMaterial = null
var _glitch_next: float = 2.0
var _glitch_left: float = 0.0
var _drop_left: float = 0.0


func _add_title_glitch(title: Label) -> void:
	var sh := load(TITLE_GLITCH_SHADER) as Shader
	if sh == null:
		return
	var over := ColorRect.new()
	over.name = "TitleGlitch"
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.set_anchors_preset(Control.PRESET_FULL_RECT)
	over.offset_left = -12.0
	over.offset_right = 12.0
	_glitch_mat = ShaderMaterial.new()
	_glitch_mat.shader = sh
	over.material = _glitch_mat
	title.add_child(over)
	_glitch_next = randf_range(1.5, 5.0)


func _process(delta: float) -> void:
	if _glitch_mat == null:
		return
	if _glitch_left > 0.0:
		_glitch_left -= delta
		if _drop_left > 0.0:
			_drop_left -= delta
		elif randf() < delta * 3.0:
			_drop_left = randf_range(0.05, 0.1)
		_glitch_mat.set_shader_parameter("burst", 1.0 if _glitch_left > 0.0 else 0.0)
		_glitch_mat.set_shader_parameter("dropout", 1.0 if _drop_left > 0.0 else 0.0)
		_glitch_mat.set_shader_parameter("flash", randf_range(0.0, 0.8) if randf() < 0.3 else 0.0)
		if _glitch_left <= 0.0:
			_drop_left = 0.0
			_glitch_mat.set_shader_parameter("dropout", 0.0)
			_glitch_mat.set_shader_parameter("flash", 0.0)
			_glitch_next = randf_range(1.5, 5.0)
		return
	_glitch_next -= delta
	if _glitch_next <= 0.0:
		_glitch_left = randf_range(0.1, 0.4)
