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

@export_group("Ð”Ð¸Ð²Ð°Ð½")
@export var couch_sit_enabled: bool = true
## Index into TashWalkPath. 35 is the living-room stop in front of the couch.
@export var couch_point_index: int = 35
@export var couch_arrive_distance: float = 0.45
@export var sit_hold_seconds: float = 24.0
## F1 living-room couch TV sit only. Office / toilet / red couch keep sit_hold_seconds.
@export var couch_sit_hold_seconds: float = 72.0
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
@export var sitting_drinking_clip_names: PackedStringArray = PackedStringArray(["sitting_drinking", "Sitting_Drinking", "Sitting Drinking"])
@export var sitting_drunk_clip_names: PackedStringArray = PackedStringArray(["sitting_drunk", "Sitting_Drunk", "Sitting Drunk", "Sitting drunk"])
@export var couch_bottle_path: NodePath = NodePath("../../../Structure/Living/Living_Bottle")
@export var couch_glass_path: NodePath = NodePath("../../../Structure/Living/Living_CouchGlass")

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
## F2 case sits on Wall_Sabira_W_N; its front points world +X. Stand east of it and yaw 90 looks -X at the books.
@export var f2_idle_body_yaw_deg: float = 90.0
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
## visible face is body yaw + 180, so yaw -90 looks world +X.
## Landing_Couch (Couch_DarkRed) maps mesh +Z onto world +X. Backrest is mesh -Z,
## so yaw -90 faces into the room (away from the wall). Yaw 90 faced the wall.
@export var red_couch_sit_body_yaw_deg: float = -90.0
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
## Recent destination picks. Force toilet only when none of the last N was toilet.
const _TOILET_QUOTA_WINDOW := 8
var _recent_picks: Array = []
var _toilet_owed: bool = false
## F1 living-couch TV sits this run. Counted when the sit starts. 2, 4, 6 drink.
var _couch_tv_sits: int = 0
var _couch_drink_this: bool = false
const _DRINK_OFF := 0
const _DRINK_CLIP := 1
const _DRUNK_LOCK := 2
var _couch_drink_phase: int = _DRINK_OFF
var _drink_clip: String = ""
var _drunk_clip: String = ""
var _drink_missing_warned: bool = false
var _drunk_missing_warned: bool = false
var _hand_missing_warned: bool = false
var _bottle_node: Node3D = null
var _glass_node: Node3D = null
var _bottle_home: Node = null
var _glass_home: Node = null
var _bottle_home_xf: Transform3D = Transform3D.IDENTITY
var _glass_home_xf: Transform3D = Transform3D.IDENTITY
var _props_held: bool = false
var _hand_attach: Array = []
var _door_was_open: Dictionary = {}
const _DRUNK_FREEZE_SEC := 2.3
var _drunk_frozen: bool = false
var _drunk_look: Node = null
var _tash_dead: bool = false
var _dying_clip: String = ""
var _dying_left: int = 0
var _dying_frozen: bool = false
var _dying_hooked: bool = false
var _stab_layer: CanvasLayer = null
var _stab_rect: ColorRect = null
const _STAB_HOLD_SEC := 3.0
const _STAB_FADE_SEC := 0.7
const _STAB_CARD := "Some monsters cannot be tamed. Some injuries cannot be healed. All we have left is just a moment."
const _STAB_TEXT_IN_SEC := 0.8
const _DYING_LOOPS := 2
const _DYING_MODEL_DROP := -0.44
const _DYING_FORWARD_Z := -1.2
var _dying_loop_index: int = 0
var _blood_puddle: MeshInstance3D = null
var _puddle_age: float = 0.0
var _puddle_locked: bool = false
const _PUDDLE_GROW_SEC := 10.0
const _PUDDLE_MIN_R := 0.05
const _PUDDLE_MAX_R := 0.46
const _STAB_LINES: PackedStringArray = [
	"Some monsters cannot be tamed.",
	"Some injuries cannot be healed.",
	"All we have left is just a moment.",
]
const _STAB_LINE_IN := 0.6
const _STAB_LINE_HOLD := 3.0
const _STAB_LINE_OUT := 0.55
# --- Noise investigation (GameState.noise_reported -> hear_noise). No detection / catch. ---
const _HEAR_RANGE_M := 12.0
const _HEAR_OTHER_FLOOR_DY := 1.5
const _HEAR_OTHER_FLOOR_MUL := 0.5
const _INV_LOOK_MIN := 6.0
const _INV_LOOK_MAX := 8.0
const _INV_LINE := "Who's there?"
var _inv_pending: bool = false
var _investigating: bool = false
var _inv_look: bool = false
var _inv_target_world: Vector3 = Vector3.ZERO
# --- Vision + chase (no catch consequences). See the VISION / CHASE section at the end. ---
const RUN_SPEED := 2.8
const RUN_ANIM_FALLBACK_SCALE := 2.0
const VIS_FOV_DEG := 80.0
const VIS_RANGE_M := 11.0
const VIS_CROUCH_MUL := 0.7
const VIS_INTERVAL := 0.1
const CHASE_LOSE_SEC := 1.5
const CHASE_REPATH_SEC := 0.5
const BREATHER_MIN := 12.0
const BREATHER_MAX := 20.0
const YELL_SEC := 2.0
const REACH_M := 1.2
const GRAB_FALLBACK_SEC := 1.2
const GRAB_COOLDOWN_SEC := 3.0
const FAIL_DIST_M := 1.0
const FAIL_FALLBACK_SEC := 2.5
const TURN_CLIP_DEG := 100.0
const _CHASE_YELL_LINES := [
	"Sabira! Get back to your room, now!",
	"Who said you could walk around? Who gave you permission?",
	"You do what I say in this house!",
	"Come here! You'll be punished for this!",
	"Back to your room, or I'll make you regret it!",
	"Don't you dare run from me!",
]
var _last_yell_i: int = -1
# First sight (once per run): one set picked at random, chunks shown in sequence during an
# extended start yell (chase stays on, vision keeps tracking).
const FIRST_SIGHT_LINES := [
	["Done with dinner? Then go to your room and pray.", "Pray for a patient husband one day. Pray you learn to obey.", "Pride is a sin. You don't get to do as you like."],
	["If you're finished eating, you go to your room. Now.", "Get on your knees. Pray for a husband patient enough to keep you.", "And pray you stop disobeying. A proud girl is a sinful girl."],
]
const FIRST_SIGHT_CHUNK_SEC := 2.7
const FIRST_SIGHT_MAX_SEC := 8.0
# Fail catch caption by safe zone (GameState.is_safe_zone()).
const FAIL_CATCH_LINES_PEAS := [
	"There. Don't you dare run around. Stay and pray, you're behaving like a prideful sinner.",
	"Kneel. And stay there until you remember your place.",
	"Pray for forgiveness. You'll need it, the way you're going.",
]
const FAIL_CATCH_LINES_CHAIR := [
	"Stay and eat. And don't forget to clean the dishes afterwards.",
	"Sit. You wanted to stay longer, so stay. Then wash everything.",
	"Eat your food. A good daughter doesn't wander. Dishes after.",
]
var _first_sight_done: bool = false
# First-sight WARNING (routine sighting only): stare + lines, then WARN_SEC watching her.
const WARN_SEC := 8.0
const WARN_OCCLUDED_SEC := 1.0
const WARN_FACE_RAD_S := 6.0
const SABIRA_ROOM_MIN := Vector3(2.5, 2.9, -1.2)
const SABIRA_ROOM_MAX := Vector3(7.0, 6.0, 2.5)
var _warn: bool = false
var _warn_t: float = 0.0
var _warn_occl_t: float = 0.0
var _roar_chunks: Array = []
var _roar_chunk_t: float = 0.0
var _last_fail_line: String = ""
## Clip map: the real clip name(s) first; fallbacks are applied in _clip() when they are missing.
## run -> walk at RUN_ANIM_FALLBACK_SCALE, yell / fail -> look_around, grab -> idle, turns -> skip.
const _CLIP_MAP := {
	"run": ["run_chase", "Run_Chase"],
	"turn_left": ["turn_left", "turn_90_left", "Turn_Left"],
	"turn_right": ["turn_right", "turn_90_right", "Turn_Right"],
	"turn_180": ["turn_180", "Turn_180"],
	"yell": ["yell", "Yell"],
	"grab": ["grab_swing", "Grab_Swing"],
	"fail": ["fail_catch", "Fail_Catch"],
	"idle_2": ["idle_2", "Idle_2"],
	"idle_aggressive": ["idle_aggressive"],
	"taunt": ["taunt_flex"],
	"idle_3": ["idle_3"],
	"walk_2": ["walk_2"],
	"jog": ["jog"],
	"strafe_walk_left": ["strafe_walk_left"],
	"strafe_walk_right": ["strafe_walk_right"],
	"strafe_run_left": ["strafe_run_left"],
	"strafe_run_right": ["strafe_run_right"],
	"drunk_walk": ["drunk_walk"],
	"drunk_idle": ["drunk_idle"],
	"drunk_idle_2": ["drunk_idle_2"],
	"drunk_run": ["drunk_run"],
	"drunk_stumble": ["drunk_stumble"],
	"drunk_turn": ["drunk_turn"],
	"fall_flat": ["fall_flat"],
	"turn_l90": ["turn_in_place_left_90"],
	"turn_r90": ["turn_in_place_right_90"],
	"turn_l180": ["turn_in_place_left_180"],
	"turn_r180": ["turn_in_place_right_180"],
	"light_switch": ["light_switch"],
}
## Baked yaw of the in-place turn clips (deg, + = left). drunk_walk_backwards is never used.
const _TURN_DEG := {"turn_l90": 89.7, "turn_r90": -102.6, "turn_l180": 176.1, "turn_r180": -172.7, "drunk_turn": 91.7}
## Looping clips (set on the AnimationPlayer's Animation resources at runtime, not BoneMap).
const _LOOP_KEYS := ["run", "idle_2", "idle_aggressive", "idle_3", "walk_2", "jog", "strafe_walk_left", "strafe_walk_right", "strafe_run_left", "strafe_run_right", "drunk_walk", "drunk_idle", "drunk_idle_2", "drunk_run"]
var _intro_frozen: bool = false
var _chasing: bool = false
var _chase_pending: bool = false
var _seen: bool = false
var _last_seen_world: Vector3 = Vector3.ZERO
var _unseen_t: float = 0.0
var _repath_t: float = 0.0
var _breather_t: float = 0.0
var _vis_t: float = 0.0
var _chase_hold: bool = false
var _hold_kind: String = ""
var _fail_walk: bool = false
var _fail_done: bool = false
var _cone_on: bool = false
var _cone_mi: MeshInstance3D = null
var _head_bone: int = -2
var _run_clip: String = ""
# Lost-chase hold (idle / idle_aggressive, 3-4 s) instead of look_around.
var _lost_search: bool = false
const LOST_HOLD_MIN := 3.0
const LOST_HOLD_MAX := 4.0
const QUICK_TURN_SEC := 0.3
# Darkness: vision range x0.45 and 0.8 s of continuous sight before chase; lit 0.1 s.
const DARK_RANGE_MUL := 0.45
const DARK_DETECT_SEC := 0.8
const LIT_DETECT_SEC := 0.1
const LIT_MIN_ENERGY := 0.055
var _sight_t: float = 0.0
var _player_lit: bool = true
var _lights_cache: Array = []
# Chase navigation: runtime-baked NavigationRegion3D + NavigationAgent3D (chase only).
const NAV_AGENT_RADIUS := 0.25
const NAV_AGENT_HEIGHT := 1.8
const NAV_CELL := 0.1
const NAV_CELL_H := 0.05
var _nav_region: NavigationRegion3D = null
var _agent: NavigationAgent3D = null
var _nav_ready: bool = false
var _doorways_cache: Array = []
# --- Hungover mode (after a drunk-lock wake, rest of the run) ---
const HUNG_WALK_SPEED := 0.45
const HUNG_RUN_SPEED := 2.0
const STUMBLE_MIN := 12.0
const STUMBLE_MAX := 25.0
var _hungover: bool = false
var _stumble_t: float = 0.0
# --- Chase fall (2% per chase, 2-6 s in): fall_flat, lie 4.5 s, fall_flat reversed 0.8x ---
const FALL_CHANCE := 0.02
const FALL_LIE_SEC := 4.5
const GETUP_SPEED := 0.8
var _fall_t: float = -1.0
var _force_fall: bool = false
# --- In-place turns (patrol / investigate, > 60 deg) ---
const INPLACE_TURN_DEG := 60.0
const TURN_REST_SEC := 0.15
var _turn_from_yaw: float = 0.0
var _turn_clip_rad: float = 0.0
var _turn_total_rad: float = 0.0
# --- Relight: light_switch noise with its lights off -> walk to the switch, relight, then look ---
const RELIGHT_AT_SEC := 1.8
const RELIGHT_FALLBACK_SEC := 1.0
var _inv_switch: Node3D = null
var _relight_pending: bool = false
var _relight_done: bool = false
var _relight_t: float = 0.0
var _relight_retry: int = 0
# Light switch hearing filter (names; floor = switch / Tash height).
const SWITCH_ALWAYS_IGNORE := ["Switch_DownstairsBath", "Switch_UpperBath", "Switch_SabiraRoom", "Switch_Hidden"]
const SWITCH_F2_ALLOWED := ["Switch_Landing"]
# Chase keeps going while line of sight holds: range 16 m, FOV 140 (initial detection: 80).
const CHASE_RANGE_M := 16.0
const CHASE_FOV_DEG := 140.0
var _los: bool = false
# Chase stairs / watchdog / start roar.
const CHASE_FACE_RAD_S := 12.0
const STUCK_SEC := 1.5
const STUCK_MOVE_M := 0.25
const ROAR_SEC := 1.7
var _graph_leg: bool = false
var _graph_goal: Vector3 = Vector3.INF
# Bookshelf stops (f1stand / f2stand / office p18): 2-3 shelf_idle clips per stop.
const SHELF_LOOP_CLIPS := ["shelf_idle_look_away", "shelf_idle_weight_shift", "shelf_idle_thoughtful", "shelf_idle_sigh", "shelf_idle_head_shake", "shelf_idle_acknowledge"]
const SHELF_NOD_CLIP := "shelf_idle_nod"
var _shelf_plan: Array = []
var _shelf_slice: float = 0.0
var _graph_force_t: float = 0.0
var _wd_t: float = 0.0
var _wd_pos: Vector3 = Vector3.ZERO
var _chase_roar: bool = false
var _chase_roar_set: bool = false


