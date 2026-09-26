# Godot 4.x - Sabira / HOUSE
class_name CoatCheck
extends Interactable
## Searchable coat / clothes pile.
## Office TashOffice_CoatBody = cage_key always (not XOR).
## Laundry piles = tash_room_key XOR. Tash closet piles = front_key XOR.
## Sabira never names keys on Search: Something cold. / A key.

@export var inventory_flag: String = ""
@export var find_line: String = ""
@export var empty_line: String = ""
@export var line_duration: float = 2.5
@export var search_prompt: String = "[E] Search coat"
## "coat" | "clothes" | "tash_clothes"
@export var line_set: String = "coat"
## Legacy dead XOR cage site.
@export var is_cage_key_site: bool = false
## Legacy dead office_key XOR (ignored by KeySpawner).
@export var is_office_key_site: bool = false
## Office coat: always holds cage_key (not XOR).
@export var is_cage_key_always: bool = false
## Bedroom key XOR site (tash_room_key).
@export var is_bedroom_key_site: bool = false
## Front key XOR site.
@export var is_front_key_site: bool = false
@export var search_stream: AudioStream
@export var search_volume_db: float = -18.0

const COAT_EMPTY: PackedStringArray = [
	"Nothing in the pockets.",
	"Lint.",
	"Empty pockets.",
]
## Sabira closet / laundry - NEVER mention a key.
const CLOTHES_EMPTY: PackedStringArray = [
	"Just old clothes.",
	"Nothing useful.",
	"Fabric. Dust.",
]
const TASH_CLOTHES_EMPTY: PackedStringArray = [
	"Nothing.",
	"Lint.",
	"Fabric. Dust.",
]
## Generic find lines - never name the key type.
const KEY_FIND_LINES: PackedStringArray = [
	"Something cold.",
	"A key.",
]

var _looted: bool = false
var _site_armed: bool = true
var _search_sfx: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	prompt_text = search_prompt
	_ensure_search_player()
	if GameState != null and not inventory_flag.is_empty() and _already_has_flag():
		_looted = true
	if is_cage_key_site:
		add_to_group("cage_key_sites")
		_site_armed = false
	if is_cage_key_always:
		add_to_group("cage_key_always")
		_site_armed = true
		if inventory_flag.is_empty():
			inventory_flag = "cage_key"
	if is_bedroom_key_site:
		add_to_group("bedroom_key_sites")
		_site_armed = false
		if inventory_flag.is_empty():
			inventory_flag = "tash_room_key"
	if is_front_key_site:
		add_to_group("front_key_sites")
		_site_armed = false
		if inventory_flag.is_empty():
			inventory_flag = "front_key"
	# Dead office_key export: keep group membership for disarm only.
	if is_office_key_site and not is_bedroom_key_site and not is_front_key_site and not is_cage_key_always:
		add_to_group("office_key_sites")
		_site_armed = false


func arm_cage_key_site(armed: bool) -> void:
	_site_armed = armed


func arm_office_key_site(armed: bool) -> void:
	# Dead path - never give office_key.
	_site_armed = false if not (is_bedroom_key_site or is_front_key_site or is_cage_key_always) else _site_armed
	if is_office_key_site and not is_bedroom_key_site and not is_front_key_site:
		_site_armed = false


func arm_bedroom_key_site(armed: bool) -> void:
	_site_armed = armed


func arm_front_key_site(armed: bool) -> void:
	_site_armed = armed


func _already_has_flag() -> bool:
	return GameState.has_inventory_flag(inventory_flag)


func _ensure_search_player() -> void:
	_search_sfx = get_node_or_null("SearchPlayer") as AudioStreamPlayer3D
	if _search_sfx == null:
		_search_sfx = AudioStreamPlayer3D.new()
		_search_sfx.name = "SearchPlayer"
		_search_sfx.max_distance = 10.0
		add_child(_search_sfx)
	if search_stream == null:
		search_stream = load("res://audio/sfx/ui_soft_click.wav") as AudioStream
	if search_stream == null:
		search_stream = load("res://audio/sfx/clothes_rummage_short.wav") as AudioStream
	_search_sfx.stream = search_stream
	_search_sfx.volume_db = search_volume_db
	_search_sfx.bus = &"Master"


func _play_search_sfx() -> void:
	if _search_sfx == null:
		_ensure_search_player()
	if _search_sfx and _search_sfx.stream:
		_search_sfx.pitch_scale = randf_range(0.96, 1.04)
		_search_sfx.volume_db = search_volume_db + randf_range(-1.0, 0.5)
		_search_sfx.play()


func _empty_caption() -> String:
	if not empty_line.is_empty():
		return empty_line
	if line_set == "coat":
		return COAT_EMPTY[randi() % COAT_EMPTY.size()]
	if line_set == "tash_clothes":
		return TASH_CLOTHES_EMPTY[randi() % TASH_CLOTHES_EMPTY.size()]
	return CLOTHES_EMPTY[randi() % CLOTHES_EMPTY.size()]


func _find_caption() -> String:
	if inventory_flag == "cage_key" or inventory_flag == "tash_room_key" or inventory_flag == "front_key":
		return KEY_FIND_LINES[randi() % KEY_FIND_LINES.size()]
	if not find_line.is_empty():
		return find_line
	return KEY_FIND_LINES[randi() % KEY_FIND_LINES.size()]


func _can_give_loot() -> bool:
	if inventory_flag.is_empty():
		return false
	# After catch strip, allow re-loot if player no longer holds the flag.
	if _looted and not _already_has_flag():
		_looted = false
	if _looted:
		return false
	if is_cage_key_always:
		return true
	if is_bedroom_key_site or is_front_key_site or is_cage_key_site:
		return _site_armed
	# Dead office_key sites never loot.
	if is_office_key_site:
		return false
	return _site_armed


func _on_interact(_player: Node) -> void:
	_play_search_sfx()
	if not _can_give_loot():
		get_tree().call_group("subtitle", "show_line", "SABIRA", _empty_caption(), line_duration)
		return
	if GameState == null:
		return
	if not GameState.add_inventory_flag(inventory_flag):
		return
	_looted = true
	get_tree().call_group("subtitle", "show_line", "SABIRA", _find_caption(), line_duration)