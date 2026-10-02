# Godot 4.x - Sabira / HOUSE
extends CharacterBody3D
## First-person walk / crouch / jump / mouse look / interact raycast.
## Soft footstep SFX via distance accumulator (walk / sprint / crouch).

@export var walk_speed: float = 3.5
@export var sprint_speed: float = 5.5
@export var crouch_speed: float = 1.8
@export var jump_velocity: float = 5.5
@export var mouse_sensitivity: float = 0.0025
@export var gravity: float = 20.0
@export var stand_height: float = 1.7
@export var crouch_height: float = 1.0
@export var interact_distance: float = 2.5
@export var footstep_interval_walk: float = 1.8
@export var footstep_interval_sprint: float = 1.28
@export var footstep_interval_crouch: float = 2.48
@export var footstep_volume_db: float = -10.0
@export var footstep_crouch_volume_db: float = -18.0
## Multiplier while GameState.carrying_amina (slow walk; sprint also scaled).
@export var carry_speed_mult: float = 0.45
## Carry body BoxShape (mesh-aligned). Owned by Player CharacterBody3D so move_and_slide sees it.
## Sized from Mom_Amina Body AABB (X~0.26 Y~0.48 Z~1.13) + pad; bias centers on mesh.
## Main player capsule stays at stand radius 0.35 (no widen) so doorways stay passable.
@export var carry_bumper_size: Vector3 = Vector3(0.30, 0.50, 0.95)
## Mom-local nudge from Mom origin toward body center (mesh lies on -Z).
@export var carry_bumper_local_bias: Vector3 = Vector3(0.0, 0.02, -0.85)
## Head capsule (front-right / bottom-right FOV). Capsule along Mom length toward head.
@export var carry_head_radius: float = 0.10
@export var carry_head_height: float = 0.18
## Mom-local bias to head tip (past body center along -Z; Z=180 maps head to screen +X).
@export var carry_head_local_bias: Vector3 = Vector3(0.0, 0.01, -1)
## Fallback camera-local head pose when Mom not yet under camera (bottom-right FOV).
@export var carry_head_cam_offset: Vector3 = Vector3(0.28, -0.40, -0.45)
## Fallback pose when Mom not yet under camera (mirrors MomWrap defaults; do not diverge).
@export var carry_pose_offset: Vector3 = Vector3(0.0, -0.50, -0.6)
@export var carry_pose_rotation_deg: Vector3 = Vector3(17.0, -90.0, 180.0)
## world (1) + interactable (4). First hit must be Interactable or the ray is occluded.
const INTERACT_RAY_MASK: int = 1 | 4

@onready var _pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _ray: RayCast3D = $CameraPivot/Camera3D/InteractRay
@onready var _prompt: Control = $PromptLayer/Prompt

var _crouching: bool = false
var _current_target: Interactable = null
var _foot_dist: float = 0.0
var _foot_player: AudioStreamPlayer
var _foot_streams_wood: Array[AudioStream] = []
var _foot_streams_stairs: Array[AudioStream] = []
var _foot_idx: int = 0
var _last_pos: Vector3
var _input_locked: bool = false
var _carry_bumper: CollisionShape3D
var _carry_head_bumper: CollisionShape3D


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 8  # world + blocker (couch solids; not in interact ray)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_ray.target_position = Vector3(0, 0, -interact_distance)
	_ray.enabled = true
	_ray.collide_with_areas = false
	_ray.collide_with_bodies = true
	_ray.collision_mask = INTERACT_RAY_MASK
	_apply_stance(false)
	if _prompt and _prompt.has_method("set_prompt"):
		_prompt.set_prompt("")
	_setup_footsteps()
	_last_pos = global_position
	_ensure_carry_bumper()
	# Capsule radius stays at scene default (0.35); never widen while carrying.
	var cap := _collision.shape as CapsuleShape3D
	if cap and absf(cap.radius - 0.35) > 0.001:
		cap.radius = 0.35


func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		velocity = Vector3.ZERO
		_current_target = null
		if _prompt and _prompt.has_method("set_prompt"):
			_prompt.set_prompt("")


func _setup_footsteps() -> void:
	_foot_player = get_node_or_null("FootstepPlayer") as AudioStreamPlayer
	if _foot_player == null:
		_foot_player = AudioStreamPlayer.new()
		_foot_player.name = "FootstepPlayer"
		add_child(_foot_player)
	_foot_player.bus = &"Master"
	_foot_player.volume_db = footstep_volume_db
	_foot_streams_wood.clear()
	_foot_streams_stairs.clear()
	for i in range(1, 6):
		var w := load("res://audio/psx_footsteps/wood/Footstep Wood %d.ogg" % i) as AudioStream
		if w:
			_foot_streams_wood.append(w)
		var st := load("res://audio/psx_footsteps/stairs/Footstep Stairs %d.ogg" % i) as AudioStream
		if st:
			_foot_streams_stairs.append(st)
	if _foot_streams_wood.is_empty():
		for i in range(1, 6):
			var f := load("res://audio/sfx/Footstep Wood %d.ogg" % i) as AudioStream
			if f:
				_foot_streams_wood.append(f)



