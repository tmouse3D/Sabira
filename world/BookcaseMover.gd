# Godot 4.x - Sabira / HOUSE
extends Node3D
## Slides bookcase mesh + collision aside to expose HiddenRoom passage.
## Supports open AND close (scrape both directions).
##
## Slide axis: BookcaseMover is unrotated at (-4.7, 0, -2.6). The secret wall face
## is in the YZ plane (wall normal = world X into/out of HiddenRoom at more-negative X).
## Books face +X (living side); solid back faces -X (hidden room).
## slide_offset must move ALONG the wall (world/local Z), NOT along the normal (X).
## Final: Vector3(0, 0, -1.6) - ~1.6 m north along the wall, clearing a walkable gap.
##
## PHOTO BOX (no tip_spill gameplay):
## First OPENING: hide shelf Living_PhotoBox, show Structure/Living_PhotoBox_Spilled,
## park floor Take hitbox on spill, arm floor + shelf PhotosPickup sites.
## After discovery: Take/Put-back floor spill <-> shelf box (discovered_photos stays).
## Caption "Photos-?" on first swap. Mum...? is NOT fired here.

signal state_changed(state: int)

enum State { CLOSED, OPENING, OPEN, CLOSING }

@export var slide_offset: Vector3 = Vector3(0, 0, -1.6)
@export var open_duration: float = 3.0
@export var noise_amount: float = 0.8
## Floor Take hitbox after swap, in BookcaseMover local space (living side / +X).
@export var photos_floor_local: Vector3 = Vector3(0.55, 0.08, 0.15)
## Spilled mesh under Structure (sibling). Default ../Living_PhotoBox_Spilled.
@export var spilled_photo_box_path: NodePath = NodePath("../Living_PhotoBox_Spilled")

@onready var _body: StaticBody3D = $BookcaseBody
@onready var _audio: AudioStreamPlayer3D = $AudioStreamPlayer3D

var _state: int = State.CLOSED
var _home_pos: Vector3
var _open_pos: Vector3
var _from_pos: Vector3
var _to_pos: Vector3
var _elapsed: float = 0.0
var _segment_duration: float = 3.0
var _photo_spill_done: bool = false
var _photos_floor: PhotosPickup
var _photos_shelf: PhotosPickup


func _ready() -> void:
	add_to_group("photos_world")
	_home_pos = position
	_open_pos = _home_pos + slide_offset
	set_physics_process(false)
	_apply_collision_for_state()
	_setup_photos_pickups()
	sync_photo_meshes()


func _setup_photos_pickups() -> void:
	_photos_floor = _bind_photos_site("Living_PhotoBoxBody", "floor")
	_photos_shelf = _bind_photos_site("Living_PhotoBoxShelfBody", "shelf")
	if _photos_floor:
		_photos_floor.arm_photos_pickup(false)
	if _photos_shelf:
		_photos_shelf.arm_photos_pickup(false)


func _bind_photos_site(node_name: String, site: String) -> PhotosPickup:
	var box_body := get_node_or_null(node_name) as StaticBody3D
	if box_body == null:
		push_warning("BookcaseMover: %s missing" % node_name)
		return null
	box_body.collision_layer = 0
	box_body.collision_mask = 0
	var pickup := box_body as PhotosPickup
	if pickup == null:
		if box_body.get_script() == null:
			box_body.set_script(load("res://interact/PhotosPickup.gd"))
		pickup = box_body as PhotosPickup
	if pickup:
		pickup.site = site
	return pickup


## Show shelf box vs floor spill from GameState.photos_resting_at (after discovery).
func sync_photo_meshes() -> void:
	var shelf := get_node_or_null("Living_PhotoBox") as Node3D
	var spilled := _get_spilled_box()
	if GameState == null or not GameState.discovered_photos:
		if shelf:
			shelf.visible = true
		if spilled:
			spilled.visible = false
		return
	var at := GameState.photos_resting_at
	if shelf:
		shelf.visible = (at == "shelf")
	if spilled:
		spilled.visible = (at == "floor")


func _get_spilled_box() -> Node3D:
	if spilled_photo_box_path.is_empty():
		return null
	return get_node_or_null(spilled_photo_box_path) as Node3D


func get_state() -> int:
	return _state


func is_fully_open() -> bool:
	return _state == State.OPEN


