# Godot 4.x - Sabira / HOUSE
# Tash patrol: weighted random stops on measured walkable edges. No BoneMap.
# Flat edges play walk. Stair edges play walk_up_stairs / walk_down_stairs.
# Bookshelf stops play a standing idle, facing the books.
# Couch plays stand_to_sit. Office chair, red couch, and toilet snap to sitting_idle.
class_name TashWalker
extends CharacterBody3D
## Advances parent PathFollow3D at walk_speed.
## Flat floor plays walk. Stair segments play walk_up_stairs / walk_down_stairs.
## Shelf stops play a standing idle. Couch plays stand_to_sit.
## Office chair, red couch, and toilet snap to sitting_idle (no stand_to_sit).

enum _Act { WALK, LOOK, SIT_DOWN, SIT_HOLD, STAND_UP, DOOR, PAUSE, IDLE }

@export var walk_speed: float = 0.6
@export var walk_clip_names: PackedStringArray = PackedStringArray(["walk", "Walk", "Walk_Loop"])
@export var path_follow_path: NodePath = NodePath("..")
## Local Y yaw (degrees) applied to Model/mesh so chest faces path tangent.
@export var model_yaw_offset_deg: float = 180.0
@export var model_node_path: NodePath = NodePath("Model")
## Uniform mesh scale. Collision capsule is unchanged so doors stay passable.
@export_range(1.0, 1.2, 0.01) var model_scale: float = 1.05

@export_group("Диван")
@export var couch_sit_enabled: bool = true
## Index into TashWalkPath. 35 is the living-room stop in front of the couch.
@export var couch_point_index: int = 35
@export var couch_arrive_distance: float = 0.45
@export var sit_hold_seconds: float = 24.0
## World yaw while seated on the F1 couch. 0 faces world -Z.
## Living_TVScreen is world -Z from TashCouchSit (same X). Model yaw 180
## maps body -Z onto the mesh face, so 0 looks at the TV.
## 90 looked world -X, off to his left. PathFollow yaw is zeroed while seated.
## Office, toilet, and red-couch yaws are separate exports.
@export var sit_body_yaw_deg: float = 0.0
@export var sit_marker_path: NodePath = NodePath("../../../TashCouchSit")
## Couch only. Pitch 0: the shared -8 pitch sank him through the cushions.
@export var couch_model_pitch_deg: float = 0.0
## Couch only. Model Y lift so the 0.57 m sit hip clears the cushion. Not the capsule.
@export var couch_model_y_offset: float = 0.10
## Couch only. World Z tuck. 0: the old +0.06 Z pushed him into the cushions.
@export var couch_model_z_offset: float = 0.0
@export var office_sit_enabled: bool = true
## Index of the office-chair stop. Snap sit, no stand_to_sit.
@export var office_chair_point_index: int = 21
## World yaw of the body while snapped on the chair, not path-relative.
## 0 faces world -Z (the desk). Model yaw 180 maps body -Z onto the mesh face.
## Path yaw 0 was wrong once progress passed the chair: the path turns toward -X
## (point 22), so a path-relative 0 looked into the back / away from the desk.
## 180 would face world +Z, into the backrest. Leave this at 0.
@export var office_sit_body_yaw_deg: float = 0.0
@export var office_sit_marker_path: NodePath = NodePath("../../../TashOfficeSit")
@export var office_arrive_distance: float = 0.28
## Office only. 0 keeps him upright. Do not pitch him through the backrest.
@export var office_model_pitch_deg: float = 0.0
## Office only. Meters along world Z. Negative tucks toward the desk (-Z).
@export var office_model_z_offset: float = -0.04
@export var stand_to_sit_clip_names: PackedStringArray = PackedStringArray(["stand_to_sit", "Stand_To_Sit", "Stand To Sit"])
@export var sitting_idle_clip_names: PackedStringArray = PackedStringArray(["sitting_idle", "Sitting_Idle", "Sitting Idle"])

@export_group("Route")
## Segment start index, inclusive. A segment is the span that leaves that point.
@export var stair_up_from_index: int = 3
## Exclusive. Segments [from, to) play walk_up_stairs.
@export var stair_up_to_index: int = 9
@export var stair_down_from_index: int = 27
@export var stair_down_to_index: int = 33
@export var shelf_point_index: int = 18
## Path reaches the shelf heading world -Z. +90 turns the chest toward +X (bookcase).
@export var look_body_yaw_deg: float = 90.0
@export var look_hold_seconds: float = 3.0
@export var look_arrive_distance: float = 0.4
@export var walk_up_stairs_clip_names: PackedStringArray = PackedStringArray(["walk_up_stairs", "Walking Up The Stairs"])
@export var walk_down_stairs_clip_names: PackedStringArray = PackedStringArray(["walk_down_stairs", "Descending Stairs"])
@export var look_around_clip_names: PackedStringArray = PackedStringArray(["look_around", "Looking Around"])
@export var idle_hold_seconds: float = 12.0
## Body yaw while standing at a shelf. Model local yaw stays 180, and the mesh face is +Z,
## so the visible face is body yaw + 180. Yaw 90 looks world -X. Yaw -90 looks world +X.
## F1 books face +X and the case is west of f1stand, so yaw 90 looks at them.
@export var f1_idle_body_yaw_deg: float = 90.0
## F2 case is east of f2stand and its front points world +X, so yaw -90 looks at the books.
@export var f2_idle_body_yaw_deg: float = -90.0
## Office case is east of p18. Its front points world -X, so yaw -90 looks +X at the books.
@export var office_idle_body_yaw_deg: float = -90.0

@export_group("Office door")
@export var office_door_path: NodePath = NodePath("../../../Doors/Door_TashOffice")
## Segment that leaves the outside point (14 -> 15). Pause before the leaf.
@export var door_enter_point_index: int = 14
## Segment that leaves the inside point (22 -> 23). Pause before the leaf.
@export var door_leave_point_index: int = 22
@export var door_arrive_distance: float = 0.45
## World X past the hinge (2.5) before the leaf may close. Inside / outside.
@export var door_clear_inside_x: float = 3.05
@export var door_clear_outside_x: float = 2.05
## Safety only. Path resumes when the Door node is open, not when the clip ends.
@export var door_open_timeout: float = 2.5
@export var open_close_door_clip_names: PackedStringArray = PackedStringArray(["open_close_door", "Opening and Closing", "Opening_and_Closing"])

