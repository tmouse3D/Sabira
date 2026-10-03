# Godot 4.x - Sabira / HOUSE
# Quaternius AnimationLibrary wiring for Tash (BoneMap / SkeletonProfileHumanoid path).
# GLB walk is idle-only; enable use_external_walk_library on TashWalker.
class_name TashAnimLib
extends RefCounted

## Library scene path (copied under res://art/anim/).
const DEFAULT_LIBRARY_SCENE := "res://art/anim/AnimationLibrary_Godot_Standard.glb"
## Preferred walk clip inside Quaternius UAL Standard (Godot strips _Loop on import).
const DEFAULT_WALK_CLIP := "Walk"
const LIB_NAME := "quaternius_ual"
## Alias clip name expected by walk_clip_names / older callers.
const WALK_ALIAS := "walk"

## SkeletonProfileHumanoid bone -> Character_02 Mixamo bone on Tash.glb AFTER Godot import.
## glTF naming_version=2 converts mixamorig:Name -> mixamorig_Name.
const MIXAMO_TO_HUMANOID := {
	"Hips": "mixamorig_Hips",
	"Spine": "mixamorig_Spine",
	"Chest": "mixamorig_Spine1",
	"UpperChest": "mixamorig_Spine2",
	"Neck": "mixamorig_Neck",
	"Head": "mixamorig_Head",
	"LeftShoulder": "mixamorig_LeftShoulder",
	"LeftUpperArm": "mixamorig_LeftArm",
	"LeftLowerArm": "mixamorig_LeftForeArm",
	"LeftHand": "mixamorig_LeftHand",
	"RightShoulder": "mixamorig_RightShoulder",
	"RightUpperArm": "mixamorig_RightArm",
	"RightLowerArm": "mixamorig_RightForeArm",
	"RightHand": "mixamorig_RightHand",
	"LeftUpperLeg": "mixamorig_LeftUpLeg",
	"LeftLowerLeg": "mixamorig_LeftLeg",
	"LeftFoot": "mixamorig_LeftFoot",
	"LeftToes": "mixamorig_LeftToeBase",
	"RightUpperLeg": "mixamorig_RightUpLeg",
	"RightLowerLeg": "mixamorig_RightLeg",
	"RightFoot": "mixamorig_RightFoot",
	"RightToes": "mixamorig_RightToeBase",
}

## SkeletonProfileHumanoid bone -> Quaternius Rigify DEF-* joints in UAL GLB.
const QUATERNIUS_TO_HUMANOID := {
	"Hips": "DEF-hips",
	"Spine": "DEF-spine.001",
	"Chest": "DEF-spine.002",
	"UpperChest": "DEF-spine.003",
	"Neck": "DEF-neck",
	"Head": "DEF-head",
	"LeftShoulder": "DEF-shoulder.L",
	"LeftUpperArm": "DEF-upper_arm.L",
	"LeftLowerArm": "DEF-forearm.L",
	"LeftHand": "DEF-hand.L",
	"RightShoulder": "DEF-shoulder.R",
	"RightUpperArm": "DEF-upper_arm.R",
	"RightLowerArm": "DEF-forearm.R",
	"RightHand": "DEF-hand.R",
	"LeftUpperLeg": "DEF-thigh.L",
	"LeftLowerLeg": "DEF-shin.L",
	"LeftFoot": "DEF-foot.L",
	"LeftToes": "DEF-toe.L",
	"RightUpperLeg": "DEF-thigh.R",
	"RightLowerLeg": "DEF-shin.R",
	"RightFoot": "DEF-foot.R",
	"RightToes": "DEF-toe.R",
}

