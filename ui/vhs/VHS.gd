# Godot 4.x - Sabira / The White Scarf
extends CanvasLayer
## VHS post filter (autoload "VHS"). A full-screen ColorRect with ui/vhs/vhs.gdshader on canvas
## layer 5: above the 3D view and the root canvas (main menu), below the HUD and every UI that
## must stay crisp (PromptLayer 10, SlotHud 12, Subtitle 20, Book/Photo 30, Keypad/Clock 40,
## Pause 85, Intro/Ending 90). The main menu gets it at MENU_MUL strength.
## Settings.vhs_enabled / Settings.vhs_intensity drive it (apply_settings()).

const MENU_MUL := 0.4
const MENU_SCENE := "res://ui/MainMenu.tscn"

var _rect: ColorRect
var _mat: ShaderMaterial
var _last_scene: Node = null


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.name = "VHSRect"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://ui/vhs/vhs.gdshader") as Shader
	_rect.material = _mat
	add_child(_rect)
	apply_settings()


func _process(_delta: float) -> void:
	var cs := get_tree().current_scene
	if cs != _last_scene:
		_last_scene = cs
		apply_settings()


func apply_settings() -> void:
	if _mat == null:
		return
	var on := true
	var k := 0.5
	var st := get_node_or_null("/root/Settings")
	if st != null:
		on = bool(st.get("vhs_enabled"))
		k = float(st.get("vhs_intensity"))
	var cs := get_tree().current_scene if get_tree() else null
	if cs != null and cs.scene_file_path == MENU_SCENE:
		k *= MENU_MUL
	_rect.visible = on and k > 0.001
	_mat.set_shader_parameter("intensity", k)