@export_group("Upper bath")
@export var bath_door_path: NodePath = NodePath("../../../Doors/Door_UpperBath")
## World Z north of the bath door leaf. Inside the room.
@export var bath_clear_inside_z: float = -2.80
## World Z south of the bath door leaf. Back in the hall.
@export var bath_clear_outside_z: float = -2.15
@export var toilet_sit_enabled: bool = true
## World yaw while snapped on the toilet. Toilet node yaw is 0.
## Tank is the mesh -Z end, so 180 faces world +Z, into the room, away from the tank.
@export var toilet_sit_body_yaw_deg: float = 180.0
@export var toilet_sit_marker_path: NodePath = NodePath("../../../TashToiletSit")
@export var red_couch_sit_enabled: bool = true
## Body yaw while snapped on the upstairs red couch. Same rule as the shelf idles:
## visible face is body yaw + 180, so yaw 90 looks world -X.
## Couch_DarkRed backrest is the mesh -Z side. This node maps local +Z onto world -X,
## so someone sitting looks world -X, out from the back and into the room.
## The old -90 looked world +X, into the backrest. It is a sit yaw, not a stand yaw.
@export var red_couch_sit_body_yaw_deg: float = 90.0
@export var red_couch_sit_marker_path: NodePath = NodePath("../../../TashRedCouchSit")
@export var footstep_paths: PackedStringArray = PackedStringArray(["res://audio/psx_footsteps/stone/Footstep Stone 1.ogg", "res://audio/psx_footsteps/stone/Footstep Stone 2.ogg", "res://audio/psx_footsteps/stone/Footstep Stone 3.ogg", "res://audio/psx_footsteps/stone/Footstep Stone 4.ogg"])
@export var tv_screen_path: NodePath = NodePath("../../../Structure/Living/Living_TVScreen")
@export var wander_pause_seconds: float = 2.0

## --- External AnimationLibrary (kept off; BoneMap ribboned the mesh) ---
@export var use_external_walk_library: bool = false
@export_file("*.glb") var external_library_scene: String = "res://art/anim/AnimationLibrary_Godot_Standard.glb"
@export var external_walk_clip: String = "Walk"
## Debug only: DEF-* -> mixamorig_* rename without BoneMap (expect twist).
@export var external_track_rename_fallback: bool = false

var _path_follow: PathFollow3D = null
var _anim: AnimationPlayer = null
var _model: Node3D = null
var _clip_path: String = ""
var _up_clip: String = ""
var _down_clip: String = ""
var _look_clip: String = ""
var _door_clip: String = ""
var _using_clip: bool = false
var _lib_root: Node = null
var _act: _Act = _Act.WALK
var _sit_clip: String = ""
var _idle_clip: String = ""
var _hold_left: float = 0.0
var _look_left: float = 0.0
var _door_left: float = 0.0
var _stand_global: Vector3 = Vector3.ZERO
var _sit_global: Vector3 = Vector3.ZERO
var _sit_yaw: float = 0.0
var _couch_latched: bool = false
var _office_latched: bool = false
var _look_latched: bool = false
var _sit_is_office: bool = false
var _office_snap: bool = false
var _door_enter_latched: bool = false
var _door_leave_latched: bool = false
var _door_wait_clear: bool = false
var _door_going_inside: bool = false
var _sit_warned: bool = false
var _up_warned: bool = false
var _down_warned: bool = false
var _look_warned: bool = false
var _door_clip_warned: bool = false
var _door_missing_warned: bool = false
var _door_timeout_warned: bool = false

const _SIT_NONE := 0
const _SIT_COUCH := 1
const _SIT_OFFICE := 2
const _SIT_TOILET := 3
const _SIT_RED := 4
var _sit_kind: int = _SIT_NONE
var _snap_sit: bool = false
var _pause_left: float = 0.0
var _patrol_started: bool = false
var _pt: Dictionary = {}
var _nb: Dictionary = {}
var _stop_node: Dictionary = {}
var _stop_weight: Dictionary = {}
var _here: String = "p0"
var _route: Array = []
var _route_i: int = 0
var _seg_dist: float = 0.0
var _opened_route_i: int = -1
var _active_stop: String = ""
var _last_stop: String = ""
var _door_kind: String = ""
var _pick_depth: int = 0
var _idle_stand_clips: Array = []
var _idle_stand_warned: bool = false
var _idle_yaw: float = 0.0
var _step_player: AudioStreamPlayer3D = null
var _step_streams: Array = []
var _step_left: float = 0.15
var _route_idle: bool = false
var _turn_count: int = 0
var _idle_when_flat: bool = false
var _turn_ids: Dictionary = {}
var _cf_n: int = 0
## Last two chosen stops. The third pick is the toilet when neither was the toilet.
var _recent_picks: Array = []
var _toilet_owed: bool = false


func _ready() -> void:
	add_to_group("tash")
	collision_layer = 1
	collision_mask = 1
	randomize()
	_path_follow = get_node_or_null(path_follow_path) as PathFollow3D
	if _path_follow == null:
		_path_follow = get_parent() as PathFollow3D
	if _path_follow != null:
		_path_follow.loop = false
		# Script owns yaw. ROTATION_Y would fight the per-edge facing.
		_path_follow.rotation_mode = PathFollow3D.ROTATION_NONE
	_apply_model_yaw_offset()
	_setup_footsteps()
	call_deferred("_try_bind_walk_clip")
	call_deferred("_start_patrol")


func _exit_tree() -> void:
	if _lib_root != null and is_instance_valid(_lib_root):
		_lib_root.queue_free()
		_lib_root = null


func _apply_model_yaw_offset() -> void:
	_model = get_node_or_null(model_node_path) as Node3D
	if _model == null:
		_model = find_child("Model", true, false) as Node3D
	if _model == null:
		return
	_model.position = Vector3.ZERO
	_model.rotation_degrees = Vector3(0.0, model_yaw_offset_deg, 0.0)
	_model.scale = Vector3.ONE * model_scale


func _apply_couch_visual() -> void:
	if _model == null:
		_apply_model_yaw_offset()
	if _model == null:
		return
	_model.rotation_degrees = Vector3(couch_model_pitch_deg, model_yaw_offset_deg, 0.0)
	_model.scale = Vector3.ONE * model_scale
	var world_off := Vector3(0.0, couch_model_y_offset, couch_model_z_offset)
	_model.position = global_transform.basis.inverse() * world_off


func _apply_office_visual() -> void:
	if _model == null:
		_apply_model_yaw_offset()
	if _model == null:
		return
	_model.rotation_degrees = Vector3(office_model_pitch_deg, model_yaw_offset_deg, 0.0)
	_model.scale = Vector3.ONE * model_scale
	var world_off := Vector3(0.0, 0.0, office_model_z_offset)
	_model.position = global_transform.basis.inverse() * world_off