func _ready() -> void:
	add_to_group("tash")
	if get_node_or_null("TashMouthCycle") == null:
		add_child(TashMouthCycle.new())
	_ensure_drunk_look()
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
	if GameState != null and GameState.has_signal("noise_reported"):
		GameState.noise_reported.connect(hear_noise)
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
	_model.rotation_degrees = Vector3(0.0, model_yaw_offset_deg + _vis_corr_deg, 0.0)
	_model.scale = Vector3.ONE * model_scale
	if _vis_corr_pos != Vector3.ZERO:
		_model.position = global_transform.basis.inverse() * _vis_corr_pos


func _apply_couch_visual() -> void:
	if _model == null:
		_apply_model_yaw_offset()
	if _model == null:
		return
	_model.rotation_degrees = Vector3(couch_model_pitch_deg, model_yaw_offset_deg + _vis_corr_deg, 0.0)
	_model.scale = Vector3.ONE * model_scale
	var world_off := Vector3(0.0, couch_model_y_offset, couch_model_z_offset) + _vis_corr_pos
	_model.position = global_transform.basis.inverse() * world_off


func _apply_office_visual() -> void:
	if _model == null:
		_apply_model_yaw_offset()
	if _model == null:
		return
	_model.rotation_degrees = Vector3(office_model_pitch_deg, model_yaw_offset_deg + _vis_corr_deg, 0.0)
	_model.scale = Vector3.ONE * model_scale
	var world_off := Vector3(0.0, 0.0, office_model_z_offset) + _vis_corr_pos
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
	_bind_drink_clips()
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
	var names: PackedStringArray = PackedStringArray(["idle", "idle_foot", "idle_looking_down", "idle_head_nod", "idle_3"])
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
	_shelf_plan = []
	if _play_hung_idle():
		return
	if _start_shelf_idles():
		return
	if _anim != null and _idle_stand_clips.size() > 0:
		var pick := String(_idle_stand_clips[randi() % _idle_stand_clips.size()])
		_anim.play(pick)
		return
	# look_around is reserved for noise investigation; no look fallback on patrol stands.
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
		_anim.play(clip_path, 0.25)


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


func _bind_drink_clips() -> void:
	_drink_clip = _first_clip(sitting_drinking_clip_names)
	_drunk_clip = _first_clip(sitting_drunk_clip_names)
	if _drink_clip != "":
		_force_loop(_drink_clip, Animation.LOOP_NONE)
	if _drunk_clip != "":
		_force_loop(_drunk_clip, Animation.LOOP_NONE)


func _house_root() -> Node:
	var house := get_parent()
	if house != null:
		house = house.get_parent()
	if house != null:
		house = house.get_parent()
	return house


func _living_prop(path: NodePath, fallback_name: String) -> Node3D:
	var node := get_node_or_null(path) as Node3D
	if node != null:
		return node
	var house := _house_root()
	if house == null:
		return null
	return house.get_node_or_null("Structure/Living/" + fallback_name) as Node3D


func _tash_skeleton() -> Skeleton3D:
	var skel := find_child("GeneralSkeleton", true, false) as Skeleton3D
	if skel == null:
		skel = find_child("Skeleton3D", true, false) as Skeleton3D
	return skel


func _find_bone(skel: Skeleton3D, names: PackedStringArray) -> int:
	if skel == null:
		return -1
	for bone_name in names:
		var idx := skel.find_bone(String(bone_name))
		if idx >= 0:
			return idx
	for i in skel.get_bone_count():
		var have := String(skel.get_bone_name(i))
		for bone_name in names:
			var want := String(bone_name).replace(":", "_")
			if have == want or have.ends_with(want):
				return i
	return -1


func _start_couch_drink() -> void:
	# Even living-couch TV sit, after he is seated. Not stand_to_sit.
	_couch_drink_phase = _DRINK_CLIP
	_force_loop(_drink_clip, Animation.LOOP_NONE)
	_grab_couch_props()
	if _anim != null:
		_anim.play(_drink_clip)
	print("TashWalker: couch drink sit ", _couch_tv_sits)


func _finish_couch_drink() -> void:
	# Dose is read when the drink clip ends, not when the sit starts.
	var dosed := GameState != null and GameState.bottle_dosed
	if dosed:
		if _drunk_clip == "":
			_bind_drink_clips()
		if _drunk_clip != "":
			# Sitting Drunk is a slumped sit, not a two-hand hold. Props go back to the couch.
			_restore_couch_props()
			_enter_drunk_lock()
			return
		if not _drunk_missing_warned:
			_drunk_missing_warned = true
			push_warning("TashWalker: sitting_drunk missing. Dosed drink does not lock.")
	_restore_couch_props()
	_couch_drink_phase = _DRINK_OFF
	if _hold_left <= 0.0:
		_begin_stand()
		return
	if _anim != null and _idle_clip != "":
		_force_loop(_idle_clip, Animation.LOOP_LINEAR)
		_anim.play(_idle_clip)


func _enter_drunk_lock() -> void:
	_couch_drink_phase = _DRUNK_LOCK
	if GameState != null:
		GameState.tash_sedated = true
	_drunk_frozen = false
	_snapshot_doors()
	# Play sitting_drunk once from the start, then freeze at the bowed pose.
	_force_loop(_drunk_clip, Animation.LOOP_NONE)
	if _anim != null:
		_anim.play(_drunk_clip)
	# One-shot Sabira caption when he falls asleep. Not again on wake.
	get_tree().call_group("subtitle", "show_line", "SABIRA", "I think it worked - dad's asleep. I better hurry.", 4.0)
	_set_drunk_look_active(true)
	print("TashWalker: couch drunk lock")

func _wake_from_drunk() -> void:
	if _tash_dead:
		return
	if _couch_drink_phase != _DRUNK_LOCK:
		return
	_set_drunk_look_active(false)
	_restore_couch_props()
	_couch_drink_phase = _DRINK_OFF
	_couch_drink_this = false
	if GameState != null:
		GameState.tash_sedated = false
	print("TashWalker: couch drunk wake")
	_set_hungover()
	_begin_stand()

func is_drunk_locked() -> bool:
	# True only during F1 living-couch sitting_drunk lock (not normal sit/drink).
	return _couch_drink_phase == _DRUNK_LOCK


func _ensure_drunk_look() -> void:
	if _drunk_look != null and is_instance_valid(_drunk_look):
		return
	var existing := get_node_or_null("TashDrunkLook")
	if existing != null:
		_drunk_look = existing
		return
	var scr := load("res://interact/TashDrunkLook.gd") as GDScript
	if scr == null:
		push_warning("TashWalker: TashDrunkLook.gd missing")
		return
	var look := scr.new() as Node
	look.name = "TashDrunkLook"
	add_child(look)
	_drunk_look = look


func _set_drunk_look_active(active: bool) -> void:
	_ensure_drunk_look()
	if _drunk_look == null:
		return
	if _drunk_look.has_method("set_look_active"):
		_drunk_look.call("set_look_active", active)

func _grab_couch_props() -> void:
	if _props_held:
		return
	_bottle_node = _living_prop(couch_bottle_path, "Living_Bottle")
	_glass_node = _living_prop(couch_glass_path, "Living_CouchGlass")
	var skel := _tash_skeleton()
	var right := _find_bone(skel, PackedStringArray(["mixamorig:RightHand", "mixamorig_RightHand", "RightHand"]))
	var left := _find_bone(skel, PackedStringArray(["mixamorig:LeftHand", "mixamorig_LeftHand", "LeftHand"]))
	_hold_prop(_glass_node, skel, right, Vector3(0.02, 0.08, 0.02), false)
	_hold_prop(_bottle_node, skel, left, Vector3(-0.02, 0.07, 0.02), true)
	_props_held = true


func _hold_prop(node: Node3D, skel: Skeleton3D, bone: int, offset: Vector3, is_bottle: bool) -> void:
	if node == null:
		return
	if is_bottle:
		_bottle_home = node.get_parent()
		_bottle_home_xf = node.transform
	else:
		_glass_home = node.get_parent()
		_glass_home_xf = node.transform
	var host: Node3D = null
	if skel != null and bone >= 0:
		var att := BoneAttachment3D.new()
		att.name = "DrinkBottleAttach" if is_bottle else "DrinkGlassAttach"
		skel.add_child(att)
		att.bone_name = skel.get_bone_name(bone)
		_hand_attach.append(att)
		host = att
	elif skel != null:
		if not _hand_missing_warned:
			_hand_missing_warned = true
			push_warning("TashWalker: hand bone missing. Drink props parented to the skeleton.")
		host = skel
	if host == null:
		node.visible = false
		return
	node.reparent(host)
	node.position = offset
	if is_bottle:
		# Bottle mesh +Y is the neck (base at Y 0). LeftHand leaves it neck-down. Local X 150, was 120.
		node.rotation_degrees = Vector3(140.0, 50.0, -50.0)
	else:
		node.rotation = Vector3.ZERO
	node.visible = true


func _restore_couch_props() -> void:
	if not _props_held:
		return
	if _bottle_node != null and is_instance_valid(_bottle_node) and _bottle_home != null and is_instance_valid(_bottle_home):
		if _bottle_node.get_parent() != _bottle_home:
			_bottle_node.reparent(_bottle_home)
		_bottle_node.transform = _bottle_home_xf
		_bottle_node.visible = true
	if _glass_node != null and is_instance_valid(_glass_node) and _glass_home != null and is_instance_valid(_glass_home):
		if _glass_node.get_parent() != _glass_home:
			_glass_node.reparent(_glass_home)
		_glass_node.transform = _glass_home_xf
		_glass_node.visible = true
	for att_any in _hand_attach:
		var att := att_any as Node
		if att != null and is_instance_valid(att):
			att.queue_free()
	_hand_attach.clear()
	_props_held = false


func _all_doorways() -> Array:
	# Every Doorway under Doors (F1 and F2). Wake uses a rising edge of is_passage_open.
	var out: Array = []
	var house := _house_root()
	if house == null:
		return out
	var doors := house.get_node_or_null("Doors")
	if doors == null:
		return out
	for child in doors.get_children():
		var door := child as Doorway
		if door == null:
			continue
		out.append(door)
	return out


func _snapshot_doors() -> void:
	# Doorway has no open signal. Snapshot is_passage_open so a door already open does not wake him.
	_door_was_open.clear()
	for door_any in _all_doorways():
		var door := door_any as Doorway
		_door_was_open[door.get_instance_id()] = door.is_passage_open()


func _tick_drunk_freeze() -> void:
	if _dying_clip != "":
		return
	# Play from 0 until _DRUNK_FREEZE_SEC (frame 69 / 30 fps), then hold the bowed pose.
	if _drunk_frozen:
		return
	if _anim == null or _drunk_clip == "":
		return
	if String(_anim.current_animation) != _drunk_clip:
		return
	if _anim.current_animation_position < _DRUNK_FREEZE_SEC:
		return
	_anim.seek(_DRUNK_FREEZE_SEC, true)
	_anim.pause()
	_drunk_frozen = true


func _poll_door_wake() -> void:
	if _tash_dead:
		return
	if _couch_drink_phase != _DRUNK_LOCK:
		return
	for door_any in _all_doorways():
		var door := door_any as Doorway
		var id := door.get_instance_id()
		var open := door.is_passage_open()
		var was := false
		if _door_was_open.has(id):
			was = bool(_door_was_open[id])
		_door_was_open[id] = open
		if open and not was:
			_wake_from_drunk()
			return

func _begin_couch() -> bool:
	if _sit_clip == "" or _idle_clip == "":
		_bind_sit_clips()
	if _sit_clip == "" or _idle_clip == "" or _anim == null:
		return false
	_couch_tv_sits += 1
	_couch_drink_this = (_couch_tv_sits % 2) == 0
	_couch_drink_phase = _DRINK_OFF
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
	_anim.play(_sit_clip, 0.35, -1.0, true)


func _finish_stand() -> void:
	_vis_capture()
	_restore_couch_props()
	_couch_drink_phase = _DRINK_OFF
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
	# Keep the facing the stand ends on (measured on the hips, with the next clip's pose).
	# Walking: rotate the path yaw by the difference, then the walk eases to the heading.
	# Anything else (in-place turn, idle): a decaying visual correction.
	if _model != null and not _tash_dead:
		var pre_yaw := _vis_pre_yaw
		var pre_pos := _vis_pre_pos
		if _anim != null:
			_anim.advance(0.0)
		var dy := angle_difference(_vis_yaw_now(), pre_yaw)
		if _act == _Act.WALK and _path_follow != null:
			_path_follow.rotation.y += dy
			_apply_model_yaw_offset()
			if _anim != null:
				_anim.advance(0.0)
		_vis_pre_yaw = pre_yaw
		_vis_pre_pos = pre_pos
		_vis_settle(false)


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
		_hold_left = couch_sit_hold_seconds
		if _sit_kind == _SIT_COUCH and _couch_drink_this:
			if _drink_clip == "":
				_bind_drink_clips()
			if _drink_clip != "":
				_start_couch_drink()
				return
			if not _drink_missing_warned:
				_drink_missing_warned = true
				push_warning("TashWalker: sitting_drinking missing. Drink sit stays on sitting_idle.")
		if _idle_clip != "":
			_anim.play(_idle_clip, 0.3)
		return
	if _act == _Act.SIT_HOLD and _couch_drink_phase == _DRINK_CLIP and done == _drink_clip:
		_finish_couch_drink()
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
	if _chasing and _run_clip != "":
		return _run_clip
	var flat_walk := _clip_path
	if _hungover:
		var dw := _real_clip("drunk_walk")
		if dw != "":
			flat_walk = dw
	if _route_i < 0 or _route_i >= _route.size() - 1:
		return flat_walk
	var a: Vector3 = _pt[String(_route[_route_i])] as Vector3
	var b: Vector3 = _pt[String(_route[_route_i + 1])] as Vector3
	var dy := b.y - a.y
	if dy > 0.05:
		if _up_clip != "":
			return _up_clip
	elif dy < -0.05:
		if _down_clip != "":
			return _down_clip
	return flat_walk