func _unhandled_input(event: InputEvent) -> void:
	if _input_locked:
		return
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		_pivot.rotation.x = clampf(_pivot.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	if event.is_action_pressed("interact"):
		_try_interact()


func _physics_process(delta: float) -> void:
	if _input_locked:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump") and not _crouching:
		velocity.y = jump_velocity

	var carrying := GameState != null and GameState.carrying_amina
	_sync_carry_bumper(carrying)
	# Unable to crouch while carrying Mum.
	var want_crouch := Input.is_action_pressed("crouch") and not carrying
	if carrying and _crouching:
		want_crouch = false
	if want_crouch != _crouching:
		_crouching = want_crouch
		_apply_stance(_crouching)
		if GameState:
			GameState.set_crouching(_crouching)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := walk_speed
	var sprinting := false
	if _crouching:
		speed = crouch_speed
	elif Input.is_action_pressed("sprint"):
		speed = sprint_speed
		sprinting = true
	if carrying:
		speed *= carry_speed_mult
		sprinting = false

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	_update_footsteps(sprinting)
	_update_interact_target()


func _update_footsteps(sprinting: bool) -> void:
	var flat := Vector3(global_position.x, 0.0, global_position.z)
	var prev := Vector3(_last_pos.x, 0.0, _last_pos.z)
	var step_len := flat.distance_to(prev)
	_last_pos = global_position
	if not is_on_floor():
		_foot_dist = 0.0
		return
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if horiz_speed < 0.15 or step_len < 0.0001:
		return
	_foot_dist += step_len
	var interval := footstep_interval_walk
	if _crouching:
		interval = footstep_interval_crouch
	elif sprinting:
		interval = footstep_interval_sprint
	if _foot_dist >= interval:
		_foot_dist = 0.0
		_play_footstep(sprinting)


func _play_footstep(sprinting: bool) -> void:
	var streams := _foot_streams_wood
	if GameState and GameState.is_on_stairs and not _foot_streams_stairs.is_empty():
		streams = _foot_streams_stairs
	if _foot_player == null or streams.is_empty():
		return
	_foot_idx = (_foot_idx + 1 + randi() % maxi(1, streams.size() - 1)) % streams.size()
	_foot_player.stream = streams[_foot_idx]
	if _crouching:
		_foot_player.volume_db = footstep_crouch_volume_db
		_foot_player.pitch_scale = randf_range(0.85, 0.95)
	elif sprinting:
		_foot_player.volume_db = footstep_volume_db + 1.5
		_foot_player.pitch_scale = randf_range(1.05, 1.18)
	else:
		_foot_player.volume_db = footstep_volume_db
		_foot_player.pitch_scale = randf_range(0.95, 1.05)
	_foot_player.play()



func _carry_shape_owner() -> Node:
	# CollisionShape3D must be a direct child of CharacterBody3D for move_and_slide.
	# Nested under Camera3D/Pivot does NOT participate (Godot CollisionObject quirk).
	return self


func _find_named_collision_shape(shape_name: String) -> CollisionShape3D:
	var found := get_node_or_null(shape_name) as CollisionShape3D
	if found:
		return found
	if _pivot != null:
		found = _pivot.get_node_or_null(shape_name) as CollisionShape3D
		if found:
			return found
	if _camera != null:
		found = _camera.get_node_or_null(shape_name) as CollisionShape3D
		if found:
			return found
	return null


func _adopt_collision_shape(shape_name: String) -> CollisionShape3D:
	var owner_n := _carry_shape_owner()
	var shape_n := owner_n.get_node_or_null(shape_name) as CollisionShape3D
	if shape_n == null:
		var legacy := _find_named_collision_shape(shape_name)
		if legacy != null:
			shape_n = legacy
	if shape_n == null:
		shape_n = CollisionShape3D.new()
		shape_n.name = shape_name
		owner_n.add_child(shape_n)
	elif shape_n.get_parent() != owner_n:
		shape_n.reparent(owner_n, false)
	return shape_n


func _find_carried_mom() -> Node3D:
	if _camera == null:
		return null
	var direct := _camera.get_node_or_null("Hidden_Mom_Amina") as Node3D
	if direct:
		return direct
	for child in _camera.get_children():
		if child is Node3D and str(child.name).begins_with("Hidden_Mom"):
			return child as Node3D
	return null


func _camera_world_from_local(local_xf: Transform3D) -> Transform3D:
	if _camera != null:
		return _camera.global_transform * local_xf
	if _pivot != null:
		return _pivot.global_transform * local_xf
	return global_transform * local_xf


func _fallback_mom_cam_local() -> Transform3D:
	var xf := Transform3D.IDENTITY
	xf.origin = carry_pose_offset
	xf.basis = Basis.from_euler(Vector3(
		deg_to_rad(carry_pose_rotation_deg.x),
		deg_to_rad(carry_pose_rotation_deg.y),
		deg_to_rad(carry_pose_rotation_deg.z)
	))
	return xf


func _ensure_carry_bumper() -> void:
	_carry_bumper = _adopt_collision_shape("CarryBumper")
	var box := _carry_bumper.shape as BoxShape3D
	if box == null:
		box = BoxShape3D.new()
		_carry_bumper.shape = box
	box.size = carry_bumper_size
	_carry_bumper.disabled = true

	_carry_head_bumper = _adopt_collision_shape("CarryHeadBumper")
	var cap := _carry_head_bumper.shape as CapsuleShape3D
	if cap == null:
		cap = CapsuleShape3D.new()
		_carry_head_bumper.shape = cap
	cap.radius = carry_head_radius
	cap.height = carry_head_height
	_carry_head_bumper.disabled = true

	_apply_carry_bumper_pose()


func _apply_carry_bumper_pose() -> void:
	var mom := _find_carried_mom()
	var mom_cam: Transform3D
	if mom != null:
		mom_cam = mom.transform
	else:
		mom_cam = _fallback_mom_cam_local()

	if _carry_bumper != null:
		var box := _carry_bumper.shape as BoxShape3D
		if box:
			box.size = carry_bumper_size
		var body_local := Transform3D(
			mom_cam.basis,
			mom_cam.origin + mom_cam.basis * carry_bumper_local_bias
		)
		# Direct child of Player: bake camera-local pose into world each frame.
		_carry_bumper.global_transform = _camera_world_from_local(body_local)
		_carry_bumper.scale = Vector3.ONE

	if _carry_head_bumper != null:
		var hcap := _carry_head_bumper.shape as CapsuleShape3D
		if hcap:
			hcap.radius = carry_head_radius
			hcap.height = carry_head_height
		var head_local: Transform3D
		if mom != null:
			# Head tip along Mom -Z; with Z=180 this is screen bottom-right (+X).
			head_local = Transform3D(
				mom_cam.basis,
				mom_cam.origin + mom_cam.basis * carry_head_local_bias
			)
		else:
			head_local = Transform3D(Basis.IDENTITY, carry_head_cam_offset)
		_carry_head_bumper.global_transform = _camera_world_from_local(head_local)
		_carry_head_bumper.scale = Vector3.ONE


func _sync_carry_bumper(carrying: bool) -> void:
	if _carry_bumper == null or _carry_head_bumper == null:
		_ensure_carry_bumper()
	if _carry_bumper != null:
		_carry_bumper.disabled = not carrying
	if _carry_head_bumper != null:
		_carry_head_bumper.disabled = not carrying
	if carrying:
		_apply_carry_bumper_pose()


func _apply_stance(crouch: bool) -> void:
	var height := crouch_height if crouch else stand_height
	var shape := _collision.shape as CapsuleShape3D
	if shape:
		shape.height = height
		_collision.position.y = height * 0.5
	_pivot.position.y = height - 0.15


func _resolve_interactable(collider: Object) -> Interactable:
	var n := collider as Node
	while n:
		if n is Interactable:
			return n as Interactable
		n = n.get_parent()
	return null


func _update_interact_target() -> void:
	_current_target = null
	if _ray.is_colliding():
		# Occlusion: mask includes world geometry; only accept if the first hit is an Interactable
		# (or has an Interactable ancestor). Walls/furniture on layer 1 block through-wall opens.
		var collider := _ray.get_collider()
		var interactable := _resolve_interactable(collider)
		# Peek past door-leaf CloseHit so fridge jar / cupboard piles win when aimed through the opening.
		if interactable is CupboardCloseHit:
			_ray.add_exception(collider)
			_ray.force_raycast_update()
			if _ray.is_colliding():
				var behind := _resolve_interactable(_ray.get_collider())
				if behind and not (behind is CupboardCloseHit) and behind.can_interact(self):
					interactable = behind
			_ray.remove_exception(collider)
			_ray.force_raycast_update()
		# Peek past couch Search front-slab so F2 Landing book Read wins when aimed at the book.
		elif interactable is CouchSearch:
			_ray.add_exception(collider)
			_ray.force_raycast_update()
			if _ray.is_colliding():
				var behind2 := _resolve_interactable(_ray.get_collider())
				if behind2 is BookRead and behind2.can_interact(self):
					interactable = behind2
			_ray.remove_exception(collider)
			_ray.force_raycast_update()
		if interactable and interactable.can_interact(self):
			_current_target = interactable
	if _prompt and _prompt.has_method("set_prompt"):
		if _current_target:
			_prompt.set_prompt(_current_target.get_prompt())
		else:
			_prompt.set_prompt("")


func _try_interact() -> void:
	if _current_target and _current_target.can_interact(self):
		_current_target.interact(self)