func _apply_office_yaw() -> void:
	# Global body yaw. 0 + model yaw 180 faces world -Z (desk), ignoring PathFollow.
	global_rotation = Vector3(0.0, deg_to_rad(office_sit_body_yaw_deg), 0.0)


func _try_bind_walk_clip() -> void:
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		_anim = _ensure_animation_player()
	if _anim == null:
		_using_clip = false
		push_warning("TashWalker: no AnimationPlayer under Tash Model.")
		return
	if not _anim.animation_finished.is_connected(_on_animation_finished):
		_anim.animation_finished.connect(_on_animation_finished)

	if use_external_walk_library:
		if _try_bind_external_library():
			_play_named(_clip_path)
			_bind_sit_clips()
			_bind_route_clips()
			return
		push_warning("TashWalker: external library bind failed - falling back to GLB clip.")

	for clip_name in walk_clip_names:
		_clip_path = _resolve_clip_path(String(clip_name))
		if _clip_path != "":
			break
	if _clip_path == "":
		_using_clip = false
		push_warning("TashWalker: no walk clip found (external + GLB).")
		return
	_using_clip = true
	_force_loop(_clip_path, Animation.LOOP_LINEAR)
	_bind_sit_clips()
	_bind_route_clips()
	_bind_idle_stands()
	_play_named(_clip_path)


func _bind_sit_clips() -> void:
	_sit_clip = ""
	_idle_clip = ""
	if _anim == null:
		return
	for clip_name in stand_to_sit_clip_names:
		_sit_clip = _resolve_clip_path(String(clip_name))
		if _sit_clip != "":
			break
	for clip_name in sitting_idle_clip_names:
		_idle_clip = _resolve_clip_path(String(clip_name))
		if _idle_clip != "":
			break
	if _sit_clip == "" or _idle_clip == "":
		if not _sit_warned:
			_sit_warned = true
			push_warning("TashWalker: stand_to_sit / sitting_idle not in Tash.glb yet. Sit skipped.")
		return
	_force_loop(_sit_clip, Animation.LOOP_NONE)
	_force_loop(_idle_clip, Animation.LOOP_LINEAR)


func _bind_route_clips() -> void:
	_up_clip = _first_clip(walk_up_stairs_clip_names)
	_down_clip = _first_clip(walk_down_stairs_clip_names)
	_look_clip = _first_clip(look_around_clip_names)
	_door_clip = _first_clip(open_close_door_clip_names)
	if _up_clip != "":
		_force_loop(_up_clip, Animation.LOOP_LINEAR)
	elif not _up_warned:
		_up_warned = true
		push_warning("TashWalker: walk_up_stairs missing. Stair up uses walk.")
	if _down_clip != "":
		_force_loop(_down_clip, Animation.LOOP_LINEAR)
	elif not _down_warned:
		_down_warned = true
		push_warning("TashWalker: walk_down_stairs missing. Stair down uses walk.")
	if _look_clip != "":
		_force_loop(_look_clip, Animation.LOOP_NONE)
	elif not _look_warned:
		_look_warned = true
		push_warning("TashWalker: look_around missing. Shelf look skipped.")
	if _door_clip != "":
		_force_loop(_door_clip, Animation.LOOP_NONE)
	elif not _door_clip_warned:
		_door_clip_warned = true
		push_warning("TashWalker: open_close_door missing. Door still opens.")


func _bind_idle_stands() -> void:
	_idle_stand_clips.clear()
	if _anim == null:
		return
	var names: PackedStringArray = PackedStringArray(["idle", "idle_foot", "idle_looking_down", "idle_head_nod"])
	for clip_name in names:
		var found := _resolve_clip_path(String(clip_name))
		if found == "":
			continue
		_force_loop(found, Animation.LOOP_LINEAR)
		_idle_stand_clips.append(found)
	if _idle_stand_clips.is_empty() and not _idle_stand_warned:
		_idle_stand_warned = true
		push_warning("TashWalker: idle clips missing. Shelf stands use look_around or a quiet pose.")


func _begin_idle_stand(yaw_deg: float) -> void:
	_act = _Act.IDLE
	_route_idle = false
	_idle_yaw = yaw_deg
	_look_left = idle_hold_seconds
	global_rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
	_apply_model_yaw_offset()
	if _anim != null and _idle_stand_clips.size() > 0:
		var pick := String(_idle_stand_clips[randi() % _idle_stand_clips.size()])
		_anim.play(pick)
		return
	if _look_clip != "" and _anim != null:
		_force_loop(_look_clip, Animation.LOOP_NONE)
		_anim.play(_look_clip)
		return
	if _anim != null and _anim.is_playing():
		_anim.pause()


func _end_idle_stand() -> void:
	_act = _Act.WALK
	rotation = Vector3.ZERO
	_apply_model_yaw_offset()
	_choose_next()


func _begin_red_couch() -> bool:
	# Snap sit, same idea as the office chair. Never a standing idle.
	if _anim == null:
		_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clip := ""
	if _anim != null:
		clip = _first_clip(sitting_idle_clip_names)
	if clip == "":
		_bind_sit_clips()
		clip = _idle_clip
	if clip == "" or _anim == null:
		push_warning("TashWalker: red couch sit missing sitting_idle.")
		return false
	_idle_clip = clip
	var marker := _marker(red_couch_sit_marker_path, "TashRedCouchSit")
	_sit_kind = _SIT_RED
	_snap_sit = true
	_route_idle = false
	_act = _Act.SIT_HOLD
	_sit_global = marker.global_position if marker != null else global_position
	# Put the PathFollow on the cushion. A child offset was easy to leave at rcouch,
	# which is beside the couch, so he looked like he was standing there.
	if _path_follow != null:
		_path_follow.position = _sit_global
	position = Vector3.ZERO
	global_rotation = Vector3(0.0, deg_to_rad(red_couch_sit_body_yaw_deg), 0.0)
	_apply_model_yaw_offset()
	_hold_left = sit_hold_seconds
	_force_loop(_idle_clip, Animation.LOOP_LINEAR)
	_anim.play(_idle_clip)
	print("TashWalker: snap sit red couch")
	return true


func _setup_footsteps() -> void:
	_step_player = AudioStreamPlayer3D.new()
	_step_player.name = "Footsteps"
	_step_player.max_distance = 12.0
	# Was -8 dB. 0.8 linear is 20*log10(0.8) = -1.938 dB, so -9.938 dB.
	_step_player.volume_db = -9.938
	add_child(_step_player)
	_step_streams.clear()
	for path_any in footstep_paths:
		var stream := load(String(path_any)) as AudioStream
		if stream != null:
			_step_streams.append(stream)
	if _step_streams.is_empty():
		push_warning("TashWalker: no footstep streams.")