func _play_locomotion() -> void:
	_play_named(_locomotion_clip())


func _physics_process(delta: float) -> void:
	_tick_vis_corr(delta)
	if _tash_dead:
		if _act == _Act.SIT_HOLD:
			global_position = _sit_global
			_latch_couch_path_yaw()
			rotation_degrees = Vector3(0.0, _sit_yaw, 0.0)
			_apply_dying_model()
			_tick_dying_speed()
			_tick_blood_puddle(delta)
		return
	if _intro_frozen:
		return
	_tick_steps(delta)
	_tick_vision(delta)
	_tick_chase(delta)
	if _hungover and _act == _Act.WALK and not _chasing:
		_stumble_t -= delta
	if _chase_pending:
		_try_begin_chase()
	if _inv_pending:
		_try_begin_investigation()
	if _act == _Act.IDLE:
		_look_left -= delta
		if _chase_hold:
			if _hold_kind == "warn":
				_tick_warn(delta)
				return
			if _hold_kind == "roar":
				if _roar_chunks.size() > 0:
					_roar_chunk_t -= delta
					if _roar_chunk_t <= 0.0:
						_show_roar_chunk()
				# Long first-sight hold: when the one-shot yell ends, hold idle_aggressive.
				if _anim != null and not _anim.is_playing() and _real_clip("idle_aggressive") != "":
					_force_loop(_real_clip("idle_aggressive"), Animation.LOOP_LINEAR)
					_anim.play(_real_clip("idle_aggressive"), 0.25)
			if _hold_kind == "relight":
				_relight_t += delta
				if _relight_t >= RELIGHT_AT_SEC and not _relight_done:
					_relight_now()
			if _look_left <= 0.0:
				_end_chase_hold()
			return
		if _inv_look:
			if _look_left <= 0.0:
				_end_investigation()
			return
		if _shelf_plan.size() > 0 and _look_left > 0.0:
			_shelf_slice -= delta
			if _shelf_slice <= 0.0:
				_shelf_plan.pop_front()
				_play_shelf_slice()
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
		# Drunk lock: path stays paused, no stand. TV stays on until wake stands him.
		if _sit_kind == _SIT_COUCH and _couch_drink_phase == _DRUNK_LOCK:
			_tick_drunk_freeze()
			_poll_door_wake()
			return
		_hold_left -= delta
		if _hold_left <= 0.0:
			# Drink clip keeps playing. Stand only after it ends, if time is already up.
			if _sit_kind == _SIT_COUCH and _couch_drink_phase == _DRINK_CLIP:
				return
			if _snap_sit:
				_finish_stand()
			else:
				_begin_stand()


func _start_patrol() -> void:
	if _patrol_started:
		return
	_patrol_started = true
	_build_nav()
	_setup_chase_nav()
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
	# F2 bookcase front at X~-1.80 (Wall_North_W/Bookcase). Wall_Sabira_W_N is at X~-2.38.
	# Stand east of the books, clear of the wall. Idle yaw 90 looks -X at them.
	# rcouch is the sit approach, not a stand. The snap uses TashRedCouchSit.
	_add_pt("f2a", -1.2, 3.01, -1.05)
	_add_pt("f2b", -1.4, 3.01, -0.55)
	_add_pt("f2stand", -1.4, 3.01, 0.15)
	# East of Wall_Sabira_W_N, in front of the red couch. Snap sits onto the marker.
	# East of the red couch. Old rcouch (-1.85, 1.27) sat inside the mesh.
	_add_pt("rcin", -1.0, 3.01, 0.15)
	_add_pt("rcouch", -1.0, 3.01, 1.27)
	# Hall p12-p13 used to run at X -1.2 and clip the east face (X -1.393).
	_add_pt("rcs", -1.2, 3.01, 0.35)
	_add_pt("rce", -0.9, 3.01, 0.35)
	_add_pt("rcn", -0.9, 3.01, 3.5)
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
	_link("p12", "rcs")
	_link("rcs", "rce")
	_link("rce", "rcn")
	_link("rcn", "p13")
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
	_link("f2stand", "rcin")
	_link("rcin", "rcouch")
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
	# Couch TV sit is common. Toilet is rare (weight 1 + quota every ~8 picks).
	_stop_weight = {
		"idle_f1": 6,
		"idle_f2": 6,
		"shelf": 6,
		"office": 3,
		"couch": 6,
		"redcouch": 3,
		"toilet": 1,
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
	if _play_hung_idle():
		return
	var idle2 := _real_clip("idle_2")
	if idle2 != "" and randi() % (_idle_stand_clips.size() + 1) == 0:
		_force_loop(idle2, Animation.LOOP_LINEAR)
		_anim.play(idle2)
		return
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
	if _chasing or _fail_walk:
		return false
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
	# Force only after a long dry spell (about every 8-10 picks), not every third.
	if _recent_picks.size() < _TOILET_QUOTA_WINDOW:
		return false
	for prev_any in _recent_picks:
		if String(prev_any) == "toilet":
			return false
	return true


func _note_pick(id: String) -> void:
	_recent_picks.append(id)
	while _recent_picks.size() > _TOILET_QUOTA_WINDOW:
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
	_maybe_inplace_turn()


func _choose_next() -> void:
	if _chase_pending:
		_start_chase()
		return
	if _inv_pending:
		# A heard noise interrupted a stop (e.g. stood up from a sit): investigate instead.
		_start_investigation()
		return
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
	if _active_stop == "chase":
		# Reached the target point: wait in place for the next re-path.
		_route = []
		_route_i = 0
		_act = _Act.WALK
		return
	if _active_stop == "failcatch":
		_begin_chase_hold("fail")
		return
	if _active_stop == "investigate":
		_begin_inv_look()
		return
	_last_stop = _active_stop
	_route = []
	_route_i = 0
	var started := true
	_vis_capture()
	if _active_stop == "shelf":
		_begin_idle_stand(office_idle_body_yaw_deg)
		_vis_settle(false)
		return
	elif _active_stop == "idle_f1":
		_begin_idle_stand(f1_idle_body_yaw_deg)
		_vis_settle(false)
		return
	elif _active_stop == "idle_f2":
		_begin_idle_stand(f2_idle_body_yaw_deg)
		_vis_settle(false)
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
		return
	_vis_settle(_active_stop == "couch")


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
		var want := atan2(-flat.x, -flat.z)
		if _act == _Act.WALK and not _chasing:
			# Smooth heading at route corners instead of snapping per segment.
			var cur := _path_follow.rotation.y
			_path_follow.rotation = Vector3(0.0, rotate_toward(cur, cur + angle_difference(cur, want), WALK_FACE_RAD_S * get_physics_process_delta_time()), 0.0)
		else:
			_path_follow.rotation = Vector3(0.0, want, 0.0)
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
	_seg_dist += walk_speed * _speed_mul() * delta
	if _seg_dist >= seg_len:
		_seg_dist = 0.0
		_route_i += 1
		_here = b_id
		_place(b, b - a)
		if _route_i >= _route.size() - 1:
			_begin_current_stop()
			return
		if _maybe_inplace_turn():
			return
		if _maybe_stumble():
			return
		if _maybe_turn_idle(b_id):
			return
		return
	_place(a.lerp(b, _seg_dist / seg_len), b - a)

func is_tash_dead() -> bool:
	return _tash_dead

func begin_couch_stab() -> void:
	if _tash_dead:
		return
	if not is_drunk_locked():
		return
	if GameState == null or not GameState.has_knife:
		return
	# Death is not a wake. Leave tash_sedated and bottle_dosed. Do not stand or resume the route.
	_tash_dead = true
	_set_drunk_look_active(false)
	_place_dying_on_floor()
	_set_player_locked(true)
	_show_stab_card()
	await _play_stab_lines()
	_apply_stab_blood()
	_start_dying()
	await _fade_stab_card()
	_set_player_locked(false)
	# Corpse Look/Search as soon as the black card fades (dying anim still playing).
	_enable_corpse_look()

func _set_player_locked(locked: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.call_group("player", "set_input_locked", locked)

func _show_stab_card() -> void:
	# SFX stub: a stab sting would play here. No audio file yet.
	if _stab_layer != null and is_instance_valid(_stab_layer):
		return
	var tree := get_tree()
	if tree == null:
		return
	_stab_layer = CanvasLayer.new()
	_stab_layer.name = "TashStabCard"
	_stab_layer.layer = 90
	_stab_rect = ColorRect.new()
	_stab_rect.name = "Black"
	_stab_rect.color = Color(0, 0, 0, 1)
	_stab_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stab_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.name = "Card"
	label.text = _STAB_CARD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 72
	label.offset_right = -72
	label.offset_top = 40
	label.offset_bottom = -40
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	_stab_rect.add_child(label)
	_stab_layer.add_child(_stab_rect)
	tree.root.add_child(_stab_layer)

func _fade_stab_text_in() -> void:
	if _stab_rect == null or not is_instance_valid(_stab_rect):
		return
	var label := _stab_rect.get_node_or_null("Card") as CanvasItem
	if label == null:
		return
	label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, _STAB_TEXT_IN_SEC)
	await tween.finished

func _fade_stab_card() -> void:
	if _stab_rect == null or not is_instance_valid(_stab_rect):
		return
	var tween := create_tween()
	tween.tween_property(_stab_rect, "modulate:a", 0.0, _STAB_FADE_SEC)
	await tween.finished
	if _stab_layer != null and is_instance_valid(_stab_layer):
		_stab_layer.queue_free()
	_stab_layer = null
	_stab_rect = null

func _place_dying_on_floor() -> void:
	# Dying hips stay near couch height. Drop the mesh onto the floor and slide
	# world -Z so the body is in front of the living couch, not across the cushions.
	var spot := _sit_global + Vector3(0.0, 0.0, _DYING_FORWARD_Z)
	spot.y = 0.0
	_sit_global = spot
	if _path_follow != null:
		_path_follow.rotation = Vector3.ZERO
		_path_follow.position = spot
	position = Vector3.ZERO
	global_position = spot
	rotation_degrees = Vector3(0.0, _sit_yaw, 0.0)
	_apply_dying_model()
	var body_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if body_shape != null:
		body_shape.disabled = true

func _apply_dying_model() -> void:
	if _model == null:
		_apply_model_yaw_offset()
	if _model == null:
		return
	_model.rotation_degrees = Vector3(0.0, model_yaw_offset_deg, 0.0)
	_model.scale = Vector3.ONE * model_scale
	_model.position = Vector3(0.0, _DYING_MODEL_DROP, 0.0)

func _start_dying() -> void:
	if _anim == null:
		push_warning("TashWalker: dying clip missing. Stab leaves the drunk pose.")
		return
	var clip := _resolve_clip_path("dying")
	if clip == "":
		push_warning("TashWalker: dying clip missing. Stab leaves the drunk pose.")
		return
	_dying_clip = clip
	_dying_left = _DYING_LOOPS
	_dying_loop_index = 0
	_dying_frozen = false
	_force_loop(clip, Animation.LOOP_NONE)
	if not _dying_hooked:
		_anim.animation_finished.connect(_on_dying_finished)
		_dying_hooked = true
	_anim.speed_scale = 1.0
	_anim.play(clip, 0.4)

func _on_dying_finished(anim_name: StringName) -> void:
	if _dying_frozen:
		return
	if _dying_clip == "" or String(anim_name) != _dying_clip:
		return
	_dying_left -= 1
	if _dying_left > 0:
		_dying_loop_index += 1
		if _anim != null:
			_anim.play(_dying_clip, 0.0)
		return
	_freeze_dying()

func _tick_dying_speed() -> void:
	if _dying_frozen or _anim == null or _dying_clip == "":
		return
	if String(_anim.current_animation) != _dying_clip:
		return
	var anim := _anim.get_animation(_dying_clip)
	if anim == null or anim.length <= 0.001:
		return
	var along := clampf(_anim.current_animation_position / anim.length, 0.0, 1.0)
	var base := 1.0
	if _dying_loop_index > 0:
		base = 0.5
	_anim.speed_scale = lerpf(base, base * 0.25, along * along)

func _freeze_dying() -> void:
	_dying_frozen = true
	if _anim != null:
		_anim.speed_scale = 1.0
	if _anim == null or _dying_clip == "":
		_enable_corpse_look()
		return
	var anim := _anim.get_animation(_dying_clip)
	var end_sec := 0.0
	if anim != null:
		end_sec = maxf(anim.length - 0.001, 0.0)
	if String(_anim.current_animation) != _dying_clip:
		_anim.play(_dying_clip)
	_anim.seek(end_sec, true)
	_anim.pause()
	_enable_corpse_look()

func _enable_corpse_look() -> void:
	_ensure_drunk_look()
	if _drunk_look != null and _drunk_look.has_method("set_corpse_look"):
		_drunk_look.call("set_corpse_look", true)


func _play_stab_lines() -> void:
	if _stab_rect == null or not is_instance_valid(_stab_rect):
		return
	var label := _stab_rect.get_node_or_null("Card") as Label
	if label == null:
		return
	for line in _STAB_LINES:
		label.text = line
		label.modulate.a = 0.0
		var fade_in := create_tween()
		fade_in.tween_property(label, "modulate:a", 1.0, _STAB_LINE_IN)
		await fade_in.finished
		await get_tree().create_timer(_STAB_LINE_HOLD).timeout
		if not is_instance_valid(label):
			return
		var fade_out := create_tween()
		fade_out.tween_property(label, "modulate:a", 0.0, _STAB_LINE_OUT)
		await fade_out.finished


func _ensure_blood_puddle() -> void:
	if _blood_puddle != null and is_instance_valid(_blood_puddle):
		return
	var house := _house_root()
	if house == null:
		return
	_blood_puddle = MeshInstance3D.new()
	_blood_puddle.name = "StabBloodPuddle"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.01
	disc.radial_segments = 28
	_blood_puddle.mesh = disc
	_blood_puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.4, 0.015, 0.02, 0.88)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_blood_puddle.material_override = mat
	house.add_child(_blood_puddle)
	_puddle_age = 0.0
	_puddle_locked = false
	_blood_puddle.scale = Vector3(_PUDDLE_MIN_R, 1.0, _PUDDLE_MIN_R)
	_blood_puddle.global_position = _neck_floor_pos()


