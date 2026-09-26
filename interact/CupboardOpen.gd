# Godot 4.x - Sabira / HOUSE
class_name CupboardOpen
extends Interactable
## Toggle CupboardDoorL / CupboardDoorR together.
## Resolves left/right paths; falls back to find_child under sibling cupboard root if nested.
## interior_mesh_paths: closet clothes piles shown only while open (default closed = hidden).
## When open: this body's collision_layer=0 so the interact ray reaches pile Bodies;
## thin CupboardCloseHit StaticBodies on the door leaves keep [E] Close cupboard.

@export var left_door_path: NodePath
@export var right_door_path: NodePath
@export var left_door_name: String = "CupboardDoorL"
@export var right_door_name: String = "CupboardDoorR"
@export var left_open_angle_deg: float = -90.0
@export var right_open_angle_deg: float = 90.0
@export var open_speed: float = 3.5
@export var open_prompt: String = "[E] Open cupboard"
@export var close_prompt: String = "[E] Close cupboard"
@export var creak_stream: AudioStream
@export var creak_volume_db: float = -18.0
## Meshes toggled with doors (Tash/Sabira ClosetClothes piles). Closed = hidden.
@export var interior_mesh_paths: Array[NodePath] = []

var _left: Node3D
var _right: Node3D
var _is_open: bool = false
var _left_closed: float = 0.0
var _right_closed: float = 0.0
var _left_target: float = 0.0
var _right_target: float = 0.0
var _creak: AudioStreamPlayer3D
var _interior_meshes: Array[Node3D] = []
var _close_hits: Array[CupboardCloseHit] = []
var _volume_shape: CollisionShape3D
var _frame_close_hit: CupboardCloseHit


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	_left = _resolve_door(left_door_path, left_door_name)
	_right = _resolve_door(right_door_path, right_door_name)
	_resolve_interior_meshes()
	_set_interior_visible(false)
	_ensure_close_hits()
	_apply_open_collision()
	if _left == null and _right == null:
		push_warning("CupboardOpen '%s': no doors resolved (L=%s R=%s)" % [name, left_door_path, right_door_path])
		interact_enabled = false
		return
	if _left:
		_left_closed = _left.rotation.y
		_left_target = _left_closed
	if _right:
		_right_closed = _right.rotation.y
		_right_target = _right_closed
	_ensure_creak_player()
	_update_prompt()


func _resolve_door(path: NodePath, node_name: String) -> Node3D:
	if path != NodePath(""):
		var via_path := get_node_or_null(path) as Node3D
		if via_path:
			return via_path
	var parent_n := get_parent()
	if parent_n and not node_name.is_empty():
		var found := parent_n.find_child(node_name, true, false) as Node3D
		if found:
			return found
	if not node_name.is_empty():
		return find_child(node_name, true, false) as Node3D
	return null


func _resolve_interior_meshes() -> void:
	_interior_meshes.clear()
	for p in interior_mesh_paths:
		if p == NodePath(""):
			continue
		var n := get_node_or_null(p) as Node3D
		if n:
			_interior_meshes.append(n)


func _set_interior_visible(on: bool) -> void:
	for m in _interior_meshes:
		if m == null:
			continue
		m.visible = on
		# Sibling *Body StaticBody (mesh + Body pair in House.tscn)
		var parent_n := m.get_parent()
		if parent_n == null:
			continue
		var body := parent_n.get_node_or_null(String(m.name) + "Body") as CollisionObject3D
		if body:
			body.collision_layer = 5 if on else 0


func _ensure_close_hits() -> void:
	_close_hits.clear()
	_volume_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	# Kill legacy cavity frame (stole Search from piles the same way fridge Close stole jar).
	var legacy := get_node_or_null("CloseHitFrame") as CupboardCloseHit
	if legacy:
		legacy.set_active(false)
		legacy.collision_layer = 0
		legacy.interact_enabled = false
	_frame_close_hit = null
	if _left:
		_close_hits.append(_make_close_hit(_left, "CloseHitL", Vector3(-0.22, 0.0, 0.015), Vector3(0.4, 1.55, 0.045)))
	if _right:
		_close_hits.append(_make_close_hit(_right, "CloseHitR", Vector3(0.22, 0.0, 0.015), Vector3(0.4, 1.55, 0.045)))


