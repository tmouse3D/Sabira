# Godot 4.x - Sabira / HOUSE
class_name PhotosPickup
extends Interactable
## Photos Take / Put-back after bookcase scrape discovery (floor spill OR shelf box).
## discovered_photos stays once set. Look-through UI only on the first Take ever.
## Floor: Take <-> Put back. Shelf: Take <-> Put on shelf (hides spill, shows shelf box).

@export_enum("floor", "shelf") var site: String = "floor"
@export var take_prompt: String = "[E] Take the photos."
@export var put_floor_prompt: String = "[E] Put the photos back."
@export var put_shelf_prompt: String = "[E] Put the photos on the shelf."
@export var take_line: String = "Took the photos."
@export var found_line: String = "Found the photos."
@export var put_floor_line: String = "Left the photos."
@export var put_shelf_line: String = "Hid the photos."
@export var line_duration: float = 2.5
@export var take_stream: AudioStream
@export var take_volume_db: float = -18.0

var _armed: bool = false
var _lookthrough_open: bool = false
var _take_sfx: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	interact_enabled = false
	add_to_group("photos_sites")
	_ensure_take_player()
	_refresh_prompt()


func arm_photos_pickup(on: bool) -> void:
	_armed = on
	collision_layer = 5 if on else 0
	interact_enabled = on
	_refresh_prompt()


func can_interact(_player: Node) -> bool:
	if _lookthrough_open:
		return false
	if not interact_enabled or not _armed or GameState == null:
		return false
	if not GameState.discovered_photos:
		return false
	# Carrying: both sites offer put (floor = leave, shelf = hide).
	if GameState.has_photos:
		return true
	# Not carrying: only the site where photos currently rest.
	return GameState.photos_resting_at == site


func get_prompt() -> String:
	if not can_interact(null):
		return ""
	if GameState.has_photos:
		if site == "shelf":
			return put_shelf_prompt
		return put_floor_prompt
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
	if GameState == null or not _armed or _lookthrough_open:
		return
	if not GameState.discovered_photos:
		return
	if GameState.has_photos:
		_put_back()
		return
	if GameState.photos_resting_at != site:
		return
	# Carry-full check before look-through / inventory.
	if not GameState.can_carry("photos"):
		GameState.add_inventory_flag("photos")  # shows Can't carry more.
		return
	_play_take_sfx()
	if not GameState.photos_looked:
		_start_lookthrough()
	else:
		_finish_take(false)


func _put_back() -> void:
	if not GameState.has_photos:
		return
	if not GameState.remove_inventory_flag("photos"):
		return
	_play_take_sfx()
	GameState.photos_resting_at = site
	var line := put_shelf_line if site == "shelf" else put_floor_line
	get_tree().call_group("subtitle", "show_line", "SABIRA", line, line_duration)
	_sync_world()
	_refresh_all_sites()


func _start_lookthrough() -> void:
	var ui := get_tree().get_first_node_in_group("photos_lookthrough")
	if ui == null or not ui.has_method("open_look"):
		_finish_take(true)
		return
	_lookthrough_open = true
	_refresh_prompt()
	if ui.has_signal("finished") and not ui.finished.is_connected(_on_lookthrough_finished):
		ui.finished.connect(_on_lookthrough_finished, CONNECT_ONE_SHOT)
	ui.open_look()


func _on_lookthrough_finished() -> void:
	_lookthrough_open = false
	_finish_take(true)


func _finish_take(first_look: bool) -> void:
	if GameState == null:
		return
	if not GameState.add_inventory_flag("photos"):
		_refresh_prompt()
		return
	GameState.photos_resting_at = ""
	if first_look:
		GameState.photos_looked = true
	var line := found_line if first_look else take_line
	get_tree().call_group("subtitle", "show_line", "SABIRA", line, line_duration)
	_sync_world()
	_refresh_all_sites()


func _sync_world() -> void:
	get_tree().call_group("photos_world", "sync_photo_meshes")


func _refresh_all_sites() -> void:
	for n in get_tree().get_nodes_in_group("photos_sites"):
		if n != self and n.has_method("_refresh_prompt"):
			n._refresh_prompt()
	_refresh_prompt()


func _refresh_prompt() -> void:
	prompt_text = get_prompt()