func _step_gap() -> float:
	var clip := _locomotion_clip()
	var frames := 44.0
	if clip != "" and clip == _up_clip:
		frames = 41.0
	elif clip != "" and clip == _down_clip:
		frames = 16.0
	return (frames / 30.0) * 0.5


func _tick_steps(delta: float) -> void:
	if _step_player == null or _step_streams.is_empty():
		return
	if _act != _Act.WALK or _route.is_empty():
		if _step_player.playing:
			_step_player.stop()
		_step_left = 0.05
		return
	_step_left -= delta
	if _step_left > 0.0:
		return
	_step_player.stream = _step_streams[randi() % _step_streams.size()] as AudioStream
	_step_player.pitch_scale = randf_range(0.94, 1.06)
	_step_player.play()
	_step_left = _step_gap()

func _first_clip(names: PackedStringArray) -> String:
	if _anim == null:
		return ""
	for clip_name in names:
		var found := _resolve_clip_path(String(clip_name))
		if found != "":
			return found
	return ""


func _force_loop(clip_path: String, mode: Animation.LoopMode) -> void:
	if _anim == null or clip_path == "":
		return
	var anim := _anim.get_animation(clip_path)
	if anim != null:
		anim.loop_mode = mode


func _ensure_animation_player() -> AnimationPlayer:
	var skel := find_child("GeneralSkeleton", true, false) as Skeleton3D
	if skel == null:
		skel = find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return null
	var parent_node := skel.get_parent()
	if parent_node == null:
		return null
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	parent_node.add_child(ap)
	ap.root_node = NodePath("..")
	print("TashWalker: created AnimationPlayer under ", parent_node.get_path())
	return ap

func _try_bind_external_library() -> bool:
	var donor := TashAnimLib.find_library_animation_player(external_library_scene)
	if donor == null:
		return false
	_lib_root = donor.get_meta("_tash_lib_root") as Node
	var walks := TashAnimLib.attach_libraries(_anim, donor, TashAnimLib.LIB_NAME)
	if _lib_root != null and is_instance_valid(_lib_root):
		_lib_root.queue_free()
		_lib_root = null
	var preferred := TashAnimLib.LIB_NAME + "/" + external_walk_clip
	var alias_path := TashAnimLib.LIB_NAME + "/" + TashAnimLib.WALK_ALIAS
	if _anim.has_animation(preferred):
		_clip_path = preferred
	elif _anim.has_animation(alias_path):
		_clip_path = alias_path
	elif _anim.has_animation(TashAnimLib.LIB_NAME + "/Walk_Loop"):
		_clip_path = TashAnimLib.LIB_NAME + "/Walk_Loop"
	elif walks.size() > 0:
		_clip_path = TashAnimLib.LIB_NAME + "/" + String(walks[0])
	else:
		return false

	if external_track_rename_fallback:
		var renamed := TashAnimLib.make_renamed_walk(_anim, _clip_path, "walk_ext", TashAnimLib.LIB_NAME)
		if renamed != "":
			_clip_path = renamed
			push_warning(
				"TashWalker: using track-rename walk_ext - limbs likely wrong without BoneMap retarget."
			)

	_force_loop(_clip_path, Animation.LOOP_LINEAR)
	_using_clip = true
	print("TashWalker: playing external walk clip ", _clip_path)
	return true


func _resolve_clip_path(clip_name: String) -> String:
	if _anim == null or clip_name == "":
		return ""
	if _anim.has_animation(clip_name):
		return clip_name
	var libs: Array = _anim.get_animation_library_list()
	for lib_name_any in libs:
		var lib_name := String(lib_name_any)
		var full := lib_name + "/" + clip_name
		if _anim.has_animation(full):
			return full
		var lib := _anim.get_animation_library(lib_name)
		if lib != null and lib.has_animation(clip_name):
			return full
	return ""


func _play_named(clip_path: String) -> void:
	if not _using_clip or _anim == null or clip_path == "":
		return
	if not _anim.has_animation(clip_path):
		return
	if _anim.current_animation != clip_path or not _anim.is_playing():
		_anim.play(clip_path)


func _marker(path: NodePath, fallback_name: String) -> Node3D:
	var marked := get_node_or_null(path) as Node3D
	if marked != null:
		return marked
	var house := get_parent()
	if house != null:
		house = house.get_parent()
	if house != null:
		house = house.get_parent()
	if house == null:
		return null
	return house.get_node_or_null(fallback_name) as Node3D


func _apply_toilet_yaw() -> void:
	global_rotation = Vector3(0.0, deg_to_rad(toilet_sit_body_yaw_deg), 0.0)


func _latch_couch_path_yaw() -> void:
	# Sit body yaw is a world yaw. Zero PathFollow so sit_body_yaw_deg 0
	# faces world -Z, toward Living_TVScreen. Model yaw 180 maps that onto the face.
	# The old legacy approach (~-47 deg) plus local 90 looked off to his left.
	if _path_follow == null:
		return
	_path_follow.rotation = Vector3.ZERO


func _set_tv(want_on: bool) -> void:
	var screen := get_node_or_null(tv_screen_path)
	if screen != null and screen.has_method("set_playing"):
		screen.set_playing(want_on)


func _set_bath_lock(want_locked: bool) -> void:
	var door := _doorway_for("bath")
	if door != null and door.has_method("set_player_locked"):
		door.set_player_locked(want_locked)


func _begin_couch() -> bool:
	if _sit_clip == "" or _idle_clip == "":
		_bind_sit_clips()
	if _sit_clip == "" or _idle_clip == "" or _anim == null:
		return false
	var marker := _marker(sit_marker_path, "TashCouchSit")
	_act = _Act.SIT_DOWN
	_sit_kind = _SIT_COUCH
	_snap_sit = false
	_sit_yaw = sit_body_yaw_deg
	_stand_global = global_position
	_sit_global = marker.global_position if marker != null else _stand_global
	_latch_couch_path_yaw()
	rotation_degrees = Vector3(0.0, _sit_yaw, 0.0)
	_apply_couch_visual()
	_set_tv(true)
	_anim.play(_sit_clip)
	return true