func _ensure_frame_close_hit() -> CupboardCloseHit:
	var existing := get_node_or_null("CloseHitFrame") as CupboardCloseHit
	if existing:
		existing.setup(self, close_prompt)
		return existing
	if _volume_shape == null:
		return null
	var hit := CupboardCloseHit.new()
	hit.name = "CloseHitFrame"
	add_child(hit)
	# Match volume shape orientation (handles Tash rotated shape vs Sabira rotated body).
	hit.transform = _volume_shape.transform
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	var src := _volume_shape.shape as BoxShape3D
	var sx := 1.05
	var sy := 1.85
	var sz := 1.1
	if src:
		sx = src.size.x
		sy = src.size.y
		sz = src.size.z
	# Thin slab on the room-facing face (local +Z of the volume shape).
	box.size = Vector3(sx * 0.95, sy * 0.92, 0.1)
	shape.shape = box
	shape.position = Vector3(0.0, 0.0, sz * 0.45)
	hit.add_child(shape)
	hit.setup(self, close_prompt)
	return hit


func _make_close_hit(parent_n: Node3D, hit_name: String, local_offset: Vector3, box_size: Vector3) -> CupboardCloseHit:
	var existing := parent_n.get_node_or_null(hit_name) as CupboardCloseHit
	if existing:
		existing.setup(self, close_prompt)
		existing.position = local_offset
		var es := existing.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if es and es.shape is BoxShape3D:
			(es.shape as BoxShape3D).size = box_size
		return existing
	var hit := CupboardCloseHit.new()
	hit.name = hit_name
	parent_n.add_child(hit)
	hit.position = local_offset
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	# Thin door leaf only - Close without covering interior piles.
	box.size = box_size
	shape.shape = box
	hit.add_child(shape)
	hit.setup(self, close_prompt)
	return hit


func _apply_open_collision() -> void:
	# Open: volume shape off + layer 0 so ray hits clothes piles; door-leaf close-hits on.
	var volume := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if volume:
		volume.disabled = _is_open
	collision_layer = 0 if _is_open else 5
	for hit in _close_hits:
		if hit:
			hit.set_active(_is_open)
			hit.prompt_text = close_prompt


func _physics_process(delta: float) -> void:
	var t := clampf(open_speed * delta, 0.0, 1.0)
	if _left:
		var c := _left.rotation.y
		if absf(wrapf(c - _left_target, -PI, PI)) < 0.01:
			_left.rotation.y = _left_target
		else:
			_left.rotation.y = lerp_angle(c, _left_target, t)
	if _right:
		var c2 := _right.rotation.y
		if absf(wrapf(c2 - _right_target, -PI, PI)) < 0.01:
			_right.rotation.y = _right_target
		else:
			_right.rotation.y = lerp_angle(c2, _right_target, t)


func _on_interact(_player: Node) -> void:
	_is_open = not _is_open
	if _left:
		_left_target = _left_closed + deg_to_rad(left_open_angle_deg) if _is_open else _left_closed
	if _right:
		_right_target = _right_closed + deg_to_rad(right_open_angle_deg) if _is_open else _right_closed
	_set_interior_visible(_is_open)
	_apply_open_collision()
	_play_creak()
	_update_prompt()


func _ensure_creak_player() -> void:
	_creak = get_node_or_null("CreakPlayer") as AudioStreamPlayer3D
	if _creak == null:
		_creak = AudioStreamPlayer3D.new()
		_creak.name = "CreakPlayer"
		_creak.max_distance = 12.0
		add_child(_creak)
	# Short hinge clip - not room door squeak / long OldDoorCreak.
	if creak_stream == null:
		creak_stream = load("res://audio/sfx/fridge_open_short.wav") as AudioStream
	if creak_stream == null:
		creak_stream = load("res://audio/darkworld/OldDoorClose.wav") as AudioStream
	if creak_stream == null:
		creak_stream = load("res://audio/sfx/door_creak.wav") as AudioStream
	_creak.stream = creak_stream
	_creak.volume_db = creak_volume_db
	_creak.bus = &"Master"


func _play_creak() -> void:
	if _creak == null:
		_ensure_creak_player()
	if _creak and _creak.stream:
		_creak.pitch_scale = randf_range(0.9, 1.1)
		_creak.volume_db = creak_volume_db + randf_range(-1.5, 0.5)
		_creak.play()


func _update_prompt() -> void:
	prompt_text = close_prompt if _is_open else open_prompt