func _neck_floor_pos() -> Vector3:
	var pos := global_position
	var skel := _tash_skeleton()
	var bone := _find_bone(skel, PackedStringArray(["mixamorig:Neck", "mixamorig_Neck", "Neck"]))
	if skel != null and bone >= 0:
		var pose := skel.get_bone_global_pose(bone)
		pos = skel.to_global(pose.origin)
	pos.y = 0.02
	return pos


func _tick_blood_puddle(delta: float) -> void:
	if _blood_puddle == null or not is_instance_valid(_blood_puddle):
		return
	if not _puddle_locked:
		_puddle_age = minf(_puddle_age + delta, _PUDDLE_GROW_SEC)
		var u := clampf(_puddle_age / _PUDDLE_GROW_SEC, 0.0, 1.0)
		var eased := u * u * (3.0 - 2.0 * u)
		var radius := lerpf(_PUDDLE_MIN_R, _PUDDLE_MAX_R, eased)
		_blood_puddle.scale = Vector3(radius, 1.0, radius)
		if not _dying_frozen:
			_blood_puddle.global_position = _neck_floor_pos()
		if u >= 1.0:
			_puddle_locked = true
func _swap_blood_albedo() -> void:
	var tex := load("res://props/Tash_albedo_blood.png") as Texture2D
	if tex == null:
		push_warning("TashWalker: blood albedo missing")
		return
	var mouth := get_node_or_null("TashMouthCycle") as TashMouthCycle
	if mouth != null:
		mouth.set_blood(true)
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := node as MeshInstance3D
		if mesh_inst == null or mesh_inst.name == "Stain":
			continue
		var mesh := mesh_inst.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			# The face surface belongs to TashMouthCycle (blood_* mouth frames).
			if mouth != null and mouth.owns(mesh_inst, s):
				continue
			var mat := mesh_inst.get_active_material(s) as StandardMaterial3D
			if mat == null:
				continue
			var copy := mat.duplicate() as StandardMaterial3D
			if copy == null:
				continue
			copy.albedo_texture = tex
			mesh_inst.set_surface_override_material(s, copy)

func _apply_stab_blood() -> void:
	_swap_blood_albedo()
	var tree := get_tree()
	if tree != null:
		tree.call_group("held_knife", "stain_blood")
	_ensure_blood_puddle()

func _add_blood_box(skel: Skeleton3D, names: PackedStringArray, att_name: String, offset: Vector3, size: Vector3) -> void:
	if skel == null:
		push_warning("TashWalker: no skeleton for " + att_name)
		return
	if skel.get_node_or_null(att_name) != null:
		return
	var bone := _find_bone(skel, names)
	if bone < 0:
		push_warning("TashWalker: bone missing for " + att_name)
		return
	var att := BoneAttachment3D.new()
	att.name = att_name
	skel.add_child(att)
	att.bone_name = skel.get_bone_name(bone)
	var stain := MeshInstance3D.new()
	stain.name = "Stain"
	var box := BoxMesh.new()
	box.size = size
	stain.mesh = box
	stain.position = offset
	stain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.45, 0.02, 0.03)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	stain.material_override = mat
	att.add_child(stain)


# --- NOISE INVESTIGATION -------------------------------------------------------------------
## GameState.noise_reported handler. Range = 12 m * loudness, halved on another floor
## (|dy| > 1.5 m). Ignored while dead or drunk-locked. Sets a pending investigation that starts
## as soon as he can safely break off (after a door / sit animation; sits stand up first).
func hear_noise(pos: Vector3, loudness: float, source: String) -> void:
	if _chasing or _chase_pending or (_chase_hold and _chasing) or _fail_walk or _intro_frozen or _warn:
		print("[NOISE] Tash ignores %s (busy: chase/fail/intro/warn)" % source)
		return
	if _tash_dead or is_drunk_locked() or not _patrol_started or _path_follow == null:
		print("[NOISE] Tash ignores %s (%s)" % [source, "dead" if _tash_dead else ("drunk" if is_drunk_locked() else "not ready")])
		return
	if source.begins_with("light_switch"):
		var why := _switch_ignore_reason(source, pos)
		if why != "":
			print("[NOISE] Tash ignores %s (%s)" % [source, why])
			return
	var dy := absf(pos.y - global_position.y)
	var hear_range := _HEAR_RANGE_M * loudness
	if dy > _HEAR_OTHER_FLOOR_DY:
		hear_range *= _HEAR_OTHER_FLOOR_MUL
	var dist := global_position.distance_to(pos)
	if dist > hear_range:
		print("[NOISE] Tash too far from %s (%.1f m > %.1f m)" % [source, dist, hear_range])
		return
	print("[NOISE] Tash hears %s (%.1f m, range %.1f m)" % [source, dist, hear_range])
	_lost_search = false
	_inv_target_world = pos
	_inv_pending = true
	_relight_pending = false
	_inv_switch = null
	if source.begins_with("light_switch"):
		_inv_switch = _switch_by_source(source, pos)
		if _inv_switch != null and _inv_switch.has_method("is_on") and not bool(_inv_switch.call("is_on")):
			# Walk to ~0.5 m in front of the switch on its ROOM side, relight, then the look-around.
			_inv_target_world = _switch_stand_point(_inv_switch)
			_relight_pending = true
			_relight_retry = 0
			print("[NOISE] Tash will relight ", _inv_switch.name)


func is_investigating() -> bool:
	return _investigating or _inv_pending


func _try_begin_investigation() -> void:
	if _tash_dead or is_drunk_locked():
		_inv_pending = false
		return
	# Let a door open / a sit-down or stand-up animation finish first.
	if _act == _Act.DOOR or _act == _Act.SIT_DOWN or _act == _Act.STAND_UP:
		return
	if _act == _Act.SIT_HOLD:
		# Stand up with the normal logic: TV off, bottle/glass restored, drink phase reset.
		# _finish_stand -> _choose_next -> _start_investigation (pending).
		_couch_drink_this = false
		if _snap_sit:
			_finish_stand()
		else:
			_begin_stand()
		return
	_start_investigation()


func _graph_ids() -> Array:
	var out: Array = []
	for id_any in _nb.keys():
		var id := String(id_any)
		if id.begins_with("nz_"):
			continue
		out.append(id)
	return out


func _path_space() -> Node3D:
	if _path_follow != null and _path_follow.get_parent() is Node3D:
		return _path_follow.get_parent() as Node3D
	return null


func _line_clear(a_local: Vector3, b_local: Vector3) -> bool:
	var space := _path_space()
	if space == null or not is_inside_tree():
		return false
	var a := space.to_global(a_local) + Vector3(0, 0.9, 0)
	var b := space.to_global(b_local) + Vector3(0, 0.9, 0)
	# Never take a straight cut through Door_DownstairsBath.
	var bath := _house_root().get_node_or_null("Doors/Door_DownstairsBath") as Node3D if _house_root() != null else null
	if bath != null:
		var d := Geometry3D.get_closest_point_to_segment(bath.global_position, a, b)
		if Vector2(d.x - bath.global_position.x, d.z - bath.global_position.z).length() < 0.7 and absf(d.y - 0.9 - bath.global_position.y) < 2.0:
			return false
	# Capsule sweep (r 0.25, 0.25-1.65 m above the floor) against world + couch blockers, so
	# straight shortcuts never cut through furniture lower than the old 0.9 m ray.
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.4
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = cap
	sq.transform = Transform3D(Basis.IDENTITY, a + Vector3(0, 0.05, 0))
	sq.motion = b - a
	sq.collision_mask = 1 | 8
	sq.exclude = [get_rid()]
	var res := get_world_3d().direct_space_state.cast_motion(sq)
	return res.size() >= 1 and res[0] >= 0.999


## Nearest route-graph node, same floor first, preferring one with a clear straight line.
func _nearest_node(local_pos: Vector3) -> String:
	var best := ""
	var best_d := INF
	var best_any := ""
	var best_any_d := INF
	for id_any in _graph_ids():
		var id := String(id_any)
		var p: Vector3 = _pt[id] as Vector3
		var d := Vector2(p.x - local_pos.x, p.z - local_pos.z).length() + absf(p.y - local_pos.y) * 3.0
		if d < best_any_d:
			best_any_d = d
			best_any = id
		if d < best_d and _line_clear(p, local_pos):
			best_d = d
			best = id
	return best if best != "" else best_any


func _clear_inv_links() -> void:
	var temp: Array = []
	for k in _nb.keys():
		if String(k).begins_with("nz_"):
			temp.append(String(k))
	for id in temp:
		if _nb.has(id):
			for nb_any in (_nb[id] as Array):
				var nb := String(nb_any)
				if _nb.has(nb):
					(_nb[nb] as Array).erase(id)
			_nb.erase(id)


func _start_investigation() -> void:
	_inv_pending = false
	_chase_hold = false
	if not _investigating:
		_lost_search = false
	if _path_follow == null or _path_space() == null:
		return
	var first := not _investigating
	_investigating = true
	_inv_look = false
	_route_idle = false
	var here_local: Vector3 = _path_follow.position
	var goal_local: Vector3 = _path_space().to_local(_inv_target_world)
	goal_local.y = snappedf(goal_local.y, 0.01)
	if _here == "nz_goal" or _here == "nz_here":
		_here = ""
	_clear_inv_links()
	var start_id := _nearest_node(here_local)
	var end_id := _nearest_node(goal_local)
	var path := _shortest(start_id, end_id)
	if path.is_empty():
		push_warning("TashWalker: no route to the noise. Ignored.")
		_investigating = false
		_choose_next()
		return
	var route: Array = []
	var start_p: Vector3 = _pt[start_id] as Vector3
	if here_local.distance_to(start_p) > 0.05:
		_pt["nz_here"] = here_local
		route.append("nz_here")
	route.append_array(path)
	var end_p: Vector3 = _pt[end_id] as Vector3
	if Vector2(goal_local.x - end_p.x, goal_local.z - end_p.z).length() > 0.3 and absf(goal_local.y - end_p.y) < 0.3 and _line_clear(end_p, goal_local):
		goal_local.y = end_p.y
		_pt["nz_goal"] = goal_local
		route.append("nz_goal")
		_link("nz_goal", end_id)
	_here = start_id
	_active_stop = "investigate"
	print("[NOISE] Tash investigates: ", route)
	if first:
		get_tree().call_group("subtitle", "show_line", "TASH", _INV_LINE, 2.5)
		if GameState != null and GameState.has_signal("tash_alert_changed"):
			GameState.tash_alert_changed.emit("search")
	if route.size() <= 1:
		_begin_inv_look()
		return
	_start_route(route)


func _begin_inv_look() -> void:
	if _relight_pending and _inv_switch != null and is_instance_valid(_inv_switch):
		_begin_relight()
		return
	_act = _Act.IDLE
	_route_idle = false
	_inv_look = true
	_look_left = randf_range(_INV_LOOK_MIN, _INV_LOOK_MAX)
	rotation = Vector3.ZERO
	_apply_model_yaw_offset()
	_face_world_point(_inv_target_world)
	if _lost_search:
		# After a lost chase: brief idle / idle_aggressive hold, never look_around.
		_look_left = randf_range(LOST_HOLD_MIN, LOST_HOLD_MAX)
		var hold_clip := _real_clip("idle_aggressive")
		if hold_clip == "" or randf() < 0.5:
			hold_clip = String(_idle_stand_clips[randi() % _idle_stand_clips.size()]) if _idle_stand_clips.size() > 0 else hold_clip
		if hold_clip != "" and _anim != null:
			_force_loop(hold_clip, Animation.LOOP_LINEAR)
			_anim.play(hold_clip)
		print("[CHASE] lost hold %.1f s (%s)" % [_look_left, hold_clip])
		return
	if _look_clip != "" and _anim != null:
		_force_loop(_look_clip, Animation.LOOP_LINEAR)
		_anim.play(_look_clip)
	elif _anim != null and _idle_stand_clips.size() > 0:
		_anim.play(String(_idle_stand_clips[randi() % _idle_stand_clips.size()]))
	print("[NOISE] Tash searching for %.1f s" % _look_left)


func _end_investigation() -> void:
	_inv_look = false
	_lost_search = false
	_investigating = false
	_act = _Act.WALK
	rotation = Vector3.ZERO
	_apply_model_yaw_offset()
	if _look_clip != "" and _anim != null:
		_force_loop(_look_clip, Animation.LOOP_NONE)
	_last_stop = ""
	_active_stop = ""
	print("[NOISE] Tash done searching, back to patrol")
	if GameState != null and GameState.has_signal("tash_alert_changed"):
		GameState.tash_alert_changed.emit("ambient")
	_choose_next()


# --- VISION / CHASE ----------------------------------------------------------------------
## Cone from the head bone (fallback model + 1.6 m): FOV 80, range 11 m (x0.7 crouched),
## checked every 0.1 s, rays (layer 1) to the player's camera and chest. No vision while the
## player is safe (GameState.is_player_safe()), drunk-locked, dead / stab, intro, or ending.
## Sight -> CHASE (run RUN_SPEED m/s, re-path 0.5 s, breather yell every 5-8 s). Lost > 1.5 s
## -> walk to the last seen spot, search look-around (alert 'search'), then patrol/ambient.
## Reach < 1.2 m -> grab_swing + "[CATCH] debug" print, 3 s cooldown. Safe during chase/search
## -> fail catch in front of her, then patrol. F11 toggles the cone draw.

func set_intro_frozen(on: bool) -> void:
	_intro_frozen = on