func _begin_office_sit() -> bool:
	if _idle_clip == "":
		_bind_sit_clips()
	if _idle_clip == "" or _anim == null:
		return false
	var marker := _marker(office_sit_marker_path, "TashOfficeSit")
	_sit_kind = _SIT_OFFICE
	_snap_sit = true
	_act = _Act.SIT_HOLD
	_sit_global = marker.global_position if marker != null else global_position
	global_position = _sit_global
	_apply_office_yaw()
	_apply_office_visual()
	_hold_left = sit_hold_seconds
	_force_loop(_idle_clip, Animation.LOOP_LINEAR)
	_anim.play(_idle_clip)
	return true


func _begin_toilet_sit() -> bool:
	if _idle_clip == "":
		_bind_sit_clips()
	if _idle_clip == "" or _anim == null:
		return false
	var marker := _marker(toilet_sit_marker_path, "TashToiletSit")
	_sit_kind = _SIT_TOILET
	_snap_sit = true
	_act = _Act.SIT_HOLD
	_sit_global = marker.global_position if marker != null else global_position
	global_position = _sit_global
	_apply_toilet_yaw()
	_apply_model_yaw_offset()
	_hold_left = sit_hold_seconds
	_set_bath_lock(true)
	_force_loop(_idle_clip, Animation.LOOP_LINEAR)
	_anim.play(_idle_clip)
	return true


func _begin_look() -> bool:
	if _look_clip == "" or _anim == null:
		if not _look_warned:
			_look_warned = true
			push_warning("TashWalker: look_around missing. Shelf look skipped.")
		return false
	_act = _Act.LOOK
	_look_left = look_hold_seconds
	rotation_degrees = Vector3(0.0, look_body_yaw_deg, 0.0)
	_apply_model_yaw_offset()
	_force_loop(_look_clip, Animation.LOOP_NONE)
	_anim.play(_look_clip)
	return true


func _end_look() -> void:
	_act = _Act.WALK
	rotation = Vector3.ZERO
	_apply_model_yaw_offset()
	_choose_next()


func _begin_pause() -> void:
	_act = _Act.PAUSE
	_pause_left = wander_pause_seconds
	rotation = Vector3.ZERO
	_apply_model_yaw_offset()
	_play_named(_clip_path)


func _begin_stand() -> void:
	_set_tv(false)
	if _anim == null or _sit_clip == "":
		_finish_stand()
		return
	_act = _Act.STAND_UP
	_anim.play(_sit_clip, -1.0, -1.0, true)


func _finish_stand() -> void:
	_set_tv(false)
	_set_bath_lock(false)
	_act = _Act.WALK
	_sit_kind = _SIT_NONE
	_snap_sit = false
	_sit_is_office = false
	_office_snap = false
	if _path_follow != null and _pt.has(_here):
		_path_follow.position = _pt[_here] as Vector3
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	_apply_model_yaw_offset()
	_choose_next()


func _doorway_for(kind: String) -> Doorway:
	if kind == "bath":
		return get_node_or_null(bath_door_path) as Doorway
	return get_node_or_null(office_door_path) as Doorway


func _face_world_point(world_point: Vector3) -> void:
	if _path_follow == null:
		return
	var flat := world_point - global_position
	flat.y = 0.0
	if flat.length_squared() < 0.0001:
		return
	var local_dir: Vector3 = _path_follow.global_transform.basis.inverse() * flat.normalized()
	var yaw := atan2(-local_dir.x, -local_dir.z)
	rotation = Vector3(0.0, yaw, 0.0)
	_apply_model_yaw_offset()


func _begin_door(kind: String, going_inside: bool) -> void:
	_opened_route_i = _route_i
	_door_kind = kind
	_door_going_inside = going_inside
	var door := _doorway_for(kind)
	if door == null or not door.has_method("set_passage_open"):
		if not _door_missing_warned:
			_door_missing_warned = true
			push_warning("TashWalker: door missing (" + kind + "). Walking through.")
		return
	_act = _Act.DOOR
	_door_wait_clear = false
	_door_left = door_open_timeout
	if _door_clip == "" and _anim != null:
		_door_clip = _first_clip(open_close_door_clip_names)
	if _door_clip != "" and _anim != null:
		_force_loop(_door_clip, Animation.LOOP_NONE)
		_anim.play(_door_clip)
	elif not _door_clip_warned:
		_door_clip_warned = true
		push_warning("TashWalker: open_close_door missing. Door still opens.")
	_face_world_point(door.global_position)
	door.set_passage_open(true)


func _tick_door(delta: float) -> void:
	_door_left -= delta
	var door := _doorway_for(_door_kind)
	if door != null:
		_face_world_point(door.global_position)
	var opened := door != null and door.has_method("is_passage_open") and door.is_passage_open()
	if not opened and _door_left > 0.0:
		return
	if not opened and not _door_timeout_warned:
		_door_timeout_warned = true
		push_warning("TashWalker: door did not finish opening. Continuing.")
	_act = _Act.WALK
	_door_wait_clear = true
	rotation = Vector3.ZERO
	_apply_model_yaw_offset()
	_play_locomotion()


func _tick_door_clear() -> void:
	if not _door_wait_clear:
		return
	var clear := false
	if _door_kind == "bath":
		if _door_going_inside:
			clear = global_position.z < bath_clear_inside_z
		else:
			clear = global_position.z > bath_clear_outside_z
	elif _door_going_inside:
		clear = global_position.x > door_clear_inside_x
	else:
		clear = global_position.x < door_clear_outside_x
	if not clear:
		return
	_door_wait_clear = false
	var door := _doorway_for(_door_kind)
	if door != null and door.has_method("set_passage_open"):
		door.set_passage_open(false)


func _on_animation_finished(anim_name: StringName) -> void:
	if _act == _Act.LOOK or _act == _Act.DOOR or _act == _Act.IDLE:
		return
	var done := String(anim_name)
	if _act == _Act.SIT_DOWN and done == _sit_clip:
		global_position = _sit_global
		_latch_couch_path_yaw()
		rotation_degrees = Vector3(0.0, _sit_yaw, 0.0)
		_apply_couch_visual()
		_act = _Act.SIT_HOLD
		_hold_left = sit_hold_seconds
		if _idle_clip != "":
			_anim.play(_idle_clip)
		return
	if _act == _Act.STAND_UP and done == _sit_clip:
		_finish_stand()


func _apply_sit_blend() -> void:
	if _anim == null or _sit_clip == "":
		return
	var anim := _anim.get_animation(_sit_clip)
	if anim == null or anim.length <= 0.001:
		return
	var w := clampf(_anim.current_animation_position / anim.length, 0.0, 1.0)
	global_position = _stand_global.lerp(_sit_global, w)
	_latch_couch_path_yaw()
	rotation_degrees = Vector3(0.0, _sit_yaw, 0.0)
	_apply_couch_visual()