## Direct Quaternius DEF-* -> Mixamo (crude track rename ONLY; BoneMap retarget preferred).
const QUATERNIUS_TO_MIXAMO := {
	"DEF-hips": "mixamorig_Hips",
	"DEF-spine.001": "mixamorig_Spine",
	"DEF-spine.002": "mixamorig_Spine1",
	"DEF-spine.003": "mixamorig_Spine2",
	"DEF-neck": "mixamorig_Neck",
	"DEF-head": "mixamorig_Head",
	"DEF-shoulder.L": "mixamorig_LeftShoulder",
	"DEF-upper_arm.L": "mixamorig_LeftArm",
	"DEF-forearm.L": "mixamorig_LeftForeArm",
	"DEF-hand.L": "mixamorig_LeftHand",
	"DEF-shoulder.R": "mixamorig_RightShoulder",
	"DEF-upper_arm.R": "mixamorig_RightArm",
	"DEF-forearm.R": "mixamorig_RightForeArm",
	"DEF-hand.R": "mixamorig_RightHand",
	"DEF-thigh.L": "mixamorig_LeftUpLeg",
	"DEF-shin.L": "mixamorig_LeftLeg",
	"DEF-foot.L": "mixamorig_LeftFoot",
	"DEF-toe.L": "mixamorig_LeftToeBase",
	"DEF-thigh.R": "mixamorig_RightUpLeg",
	"DEF-shin.R": "mixamorig_RightLeg",
	"DEF-foot.R": "mixamorig_RightFoot",
	"DEF-toe.R": "mixamorig_RightToeBase",
}


static func build_mixamo_bonemap() -> BoneMap:
	var bm := BoneMap.new()
	bm.profile = SkeletonProfileHumanoid.new()
	for humanoid_name in MIXAMO_TO_HUMANOID.keys():
		bm.set_skeleton_bone_name(StringName(humanoid_name), StringName(MIXAMO_TO_HUMANOID[humanoid_name]))
	return bm


static func build_quaternius_bonemap() -> BoneMap:
	var bm := BoneMap.new()
	bm.profile = SkeletonProfileHumanoid.new()
	for humanoid_name in QUATERNIUS_TO_HUMANOID.keys():
		bm.set_skeleton_bone_name(StringName(humanoid_name), StringName(QUATERNIUS_TO_HUMANOID[humanoid_name]))
	return bm


## Instantiates the Quaternius GLB PackedScene and returns its AnimationPlayer (or null).
static func find_library_animation_player(library_scene_path: String) -> AnimationPlayer:
	if library_scene_path == "" or not ResourceLoader.exists(library_scene_path):
		push_warning("TashAnimLib: library scene missing: %s" % library_scene_path)
		return null
	var packed := load(library_scene_path) as PackedScene
	if packed == null:
		push_warning("TashAnimLib: failed to load PackedScene: %s" % library_scene_path)
		return null
	var root := packed.instantiate()
	if root == null:
		return null
	var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		root.queue_free()
		push_warning("TashAnimLib: no AnimationPlayer in %s" % library_scene_path)
		return null
	# Keep root alive; caller must reparent or free via meta.
	ap.set_meta("_tash_lib_root", root)
	return ap


## Copies animation libraries from donor AnimationPlayer onto target.
## Returns list of clip names found that look like walks.
static func attach_libraries(target: AnimationPlayer, donor: AnimationPlayer, lib_name: String = LIB_NAME) -> PackedStringArray:
	var walks := PackedStringArray()
	if target == null or donor == null:
		return walks
	if target.has_animation_library(lib_name):
		target.remove_animation_library(lib_name)
	var merged := AnimationLibrary.new()
	for donor_lib_name_any in donor.get_animation_library_list():
		var donor_lib_name := String(donor_lib_name_any)
		var donor_lib := donor.get_animation_library(donor_lib_name)
		if donor_lib == null:
			continue
		for anim_name_any in donor_lib.get_animation_list():
			var anim_name := String(anim_name_any)
			var anim := donor_lib.get_animation(anim_name)
			if anim == null:
				continue
			var key := anim_name
			if merged.has_animation(key):
				key = donor_lib_name + "_" + anim_name
			var dup := anim.duplicate(true) as Animation
			# Retargeted imports rename Skeleton3D -> GeneralSkeleton; remap track roots
			# so clips bind to Tash Model skeleton node path.
			_remap_general_skeleton_tracks(dup)
			merged.add_animation(key, dup)
			var lower := anim_name.to_lower()
			if "walk" in lower or "jog" in lower or "sprint" in lower:
				walks.append(key)
	# Alias primary walk as "walk" for TashWalker walk_clip_names.
	_ensure_walk_alias(merged, walks)
	target.add_animation_library(lib_name, merged)
	return walks


