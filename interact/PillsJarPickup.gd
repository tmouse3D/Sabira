# Godot 4.x - Sabira / HOUSE
class_name PillsJarPickup
extends Interactable
## Sleeping pills jar (fridge OR F2 bath). KeySpawner arms exactly one pills site.
## Armed + present: [E] Take sleeping pills -> Took the pills.
## Carrying at same spawn site: [E] Put the pills back. -> remove flag, show mesh, soft click.
## Empty rotate: Empty. / Already took those. / Nothing left.
## Unarmed: mesh hidden, no interact.

@export var mesh_path: NodePath
@export var take_prompt: String = "[E] Take sleeping pills"
@export var return_prompt: String = "[E] Put the pills back."
@export var find_line: String = "Took the pills."
@export var line_duration: float = 2.5
@export var is_pills_site: bool = true
@export var take_stream: AudioStream
@export var take_volume_db: float = -18.0

const EMPTY_LINES: PackedStringArray = [
	"Empty.",
	"Already took those.",
	"Nothing left.",
]

var _mesh: Node3D
var _looted: bool = false
var _site_armed: bool = false
var _take_sfx: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	_mesh = get_node_or_null(mesh_path) as Node3D
	_ensure_take_player()
	if is_pills_site:
		add_to_group("pills_sites")
	if GameState != null and GameState.has_pills:
		_looted = true
	# Until KeySpawner arms: hide + disable (only one random site goes live).
	_apply_armed_visual()
	_refresh_prompt()


func arm_pills_site(armed: bool) -> void:
	_site_armed = armed
	if GameState != null and GameState.has_pills:
		_looted = true
	_apply_armed_visual()
	_refresh_prompt()


func _apply_armed_visual() -> void:
	if _mesh == null and mesh_path != NodePath(""):
		_mesh = get_node_or_null(mesh_path) as Node3D
	var show := _site_armed and not _looted
	if _mesh:
		_mesh.visible = show
	interact_enabled = _site_armed
	# Unarmed / parked site must not steal the interact ray.
	collision_layer = 5 if _site_armed else 0


func can_interact(_player: Node) -> bool:
	return interact_enabled and _site_armed and GameState != null


func get_prompt() -> String:
	if not can_interact(null):
		return ""
	# Put-back only at the same spawn site that was taken from.
	if GameState != null and GameState.has_pills and _looted:
		return return_prompt
	if _looted or (GameState != null and GameState.has_pills):
		return "[E] Check jar"
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
	if GameState == null or not _site_armed:
		return
	# Same-site put-back while carrying.
	if GameState.has_pills and _looted:
		_return_pills()
		return
	_play_take_sfx()
	var dur := line_duration
	if _looted or GameState.has_pills:
		get_tree().call_group("subtitle", "show_line", "SABIRA", EMPTY_LINES[randi() % EMPTY_LINES.size()], dur)
		return
	if not GameState.add_inventory_flag("pills"):
		return
	_looted = true
	if _mesh == null and mesh_path != NodePath(""):
		_mesh = get_node_or_null(mesh_path) as Node3D
	if _mesh:
		_mesh.visible = false
	get_tree().call_group("subtitle", "show_line", "SABIRA", find_line, dur)
	_refresh_prompt()


func _return_pills() -> void:
	if not GameState.has_pills:
		return
	if not GameState.remove_inventory_flag("pills"):
		return
	_looted = false
	_play_take_sfx()
	if _mesh == null and mesh_path != NodePath(""):
		_mesh = get_node_or_null(mesh_path) as Node3D
	if _mesh:
		_mesh.visible = true
	_refresh_prompt()


func _refresh_prompt() -> void:
	prompt_text = get_prompt()