func _locomotion_clip() -> String:
	if _route_i < 0 or _route_i >= _route.size() - 1:
		return _clip_path
	var a: Vector3 = _pt[String(_route[_route_i])] as Vector3
	var b: Vector3 = _pt[String(_route[_route_i + 1])] as Vector3
	var dy := b.y - a.y
	if dy > 0.05:
		if _up_clip != "":
			return _up_clip
	elif dy < -0.05:
		if _down_clip != "":
			return _down_clip
	return _clip_path


func _play_locomotion() -> void:
	_play_named(_locomotion_clip())


func _physics_process(delta: float) -> void:
	_tick_steps(delta)
	if _act == _Act.IDLE:
		_look_left -= delta
		if _route_idle:
			if _look_left <= 0.0:
				_end_route_idle()
			return
		global_rotation = Vector3(0.0, deg_to_rad(_idle_yaw), 0.0)
		_apply_model_yaw_offset()
		if _look_left <= 0.0:
			_end_idle_stand()
		return
	if _act == _Act.LOOK:
		_look_left -= delta
		if _look_left <= 0.0:
			_end_look()
		return
	if _act == _Act.DOOR:
		_tick_door(delta)
		return
	if _act == _Act.PAUSE:
		_pause_left -= delta
		_play_named(_clip_path)
		if _pause_left <= 0.0:
			_act = _Act.WALK
			_choose_next()
		return
	if _act == _Act.WALK:
		_advance_route(delta)
		if _act == _Act.WALK:
			if _using_clip:
				_play_locomotion()
			_tick_door_clear()
		return
	if _act == _Act.SIT_DOWN or _act == _Act.STAND_UP:
		_apply_sit_blend()
		return
	if _act == _Act.SIT_HOLD:
		global_position = _sit_global
		if _sit_kind == _SIT_OFFICE:
			_apply_office_yaw()
			_apply_office_visual()
		elif _sit_kind == _SIT_TOILET:
			_apply_toilet_yaw()
			_apply_model_yaw_offset()
		elif _sit_kind == _SIT_RED:
			if _path_follow != null:
				_path_follow.position = _sit_global
			position = Vector3.ZERO
			global_rotation = Vector3(0.0, deg_to_rad(red_couch_sit_body_yaw_deg), 0.0)
			_apply_model_yaw_offset()
			if _anim != null and _idle_clip != "" and (_anim.current_animation != _idle_clip or not _anim.is_playing()):
				_anim.play(_idle_clip)
		else:
			_latch_couch_path_yaw()
			rotation_degrees = Vector3(0.0, _sit_yaw, 0.0)
			_apply_couch_visual()
		_hold_left -= delta
		if _hold_left <= 0.0:
			if _snap_sit:
				_finish_stand()
			else:
				_begin_stand()


func _start_patrol() -> void:
	if _patrol_started:
		return
	_patrol_started = true
	_build_nav()
	_here = "p0"
	if _path_follow != null and _pt.has("p0"):
		_path_follow.position = _pt["p0"] as Vector3
	_last_stop = ""
	_choose_next()


func _build_nav() -> void:
	# Points copied from Curve3D_tash_walk, plus measured open floor.
	# Edges are the old loop pieces. No shortcut through walls or Door_DownstairsBath.
	# Next stop is a weighted random among stops other than the one just finished.
	# Travel is the shortest path on this graph. Stairs are edges, not stops.
	_add_pt("p0", 2.2, 0.0, 4.6)
	_add_pt("p1", -0.5, 0.0, 4.5)
	_add_pt("p2", -3.6, 0.0, 4.2)
	_add_pt("p3", -3.6, 0.0, 3.2)
	_add_pt("p4", -3.6, 0.161, 2.55)
	_add_pt("p5", -3.6, 0.966, 1.45)
	_add_pt("p6", -3.6, 1.771, 0.35)
	_add_pt("p7", -3.6, 2.576, -0.75)
	_add_pt("p8", -3.6, 2.898, -1.19)
	_add_pt("p9", -3.6, 3.01, -1.7)
	_add_pt("p10", -2.4, 3.01, -2.12)
	_add_pt("p11", -1.2, 3.01, -2.12)
	_add_pt("p12", -1.2, 3.01, 0.2)
	_add_pt("p13", -1.2, 3.01, 3.88)
	_add_pt("p14", 1.85, 3.01, 3.88)
	_add_pt("p15", 3.2, 3.01, 3.88)
	_add_pt("p16", 3.2, 3.01, 4.38)
	_add_pt("p17", 6.05, 3.01, 4.38)
	_add_pt("p18", 6.05, 3.01, 3.55)
	_add_pt("p20", 5.15, 3.01, 4.38)
	_add_pt("p21", 5.15, 3.01, 4.05)
	_add_pt("p34", -2.0, 0.0, 2.4)
	# West of Living couch collision (X min -1.2), then in front (Z front 1.208).
	# 0.4 m clearance. Old p34->p35 cut the west side.
	_add_pt("cside", -1.6, 0.0, 0.8)
	_add_pt("p35", -0.2, 0.0, 0.8)
	_add_pt("p36", -0.2, 0.0, 0.3)
	_add_pt("p37", 1.876662, 0.0, 0.9638408)
	_add_pt("p38", 0.6, 0.0, 4.6)
	_add_pt("kdoor", 2.6, 0.0, -0.4)
	_add_pt("kit", 5.0, 0.0, -1.2)
	_add_pt("bout", -3.62, 3.01, -2.02)
	_add_pt("bin", -3.62, 3.01, -2.95)
	_add_pt("bmid", -4.20, 3.01, -3.70)
	_add_pt("bapp", -4.474046, 3.01, -4.335)
	# F1 bookcase faces +X. Stand on the living side, clear of the stair volume.
	_add_pt("f1a", -2.15, 0.0, -0.5)
	_add_pt("f1b", -2.15, 0.0, -2.6)
	_add_pt("f1stand", -3.68, 0.0, -2.6)
	# F2 bookcase is east of f2stand, front toward +X. Idle yaw -90 looks at it.
	# rcouch is the sit approach, not a stand. The snap uses TashRedCouchSit.
	_add_pt("f2a", -1.2, 3.01, -1.05)
	_add_pt("f2b", -2.75, 3.01, -1.05)
	_add_pt("f2stand", -2.75, 3.01, 0.15)
	# In front of the red couch right corner. Snap sits onto the marker.
	_add_pt("rcouch", -2.55, 3.01, 1.27)
	_link("p0", "p1")
	_link("p1", "p2")
	_link("p2", "p3")
	_link("p3", "p4")
	_link("p4", "p5")
	_link("p5", "p6")
	_link("p6", "p7")
	_link("p7", "p8")
	_link("p8", "p9")
	_link("p9", "p10")
	_link("p10", "p11")
	_link("p11", "p12")
	_link("p12", "p13")
	_link("p13", "p14")
	_link("p14", "p15")
	_link("p15", "p16")
	_link("p16", "p17")
	_link("p17", "p18")
	_link("p17", "p20")
	_link("p20", "p21")
	_link("p3", "p34")
	_link("p34", "cside")
	_link("cside", "p35")
	_link("p35", "p36")
	_link("p36", "p37")
	_link("p37", "p38")
	_link("p38", "p0")
	_link("p37", "kdoor")
	_link("kdoor", "kit")
	_link("p10", "bout")
	_link("bout", "bin")
	_link("bin", "bmid")
	_link("bmid", "bapp")
	_link("p34", "f1a")
	_link("f1a", "f1b")
	_link("f1b", "f1stand")
	_link("p12", "f2a")
	_link("f2a", "f2b")
	_link("f2b", "f2stand")
	_link("f2stand", "rcouch")
	_stop_node = {
		"idle_f1": "f1stand",
		"idle_f2": "f2stand",
		"shelf": "p18",
		"office": "p21",
		"couch": "p35",
		"redcouch": "rcouch",
		"toilet": "bapp",
		"wander_living": "p0",
		"wander_kitchen": "kit",
		"wander_hall": "p12",
	}
	# Bookshelf idles are the usual stop. Sits are next. Wander is light.
	# The stop just finished is never picked again.
	_stop_weight = {
		"idle_f1": 6,
		"idle_f2": 6,
		"shelf": 6,
		"office": 3,
		"couch": 3,
		"redcouch": 3,
		"toilet": 3,
		"wander_living": 1,
		"wander_kitchen": 1,
		"wander_hall": 1,
	}


