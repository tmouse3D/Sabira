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


## Seat-only target: a box over the seat cushions (no back, no arms) reaching ~0.15 m past
## the front edge, used for both the body shape and its InteractHit. Reach is capped at
## COUCH_REACH and the player must stand on the front side (front = local -Z, toward the room).
const COUCH_REACH := 1.3
const SEAT_FRONT_EXTRA_M := 0.15

func _ensure_front_only_collision() -> void:
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs == null:
		return
	var src := cs.shape as BoxShape3D
	var sz3 := src.size if src != null else Vector3(2.0, 0.85, 0.9)
	var sc := global_transform.basis.get_scale()
	var c0 := cs.position
	var arm := 0.17 / maxf(sc.x, 0.01)
	var extra := SEAT_FRONT_EXTRA_M / maxf(sc.z, 0.01)
	var z_front := c0.z - sz3.z * 0.5 - extra
	var z_back := c0.z + sz3.z * 0.1
	var y_lo := c0.y - sz3.y * 0.3
	var y_hi := c0.y + sz3.y * 0.12
	var box := BoxShape3D.new()
	box.size = Vector3(sz3.x - 2.0 * arm, y_hi - y_lo, z_back - z_front)
	var ctr := Vector3(c0.x, (y_lo + y_hi) * 0.5, (z_front + z_back) * 0.5)
	cs.shape = box
	cs.position = ctr
	var hit := get_node_or_null("InteractHit/CollisionShape3D") as CollisionShape3D
	if hit != null:
		hit.shape = box
		hit.transform = Transform3D(Basis(), ctr)
	max_interact_distance = COUCH_REACH
	front_only = true
	front_forward = -global_transform.basis.z
	front_origin = global_transform * Vector3(c0.x, c0.y, c0.z - sz3.z * 0.5)


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
	return front_ok(player)


func _on_interact(_player: Node) -> void:
	_play_sfx()
	if GameState == null:
		get_tree().call_group("subtitle", "show_line", "SABIRA", EMPTY_LINES[randi() % EMPTY_LINES.size()], line_duration)
		return
	if GameState.search_site_for_minute_hand(self, _site_armed):
		return
	# Armed site now hides Dad's pocket watch (clock puzzle), not tash_room_key.
	if _site_armed:
		GameState.find_pocket_watch(self)
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