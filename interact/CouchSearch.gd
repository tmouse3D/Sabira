# Godot 4.x - Sabira / HOUSE
class_name CouchSearch
extends Interactable
## Living couch Search - bedroom key XOR site (tash_room_key). Empty: Nothing. / Just cushions.
## Front-only: thin slab on seat face (local -Z) + facing gate (closet-style occlusion).

@export var search_prompt: String = "[E] Search the couch."
@export var line_duration: float = 2.5
@export var search_stream: AudioStream
@export var search_volume_db: float = -18.0
## Min dot(to_player, front) to arm Search. Front = local -Z (toward room / TV).
@export var front_dot_min: float = 0.25

const EMPTY_LINES: PackedStringArray = [
	"Nothing.",
	"Just cushions.",
]
const KEY_FIND_LINES: PackedStringArray = [
	"Something cold.",
	"A key.",
]

var _looted: bool = false
var _site_armed: bool = false
var _search_sfx: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	prompt_text = search_prompt
	add_to_group("bedroom_key_sites")
	_ensure_front_only_collision()
	_ensure_sfx()
	if GameState != null and GameState.has_inventory_flag("tash_room_key"):
		_looted = true


## Shrink interact hit to a thin slab on the seat/front face so back/side rays miss
## (mirrors CupboardOpen CloseHitFrame thin slab on room-facing face).
func _ensure_front_only_collision() -> void:
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs == null:
		return
	var src := cs.shape as BoxShape3D
	var sx := 1.9
	var sy := 0.7
	var sz := 0.9
	if src:
		sx = src.size.x
		sy = src.size.y
		sz = src.size.z
	var box := BoxShape3D.new()
	box.size = Vector3(sx * 0.95, sy * 0.85, 0.12)
	cs.shape = box
	# Original box centered; front face at local -Z (toward TV / room).
	cs.position = Vector3(cs.position.x, cs.position.y, -sz * 0.45)


func arm_bedroom_key_site(armed: bool) -> void:
	_site_armed = armed


func _ensure_sfx() -> void:
	_search_sfx = get_node_or_null("SearchPlayer") as AudioStreamPlayer3D
	if _search_sfx == null:
		_search_sfx = AudioStreamPlayer3D.new()
		_search_sfx.name = "SearchPlayer"
		_search_sfx.max_distance = 10.0
		add_child(_search_sfx)
	if search_stream == null:
		search_stream = load("res://audio/sfx/ui_soft_click.wav") as AudioStream
	_search_sfx.stream = search_stream
	_search_sfx.volume_db = search_volume_db
	_search_sfx.bus = &"Master"


func _play_sfx() -> void:
	if _search_sfx == null:
		_ensure_sfx()
	if _search_sfx and _search_sfx.stream:
		_search_sfx.pitch_scale = randf_range(0.96, 1.04)
		_search_sfx.volume_db = search_volume_db + randf_range(-1.0, 0.5)
		_search_sfx.play()


func _is_player_in_front(player: Node) -> bool:
	if player == null or not (player is Node3D):
		return true
	var p := player as Node3D
	var to_player := p.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() < 0.0001:
		return true
	# Seat faces local -Z (Living_Couch mesh is yaw-180; body is identity).
	var front := -global_transform.basis.z
	front.y = 0.0
	if front.length_squared() < 0.0001:
		return true
	front = front.normalized()
	return to_player.normalized().dot(front) >= front_dot_min


func can_interact(player: Node) -> bool:
	if not interact_enabled:
		return false
	return _is_player_in_front(player)


func _on_interact(_player: Node) -> void:
	_play_sfx()
	if GameState == null:
		get_tree().call_group("subtitle", "show_line", "SABIRA", EMPTY_LINES[randi() % EMPTY_LINES.size()], line_duration)
		return
	if _looted and not GameState.has_inventory_flag("tash_room_key"):
		_looted = false
	if _site_armed and not _looted:
		if not GameState.add_inventory_flag("tash_room_key"):
			return
		_looted = true
		get_tree().call_group("subtitle", "show_line", "SABIRA", KEY_FIND_LINES[randi() % KEY_FIND_LINES.size()], line_duration)
		return
	get_tree().call_group("subtitle", "show_line", "SABIRA", EMPTY_LINES[randi() % EMPTY_LINES.size()], line_duration)