func _add_pt(id: String, x: float, y: float, z: float) -> void:
	_pt[id] = Vector3(x, y, z)


func _link(a: String, b: String) -> void:
	if not _nb.has(a):
		_nb[a] = []
	if not _nb.has(b):
		_nb[b] = []
	var left: Array = _nb[a]
	var right: Array = _nb[b]
	left.append(b)
	right.append(a)


func _weight_of(id: String) -> int:
	if id == "office" and not office_sit_enabled:
		return 0
	if id == "couch" and not couch_sit_enabled:
		return 0
	if id == "toilet" and not toilet_sit_enabled:
		return 0
	if id == "redcouch" and not red_couch_sit_enabled:
		return 0
	if not _stop_weight.has(id):
		return 0
	return int(_stop_weight[id])


func _pick_stop(banned: Array) -> String:
	var total := 0
	for id_any in _stop_weight.keys():
		var id := String(id_any)
		if banned.has(id):
			continue
		total += _weight_of(id)
	if total <= 0:
		return ""
	var roll := randi_range(1, total)
	var acc := 0
	for id_any in _stop_weight.keys():
		var id := String(id_any)
		if banned.has(id):
			continue
		acc += _weight_of(id)
		if roll <= acc:
			return id
	return ""


func _shortest(start: String, goal: String) -> Array:
	if start == goal:
		return [start]
	if not _nb.has(start):
		return []
	var q: Array = [start]
	var prev := {}
	var seen := {start: true}
	while q.size() > 0:
		var cur := String(q.pop_front())
		var nbs: Array = _nb[cur]
		for nb_any in nbs:
			var nb := String(nb_any)
			if seen.has(nb):
				continue
			seen[nb] = true
			prev[nb] = cur
			if nb == goal:
				var out: Array = [goal]
				var walk := goal
				while walk != start:
					walk = String(prev[walk])
					out.push_front(walk)
				return out
			q.append(nb)
	return []


func _is_stair_id(id: String) -> bool:
	if not _pt.has(id):
		return false
	var spot: Vector3 = _pt[id] as Vector3
	return spot.y > 0.08 and spot.y < 2.95


func _is_door_id(id: String) -> bool:
	return id == "p14" or id == "p15" or id == "bout" or id == "bin"


func _heading_delta(a: Vector3, b: Vector3, c: Vector3) -> float:
	var d1 := b - a
	var d2 := c - b
	d1.y = 0.0
	d2.y = 0.0
	if d1.length_squared() < 0.0001 or d2.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(d1.angle_to(d2))


func _drop_chamfers() -> void:
	var dead: Array = []
	for key_any in _pt.keys():
		var key := String(key_any)
		if key.begins_with("cf"):
			dead.append(key)
	for key_any in dead:
		_pt.erase(String(key_any))


func _chamfer_route(ids: Array) -> Array:
	# Cut about 0.55 m across each sharp corner so he does not snap 90 degrees.
	# Door edges stay intact. Stair-slope points stay on the flight.
	_drop_chamfers()
	_turn_ids = {}
	if ids.size() < 3:
		return ids
	var out: Array = [String(ids[0])]
	var last_i := ids.size() - 1
	for i in range(1, last_i):
		var a_id := String(ids[i - 1])
		var b_id := String(ids[i])
		var c_id := String(ids[i + 1])
		var a: Vector3 = _pt[a_id] as Vector3
		var b: Vector3 = _pt[b_id] as Vector3
		var c: Vector3 = _pt[c_id] as Vector3
		var turn := _heading_delta(a, b, c)
		if turn <= 50.0:
			out.append(b_id)
			continue
		# A hairpin is a graph backtrack, not a 90 degree corner. Do not fold it.
		if turn > 150.0:
			out.append(b_id)
			_turn_ids[b_id] = true
			continue
		var blocked := _is_door_id(b_id) or _is_stair_id(b_id)
		blocked = blocked or _cross_door(a_id, b_id) != "" or _cross_door(b_id, c_id) != ""
		var mark_id := b_id
		if not blocked:
			var len_in := Vector2(a.x - b.x, a.z - b.z).length()
			var len_out := Vector2(c.x - b.x, c.z - b.z).length()
			var inset := 0.55
			inset = minf(inset, len_in * 0.4)
			inset = minf(inset, len_out * 0.4)
			if inset >= 0.35 and len_in > 0.001 and len_out > 0.001:
				var p_pos := b.lerp(a, inset / len_in)
				var q_pos := b.lerp(c, inset / len_out)
				_cf_n += 1
				var pid := "cf" + str(_cf_n) + "a"
				_cf_n += 1
				var qid := "cf" + str(_cf_n) + "b"
				_pt[pid] = p_pos
				_pt[qid] = q_pos
				out.append(pid)
				out.append(qid)
				mark_id = pid
			else:
				out.append(b_id)
		else:
			out.append(b_id)
		_turn_ids[mark_id] = true
	out.append(String(ids[last_i]))
	return out


