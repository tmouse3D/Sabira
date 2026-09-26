# Godot 4.x - Sabira / HOUSE
class_name MomRestless
extends Node3D
## Prefer GLB idle_restless loop when present; bob fallback. Stops when carried.

@export var pos_amplitude_m: float = 0.012
@export var rot_amplitude_deg: float = 2.0
@export var bob_speed: float = 1.15
@export var idle_clip: String = "idle_restless"

var _home_pos: Vector3 = Vector3.ZERO
var _home_rot: Vector3 = Vector3.ZERO
var _t: float = 0.0
var _home_ready: bool = false
var _anim: AnimationPlayer = null
var _using_clip: bool = false
var _clip_path: String = ""


func _ready() -> void:
	add_to_group("mom_amina")
	_home_pos = position
	_home_rot = rotation
	_home_ready = true
	_t = randf() * TAU
	_ensure_mouth_cycle()
	# Defer so GLB AnimationPlayer children exist after instance ready.
	call_deferred("_try_bind_idle_clip")


func _ensure_mouth_cycle() -> void:
	# Stub: Mouth_Plea / Mouth_Scream / Mouth_Grimace (~5s). Fail soft if absent.
	if get_node_or_null("MomMouthCycle") != null:
		return
	var script := load("res://interact/MomMouthCycle.gd")
	if script == null:
		return
	var cycle: Node = script.new()
	cycle.name = "MomMouthCycle"
	add_child(cycle)


func _try_bind_idle_clip() -> void:
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		_using_clip = false
		return
	_clip_path = _resolve_clip_path(idle_clip)
	if _clip_path == "":
		_clip_path = _resolve_clip_path("idle_restless_body")
	if _clip_path == "":
		_using_clip = false
		push_warning("MomRestless: idle_restless clip missing; using bob fallback")
		return
	_using_clip = true
	var anim := _anim.get_animation(_clip_path)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR
	_play_idle()


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


func _play_idle() -> void:
	if not _using_clip or _anim == null or _clip_path == "":
		return
	if not _anim.has_animation(_clip_path):
		return
	_anim.play(_clip_path)


func _stop_idle() -> void:
	if _anim != null and _anim.is_playing():
		_anim.stop()


func _process(delta: float) -> void:
	if not _home_ready:
		return
	var carried := GameState != null and GameState.carrying_amina
	if carried or not visible:
		_stop_idle()
		return
	if _using_clip:
		if _anim != null and not _anim.is_playing():
			_play_idle()
		return
	# Bob fallback if GLB clip is missing.
	_t += delta * bob_speed
	var s := sin(_t)
	var c := cos(_t * 0.73)
	# Keep motion tiny so she never leaves bed bounds (~1.2 cm / few deg).
	position = _home_pos + Vector3(
		s * pos_amplitude_m * 0.55,
		absf(s) * pos_amplitude_m * 0.3,
		c * pos_amplitude_m * 0.45
	)
	rotation = _home_rot + Vector3(
		deg_to_rad(s * rot_amplitude_deg * 0.35),
		deg_to_rad(c * rot_amplitude_deg * 0.3),
		deg_to_rad(s * rot_amplitude_deg * 0.22)
	)


func snap_home() -> void:
	if not _home_ready:
		_home_pos = position
		_home_rot = rotation
		_home_ready = true
	_stop_idle()
	position = _home_pos
	rotation = _home_rot


func restore_to_bed_after_catch() -> void:
	visible = true
	snap_home()
	_play_idle()
