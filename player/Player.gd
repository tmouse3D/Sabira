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
## Heights ~9% shorter than the old 1.55 / 1.0 / 1.15 (2026-10-10). Eye = height - eye_below_top.
@export var stand_height: float = 1.41
@export var crouch_height: float = 0.91
@export var sit_height: float = 1.05
## Camera pivot sits this far below the top of the capsule (old fixed 0.15, scaled 0.91).
@export var eye_below_top: float = 0.1365
@export var interact_distance: float = 2.5
@export_group("Held Knife")
@export var knife_hold_offset: Vector3 = Vector3(0.22, -0.22, -0.42)
@export var knife_hold_rotation_deg: Vector3 = Vector3(-10, 85, 110)
@export var knife_hold_scale: float = 1.15
@export_group("")
@export var footstep_interval_walk: float = 1.8
@export var footstep_interval_sprint: float = 1.28
@export var footstep_interval_crouch: float = 2.48
@export var footstep_volume_db: float = -10.0
@export var footstep_crouch_volume_db: float = -18.0
## Multiplier while GameState.carrying_amina (slow walk; sprint also scaled).
@export var carry_speed_mult: float = 0.45
## Carry abdomen/legs BoxShape (mesh-aligned). Owned by Player CharacterBody3D so move_and_slide sees it.
## Wider for side walls, flatter (less dead height), longer for legs/abdomen; bias centers midriff/legs.
## Main player capsule stays at stand radius 0.35 (no widen) so doorways stay passable.
@export var carry_bumper_size: Vector3 = Vector3(0.34, 0.40, 1.20)
## Mom-local nudge from Mom origin toward abdomen/legs center (mesh lies on -Z; not head tip).
@export var carry_bumper_local_bias: Vector3 = Vector3(0.0, -0.02, -0.35)
## Small head-tip capsule (tight; trim empty space past skull).
@export var carry_head_radius: float = 0.07
@export var carry_head_height: float = 0.10
## Mom-local head tip bias (actual skull along -Z; Z=180 maps screen-right).
@export var carry_head_local_bias: Vector3 = Vector3(0.0, -0.01, -0.91)
## Fallback camera-local head tip pose when Mom not yet under camera (closer to cam; less deep -Z).
@export var carry_head_cam_offset: Vector3 = Vector3(0.22, -0.42, -0.28)
## Camera-local pull toward camera (+Z) / slight screen-right (+X) so walls hit before mesh clips.
@export var carry_collision_cam_pull: Vector3 = Vector3(0.07, 0.0, 0.23)
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
var _sitting: bool = false
var _sit_chair: Node = null


func _ready() -> void:
	add_to_group("player")
	# Settings autoload (user://settings.cfg) owns mouse sensitivity; Settings.apply() also pushes it live.
	mouse_sensitivity = Settings.mouse_sensitivity
	# Esc pause menu (ui/PauseMenu.tscn) lives with the player for this run.
	var pause_menu := (load("res://ui/PauseMenu.tscn") as PackedScene).instantiate()
	add_child.call_deferred(pause_menu)
	# New game (Play / Restart): intro slideshow, then seated at dinner (ui/IntroSlides.gd).
	if GameState.intro_pending:
		GameState.intro_pending = false
		var intro := (load("res://ui/IntroSlides.tscn") as PackedScene).instantiate()
		get_tree().root.add_child.call_deferred(intro)
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
	if GameState != null and GameState.has_signal("tash_alert_changed"):
		GameState.tash_alert_changed.connect(_on_conc_alert)
	# Capsule radius stays at scene default (0.35); never widen while carrying.
	var cap := _collision.shape as CapsuleShape3D
	if cap and absf(cap.radius - 0.35) > 0.001:
		cap.radius = 0.35
	# Belt-and-suspenders: ensure HeldKnife script loads (Inspector path: Player > Held Knife).
	var hk := _camera.get_node_or_null("HeldKnife") if _camera else null
	if hk != null and hk.get_script() == null:
		hk.set_script(load("res://player/HeldKnife.gd"))


func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		velocity = Vector3.ZERO
		_current_target = null
		if _prompt and _prompt.has_method("set_prompt"):
			_prompt.set_prompt("")


# --- First-sight face lock (props_subs 2026-10-14) -----------------------------------------
## TashWalker calls begin_face_lock(self, 2.0) when his first-sight speech starts: look + move
## input off, body yaw + pivot pitch ease-out onto target.face_point() over FACE_LOCK_TURN_SEC,
## then keep tracking it until total_sec, then input back. Skipped while a UI holds
## _input_locked, the mouse is free, she sits or carries Mum. Crouch stance is left as it is.
const FACE_LOCK_TURN_SEC := 0.35
const FACE_LOCK_PITCH_MAX_DEG := 85.0
var _face_lock_t: float = -1.0
var _face_lock_total: float = 0.0
var _face_lock_target: Node3D = null
var _face_lock_from_yaw: float = 0.0
var _face_lock_from_pitch: float = 0.0