func _begin_route_idle() -> void:
	_act = _Act.IDLE
	_route_idle = true
	_look_left = randf_range(3.0, 4.0)
	rotation = Vector3.ZERO
	_apply_model_yaw_offset()
	if _anim != null and _idle_stand_clips.size() > 0:
		var pick := String(_idle_stand_clips[randi() % _idle_stand_clips.size()])
		_anim.play(pick)
		return
	if _anim != null and _anim.is_playing():
		_anim.pause()


func _end_route_idle() -> void:
	_route_idle = false
	_act = _Act.WALK
	rotation = Vector3.ZERO
	_apply_model_yaw_offset()
	_play_locomotion()


func _maybe_turn_idle(point_id: String) -> bool:
	if _turn_ids.has(point_id):
		_turn_count += 1
	var owed := _turn_count >= 2 or _idle_when_flat
	if not owed:
		return false
	# A turn on the stairs waits until the landing. Never pause on a door edge.
	if _is_stair_id(point_id):
		_idle_when_flat = true
		return false
	if _is_door_id(point_id):
		_idle_when_flat = true
		return false
	if _route_i < _route.size() - 1:
		var nxt := String(_route[_route_i + 1])
		if _cross_door(point_id, nxt) != "":
			_idle_when_flat = true
			return false
	_turn_count = 0
	_idle_when_flat = false
	_begin_route_idle()
	return true


func _toilet_quota_due() -> bool:
	if not toilet_sit_enabled:
		return false
	if _toilet_owed:
		return true
	if _recent_picks.size() < 2:
		return false
	for prev_any in _recent_picks:
		if String(prev_any) == "toilet":
			return false
	return true


func _note_pick(id: String) -> void:
	_recent_picks.append(id)
	while _recent_picks.size() > 2:
		_recent_picks.pop_front()
	if id == "toilet":
		_toilet_owed = false


func _start_route(route: Array) -> void:
	_turn_count = 0
	_idle_when_flat = false
	_route_idle = false
	if route.size() <= 1:
		_begin_current_stop()
		return
	_route = _chamfer_route(route)
	_route_i = 0
	_seg_dist = 0.0
	_opened_route_i = -1
	_act = _Act.WALK


func _choose_next() -> void:
	if _pick_depth > 6:
		_act = _Act.WALK
		return
	_pick_depth += 1
	var banned: Array = []
	if _last_stop != "":
		banned.append(_last_stop)
	var due := _toilet_quota_due()
	if due and (_last_stop == "toilet" or banned.has("toilet")):
		# He just finished the toilet, so this pick is not legal. Force the next one.
		_toilet_owed = true
		due = false
	var picked := false
	if due:
		var goal_t := String(_stop_node["toilet"])
		var route_t := _shortest(_here, goal_t)
		if route_t.is_empty():
			_toilet_owed = true
		else:
			_active_stop = "toilet"
			_note_pick("toilet")
			picked = true
			print("TashWalker: next stop toilet")
			_start_route(route_t)
	if not picked:
		for _attempt in 8:
			var id := _pick_stop(banned)
			if id == "":
				break
			var goal := String(_stop_node[id])
			var route := _shortest(_here, goal)
			if route.is_empty():
				banned.append(id)
				continue
			_active_stop = id
			_note_pick(id)
			picked = true
			print("TashWalker: next stop ", id)
			_start_route(route)
			break
	if not picked:
		_act = _Act.WALK
	_pick_depth -= 1


func _begin_current_stop() -> void:
	_last_stop = _active_stop
	_route = []
	_route_i = 0
	var started := true
	if _active_stop == "shelf":
		_begin_idle_stand(office_idle_body_yaw_deg)
		return
	elif _active_stop == "idle_f1":
		_begin_idle_stand(f1_idle_body_yaw_deg)
		return
	elif _active_stop == "idle_f2":
		_begin_idle_stand(f2_idle_body_yaw_deg)
		return
	elif _active_stop == "office":
		started = _begin_office_sit()
	elif _active_stop == "couch":
		started = _begin_couch()
	elif _active_stop == "redcouch":
		# Approach point rcouch is not an idle. Snap sitting_idle for the full hold.
		started = _begin_red_couch()
	elif _active_stop == "toilet":
		started = _begin_toilet_sit()
	else:
		_begin_pause()
		return
	if not started:
		_choose_next()


func _cross_door(a_id: String, b_id: String) -> String:
	if (a_id == "p14" and b_id == "p15") or (a_id == "p15" and b_id == "p14"):
		return "office"
	if (a_id == "bout" and b_id == "bin") or (a_id == "bin" and b_id == "bout"):
		return "bath"
	return ""


func _place(pos: Vector3, dir: Vector3) -> void:
	if _path_follow == null:
		return
	_path_follow.position = pos
	var flat := dir
	flat.y = 0.0
	if flat.length_squared() > 0.0001:
		_path_follow.rotation = Vector3(0.0, atan2(-flat.x, -flat.z), 0.0)
	_apply_model_yaw_offset()


func _advance_route(delta: float) -> void:
	if _route.is_empty() or _route_i >= _route.size() - 1:
		return
	var a_id := String(_route[_route_i])
	var b_id := String(_route[_route_i + 1])
	var a: Vector3 = _pt[a_id] as Vector3
	var b: Vector3 = _pt[b_id] as Vector3
	var door_name := _cross_door(a_id, b_id)
	if door_name != "" and _opened_route_i != _route_i:
		var going_in := false
		if door_name == "office":
			going_in = b.x > a.x
		else:
			going_in = b.z < a.z
		_begin_door(door_name, going_in)
		return
	var seg_len := a.distance_to(b)
	if seg_len < 0.001:
		_seg_dist = 0.0
		_route_i += 1
		_here = b_id
		if _route_i >= _route.size() - 1:
			_begin_current_stop()
		return
	_seg_dist += walk_speed * delta
	if _seg_dist >= seg_len:
		_seg_dist = 0.0
		_route_i += 1
		_here = b_id
		_place(b, b - a)
		if _route_i >= _route.size() - 1:
			_begin_current_stop()
			return
		if _maybe_turn_idle(b_id):
			return
		return
	_place(a.lerp(b, _seg_dist / seg_len), b - a)