func is_fully_closed() -> bool:
	return _state == State.CLOSED and position.distance_to(_home_pos) < 0.04


func is_moving() -> bool:
	return _state == State.OPENING or _state == State.CLOSING


func toggle_or_stop() -> void:
	match _state:
		State.CLOSED:
			_start_toward(_open_pos, State.OPENING)
		State.OPENING, State.CLOSING:
			_stop_in_place()
		State.OPEN:
			_start_toward(_home_pos, State.CLOSING)


func _start_toward(target: Vector3, next_state: int) -> void:
	_from_pos = position
	_to_pos = target
	var full := _home_pos.distance_to(_open_pos)
	var remaining := _from_pos.distance_to(_to_pos)
	if full > 0.001:
		_segment_duration = open_duration * (remaining / full)
	else:
		_segment_duration = open_duration
	_segment_duration = maxf(_segment_duration, 0.05)
	_elapsed = 0.0
	_state = next_state
	set_physics_process(true)
	_play_scrape(true)
	_apply_collision_for_state()
	state_changed.emit(_state)
	if next_state == State.OPENING and not _photo_spill_done:
		_do_photo_box_swap()


func _stop_in_place() -> void:
	set_physics_process(false)
	_play_scrape(false)
	if position.distance_to(_open_pos) < 0.04:
		position = _open_pos
		_state = State.OPEN
		if GameState:
			GameState.bookcase_unlocked = true
	elif position.distance_to(_home_pos) < 0.04:
		position = _home_pos
		_state = State.CLOSED
	else:
		_state = State.CLOSED
	_apply_collision_for_state()
	state_changed.emit(_state)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var u := clampf(_elapsed / _segment_duration, 0.0, 1.0)
	var s := u * u * (3.0 - 2.0 * u)
	position = _from_pos.lerp(_to_pos, s)
	if GameState:
		GameState.report_noise(noise_amount)
	if u >= 1.0:
		position = _to_pos
		set_physics_process(false)
		_play_scrape(false)
		if _state == State.OPENING:
			_state = State.OPEN
			if GameState:
				GameState.bookcase_unlocked = true
		elif _state == State.CLOSING:
			_state = State.CLOSED
		_apply_collision_for_state()
		state_changed.emit(_state)


func _apply_collision_for_state() -> void:
	if _body == null:
		return
	var solid := _state != State.OPEN
	_body.collision_layer = 1 if solid else 0
	_body.collision_mask = 0


func _play_scrape(on: bool) -> void:
	if _audio == null or _audio.stream == null:
		return
	if on:
		if not _audio.playing:
			_audio.play()
		if not _audio.finished.is_connected(_on_scrape_finished):
			_audio.finished.connect(_on_scrape_finished)
	else:
		if _audio.finished.is_connected(_on_scrape_finished):
			_audio.finished.disconnect(_on_scrape_finished)
		_audio.stop()


func _on_scrape_finished() -> void:
	if is_moving() and _audio and _audio.stream:
		_audio.play()


## First scrape: shelf box vanishes, floor spill shows, both Take sites arm.
func _do_photo_box_swap() -> void:
	_photo_spill_done = true
	if GameState:
		GameState.discovered_photos = true
		GameState.photos_resting_at = "floor"
	get_tree().call_group("subtitle", "show_line", "SABIRA", "Photos-?", 2.2)

	if _photos_floor == null or _photos_shelf == null:
		_setup_photos_pickups()

	var structure := get_parent() as Node3D
	var spilled := _get_spilled_box()
	if _photos_floor and structure and is_instance_valid(_photos_floor) and _photos_floor.get_parent() == self:
		_photos_floor.reparent(structure, true)
	if _photos_floor:
		var floor_global := to_global(photos_floor_local)
		_photos_floor.global_position = floor_global
		if spilled:
			_photos_floor.global_position = spilled.global_position + Vector3(0.0, 0.06, 0.0)
		var shape := _photos_floor.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape and shape.shape is BoxShape3D:
			(shape.shape as BoxShape3D).size = Vector3(0.55, 0.12, 0.45)

	sync_photo_meshes()
	if _photos_floor:
		_photos_floor.arm_photos_pickup(true)
	if _photos_shelf:
		_photos_shelf.arm_photos_pickup(true)
