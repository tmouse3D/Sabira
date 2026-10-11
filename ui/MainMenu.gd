# Godot 4.x - Sabira / HOUSE
extends Control
## Main menu (run/main_scene). Illustration panel + title + Play / Settings / Exit.
## Swap the art: replace ui/menu/menu_illustration.png, or set `illustration` on the MainMenu
## node in ui/MainMenu.tscn (any Texture2D).

const HOUSE_SCENE := "res://world/House.tscn"
const TEXT_COLOR := Color(0.93, 0.91, 0.86)

@export var illustration: Texture2D
@export var title_text: String = "The White Scarf"

var _buttons: Array[ScratchButton] = []
var _settings: SettingsPanel
var _main_box: Control


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
	_settings = (load("res://ui/SettingsPanel.tscn") as PackedScene).instantiate() as SettingsPanel
	add_child(_settings)
	_settings.closed.connect(func() -> void:
		_main_box.show()
		_buttons[1].grab_focus())
	_buttons[0].grab_focus.call_deferred()


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
	GameState.reset_for_new_game()
	MusicManager.start_game()
	get_tree().change_scene_to_file(HOUSE_SCENE)


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