static func _remap_general_skeleton_tracks(anim: Animation) -> void:
	if anim == null:
		return
	for i in range(anim.get_track_count()):
		var path := String(anim.track_get_path(i))
		# Prefer unique-name paths (%GeneralSkeleton) so AP can live anywhere under Tash.
		if path.begins_with("%GeneralSkeleton:"):
			continue
		if path.begins_with("Rig/GeneralSkeleton:"):
			anim.track_set_path(i, NodePath(path.replace("Rig/GeneralSkeleton:", "%GeneralSkeleton:")))
		elif path.begins_with("GeneralSkeleton:"):
			anim.track_set_path(i, NodePath(path.replace("GeneralSkeleton:", "%GeneralSkeleton:")))
		elif path.begins_with("Rig/Skeleton3D:"):
			anim.track_set_path(i, NodePath(path.replace("Rig/Skeleton3D:", "%GeneralSkeleton:")))
		elif path.begins_with("Skeleton3D:"):
			anim.track_set_path(i, NodePath(path.replace("Skeleton3D:", "%GeneralSkeleton:")))


static func _ensure_walk_alias(lib: AnimationLibrary, walks: PackedStringArray) -> void:
	if lib == null:
		return
	var source := ""
	if lib.has_animation(DEFAULT_WALK_CLIP):
		source = DEFAULT_WALK_CLIP
	elif lib.has_animation("Walk_Loop"):
		source = "Walk_Loop"
	elif walks.size() > 0:
		source = String(walks[0])
	if source == "" or not lib.has_animation(source):
		return
	if lib.has_animation(WALK_ALIAS):
		return
	var src_anim := lib.get_animation(source)
	if src_anim == null:
		return
	var alias := src_anim.duplicate(true) as Animation
	alias.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation(WALK_ALIAS, alias)


## Best-effort: duplicate Walk with DEF-* tracks renamed to mixamorig_*.
## Prefer import BoneMap retarget; this is debug-only if retarget missing.
static func make_renamed_walk(
	target: AnimationPlayer,
	source_full_path: String,
	out_clip_name: String = "walk_ext",
	lib_name: String = LIB_NAME
) -> String:
	if target == null or not target.has_animation(source_full_path):
		return ""
	var src := target.get_animation(source_full_path)
	if src == null:
		return ""
	var dup := src.duplicate(true) as Animation
	for i in range(dup.get_track_count()):
		var path := String(dup.track_get_path(i))
		var new_path := path
		for def_name in QUATERNIUS_TO_MIXAMO.keys():
			if def_name in path:
				new_path = path.replace(def_name, QUATERNIUS_TO_MIXAMO[def_name])
				break
		if "GeneralSkeleton:" in new_path:
			pass
		elif "Skeleton3D:" in new_path:
			new_path = new_path.replace("Skeleton3D:", "GeneralSkeleton:")
		if new_path != path:
			dup.track_set_path(i, NodePath(new_path))
	dup.loop_mode = Animation.LOOP_LINEAR
	var lib := target.get_animation_library(lib_name)
	if lib == null:
		lib = AnimationLibrary.new()
		target.add_animation_library(lib_name, lib)
	if lib.has_animation(out_clip_name):
		lib.remove_animation(out_clip_name)
	lib.add_animation(out_clip_name, dup)
	return lib_name + "/" + out_clip_name


static func bone_mismatch_report() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Tash (Character_02 Mixamo): mixamorig_* after import - BoneMap_Mixamo_Tash.tres")
	lines.append("Quaternius UAL: Rigify DEF-* - BoneMap_Quaternius_UAL.tres")
	lines.append("Both imports rename to SkeletonProfileHumanoid + overwrite_axis for shared Walk.")
	lines.append("Clip: Walk (Godot drop _Loop) aliased as walk for TashWalker.")
	return "\n".join(lines)