func begin_face_lock(target: Node3D, total_sec: float = 2.0) -> void:
	if target == null or _input_locked or _sitting or (GameState != null and GameState.carrying_amina) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		print("[FACELOCK] skipped (ui / mouse free / sitting / carrying)")
		return
	_face_lock_target = target
	_face_lock_total = total_sec
	_face_lock_t = 0.0
	_face_lock_from_yaw = rotation.y
	_face_lock_from_pitch = _pivot.rotation.x
	velocity.x = 0.0
	velocity.z = 0.0
	print("[FACELOCK] start %.2f s" % total_sec)


func is_face_locked() -> bool:
	return _face_lock_t >= 0.0


func _face_lock_tick(delta: float) -> void:
	if _face_lock_t < 0.0:
		return
	if _input_locked or _face_lock_target == null or not is_instance_valid(_face_lock_target):
		_face_lock_t = -1.0
		print("[FACELOCK] cancelled")
		return
	_face_lock_t += delta
	var tgt: Vector3 = _face_lock_target.call("face_point") if _face_lock_target.has_method("face_point") else _face_lock_target.global_position + Vector3(0, 1.6, 0)
	var eye := _camera.global_position if _camera != null else global_position + Vector3(0, 1.5, 0)
	var d := tgt - eye
	var want_yaw := atan2(-d.x, -d.z)
	var lim := deg_to_rad(FACE_LOCK_PITCH_MAX_DEG)
	var want_pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -lim, lim)
	var k := clampf(_face_lock_t / FACE_LOCK_TURN_SEC, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	rotation.y = lerp_angle(_face_lock_from_yaw, want_yaw, e)
	_pivot.rotation.x = lerpf(_face_lock_from_pitch, want_pitch, e)
	if _face_lock_t >= _face_lock_total:
		_face_lock_t = -1.0
		print("[FACELOCK] released")


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
	if _input_locked or _face_lock_t >= 0.0:
		return
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Esc is handled by ui/PauseMenu.gd (pause + free the mouse); no Esc mouse release here.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		_pivot.rotation.x = clampf(_pivot.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	if event.is_action_pressed("interact"):
		_try_interact()


func _physics_process(delta: float) -> void:
	_face_lock_tick(delta)
	if _input_locked or _face_lock_t >= 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		return
	var carrying := GameState != null and GameState.carrying_amina
	if not is_on_floor():
		velocity.y -= gravity * delta
	# Unable to jump while carrying Mum.
	elif Input.is_action_just_pressed("jump") and not _crouching and not carrying and not _sitting:
		velocity.y = jump_velocity

	_sync_carry_bumper(carrying)

	if _sitting:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_update_interact_target()
		return

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
	_conc_tick_walk(delta, direction != Vector3.ZERO and not carrying)


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
		body_local.origin += carry_collision_cam_pull
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
			# Small head tip along Mom -Z; with Z=180 this is screen-right (+X).
			head_local = Transform3D(
				mom_cam.basis,
				mom_cam.origin + mom_cam.basis * carry_head_local_bias
			)
		else:
			head_local = Transform3D(Basis.IDENTITY, carry_head_cam_offset)
		head_local.origin += carry_collision_cam_pull
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
	_pivot.position.y = height - eye_below_top


func _apply_sit_stance() -> void:
	var height := sit_height
	var shape := _collision.shape as CapsuleShape3D
	if shape:
		shape.height = height
		_collision.position.y = height * 0.5
	_pivot.position.y = height - eye_below_top


func is_sitting() -> bool:
	return _sitting


func begin_sit(chair: Node, sit_xf: Transform3D) -> void:
	if _sitting:
		return
	if GameState != null and GameState.carrying_amina:
		return
	global_position = sit_xf.origin
	rotation.y = sit_xf.basis.get_euler().y
	velocity = Vector3.ZERO
	_sitting = true
	_sit_chair = chair
	_crouching = false
	if GameState:
		GameState.set_crouching(false)
	_apply_sit_stance()


func end_sit(stand_xf: Variant = null) -> void:
	if not _sitting:
		return
	var chair := _sit_chair
	_sitting = false
	_sit_chair = null
	if chair != null and is_instance_valid(chair) and chair.has_method("clear_occupant"):
		chair.clear_occupant()
	if stand_xf is Transform3D:
		global_position = (stand_xf as Transform3D).origin
		rotation.y = (stand_xf as Transform3D).basis.get_euler().y
	velocity = Vector3.ZERO
	_apply_stance(false)
	if _prompt and _prompt.has_method("set_prompt"):
		_prompt.set_prompt("")


func _resolve_interactable(collider: Object) -> Interactable:
	var n := collider as Node
	while n:
		if n is Interactable:
			return n as Interactable
		n = n.get_parent()
	return null


func _update_interact_target() -> void:
	if _sitting:
		_current_target = null
		var stand_txt := "[E] Stand up"
		if _sit_chair != null and is_instance_valid(_sit_chair) and _sit_chair.has_method("get_prompt"):
			stand_txt = str(_sit_chair.get_prompt())
		if _prompt and _prompt.has_method("set_prompt"):
			_prompt.set_prompt(stand_txt)
		return
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
		# Per-interactable reach cap (e.g. kitchen counter drawer: only right in front).
		if interactable and interactable.max_interact_distance > 0.0 and _ray.is_colliding():
			if _ray.global_position.distance_to(_ray.get_collision_point()) > interactable.max_interact_distance:
				interactable = null
		if interactable and interactable.can_interact(self):
			_current_target = interactable
	if _prompt and _prompt.has_method("set_prompt"):
		if _current_target:
			_prompt.set_prompt(_current_target.get_prompt())
		else:
			_prompt.set_prompt("")


func _try_interact() -> void:
	if _sitting:
		var stand_xf: Variant = null
		if _sit_chair != null and is_instance_valid(_sit_chair) and _sit_chair.has_method("get_stand_transform"):
			stand_xf = _sit_chair.get_stand_transform()
		end_sit(stand_xf)
		return
	if _current_target and _current_target.can_interact(self):
		_current_target.interact(self)


# --- Concussion spells (Realistic + cat_scratch + met_dana + market_warned) ----------------
## Easy: never. _conc_enabled() gates the walk/chase roll and the forced first spell, and
## _conc_start() re-checks, so no spell, camera tilt, blur or CONC_LINES subtitle on Easy.
## While she walks: every CONC_ROLL_SEC of walking roll CONC_CHANCE (min CONC_GAP_SEC apart,
## max CONC_MAX per run). In a chase: at most once, and a successful roll still only fires 40%.
## Effect: slight dim + camera tilts down and shakes for ~3.5 s, then recovers. Uses only the
## Camera3D's own local rotation.x and h/v_offset (pivot look, crouch/sit stance untouched);
## never starts while sitting, locked or carrying Mum, and aborts at once if one begins.
## State lives on the Player, so every run (new House scene) starts fresh.
const CONC_ROLL_SEC := 20.0
const CONC_CHANCE := 0.12
const CONC_CHASE_CHANCE := 0.4
const CONC_GAP_SEC := 60.0
const CONC_MAX := 3
const CONC_DUR := 3.5
const CONC_TILT_DEG := 28.0
const CONC_DIM := 0.35
const CONC_LINES := [
	"Not again... it's the old hits.",
	"Too many times to my head... it never really stops.",
	"Every time he hit me, something stayed broken.",
]
var _conc_walk_t: float = 0.0
var _conc_count: int = 0
var _conc_chase_used: bool = false
var _conc_last_ms: int = -1000000
var _conc_t: float = -1.0
var _conc_chasing: bool = false
var _conc_dim: ColorRect = null
var _conc_blur: ColorRect = null
var _conc_blur_mat: ShaderMaterial = null
const CONC_BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
void fragment() {
	float lod = amount * 3.0;
	vec2 o = SCREEN_PIXEL_SIZE * (2.0 + 6.0 * amount);
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb * 0.36;
	c += textureLod(screen_tex, SCREEN_UV + vec2(o.x, 0.0), lod).rgb * 0.16;
	c += textureLod(screen_tex, SCREEN_UV - vec2(o.x, 0.0), lod).rgb * 0.16;
	c += textureLod(screen_tex, SCREEN_UV + vec2(0.0, o.y), lod).rgb * 0.16;
	c += textureLod(screen_tex, SCREEN_UV - vec2(0.0, o.y), lod).rgb * 0.16;
	COLOR = vec4(c, amount);
}
"""
var _conc_cam_rx: float = 0.0


func _on_conc_alert(st: String) -> void:
	_conc_chasing = st == "chase"


func _conc_enabled() -> bool:
	if GameState == null or GameState.difficulty != "realistic":
		return false
	var f: Dictionary = GameState.prologue_flags
	return bool(f.get("cat_scratch", false)) and bool(f.get("met_dana", false)) and bool(f.get("market_warned", false))


func _conc_tick_walk(delta: float, walking: bool) -> void:
	if not walking or _conc_t >= 0.0 or _conc_count >= CONC_MAX:
		return
	_conc_walk_t += delta
	if _conc_walk_t < CONC_ROLL_SEC:
		return
	_conc_walk_t = 0.0
	if not _conc_enabled():
		return
	if Time.get_ticks_msec() - _conc_last_ms < int(CONC_GAP_SEC * 1000.0):
		return
	if randf() >= CONC_CHANCE:
		return
	if _conc_chasing:
		if _conc_chase_used or randf() >= CONC_CHASE_CHANCE:
			return
		_conc_chase_used = true
	_conc_start()


## First spell is forced 20-30 s of unlocked play after she first gets control (intro seated
## start); it counts toward CONC_MAX. Waits until she is standing, unlocked, not carrying.
var _conc_first_t: float = -1.0
var _conc_first_done: bool = false


func _conc_tick_first(delta: float) -> void:
	if _conc_first_done:
		return
	if _conc_first_t < 0.0:
		if not _conc_enabled():
			return
		_conc_first_t = randf_range(20.0, 30.0)
		print("[CONC] first spell forced in %.1f s of play" % _conc_first_t)
		return
	if _input_locked:
		return
	_conc_first_t = maxf(0.0, _conc_first_t - delta)
	if _conc_first_t > 0.0 or _conc_t >= 0.0:
		return
	if _sitting or (GameState != null and GameState.carrying_amina):
		return
	_conc_first_done = true
	if _conc_count >= CONC_MAX:
		return
	if _conc_chasing:
		_conc_chase_used = true
	_conc_start()


func _conc_start() -> void:
	# Concussion is Realistic-only: hard stop for every caller (walk roll, chase roll, forced first).
	if GameState == null or GameState.is_easy() or not _conc_enabled():
		print("[CONC] spell blocked (not Realistic)")
		return
	_conc_count += 1
	_conc_last_ms = Time.get_ticks_msec()
	_conc_t = 0.0
	_conc_cam_rx = _camera.rotation.x if _camera != null else 0.0
	if _conc_dim == null:
		var layer := CanvasLayer.new()
		layer.layer = 4
		add_child(layer)
		# Blur under the dim: screen texture with mip LOD + a small tap ring.
		_conc_blur = ColorRect.new()
		_conc_blur.set_anchors_preset(Control.PRESET_FULL_RECT)
		_conc_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = CONC_BLUR_SHADER
		_conc_blur_mat = ShaderMaterial.new()
		_conc_blur_mat.shader = sh
		_conc_blur.material = _conc_blur_mat
		_conc_blur.visible = false
		layer.add_child(_conc_blur)
		_conc_dim = ColorRect.new()
		_conc_dim.color = Color.BLACK
		_conc_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_conc_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_conc_dim.modulate.a = 0.0
		layer.add_child(_conc_dim)
	get_tree().call_group("subtitle", "show_line", "SABIRA", String(CONC_LINES[randi() % CONC_LINES.size()]), 3.5)
	print("[CONC] spell %d/%d%s" % [_conc_count, CONC_MAX, " (chase)" if _conc_chasing else ""])


func _conc_end() -> void:
	_conc_t = -1.0
	if _camera != null:
		_camera.rotation.x = _conc_cam_rx
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
	if _conc_dim != null:
		_conc_dim.modulate.a = 0.0
	if _conc_blur != null:
		_conc_blur.visible = false


func _process(delta: float) -> void:
	_conc_tick_first(delta)
	if _conc_t < 0.0:
		return
	if _sitting or _input_locked or (GameState != null and GameState.carrying_amina) or _camera == null:
		print("[CONC] aborted (sit/lock/carry)")
		_conc_end()
		return
	_conc_t += delta
	if _conc_t >= CONC_DUR:
		_conc_end()
		return
	var e := minf(smoothstep(0.0, 0.7, _conc_t), 1.0 - smoothstep(CONC_DUR - 1.2, CONC_DUR, _conc_t))
	var tm := Time.get_ticks_msec() * 0.001
	_camera.rotation.x = _conc_cam_rx - deg_to_rad(CONC_TILT_DEG) * e + sin(tm * 2.3) * 0.04 * e
	_camera.h_offset = (sin(tm * 17.0) + sin(tm * 29.0) * 0.5) * 0.024 * e
	_camera.v_offset = (sin(tm * 21.0 + 1.3)) * 0.02 * e
	_conc_dim.modulate.a = CONC_DIM * e
	# ~1 s blur near the start of each spell (fade in 0.3 s, hold, fade out 0.3 s).
	var b := smoothstep(0.15, 0.45, _conc_t) * (1.0 - smoothstep(0.95, 1.25, _conc_t))
	if _conc_blur != null:
		_conc_blur.visible = b > 0.001
		_conc_blur_mat.set_shader_parameter("amount", b)
