# Godot 4.x - Sabira / HOUSE
# Milestone 2: Tash simple walk loop (no reactions / catch / VO).
class_name TashWalker
extends CharacterBody3D
## Advances parent PathFollow3D at walk_speed.
## Default: Quaternius UAL Walk via BoneMap retarget (props/Tash.glb is idle-only).

@export var walk_speed: float = 0.75
@export var walk_clip_names: PackedStringArray = PackedStringArray(["walk", "Walk", "Walk_Loop"])
@export var path_follow_path: NodePath = NodePath("..")
## Local Y yaw (degrees) applied to Model/mesh so chest faces path tangent.
@export var model_yaw_offset_deg: float = 180.0
@export var model_node_path: NodePath = NodePath("Model")

## --- External AnimationLibrary (Quaternius UAL; ON - GLB has no walk) ---
@export var use_external_walk_library: bool = false
@export_file("*.glb") var external_library_scene: String = "res://art/anim/AnimationLibrary_Godot_Standard.glb"
@export var external_walk_clip: String = "Walk"
## Debug only: DEF-* -> mixamorig_* rename without BoneMap (expect twist).
@export var external_track_rename_fallback: bool = false

var _path_follow: PathFollow3D = null
var _anim: AnimationPlayer = null
var _model: Node3D = null
var _clip_path: String = ""
var _using_clip: bool = false
var _lib_root: Node = null


func _ready() -> void:
	add_to_group("tash")
	collision_layer = 1
	collision_mask = 1
	_path_follow = get_node_or_null(path_follow_path) as PathFollow3D
	if _path_follow == null:
		_path_follow = get_parent() as PathFollow3D
	if _path_follow != null:
		_path_follow.loop = true
		_path_follow.rotation_mode = PathFollow3D.ROTATION_Y
	_apply_model_yaw_offset()
	call_deferred("_try_bind_walk_clip")


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
	_model.rotation_degrees.y = model_yaw_offset_deg


func _try_bind_walk_clip() -> void:
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		_anim = _ensure_animation_player()
	if _anim == null:
		_using_clip = false
		push_warning("TashWalker: no AnimationPlayer under Tash Model.")
		return

	# External Quaternius library first (default ON - idle GLB has no walk).
	if use_external_walk_library:
		if _try_bind_external_library():
			_play_walk()
			return
		push_warning("TashWalker: external library bind failed - falling back to GLB clip.")

	# Fallback: any baked GLB clip named walk / Walk (usually absent after idle strip).
	for clip_name in walk_clip_names:
		_clip_path = _resolve_clip_path(String(clip_name))
		if _clip_path != "":
			break
	if _clip_path == "":
		_using_clip = false
		push_warning("TashWalker: no walk clip found (external + GLB).")
		return
	_using_clip = true
	var anim := _anim.get_animation(_clip_path)
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR
	_play_walk()



func _ensure_animation_player() -> AnimationPlayer:
	# Idle Tash.glb has Skeleton3D but no AnimationPlayer - create one beside GeneralSkeleton.
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
	# Tracks use %GeneralSkeleton unique-name paths from BoneMap rename.
	ap.root_node = NodePath("..")
	print("TashWalker: created AnimationPlayer under ", parent_node.get_path())
	return ap

func _try_bind_external_library() -> bool:
	var donor := TashAnimLib.find_library_animation_player(external_library_scene)
	if donor == null:
		return false
	_lib_root = donor.get_meta("_tash_lib_root") as Node
	# Do not parent donor into the tree (its %GeneralSkeleton would clash with Tash).
	var walks := TashAnimLib.attach_libraries(_anim, donor, TashAnimLib.LIB_NAME)
	# Animations are duplicated; free donor so %GeneralSkeleton unique-name is only on Tash.
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

	var anim := _anim.get_animation(_clip_path)
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR
	_using_clip = true
	print("TashWalker: playing external walk clip ", _clip_path)
	return true


func _resolve_clip_path(clip_name: String) -> String:
	if _anim == null:
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


func _play_walk() -> void:
	if not _using_clip or _anim == null or _clip_path == "":
		return
	if not _anim.has_animation(_clip_path):
		return
	if _anim.current_animation != _clip_path or not _anim.is_playing():
		_anim.play(_clip_path)


func _physics_process(delta: float) -> void:
	if _path_follow != null:
		_path_follow.progress += walk_speed * delta
	if _using_clip:
		_play_walk()