## Intro end: start in the F1 couch TV sit (sit 1 = not a drink sit), then the normal route.
func begin_intro_couch() -> void:
	_start_patrol()
	_intro_frozen = false
	_inv_pending = false
	_chase_pending = false
	_investigating = false
	_chasing = false
	_route = []
	_route_i = 0
	_seg_dist = 0.0
	if _anim != null:
		_anim.speed_scale = 1.0
	if _path_follow != null and _pt.has("p35"):
		_path_follow.position = _pt["p35"] as Vector3
	_here = "p35"
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	_apply_model_yaw_offset()
	_couch_tv_sits = 0
	_active_stop = "couch"
	_note_pick("couch")
	print("TashWalker: intro start, couch TV sit")
	_begin_current_stop()


func is_chasing() -> bool:
	return _chasing


func _speed_mul() -> float:
	if walk_speed <= 0.001:
		return 1.0
	if _chasing:
		return _run_speed() / walk_speed
	if _hungover:
		return HUNG_WALK_SPEED / walk_speed
	return 1.0


func _run_speed() -> float:
	return HUNG_RUN_SPEED if _hungover else RUN_SPEED


func _clip(key: String) -> String:
	var real := _real_clip(key)
	if real != "":
		return real
	match key:
		"run":
			return ""
		"yell", "fail", "grab", "idle_2", "idle_aggressive":
			return String(_idle_stand_clips[0]) if _idle_stand_clips.size() > 0 else ""
	return ""


func _apply_clip_loops() -> void:
	for k in _LOOP_KEYS:
		var c := _real_clip(String(k))
		if c != "":
			_force_loop(c, Animation.LOOP_LINEAR)


func _real_clip(key: String) -> String:
	if _anim == null or not _CLIP_MAP.has(key):
		return ""
	return _first_clip(PackedStringArray(_CLIP_MAP[key]))


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _eye_pos() -> Vector3:
	var skel := _tash_skeleton()
	if _head_bone == -2:
		_head_bone = _find_bone(skel, PackedStringArray(["Head", "head", "mixamorig:Head"]))
	if skel != null and _head_bone >= 0:
		return skel.global_transform * skel.get_bone_global_pose(_head_bone).origin
	return global_position + Vector3(0, 1.6, 0)


func _forward_flat() -> Vector3:
	var f := Vector3.ZERO
	if _model == null:
		_model = get_node_or_null(model_node_path) as Node3D
	if _model != null:
		f = _model.global_transform.basis.z
	else:
		f = -global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


func _vision_blocked_reason() -> String:
	if _tash_dead:
		return "dead"
	if _chase_hold and (_hold_kind == "fall" or _hold_kind == "lie" or _hold_kind == "getup"):
		return "fallen"
	if is_drunk_locked():
		return "drunk"
	if _intro_frozen:
		return "intro"
	if GameState != null and GameState.ending_reached != "":
		return "ending"
	if GameState != null and GameState.is_player_safe():
		return "safe"
	return ""


func _can_see_player() -> bool:
	if _vision_blocked_reason() != "":
		return false
	var p := _player()
	if p == null:
		return false
	var eye := _eye_pos()
	var cam := p.get("_camera") as Camera3D
	var top: Vector3 = cam.global_position if cam != null else p.global_position + Vector3(0, 1.5, 0)
	var chest := top - Vector3(0, 0.55, 0)
	if _chasing:
		# Active chase: only a real occluder (or > 16 m) breaks sight. FOV 140 for tracking;
		# _los ignores the cone so turning away never ends the chase.
		_los = eye.distance_to(chest) <= CHASE_RANGE_M and _rays_clear(eye, top, chest, p)
		var tc := chest - eye
		tc.y = 0.0
		return _los and (tc.length_squared() < 0.0001 or rad_to_deg(_forward_flat().angle_to(tc.normalized())) <= CHASE_FOV_DEG * 0.5)
	_los = false
	var rng := VIS_RANGE_M * (VIS_CROUCH_MUL if GameState != null and GameState.is_crouching else 1.0)
	_player_lit = _is_lit(chest)
	if not _player_lit:
		rng *= DARK_RANGE_MUL
	if eye.distance_to(chest) > rng:
		return false
	var to := chest - eye
	to.y = 0.0
	if to.length_squared() > 0.0001 and rad_to_deg(_forward_flat().angle_to(to.normalized())) > VIS_FOV_DEG * 0.5:
		return false
	var space := get_world_3d().direct_space_state
	var excl: Array[RID] = [get_rid()]
	if p is CollisionObject3D:
		excl.append((p as CollisionObject3D).get_rid())
	for target in [top, chest]:
		var q := PhysicsRayQueryParameters3D.create(eye, target)
		q.collision_mask = 1
		q.exclude = excl
		if space.intersect_ray(q).is_empty():
			return true
	return false


func _tick_vision(delta: float) -> void:
	_vis_t -= delta
	if _vis_t > 0.0:
		return
	_vis_t = VIS_INTERVAL
	var safe := GameState != null and GameState.is_player_safe()
	if not safe:
		_fail_done = false
	var was := _seen
	_seen = _can_see_player()
	var p := _player()
	if (_seen or _los) and p != null:
		_last_seen_world = p.global_position
		_unseen_t = 0.0
	if _cone_on:
		_draw_cone()
		if was != _seen:
			print("[VISION] seen=%s (%s) player %s" % [_seen, _vision_blocked_reason(), "lit" if _player_lit else "dark"])
	# Fail catch: she reached a safe spot while he was chasing or searching.
	if safe and not _fail_done and not _fail_walk and (_chasing or _investigating or _chase_pending) and _vision_blocked_reason() != "fallen":
		if _act == _Act.WALK or _act == _Act.IDLE or _act == _Act.PAUSE or _act == _Act.LOOK:
			_start_fail_catch()
		return
	_sight_t = _sight_t + VIS_INTERVAL if _seen else 0.0
	var need := LIT_DETECT_SEC if _player_lit else DARK_DETECT_SEC
	if _seen and _sight_t >= need - 0.001 and not _chasing and not _chase_pending and not _fail_walk and not _warn:
		print("[VISION] Tash sees the player (%s, %.1f s)" % ["lit" if _player_lit else "dark", _sight_t])
		_chase_pending = true


func _try_begin_chase() -> void:
	if _vision_blocked_reason() != "":
		_chase_pending = false
		return
	if not _chase_roar_set:
		# Normal routine (patrol / idle / sit) -> roar first; investigating / searching -> run.
		_chase_roar = not (_investigating or _inv_pending or _lost_search or _fail_walk)
		_chase_roar_set = true
	if _act == _Act.DOOR or _act == _Act.SIT_DOWN or _act == _Act.STAND_UP:
		return
	if _act == _Act.SIT_HOLD:
		_couch_drink_this = false
		_play_huh()
		if _snap_sit:
			_finish_stand()
		else:
			_begin_stand_fast()
		return
	_start_chase()


## Spotted her while sitting: startled 'Huh?!' (3D grunt + caption), then a 3x stand.
const HUH_SFX := "res://audio/sfx/tash_huh.wav"
const HUH_CAPTION_SEC := 1.2
const STAND_FAST_SCALE := 3.0
var _huh_until_ms: int = 0
var _huh_player: AudioStreamPlayer3D = null


func _play_huh() -> void:
	if _huh_player == null:
		_huh_player = AudioStreamPlayer3D.new()
		_huh_player.name = "HuhSfx"
		_huh_player.stream = load(HUH_SFX) as AudioStream
		_huh_player.unit_size = 4.0
		_huh_player.position = Vector3(0, 1.6, 0)
		add_child(_huh_player)
	_huh_player.play()
	get_tree().call_group("subtitle", "show_line", "TASH", "Huh?!", HUH_CAPTION_SEC)
	_huh_until_ms = Time.get_ticks_msec() + int(HUH_CAPTION_SEC * 1000.0)
	print("[VISION] Tash startled while sitting: Huh?! (fast stand x%.0f)" % STAND_FAST_SCALE)


func _huh_left() -> float:
	return maxf(0.0, float(_huh_until_ms - Time.get_ticks_msec()) / 1000.0)


func _begin_stand_fast() -> void:
	_set_tv(false)
	if _anim == null or _sit_clip == "":
		_finish_stand()
		return
	_act = _Act.STAND_UP
	_anim.play(_sit_clip, 0.2, -STAND_FAST_SCALE, true)


func _start_chase() -> void:
	if not _first_sight_done and _chase_roar and _chase_roar_set:
		_begin_warn()
		return
	_chase_pending = false
	_inv_pending = false
	_inv_look = false
	_investigating = false
	_route_idle = false
	_chasing = true
	_chase_hold = false
	_unseen_t = 0.0
	_repath_t = 0.0
	_breather_t = randf_range(BREATHER_MIN, BREATHER_MAX)
	_apply_clip_loops()
	_run_clip = _clip("run")
	if _hungover and _real_clip("drunk_run") != "":
		_run_clip = _real_clip("drunk_run")
	_relight_pending = false
	_fall_t = -1.0
	if _force_fall or randf() < FALL_CHANCE:
		_fall_t = randf_range(2.0, 6.0)
		print("[CHASE] fall rolled: in %.1f s%s" % [_fall_t, " (forced)" if _force_fall else ""])
	_force_fall = false
	print("[CHASE] start (run clip: %s)" % (_run_clip if _run_clip != "" else "walk x%.1f" % RUN_ANIM_FALLBACK_SCALE))
	if GameState != null and GameState.has_signal("tash_alert_changed"):
		GameState.tash_alert_changed.emit("chase")
	_act = _Act.WALK
	_sight_t = 0.0
	_graph_leg = false
	_graph_force_t = 0.0
	_wd_t = 0.0
	_wd_pos = global_position
	var roar := (_chase_roar and _chase_roar_set) or not _first_sight_done
	_chase_roar_set = false
	_chase_roar = false
	if roar:
		_begin_chase_hold("roar")
		return
	_chase_repath()


func _tick_chase(delta: float) -> void:
	if not _chasing:
		return
	if _vision_blocked_reason() == "dead" or _vision_blocked_reason() == "drunk":
		_chasing = false
		return
	if _anim != null:
		_anim.speed_scale = RUN_ANIM_FALLBACK_SCALE if (_act == _Act.WALK and _real_clip("run") == "") else 1.0
	if _chase_hold or _act != _Act.WALK:
		return
	if _fall_t > 0.0:
		_fall_t -= delta
		if _fall_t <= 0.0:
			_begin_chase_hold("fall")
			return
	if not (_seen or _los):
		_unseen_t += delta
		if _unseen_t > CHASE_LOSE_SEC:
			_chase_lost()
			return
	var p := _player()
	if p != null:
		var d := p.global_position - global_position
		if absf(d.y) < 1.5 and Vector2(d.x, d.z).length() < REACH_M:
			_begin_chase_hold("grab")
			return
	_breather_t -= delta
	if _breather_t <= 0.0:
		_begin_chase_hold("yell")
		return
	_chase_watchdog(delta)
	var want_graph := _chase_wants_graph()
	if want_graph != _graph_leg:
		_graph_leg = want_graph
		print("[CHASE] %s leg" % ("route-graph (stairs/floor change)" if want_graph else "navmesh"))
		_repath_t = 0.0
		if want_graph:
			_chase_repath()
		else:
			_route = []
			_route_i = 0
			_agent.target_position = _last_seen_world
	if _nav_ready and _agent != null and not _graph_leg:
		_repath_t -= delta
		if _repath_t <= 0.0:
			_repath_t = CHASE_REPATH_SEC
			_agent.target_position = _last_seen_world
		_nav_step(delta)
		return
	_repath_t -= delta
	if _repath_t <= 0.0:
		_repath_t = CHASE_REPATH_SEC
		# Graph leg: keep the current route unless it ran out or the target moved > 1 m
		# (re-routing every 0.5 s made him dither at the start node).
		if not _graph_leg or _route.is_empty() or _route_i >= _route.size() - 1 or _last_seen_world.distance_to(_graph_goal) > 1.0:
			_chase_repath()


func _chase_repath() -> void:
	if _nav_ready and _agent != null and not _graph_leg:
		_route = []
		_route_i = 0
		_active_stop = "chase"
		_agent.target_position = _last_seen_world
		return
	var route := _route_to(_last_seen_world)
	if route.is_empty():
		return
	_graph_goal = _last_seen_world
	_active_stop = "chase"
	_start_route(route)


func _route_to(world: Vector3) -> Array:
	if _path_follow == null or _path_space() == null:
		return []
	var here_local: Vector3 = _path_follow.position
	var goal_local: Vector3 = _path_space().to_local(world)
	var next_id := ""
	if _route_i + 1 < _route.size():
		next_id = String(_route[_route_i + 1])
	if _here.begins_with("nz_"):
		_here = ""
	_clear_inv_links()
	_pt["nz_here"] = here_local
	if absf(goal_local.y - here_local.y) < 0.3 and _line_clear(here_local, goal_local):
		goal_local.y = here_local.y
		_pt["nz_goal"] = goal_local
		_link("nz_goal", _nearest_node(goal_local))
		return ["nz_here", "nz_goal"]
	var start_id := ""
	if _nb.has(next_id) and not next_id.begins_with("nz_") and _line_clear(here_local, _pt[next_id] as Vector3):
		start_id = next_id
	else:
		start_id = _nearest_node(here_local)
	var end_id := _nearest_node(goal_local)
	var path := _shortest(start_id, end_id)
	if path.is_empty():
		return []
	var route: Array = []
	if here_local.distance_to(_pt[start_id] as Vector3) > 0.05:
		route.append("nz_here")
	route.append_array(path)
	var end_p: Vector3 = _pt[end_id] as Vector3
	if Vector2(goal_local.x - end_p.x, goal_local.z - end_p.z).length() > 0.3 and absf(goal_local.y - end_p.y) < 0.3 and _line_clear(end_p, goal_local):
		goal_local.y = end_p.y
		_pt["nz_goal"] = goal_local
		route.append("nz_goal")
		_link("nz_goal", end_id)
	_here = start_id
	return route


func _chase_lost() -> void:
	print("[CHASE] lost sight > %.1f s, searching the last seen spot" % CHASE_LOSE_SEC)
	_chasing = false
	_run_clip = ""
	if _anim != null:
		_anim.speed_scale = 1.0
	if GameState != null and GameState.has_signal("tash_alert_changed"):
		GameState.tash_alert_changed.emit("search")
	_inv_target_world = _last_seen_world
	_investigating = true
	_lost_search = true
	_start_investigation()


