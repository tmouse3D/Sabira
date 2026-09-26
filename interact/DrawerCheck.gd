# Godot 4.x - Sabira / HOUSE
class_name DrawerCheck
extends Interactable
## Search drawers / desk - empty lines, pills loot, bedroom or front key XOR.

@export var object_label: String = ""
## If true, this site may hold pills (KeySpawner arms exactly one).
@export var is_pills_site: bool = false
## Legacy dead office_key XOR (ignored).
@export var is_office_key_site: bool = false
## Bedroom key XOR (tash_room_key) - F1 drawers.
@export var is_bedroom_key_site: bool = false
## Front key XOR - office desk.
@export var is_front_key_site: bool = false
@export var find_line: String = "Took the pills."
@export var line_duration: float = 2.5
@export var check_stream: AudioStream
@export var check_volume_db: float = -18.0

const EMPTY_LINES: PackedStringArray = [
	"Empty.",
	"Dust and receipts.",
	"Not what I'm looking for.",
]
const KEY_FIND_LINES: PackedStringArray = [
	"Something cold.",
	"A key.",
]

const LINE_DURATION := 2.5

var _looted: bool = false
var _site_armed: bool = false
var _key_armed: bool = false
var _check_sfx: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	_ensure_check_player()
	_apply_prompt()
	if is_pills_site:
		add_to_group("pills_sites")
		if GameState != null and GameState.has_pills:
			_looted = true
	if is_bedroom_key_site:
		add_to_group("bedroom_key_sites")
		if GameState != null and GameState.has_inventory_flag("tash_room_key"):
			_looted = true
	if is_front_key_site:
		add_to_group("front_key_sites")
		if GameState != null and GameState.has_inventory_flag("front_key"):
			_looted = true
	if is_office_key_site and not is_bedroom_key_site and not is_front_key_site:
		add_to_group("office_key_sites")


func arm_pills_site(armed: bool) -> void:
	_site_armed = armed


func arm_office_key_site(_armed: bool) -> void:
	# Dead path.
	_key_armed = false


func arm_bedroom_key_site(armed: bool) -> void:
	_key_armed = armed


func arm_front_key_site(armed: bool) -> void:
	_key_armed = armed


func _apply_prompt() -> void:
	var label := object_label.strip_edges()
	if label.is_empty():
		label = _infer_label()
	prompt_text = "[E] Search %s" % label


func _infer_label() -> String:
	var n := String(name).to_lower()
	if n.contains("desk"):
		return "desk"
	if n.contains("drawer"):
		return "drawers"
	if n.contains("shelf") or n.contains("bookcase"):
		return "shelf"
	var p := get_parent()
	if p:
		var pn := String(p.name).to_lower()
		if pn.contains("desk"):
			return "desk"
		if pn.contains("drawer"):
			return "drawers"
		if pn.contains("shelf") or pn.contains("bookcase"):
			return "shelf"
	return "drawers"


func _empty_caption() -> String:
	return EMPTY_LINES[randi() % EMPTY_LINES.size()]


func _key_find_caption() -> String:
	return KEY_FIND_LINES[randi() % KEY_FIND_LINES.size()]


func _ensure_check_player() -> void:
	_check_sfx = get_node_or_null("CheckPlayer") as AudioStreamPlayer3D
	if _check_sfx == null:
		_check_sfx = AudioStreamPlayer3D.new()
		_check_sfx.name = "CheckPlayer"
		_check_sfx.max_distance = 10.0
		add_child(_check_sfx)
	if check_stream == null:
		check_stream = load("res://audio/sfx/ui_soft_click.wav") as AudioStream
	_check_sfx.stream = check_stream
	_check_sfx.volume_db = check_volume_db
	_check_sfx.bus = &"Master"


func _play_check_sfx() -> void:
	if _check_sfx == null:
		_ensure_check_player()
	if _check_sfx and _check_sfx.stream:
		_check_sfx.pitch_scale = randf_range(0.96, 1.04)
		_check_sfx.volume_db = check_volume_db + randf_range(-1.0, 0.5)
		_check_sfx.play()


func _key_flag() -> String:
	if is_bedroom_key_site:
		return "tash_room_key"
	if is_front_key_site:
		return "front_key"
	return ""


func _on_interact(_player: Node) -> void:
	_play_check_sfx()
	var dur := line_duration if line_duration > 0.0 else LINE_DURATION
	if GameState == null:
		get_tree().call_group("subtitle", "show_line", "SABIRA", _empty_caption(), dur)
		return
	var key_flag := _key_flag()
	# After catch strip, allow re-loot if flag gone.
	if _looted and not key_flag.is_empty() and not GameState.has_inventory_flag(key_flag):
		_looted = false
	if _looted and is_pills_site and not GameState.has_pills:
		_looted = false
	if not key_flag.is_empty() and _key_armed and not _looted:
		if not GameState.add_inventory_flag(key_flag):
			return
		_looted = true
		get_tree().call_group("subtitle", "show_line", "SABIRA", _key_find_caption(), dur)
		return
	if is_pills_site:
		if _looted or not _site_armed:
			get_tree().call_group("subtitle", "show_line", "SABIRA", _empty_caption(), dur)
			return
		if not GameState.add_inventory_flag("pills"):
			return
		_looted = true
		get_tree().call_group("subtitle", "show_line", "SABIRA", find_line, dur)
		return
	get_tree().call_group("subtitle", "show_line", "SABIRA", _empty_caption(), dur)