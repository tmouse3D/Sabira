# Godot 4.x - Sabira / HOUSE
class_name KeypadDrawer
extends Interactable
## Tash bedroom drawer with a 4-digit keypad (front_key).
## Code = GameState.front_code (written by world/PaintingPuzzle.gd at scene load).
## [E] Use keypad -> ui/KeypadUI.gd (locks player, frees mouse, Esc closes).
## Correct code: the Drawer child slides out and front_key goes into the carry slots through
## GameState.add_inventory_flag (same path as DrawerCheck / CoatCheck keys).
## Carry full or catch-1 strip: prompt becomes [E] Take key while the front door is still locked.

const KeypadUIScript := preload("res://ui/KeypadUI.gd")

@export var keypad_prompt: String = "[E] Use keypad"
@export var take_prompt: String = "[E] Take key"
@export var look_prompt: String = "[E] Look"
@export var drawer_path: NodePath = NodePath("Drawer")
@export var key_mesh_path: NodePath = NodePath("Drawer/KeyMesh")
@export var slide_distance: float = 0.28
@export var slide_time: float = 0.6
@export var key_line: String = "A key. It has to be the front door."
@export var empty_line: String = "Empty now."
@export var line_duration: float = 2.5
@export var slide_stream: AudioStream
@export var slide_volume_db: float = -16.0

var _solved: bool = false
var _slid_open: bool = false
var _sliding: bool = false
var _ui: Node = null
var _drawer: Node3D = null
var _key_mesh: Node3D = null
var _drawer_closed_pos: Vector3 = Vector3.ZERO
var _front_door: Node = null
var _sfx: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	prompt_text = keypad_prompt
	_drawer = get_node_or_null(drawer_path) as Node3D
	if _drawer != null:
		_drawer_closed_pos = _drawer.position
	_key_mesh = get_node_or_null(key_mesh_path) as Node3D
	if _key_mesh != null:
		_key_mesh.visible = false
	_ensure_sfx()
	if GameState != null and not GameState.inventory_changed.is_connected(_refresh_key_mesh):
		GameState.inventory_changed.connect(_refresh_key_mesh)


func _ensure_sfx() -> void:
	_sfx = get_node_or_null("SlidePlayer") as AudioStreamPlayer3D
	if _sfx == null:
		_sfx = AudioStreamPlayer3D.new()
		_sfx.name = "SlidePlayer"
		_sfx.max_distance = 10.0
		add_child(_sfx)
	if slide_stream == null:
		slide_stream = load("res://audio/sfx/ui_soft_click.wav") as AudioStream
	_sfx.stream = slide_stream
	_sfx.volume_db = slide_volume_db
	_sfx.bus = &"Master"


func _play_sfx(pitch: float) -> void:
	if _sfx == null:
		_ensure_sfx()
	if _sfx and _sfx.stream:
		_sfx.pitch_scale = pitch * randf_range(0.96, 1.04)
		_sfx.play()


func _ui_open() -> bool:
	return _ui != null and is_instance_valid(_ui) and bool(_ui.call("is_open"))


func can_interact(_player: Node) -> bool:
	return interact_enabled and not _sliding and not _ui_open()


func get_prompt() -> String:
	if not can_interact(null):
		return ""
	if not _solved:
		return keypad_prompt
	if _key_available():
		return take_prompt
	return look_prompt


## Key still in the drawer: not carried and the front door not yet unlocked (front_key is
## consumed on unlock, so it must not come back after that).
func _key_available() -> bool:
	if GameState == null:
		return false
	if GameState.has_inventory_flag("front_key"):
		return false
	# Catch 1 re-hid the key in a search site: the drawer stays empty.
	if GameState.key_hidden_elsewhere("front_key"):
		return false
	return _front_door_locked()


func _front_door_locked() -> bool:
	if _front_door == null or not is_instance_valid(_front_door):
		_front_door = _find_front_door()
	if _front_door == null:
		return true
	return bool(_front_door.get("locked"))


func _find_front_door() -> Node:
	var root := get_tree().current_scene
	if root == null:
		return null
	for n in root.find_children("*", "StaticBody3D", true, false):
		if n is Door and (n as Door).required_key == "front_key":
			return n
	return null


func _refresh_key_mesh() -> void:
	if _key_mesh == null:
		return
	_key_mesh.visible = _slid_open and _key_available()


func _on_interact(_player: Node) -> void:
	if GameState == null:
		return
	if not _solved:
		_open_keypad()
		return
	if _key_available():
		_give_key()
		return
	get_tree().call_group("subtitle", "show_line", "SABIRA", empty_line, line_duration)


func _open_keypad() -> void:
	if _ui == null or not is_instance_valid(_ui):
		_ui = KeypadUIScript.new()
		_ui.name = "KeypadUI"
		var host: Node = get_tree().current_scene
		if host == null:
			host = get_tree().root
		host.add_child(_ui)
		_ui.connect("solved", _on_keypad_solved)
		_ui.connect("closed", _on_keypad_closed)
	var code: String = GameState.front_code
	if code.length() != 4:
		push_warning("KeypadDrawer: GameState.front_code not set (PaintingPuzzle missing?)")
	_ui.call("open", code)


func _on_keypad_solved() -> void:
	_solved = true


func _on_keypad_closed() -> void:
	if not _solved or _slid_open:
		return
	await _slide_open()
	_give_key()


func _slide_open() -> void:
	_slid_open = true
	_play_sfx(0.7)
	if _drawer == null:
		_refresh_key_mesh()
		return
	_sliding = true
	_refresh_key_mesh()
	var target := _drawer_closed_pos + Vector3(0.0, 0.0, slide_distance)
	var tw := create_tween()
	tw.tween_property(_drawer, "position", target, slide_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_sliding = false


func _give_key() -> void:
	if GameState == null or GameState.has_inventory_flag("front_key") or GameState.key_hidden_elsewhere("front_key"):
		return
	# Carry full: GameState shows "Can't carry more." and the prompt stays [E] Take key.
	if not GameState.add_inventory_flag("front_key"):
		_refresh_key_mesh()
		return
	_play_sfx(1.1)
	_refresh_key_mesh()
	get_tree().call_group("subtitle", "show_line", "SABIRA", key_line, line_duration)