func _begin_chase_hold(kind: String, turn_key: String = "") -> void:
	_chase_hold = true
	_hold_kind = kind
	_act = _Act.IDLE
	_route_idle = false
	if _anim != null:
		_anim.speed_scale = 1.0
	var p := _player()
	if p != null and kind != "turn" and kind != "fall" and kind != "stumble":
		rotation = Vector3.ZERO
		_face_world_point(p.global_position)
	var clip := ""
	var sec := 0.0
	match kind:
		"roar":
			# One-shot start yell, cut by the timer (vision keeps tracking).
			clip = _clip("yell")
			sec = ROAR_SEC
			_roar_chunks = []
			if not _first_sight_done:
				_first_sight_done = true
				var set_lines: Array = FIRST_SIGHT_LINES[randi() % FIRST_SIGHT_LINES.size()]
				_roar_chunks = set_lines.duplicate()
				sec = minf(FIRST_SIGHT_CHUNK_SEC * _roar_chunks.size() + 0.3, FIRST_SIGHT_MAX_SEC)
				_show_roar_chunk()
			else:
				_show_yell_line()
		"yell":
			clip = _clip("yell")
			sec = YELL_SEC
			_show_yell_line()
		"grab":
			clip = _clip("grab")
			sec = GRAB_FALLBACK_SEC
			var d := 0.0
			if p != null:
				d = Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
			print("[CATCH] debug (flat %.2f m)" % d)
		"cool":
			clip = _clip("idle_2")
			sec = GRAB_COOLDOWN_SEC
		"turn":
			clip = _real_clip(turn_key)
			if clip == "":
				clip = _real_clip("turn_180")
		"fail":
			clip = _clip("fail")
			sec = FAIL_FALLBACK_SEC
			_show_fail_line()
		"taunt":
			clip = _real_clip("taunt")
			sec = 2.0
		"fall":
			clip = _real_clip("fall_flat")
			sec = 2.9
		"stumble":
			clip = _real_clip("drunk_stumble")
			sec = 1.5
	if clip != "" and _anim != null:
		var real := kind == "turn" or _real_clip({"yell": "yell", "roar": "yell", "grab": "grab", "fail": "fail", "cool": "idle_2", "taunt": "taunt", "fall": "fall_flat", "stumble": "drunk_stumble"}.get(kind, "")) != ""
		_force_loop(clip, Animation.LOOP_NONE if real and kind != "cool" else Animation.LOOP_LINEAR)
		_anim.play(clip)
		var a := _anim.get_animation(clip)
		if real and a != null and kind != "cool" and kind != "roar":
			sec = a.length
	_look_left = maxf(sec, 0.2)
	print("[CHASE] %s %.1f s (clip %s)" % [kind, _look_left, clip if clip != "" else "-"])


func _end_chase_hold() -> void:
	_chase_hold = false
	var kind := _hold_kind
	_hold_kind = ""
	_act = _Act.WALK
	rotation = Vector3.ZERO
	_apply_model_yaw_offset()
	if _look_clip != "":
		_force_loop(_look_clip, Animation.LOOP_NONE)
	match kind:
		"grab":
			_begin_chase_hold("cool")
		"cool", "yell", "roar":
			_breather_t = randf_range(BREATHER_MIN, BREATHER_MAX)
			if _chasing and (_seen or _los or _unseen_t <= CHASE_LOSE_SEC):
				_repath_t = 0.0
				_chase_repath()
			elif _chasing:
				_chase_lost()
		"turn":
			# Turn clips bake their yaw; the route already faces the new heading, so the
			# next locomotion pose (reset clip) lines up without a snap.
			_play_locomotion()
		"fail":
			if _hungover and _real_clip("taunt") != "" and randf() < 0.5:
				_begin_chase_hold("taunt")
			else:
				_end_fail_catch()
		"taunt":
			_end_fail_catch()
		"fall":
			_begin_fall_hold("lie")
		"lie":
			_begin_fall_hold("getup")
		"getup":
			print("[CHASE] got up")
			if _chasing and (_seen or _los):
				_repath_t = 0.0
				_chase_repath()
			elif _chasing:
				_chase_lost()
		"stumble", "rest":
			_play_locomotion()
		"pturn":
			_finish_inplace_turn()
		"relight":
			_relight_now()
			_begin_inv_look()


func _start_fail_catch() -> void:
	var p := _player()
	if p == null:
		return
	print("[CHASE] fail catch: she is safe")
	_fail_done = true
	_chasing = false
	_chase_pending = false
	_chase_hold = false
	_investigating = false
	_inv_look = false
	_inv_pending = false
	_run_clip = ""
	if _anim != null:
		_anim.speed_scale = 1.0
	_fail_walk = true
	var away := global_position - p.global_position
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.0001 else Vector3.FORWARD
	var target := p.global_position + away * FAIL_DIST_M
	target.y = global_position.y if absf(p.global_position.y - global_position.y) < 1.5 else p.global_position.y
	var route := _route_to(target)
	_active_stop = "failcatch"
	if route.size() <= 1:
		_begin_chase_hold("fail")
		return
	_start_route(route)
	_play_locomotion()


func _end_fail_catch() -> void:
	_fail_walk = false
	_last_stop = ""
	_active_stop = ""
	print("[CHASE] fail catch done, back to patrol")
	if GameState != null and GameState.has_signal("tash_alert_changed"):
		GameState.tash_alert_changed.emit("ambient")
	_choose_next()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F11 and (event as InputEventKey).shift_pressed:
		_force_fall = true
		print("[CHASE] debug: next chase will fall (2-6 s in)")
		if _chasing and _fall_t <= 0.0:
			_fall_t = randf_range(2.0, 6.0)
			_force_fall = false
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F11:
		_cone_on = not _cone_on
		if _cone_mi != null:
			_cone_mi.visible = _cone_on
		var pl := _player()
		if pl != null:
			_player_lit = _is_lit(pl.global_position + Vector3(0, 1.0, 0))
		print("[VISION] cone draw %s | seen=%s chasing=%s blocked=%s player %s nav=%s" % [_cone_on, _seen, _chasing, _vision_blocked_reason(), "LIT" if _player_lit else "DARK", _nav_ready])
		if _cone_on:
			_draw_cone()


func _draw_cone() -> void:
	if _cone_mi == null:
		_cone_mi = MeshInstance3D.new()
		_cone_mi.name = "TashVisionCone"
		_cone_mi.top_level = true
		_cone_mi.mesh = ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.no_depth_test = true
		_cone_mi.material_override = mat
		add_child(_cone_mi)
	_cone_mi.global_transform = Transform3D.IDENTITY
	var im := _cone_mi.mesh as ImmediateMesh
	im.clear_surfaces()
	var eye := _eye_pos()
	var fwd := _forward_flat()
	var rng := VIS_RANGE_M * (VIS_CROUCH_MUL if GameState != null and GameState.is_crouching else 1.0)
	if not _player_lit:
		rng *= DARK_RANGE_MUL
	var col := Color(1, 0.1, 0.1) if _seen else (Color(0.4, 0.4, 0.4) if _vision_blocked_reason() != "" else Color(1, 0.85, 0.2))
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var half := deg_to_rad(VIS_FOV_DEG * 0.5)
	var steps := 8
	var prev := Vector3.ZERO
	for i in steps + 1:
		var a := -half + (2.0 * half) * float(i) / float(steps)
		var tip := eye + fwd.rotated(Vector3.UP, a) * rng
		if i == 0 or i == steps:
			im.surface_set_color(col)
			im.surface_add_vertex(eye)
			im.surface_set_color(col)
			im.surface_add_vertex(tip)
		if i > 0:
			im.surface_set_color(col)
			im.surface_add_vertex(prev)
			im.surface_set_color(col)
			im.surface_add_vertex(tip)
		prev = tip
	im.surface_end()


# --- CHASE NAVMESH / QUICK TURN / DARKNESS ----------------------------------------------------
## Bake a NavigationRegion3D at runtime from static colliders (layers 1 | 8: walls, floors,
## stairs, furniture, couch blockers). Unlocked door leaves are switched off for the parse so
## doorways stay walkable; locked doors stay solid. Agent radius 0.3, height 1.8. Used for
## CHASE movement only; patrol / investigation keep the route graph.
func _setup_chase_nav() -> void:
	var root := _house_root()
	if root == null or not is_inside_tree():
		return
	var nm := NavigationMesh.new()
	nm.agent_radius = NAV_AGENT_RADIUS
	nm.agent_height = NAV_AGENT_HEIGHT
	nm.agent_max_climb = 0.35
	nm.agent_max_slope = 50.0
	nm.cell_size = NAV_CELL
	nm.cell_height = NAV_CELL_H
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1 | 8
	nm.region_min_size = 1.0
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, NAV_CELL)
	NavigationServer3D.map_set_cell_height(map, NAV_CELL_H)
	var off: Array = []
	for d in root.find_children("*", "Door", true, false):
		var door := d as CollisionObject3D
		if door != null and not bool(door.get("locked")):
			off.append([door, door.collision_layer])
			door.collision_layer = 0
	var src := NavigationMeshSourceGeometryData3D.new()
	var t0 := Time.get_ticks_msec()
	NavigationServer3D.parse_source_geometry_data(nm, src, root)
	for pair in off:
		(pair[0] as CollisionObject3D).collision_layer = int(pair[1])
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "TashChaseNav"
	_nav_region.navigation_mesh = nm
	root.add_child(_nav_region)
	_agent = NavigationAgent3D.new()
	_agent.name = "ChaseAgent"
	_agent.radius = NAV_AGENT_RADIUS
	_agent.height = NAV_AGENT_HEIGHT
	_agent.path_desired_distance = 0.3
	_agent.target_desired_distance = 0.5
	_agent.avoidance_enabled = false
	add_child(_agent)
	_nav_ready = nm.get_polygon_count() > 0
	print("[NAV] chase navmesh baked: %d polys in %d ms (ready=%s)" % [nm.get_polygon_count(), Time.get_ticks_msec() - t0, _nav_ready])
	for dw in root.find_children("*", "", true, false):
		if dw is Doorway:
			_doorways_cache.append(dw)


func _nav_step(delta: float) -> void:
	if _agent.is_navigation_finished():
		return
	var next := _agent.get_next_path_position()
	var d := next - global_position
	var flat := Vector3(d.x, 0.0, d.z)
	if flat.length() < 0.02:
		return
	# Face along the nav velocity with a fast smooth turn (no clips, no tween in chase);
	# slow down while the body is still turning so he never runs sideways/backwards.
	var cur_y := _path_follow.rotation.y
	var want_y := atan2(-flat.x, -flat.z)
	var new_y := rotate_toward(cur_y, cur_y + angle_difference(cur_y, want_y), CHASE_FACE_RAD_S * delta)
	var align := cos(absf(angle_difference(new_y, want_y)))
	var step := minf(_run_speed() * delta * clampf(align, 0.25, 1.0), flat.length())
	var new_w := global_position + flat.normalized() * step
	# Follow height on stairs only; navmesh sits a few cm above flat floors.
	if absf(d.y) > 0.12:
		new_w.y = move_toward(global_position.y, next.y, RUN_SPEED * delta)
	rotation = Vector3.ZERO
	_place(_path_space().to_local(new_w), Vector3(-sin(new_y), 0.0, -cos(new_y)))
	_open_doors_near()


## Big heading change (> 100 deg): tween the body yaw in place over 0.3 s, holding the
## current run / idle pose, then keep running forward. No turn clips, no backwards running.
func _begin_quick_turn(dir: Vector3) -> void:
	if _path_follow == null:
		return
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	rotation = Vector3.ZERO
	var from_y := _path_follow.rotation.y
	var to_y := from_y + angle_difference(from_y, atan2(-flat.x, -flat.z))
	_chase_hold = true
	_hold_kind = "turn"
	_act = _Act.IDLE
	_route_idle = false
	_look_left = QUICK_TURN_SEC
	var tw := create_tween()
	tw.tween_property(_path_follow, "rotation:y", to_y, QUICK_TURN_SEC)
	print("[CHASE] quick turn %.0f deg" % rad_to_deg(to_y - from_y))


func _open_doors_near() -> void:
	for dw_any in _doorways_cache:
		var dw := dw_any as Doorway
		if dw == null or not is_instance_valid(dw) or dw.locked:
			continue
		var c := dw.global_position + dw.global_transform.basis.z * 0.475
		if absf(c.y - global_position.y) > 1.5:
			continue
		if Vector2(c.x - global_position.x, c.z - global_position.z).length() < 1.1 and not dw.is_passage_open():
			dw.set_passage_open(true)
			print("[CHASE] opens ", dw.name)


## Lit = any visible Omni/Spot light above residual energy whose range reaches the point
## with a clear line (walls block). Switch-off leaves lights at 0.03 = dark.
func _is_lit(point: Vector3) -> bool:
	var root := _house_root()
	if root == null:
		return true
	if _lights_cache.is_empty():
		for l in root.find_children("*", "Light3D", true, false):
			if l is OmniLight3D or l is SpotLight3D:
				_lights_cache.append(l)
	var space := get_world_3d().direct_space_state
	for l_any in _lights_cache:
		var l := l_any as Light3D
		if l == null or not is_instance_valid(l) or not l.is_visible_in_tree() or l.light_energy <= LIT_MIN_ENERGY:
			continue
		var rng := 0.0
		if l is OmniLight3D:
			rng = (l as OmniLight3D).omni_range
		else:
			rng = (l as SpotLight3D).spot_range
		var lp := l.global_position
		# Same storey only: ceiling lights sit ~1-2.5 m above a standing chest point.
		if lp.y - point.y < -0.5 or lp.y - point.y > 2.6:
			continue
		if lp.distance_to(point) > rng:
			continue
		var q := PhysicsRayQueryParameters3D.create(lp, point)
		q.collision_mask = 1
		var hit := space.intersect_ray(q)
		if hit.is_empty() or (hit["position"] as Vector3).distance_to(point) < 0.3:
			if _cone_on:
				print("[VISION] lit by ", l.get_path())
			return true
	return false


