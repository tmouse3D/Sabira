# Godot 4.x - Sabira / HOUSE
class_name BlanketPickup
extends Interactable
## Independent bed blankets (Tash_Blanket / Sabira_Blanket meshes).
## One HUD blanket flag. While carrying: Take disabled on BOTH beds (other mesh
## stays visible but silent / can_interact false). Put-back only on the empty
## origin bed; restores that bed mesh and clears carry.

@export var mesh_path: NodePath
@export var bed_id: String = ""
@export var take_line: String = "Took the blanket."
@export var return_line: String = "Put the blanket back."
@export var line_duration: float = 2.0
@export var take_prompt: String = "[E] Take blanket"
@export var return_prompt: String = "[E] Put the blanket back."
@export var take_stream: AudioStream
@export var take_volume_db: float = -18.0

var _mesh: Node3D
var _take_sfx: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	add_to_group("blanket_beds")
	_mesh = get_node_or_null(mesh_path) as Node3D
	_ensure_take_player()
	_sync_visual_from_state()
	_refresh_prompt()


func get_bed_id() -> String:
	if not bed_id.is_empty():
		return bed_id
	var n := String(name).to_lower()
	if "sabira" in n:
		return "sabira"
	return "tash"


func _mesh_present() -> bool:
	if _mesh == null and mesh_path != NodePath(""):
		_mesh = get_node_or_null(mesh_path) as Node3D
	return _mesh != null and _mesh.visible


func can_interact(_player: Node) -> bool:
	if not interact_enabled or GameState == null:
		return false
	# Carrying: only the empty origin bed accepts Put back (silent on the other).
	if GameState.has_blanket or ("blanket" in GameState.carried_flags):
		return GameState.blanket_origin == get_bed_id() and not _mesh_present()
	# Not carrying: Take only if this bed still has its world mesh.
	return _mesh_present()


func get_prompt() -> String:
	if not can_interact(null):
		return ""
	if GameState != null and (GameState.has_blanket or ("blanket" in GameState.carried_flags)):
		return return_prompt
	return take_prompt


func _ensure_take_player() -> void:
	_take_sfx = get_node_or_null("TakePlayer") as AudioStreamPlayer3D
	if _take_sfx == null:
		_take_sfx = AudioStreamPlayer3D.new()
		_take_sfx.name = "TakePlayer"
		_take_sfx.max_distance = 10.0
		add_child(_take_sfx)
	if take_stream == null:
		take_stream = load("res://audio/sfx/ui_soft_click.wav") as AudioStream
	_take_sfx.stream = take_stream
	_take_sfx.volume_db = take_volume_db
	_take_sfx.bus = &"Master"


func _play_take_sfx() -> void:
	if _take_sfx == null:
		_ensure_take_player()
	if _take_sfx and _take_sfx.stream:
		_take_sfx.pitch_scale = randf_range(0.96, 1.04)
		_take_sfx.volume_db = take_volume_db + randf_range(-1.0, 0.5)
		_take_sfx.play()


func _on_interact(_player: Node) -> void:
	if GameState == null:
		return
	if not can_interact(_player):
		return
	if GameState.has_blanket or ("blanket" in GameState.carried_flags):
		_return_blanket()
	else:
		_take_blanket()


func _take_blanket() -> void:
	if GameState.has_blanket or ("blanket" in GameState.carried_flags):
		return
	if not _mesh_present():
		return
	if not GameState.add_inventory_flag("blanket"):
		return
	GameState.blanket_origin = get_bed_id()
	_play_take_sfx()
	get_tree().call_group("subtitle", "show_line", "SABIRA", take_line, line_duration)
	_consume_visual()
	_refresh_all_prompts()


func _return_blanket() -> void:
	if not (GameState.has_blanket or ("blanket" in GameState.carried_flags)):
		return
	# Prefer restoring the bed the player is interacting with (origin empty slot).
	var restore_id := get_bed_id()
	if not GameState.remove_inventory_flag("blanket"):
		return
	GameState.blanket_origin = ""
	_play_take_sfx()
	for n in get_tree().get_nodes_in_group("blanket_beds"):
		if n.has_method("get_bed_id") and n.call("get_bed_id") == restore_id:
			if n.has_method("_restore_visual"):
				n.call("_restore_visual")
		if n.has_method("_refresh_prompt"):
			n.call("_refresh_prompt")
	if not return_line.is_empty():
		get_tree().call_group("subtitle", "show_line", "SABIRA", return_line, line_duration)


func _sync_visual_from_state() -> void:
	if GameState != null and GameState.has_blanket and GameState.blanket_origin == get_bed_id():
		_consume_visual()
	else:
		# Keep mesh if this bed was never taken (other bed still has blanket).
		if _mesh == null and mesh_path != NodePath(""):
			_mesh = get_node_or_null(mesh_path) as Node3D
		# Only force-show when not the taken origin.
		if GameState == null or not GameState.has_blanket or GameState.blanket_origin != get_bed_id():
			_restore_visual()


func _consume_visual() -> void:
	if _mesh == null and mesh_path != NodePath(""):
		_mesh = get_node_or_null(mesh_path) as Node3D
	if _mesh:
		_mesh.visible = false


func _restore_visual() -> void:
	if _mesh == null and mesh_path != NodePath(""):
		_mesh = get_node_or_null(mesh_path) as Node3D
	if _mesh:
		_mesh.visible = true


func _refresh_prompt() -> void:
	prompt_text = get_prompt()


func _refresh_all_prompts() -> void:
	for n in get_tree().get_nodes_in_group("blanket_beds"):
		if n.has_method("_refresh_prompt"):
			n.call("_refresh_prompt")