# --- HUNGOVER / FALL / IN-PLACE TURNS / RELIGHT ----------------------------------------------
func _set_hungover() -> void:
	if _tash_dead or _hungover:
		return
	_hungover = true
	_stumble_t = randf_range(STUMBLE_MIN, STUMBLE_MAX)
	_apply_clip_loops()
	print("[HUNG] Tash is hungover: walk %.2f m/s, run %.1f m/s" % [HUNG_WALK_SPEED, HUNG_RUN_SPEED])


func is_hungover() -> bool:
	return _hungover


func _play_hung_idle() -> bool:
	if not _hungover or _anim == null:
		return false
	var pool: Array = []
	for k in ["drunk_idle", "drunk_idle_2"]:
		var c := _real_clip(String(k))
		if c != "":
			pool.append(c)
	if pool.is_empty():
		return false
	var pick := String(pool[randi() % pool.size()])
	_force_loop(pick, Animation.LOOP_LINEAR)
	var taunt := _real_clip("taunt")
	if taunt != "" and randf() < 0.15:
		# Hungover only: an occasional taunt_flex, then back to the drunk idle.
		_force_loop(taunt, Animation.LOOP_NONE)
		_anim.play(taunt, 0.25)
		_anim.queue(pick)
		return true
	_anim.play(pick, 0.25)
	return true


## Hungover walking: a drunk_stumble in place every 12-25 s (checked at route nodes).
func _maybe_stumble() -> bool:
	if not _hungover or _chasing or _stumble_t > 0.0:
		return false
	if _route_i < _route.size() - 1:
		var nxt := String(_route[_route_i + 1])
		if _is_stair_id(String(_route[_route_i])) or _is_stair_id(nxt) or _cross_door(String(_route[_route_i]), nxt) != "":
			return false
	_stumble_t = randf_range(STUMBLE_MIN, STUMBLE_MAX)
	if _real_clip("drunk_stumble") == "":
		return false
	_begin_chase_hold("stumble")
	return true


func _begin_fall_hold(kind: String) -> void:
	_chase_hold = true
	_hold_kind = kind
	_act = _Act.IDLE
	var clip := _real_clip("fall_flat")
	if kind == "lie":
		_look_left = FALL_LIE_SEC
		if _anim != null:
			_anim.pause()
	else:
		var a: Animation = _anim.get_animation(clip) if (_anim != null and clip != "") else null
		_look_left = (a.length / GETUP_SPEED) if a != null else 1.0
		if a != null:
			_anim.play(clip, 0.0, -GETUP_SPEED, true)
	print("[CHASE] %s %.1f s" % [kind, _look_left])


const USE_TURN_CLIPS := false
const WALK_FACE_RAD_S := 4.5
const TURN_RATE_RAD_S := 2.6
const TURN_MIN_SEC := 0.3


func _yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


## Patrol / investigation heading change > 60 deg at a route node or route start: play the
## nearest in-place turn clip (90 / 180, by direction; hungover: drunk_turn for left turns),
## rotate the node by the clip's baked yaw at the end, then tween the remainder (0.15 s).
func _maybe_inplace_turn() -> bool:
	if _chasing or _fail_walk or _path_follow == null or _route_i >= _route.size() - 1:
		return false
	var a: Vector3 = _pt[String(_route[_route_i])] as Vector3
	var b: Vector3 = _pt[String(_route[_route_i + 1])] as Vector3
	var nd := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if nd.length_squared() < 0.0001:
		return false
	var fwd := _forward_flat()
	var ang := fwd.signed_angle_to(nd.normalized(), Vector3.UP)
	if absf(rad_to_deg(ang)) <= INPLACE_TURN_DEG:
		return false
	var key := ""
	if _hungover:
		if ang > 0.0 and rad_to_deg(ang) < 135.0:
			key = "drunk_turn"
	elif rad_to_deg(absf(ang)) < 135.0:
		key = "turn_l90" if ang > 0.0 else "turn_r90"
	else:
		key = "turn_l180" if ang > 0.0 else "turn_r180"
	# Turn clips disabled (F5: start pose / end snap mismatch). Every patrol / investigate /
	# hungover heading change is a smooth in-place yaw over the normal idle animation.
	var clip := _real_clip(key) if (key != "" and USE_TURN_CLIPS) else ""
	_turn_from_yaw = _yaw_of(fwd)
	_turn_total_rad = ang
	rotation = Vector3.ZERO
	_path_follow.rotation.y = _turn_from_yaw
	_vis_corr_deg = 0.0
	_vis_corr0_deg = 0.0
	_apply_model_yaw_offset()
	_chase_hold = true
	_act = _Act.IDLE
	_route_idle = false
	if clip == "" or _anim == null:
		_turn_clip_rad = 0.0
		_hold_kind = "rest"
		var dur := maxf(TURN_MIN_SEC, absf(ang) / TURN_RATE_RAD_S)
		_look_left = dur
		if _anim != null and not _play_hung_idle():
			var idle := _clip("idle")
			_force_loop(idle, Animation.LOOP_LINEAR)
			_anim.play(idle, 0.25)
		var tw := create_tween()
		tw.tween_property(_path_follow, "rotation:y", _turn_from_yaw + ang, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(_apply_model_yaw_offset)
		print("[TURN] smooth yaw %.0f deg over %.2f s" % [rad_to_deg(ang), dur])
		return true
	_turn_clip_rad = deg_to_rad(float(_TURN_DEG[key]))
	_hold_kind = "pturn"
	_force_loop(clip, Animation.LOOP_NONE)
	_anim.play(clip, 0.0)
	var anim := _anim.get_animation(clip)
	_look_left = anim.length if anim != null else 0.9
	print("[TURN] %s for %.0f deg (clip %.1f)" % [clip, rad_to_deg(ang), _TURN_DEG[key]])
	return true


func _finish_inplace_turn() -> void:
	# Bake the clip's yaw into the node, reset the pose (walk / idle), tween the rest.
	_path_follow.rotation.y = _turn_from_yaw + _turn_clip_rad
	rotation = Vector3.ZERO
	_apply_model_yaw_offset()
	var rest := _turn_total_rad - _turn_clip_rad
	if absf(rad_to_deg(rest)) > 4.0:
		_chase_hold = true
		_hold_kind = "rest"
		_act = _Act.IDLE
		_look_left = TURN_REST_SEC
		_play_locomotion()
		create_tween().tween_property(_path_follow, "rotation:y", _turn_from_yaw + _turn_total_rad, TURN_REST_SEC)
		return
	_play_locomotion()


func _switch_near(pos: Vector3) -> Node3D:
	var root := _house_root()
	if root == null:
		return null
	var best: Node3D = null
	var best_d := 1.0
	for n in root.find_children("*", "LightSwitch", true, false):
		var sw := n as Node3D
		var d := sw.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = sw
	return best


func _begin_relight() -> void:
	if not _in_switch_room(_inv_switch):
		if _relight_retry < 2 and _path_via_navmesh(_switch_stand_point(_inv_switch)):
			_relight_retry += 1
			print("[NOISE] Tash is on the wrong side of %s, re-pathing (navmesh)" % _inv_switch.name)
			return
		print("[NOISE] Tash can't reach the room side of %s; skipping relight" % _inv_switch.name)
		_relight_pending = false
		_inv_switch = null
		_begin_inv_look()
		return
	_relight_pending = false
	_relight_done = false
	_relight_t = 0.0
	_route = []
	_route_i = 0
	_chase_hold = true
	_hold_kind = "relight"
	_act = _Act.IDLE
	_route_idle = false
	rotation = Vector3.ZERO
	_face_world_point(_inv_switch.global_position)
	var clip := _real_clip("light_switch")
	if clip != "" and _anim != null:
		_force_loop(clip, Animation.LOOP_NONE)
		_anim.play(clip)
		var anim := _anim.get_animation(clip)
		_look_left = anim.length if anim != null else 4.4
	else:
		_look_left = RELIGHT_FALLBACK_SEC
		_relight_t = RELIGHT_AT_SEC
		if _idle_stand_clips.size() > 0 and _anim != null:
			_anim.play(String(_idle_stand_clips[0]))
	print("[NOISE] Tash relights %s (clip %s)" % [_inv_switch.name, clip if clip != "" else "fallback idle"])


func _relight_now() -> void:
	if _relight_done:
		return
	_relight_done = true
	if _inv_switch != null and is_instance_valid(_inv_switch) and _inv_switch.has_method("set_lights_on_silent"):
		_inv_switch.call("set_lights_on_silent", true)
		print("[NOISE] Tash turned %s back on (silent)" % _inv_switch.name)
	_inv_switch = null


# --- SWITCH FILTER / RELIGHT ROOM SIDE / CHASE LOS ----------------------------------------
func _rays_clear(eye: Vector3, top: Vector3, chest: Vector3, p: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	var excl: Array[RID] = [get_rid()]
	if p is CollisionObject3D:
		excl.append((p as CollisionObject3D).get_rid())
	for target in [top, chest]:
		var q := PhysicsRayQueryParameters3D.create(eye, target)
		q.collision_mask = 1
		q.exclude = excl
		if space.intersect_ray(q).is_empty():
			return true
	return false


func _switch_name_of(source: String) -> String:
	var i := source.find(":")
	return source.substr(i + 1) if i >= 0 else ""


## "" = react. Always ignore the bathroom / Sabira / hidden switches. Tash on F1: ignore F2
## switches. Tash on F2: only Switch_Landing.
func _switch_ignore_reason(source: String, pos: Vector3) -> String:
	var sw_name := _switch_name_of(source)
	if sw_name == "":
		var near := _switch_near(pos)
		sw_name = String(near.name) if near != null else ""
	if SWITCH_ALWAYS_IGNORE.has(sw_name):
		return "%s is always ignored" % sw_name
	var tash_f2 := global_position.y > 1.5
	var switch_f2 := pos.y > 2.6
	if not tash_f2 and switch_f2:
		return "%s is on F2, Tash on F1" % sw_name
	if tash_f2 and not SWITCH_F2_ALLOWED.has(sw_name):
		return "Tash on F2 reacts only to Switch_Landing"
	return ""


func _switch_by_source(source: String, pos: Vector3) -> Node3D:
	var sw_name := _switch_name_of(source)
	var root := _house_root()
	if sw_name != "" and root != null:
		var n := root.get_node_or_null("LightSwitches/" + sw_name) as Node3D
		if n != null:
			return n
	return _switch_near(pos)


## Stand point 0.5 m in front of the plate on the side facing the room it lights (plate's thin
## axis = wall normal; sign toward the switch's first light), at that floor's height.
func _switch_stand_point(sw: Node3D) -> Vector3:
	var n := Vector3.FORWARD
	var plate := sw.get_node_or_null("Plate") as CSGBox3D
	if plate != null:
		var sz := plate.size
		var axis_i := 0
		if sz.y < sz[axis_i]:
			axis_i = 1
		if sz.z < sz[axis_i]:
			axis_i = 2
		n = plate.global_transform.basis[axis_i].normalized()
	n.y = 0.0
	n = n.normalized() if n.length_squared() > 0.0001 else Vector3.FORWARD
	var lights: Array = sw.get("_lights") if sw.get("_lights") != null else []
	var room_dir := Vector3.ZERO
	if lights.size() > 0 and is_instance_valid(lights[0]):
		room_dir = (lights[0] as Node3D).global_position - sw.global_position
	if room_dir.dot(n) < 0.0:
		n = -n
	var floor_y := 3.01 if sw.global_position.y > 2.6 else 0.0
	var sp := sw.global_position + n * 0.5
	return Vector3(sp.x, floor_y, sp.z)


## In the room: a clear line from his chest to the plate (only the switch itself may be hit)
## and he is on the room side of the plate.
func _in_switch_room(sw: Node3D) -> bool:
	if sw == null:
		return false
	var stand := _switch_stand_point(sw)
	var n := stand - sw.global_position
	n.y = 0.0
	var me := global_position - sw.global_position
	me.y = 0.0
	if me.dot(n) <= 0.0:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.3, 0), sw.global_position)
	q.collision_mask = 1
	var ex: Array[RID] = [get_rid()]
	if sw is CollisionObject3D:
		ex.append((sw as CollisionObject3D).get_rid())
	q.exclude = ex
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(sw.global_position) < 0.15


## Walk a navmesh path (walk speed) to world_goal as a temporary route; arrival -> investigate stop.
func _path_via_navmesh(world_goal: Vector3) -> bool:
	if not _nav_ready or _path_space() == null:
		return false
	var map := get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, global_position, world_goal, true)
	if path.size() < 2:
		return false
	_clear_inv_links()
	var ids: Array = []
	var sp := _path_space()
	for i in path.size():
		var id := "nz_p%d" % i
		var lp := sp.to_local(path[i])
		lp.y = global_position.y if absf(path[i].y - global_position.y) < 0.3 else lp.y
		_pt[id] = lp
		ids.append(id)
	_pt["nz_p0"] = _path_follow.position
	var last_id := String(ids[ids.size() - 1])
	_link(last_id, _nearest_node(_pt[last_id] as Vector3))
	_relight_pending = true
	_active_stop = "investigate"
	_start_route(ids)
	return true


# --- CHASE STAIRS LEG + STUCK WATCHDOG ---------------------------------------------------
## Root cause of the stair-top stuck: the baked navmesh has no connection between the stair
## polys and the F2 landing (stairwell ceiling/lip cuts it), so map paths ended at the stair
## top. Cross-floor chases (and anything the navmesh can't reach) use the route graph's stair
## edges (p6..p9) until he is on the target's floor and off the stairs.
func _chase_wants_graph() -> bool:
	if not _nav_ready or _agent == null:
		return true
	if _graph_force_t > 0.0:
		return true
	var y := global_position.y
	if y > 0.3 and y < 2.7:
		return true
	if absf(_last_seen_world.y - y) > 1.0:
		return true
	var path := NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, _last_seen_world, true)
	if path.size() == 0:
		return true
	var end: Vector3 = path[path.size() - 1]
	return Vector2(end.x - _last_seen_world.x, end.z - _last_seen_world.z).length() > 0.8 or absf(end.y - _last_seen_world.y) > 0.6


func _chase_watchdog(delta: float) -> void:
	if _graph_force_t > 0.0:
		_graph_force_t -= delta
	_wd_t += delta
	if _wd_t < STUCK_SEC:
		return
	var moved := global_position.distance_to(_wd_pos)
	var far := Vector2(_last_seen_world.x - global_position.x, _last_seen_world.z - global_position.z).length() > REACH_M + 0.3 or absf(_last_seen_world.y - global_position.y) > 1.0
	if moved < STUCK_MOVE_M and far:
		print("[CHASE] stuck watchdog at %s (moved %.2f m in %.1f s): re-path on the route graph" % [global_position.snappedf(0.01), moved, _wd_t])
		_graph_force_t = 3.0
		_graph_leg = true
		_chase_repath()
	_wd_t = 0.0
	_wd_pos = global_position

# --- BOOKSHELF IDLES ----------------------------------------------------------------------
## Plan 2-3 random shelf_idle clips across the stop (no back-to-back repeat). Looped clips
## loop until their slice ends; the one-shot nod plays once fully, only between two others.
func _start_shelf_idles() -> bool:
	if _anim == null or _hungover:
		return false
	var loops: Array = []
	for c in SHELF_LOOP_CLIPS:
		if _anim.has_animation(c):
			loops.append(c)
	if loops.size() < 2:
		return false
	var count := randi_range(2, 3)
	var names: Array = []
	var pool := loops.duplicate()
	pool.shuffle()
	for i in mini(count, pool.size()):
		names.append(pool[i])
	var nod_len := 0.0
	if names.size() == 3 and _anim.has_animation(SHELF_NOD_CLIP) and randf() < 0.5:
		names[1] = SHELF_NOD_CLIP
		nod_len = _anim.get_animation(SHELF_NOD_CLIP).length
	var rest := maxf(_look_left - nod_len, 1.0)
	var loop_n := names.size() - (1 if nod_len > 0.0 else 0)
	for n in names:
		_shelf_plan.append([n, nod_len if n == SHELF_NOD_CLIP else rest / float(loop_n)])
	print("[TASH] shelf idles: ", _shelf_plan)
	_play_shelf_slice()
	return true


func _play_shelf_slice() -> void:
	if _shelf_plan.is_empty() or _anim == null:
		return
	var clip := String(_shelf_plan[0][0])
	_shelf_slice = float(_shelf_plan[0][1])
	_force_loop(clip, Animation.LOOP_NONE if clip == SHELF_NOD_CLIP else Animation.LOOP_LINEAR)
	_anim.play(clip, 0.25)


## Random TASH chase caption, never the same one twice in a row.
func _show_yell_line() -> void:
	if _huh_left() > 0.0:
		get_tree().create_timer(_huh_left()).timeout.connect(_show_yell_line)
		return
	var i := randi() % _CHASE_YELL_LINES.size()
	if i == _last_yell_i:
		i = (i + 1 + randi() % (_CHASE_YELL_LINES.size() - 1)) % _CHASE_YELL_LINES.size()
	_last_yell_i = i
	get_tree().call_group("subtitle", "show_line", "TASH", String(_CHASE_YELL_LINES[i]), 2.6)


func _show_roar_chunk() -> void:
	if _roar_chunks.is_empty():
		return
	var line := String(_roar_chunks.pop_front())
	_roar_chunk_t = FIRST_SIGHT_CHUNK_SEC
	get_tree().call_group("subtitle", "show_line", "TASH", line, FIRST_SIGHT_CHUNK_SEC - 0.1)


func _show_fail_line() -> void:
	var zone := ""
	if GameState != null and GameState.has_method("is_safe_zone"):
		zone = String(GameState.is_safe_zone())
	var pool: Array = FAIL_CATCH_LINES_PEAS if zone == "peas" else (FAIL_CATCH_LINES_CHAIR if zone == "chair" else [])
	if pool.is_empty():
		return
	var pick := String(pool[randi() % pool.size()])
	if pick == _last_fail_line and pool.size() > 1:
		pick = String(pool[(pool.find(pick) + 1 + randi() % (pool.size() - 1)) % pool.size()])
	_last_fail_line = pick
	get_tree().call_group("subtitle", "show_line", "TASH", pick, 4.0)


# --- FIRST-SIGHT WARNING -------------------------------------------------------------------
## First routine sighting per run: no chase. He stops, tracks her, yells, then idle_aggressive
## (drunk idles when hungover) while the FIRST_SIGHT chunks play, then watches WARN_SEC more.
## Let go (ambient, routine resumes) if she is occluded WARN_OCCLUDED_SEC, enters Sabira's
## room, or becomes safe. Still visible when the time is up -> normal chase (no second yell).
func _begin_warn() -> void:
	_first_sight_done = true
	_chase_pending = false
	_chase_roar = false
	_chase_roar_set = false
	_inv_pending = false
	_warn = true
	_warn_occl_t = 0.0
	_route_idle = false
	_chase_hold = true
	_hold_kind = "warn"
	_act = _Act.IDLE
	rotation = Vector3.ZERO
	var set_lines: Array = FIRST_SIGHT_LINES[randi() % FIRST_SIGHT_LINES.size()]
	_roar_chunks = set_lines.duplicate()
	_warn_t = FIRST_SIGHT_CHUNK_SEC * _roar_chunks.size() + WARN_SEC
	_look_left = 999.0
	if _anim != null:
		_anim.speed_scale = 1.0
		var c := _real_clip("drunk_idle") if _hungover and _real_clip("drunk_idle") != "" else _clip("yell")
		if _hungover:
			_force_loop(c, Animation.LOOP_LINEAR)
		else:
			_force_loop(c, Animation.LOOP_NONE)
		_anim.play(c, 0.2)
	if _huh_left() > 0.0:
		_roar_chunk_t = _huh_left()
	else:
		_show_roar_chunk()
	if GameState != null and GameState.has_signal("tash_alert_changed"):
		GameState.tash_alert_changed.emit("search")
	print("[WARN] first sight: warning %.1f s (lines + %.0f s watch)" % [_warn_t, WARN_SEC])


func _tick_warn(delta: float) -> void:
	var p := _player()
	if p == null:
		_end_warn(false, "no player")
		return
	# Track her with a smooth yaw.
	var to := p.global_position - global_position
	to.y = 0.0
	if to.length_squared() > 0.0001 and _path_follow != null:
		var want := atan2(-to.x, -to.z)
		var cur := _path_follow.rotation.y
		_path_follow.rotation.y = rotate_toward(cur, cur + angle_difference(cur, want), WARN_FACE_RAD_S * delta)
		_apply_model_yaw_offset()
	if _roar_chunks.size() > 0:
		_roar_chunk_t -= delta
		if _roar_chunk_t <= 0.0:
			_show_roar_chunk()
	if _anim != null and not _anim.is_playing():
		var idle := _real_clip("idle_aggressive")
		if idle != "":
			_force_loop(idle, Animation.LOOP_LINEAR)
			_anim.play(idle, 0.25)
	if GameState != null and GameState.is_player_safe():
		_end_warn(false, "she is safe")
		return
	var pp := p.global_position
	if pp.x > SABIRA_ROOM_MIN.x and pp.x < SABIRA_ROOM_MAX.x and pp.y > SABIRA_ROOM_MIN.y and pp.y < SABIRA_ROOM_MAX.y and pp.z > SABIRA_ROOM_MIN.z and pp.z < SABIRA_ROOM_MAX.z:
		_end_warn(false, "she went to her room")
		return
	var cam := p.get("_camera") as Camera3D
	var top: Vector3 = cam.global_position if cam != null else pp + Vector3(0, 1.5, 0)
	var eye := _eye_pos()
	if _rays_clear(eye, top, top - Vector3(0, 0.55, 0), p):
		_warn_occl_t = 0.0
	else:
		_warn_occl_t += delta
		if _warn_occl_t >= WARN_OCCLUDED_SEC:
			_end_warn(false, "out of sight %.1f s" % _warn_occl_t)
			return
	_warn_t -= delta
	if _warn_t <= 0.0:
		_end_warn(true, "still visible")


func _end_warn(chase: bool, why: String) -> void:
	_warn = false
	_chase_hold = false
	_hold_kind = ""
	_roar_chunks = []
	rotation = Vector3.ZERO
	_apply_model_yaw_offset()
	print("[WARN] end: %s -> %s" % [why, "chase" if chase else "let it go"])
	if chase:
		var p := _player()
		if p != null:
			_last_seen_world = p.global_position
		_start_chase()
		return
	if GameState != null and GameState.has_signal("tash_alert_changed"):
		GameState.tash_alert_changed.emit("ambient")
	_sight_t = 0.0
	_act = _Act.WALK
	_choose_next()


# --- Sit / stand visual smoothing -------------------------------------------------------
## Sit and stand set the body yaw/position outright (approved seat facings stay exact). To
## hide the snap, the Model gets a temporary visual yaw/position correction equal to the
## jump, eased back to zero: yaw over 0.6-1.0 s, position over SETTLE_POS_SEC. For the F1
## couch the stand_to_sit clip holds its first frame until the yaw ease is done.
const SETTLE_POS_SEC := 0.25
const SETTLE_YAW_MIN_SEC := 0.6
const SETTLE_YAW_MAX_SEC := 1.0
var _vis_corr_deg: float = 0.0
var _vis_corr0_deg: float = 0.0
var _vis_corr_pos: Vector3 = Vector3.ZERO
var _vis_corr0_pos: Vector3 = Vector3.ZERO
var _sv_t: float = 0.0
var _vis_yaw_dur: float = 0.0
var _vis_hold_sit: bool = false
var _vis_pre_yaw: float = 0.0
var _vis_pre_pos: Vector3 = Vector3.ZERO


var _sv_skel: Skeleton3D = null
var _sv_hips: int = -1


## Visible facing = the hips bone forward (so clip poses such as stand_to_sit frame 0 are
## included), falling back to the Model forward.
func _vis_yaw_now() -> float:
	if _model == null:
		return 0.0
	if _sv_skel == null:
		_sv_skel = _model.find_child("*", true, false) as Skeleton3D
		var sks := _model.find_children("*", "Skeleton3D", true, false)
		_sv_skel = sks[0] as Skeleton3D if not sks.is_empty() else null
		if _sv_skel != null:
			for i in _sv_skel.get_bone_count():
				if _sv_skel.get_bone_name(i).ends_with("Hips"):
					_sv_hips = i
					break
	if _sv_skel != null and _sv_hips >= 0:
		var g: Transform3D = _sv_skel.global_transform * _sv_skel.get_bone_global_pose(_sv_hips)
		return atan2(g.basis.z.x, g.basis.z.z)
	var f := _model.global_transform.basis.z
	return atan2(f.x, f.z)


func _vis_capture() -> void:
	if _model == null:
		_model = get_node_or_null(model_node_path) as Node3D
	if _model == null:
		return
	_vis_pre_yaw = _vis_yaw_now()
	_vis_pre_pos = _model.global_position


func _reapply_visual() -> void:
	if _model == null or _tash_dead:
		return
	if _sit_kind == _SIT_COUCH and (_act == _Act.SIT_DOWN or _act == _Act.SIT_HOLD or _act == _Act.STAND_UP):
		_apply_couch_visual()
	elif _sit_kind == _SIT_OFFICE and _act == _Act.SIT_HOLD:
		_apply_office_visual()
	else:
		_apply_model_yaw_offset()


func _vis_settle(hold_sit_clip: bool) -> void:
	if _model == null or _tash_dead:
		return
	_vis_corr_deg = 0.0
	_vis_corr_pos = Vector3.ZERO
	_reapply_visual()
	var hold := hold_sit_clip and _anim != null and _anim.is_playing()
	if _anim != null:
		if hold:
			_anim.seek(0.0, true)
		else:
			_anim.advance(0.0)
	var d := rad_to_deg(angle_difference(_vis_yaw_now(), _vis_pre_yaw))
	var dp := _vis_pre_pos - _model.global_position
	if dp.length() > 1.5:
		dp = Vector3.ZERO
	_vis_corr0_deg = d if absf(d) > 1.0 else 0.0
	_vis_corr0_pos = dp if dp.length() > 0.01 else Vector3.ZERO
	_vis_corr_deg = _vis_corr0_deg
	_vis_corr_pos = _vis_corr0_pos
	_sv_t = 0.0
	_vis_yaw_dur = lerpf(SETTLE_YAW_MIN_SEC, SETTLE_YAW_MAX_SEC, clampf(absf(d) / 180.0, 0.0, 1.0)) if _vis_corr0_deg != 0.0 else 0.0
	_reapply_visual()
	_vis_hold_sit = false
	if hold and _vis_corr0_deg != 0.0:
		_anim.pause()
		_vis_hold_sit = true
	if _vis_corr0_deg != 0.0 or _vis_corr0_pos != Vector3.ZERO:
		print("[SIT] settle %.0f deg over %.2f s, %.2f m over %.2f s" % [d, _vis_yaw_dur, dp.length(), SETTLE_POS_SEC])


func _tick_vis_corr(delta: float) -> void:
	if _vis_corr_deg == 0.0 and _vis_corr_pos == Vector3.ZERO and not _vis_hold_sit:
		return
	_sv_t += delta
	var ky := 0.0
	if _vis_yaw_dur > 0.0:
		ky = 1.0 - smoothstep(0.0, 1.0, _sv_t / _vis_yaw_dur)
	var kp := 1.0 - smoothstep(0.0, 1.0, _sv_t / SETTLE_POS_SEC)
	_vis_corr_deg = _vis_corr0_deg * ky
	_vis_corr_pos = _vis_corr0_pos * kp
	if ky <= 0.0:
		_vis_corr_deg = 0.0
	if kp <= 0.0:
		_vis_corr_pos = Vector3.ZERO
	_reapply_visual()
	if _vis_hold_sit and _vis_corr_deg == 0.0:
		_vis_hold_sit = false
		if _anim != null and _act == _Act.SIT_DOWN:
			_anim.play()
