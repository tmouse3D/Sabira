# Godot 4.x - Sabira / HOUSE
class_name TashMouthCycle
extends Node
## Tash talking mouth: swaps the albedo of Body / Tash_Body_Mat surface 0 between
## props/tash_mouth/Tash_albedo_{closed,half,open}.png (blood_* after the stab).
## (MomMouthCycle toggles overlay meshes; Tash's face is in the albedo, so this swaps the texture
## on a material instance unique to this Tash instead.)
## Created by TashWalker._ready as child "TashMouthCycle". Single owner of Body surface 0:
## TashWalker._swap_blood_albedo skips that surface and calls set_blood(true).
## Speaking = a TASH caption is on screen (GameState.caption_changed from ui/Subtitle.gd).
## Talk: half/closed at ~8-10 fps with random timing. Loud (yell / roar clip playing, "Huh?!",
## first-sight lines, captions with "!"): mostly open, sometimes half. Silent: closed.
## Dead: closed (blood set).

const DIR := "res://props/tash_mouth/"
const MESH_NAME := "Body"
const SURFACE := 0
const LOUD_CLIPS := ["yell", "roar"]
const DEBUG_LOG := false

var _tex: Dictionary = {}
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _blood: bool = false
var _speaking_until_ms: int = 0
var _loud_caption: bool = false
var _frame: String = ""
var _next_t: float = 0.0
var _walker: Node
## Voice blip sync (autoload Voices): mouth opens on each TASH blip, closes between them.
var _voices: Node
var _blip_until_ms: int = 0
var _blip_loud: bool = false


func _ready() -> void:
	name = "TashMouthCycle"
	_walker = get_parent()
	for k in ["closed", "half", "open", "blood_closed", "blood_half", "blood_open"]:
		_tex[k] = load(DIR + "Tash_albedo_%s.png" % k) as Texture2D
	if GameState != null and GameState.has_signal("caption_changed"):
		GameState.caption_changed.connect(_on_caption)
	_voices = get_node_or_null("/root/Voices")
	if _voices != null and is_instance_valid(_voices) and _voices.has_signal("blip") and not _voices.blip.is_connected(_on_blip):
		_voices.blip.connect(_on_blip)
	call_deferred("_bind")


func _on_blip(speaker: String, loud: bool, sec: float) -> void:
	if speaker != "TASH" or _mat == null or _dead():
		return
	_blip_until_ms = Time.get_ticks_msec() + int(sec * 900.0)
	_blip_loud = loud
	if loud:
		_set_frame("open" if randf() < 0.8 else "half")
	else:
		_set_frame("half" if randf() < 0.8 else "open")


func _bind() -> void:
	_mesh = _walker.find_child(MESH_NAME, true, false) as MeshInstance3D if _walker else null
	if _mesh == null or _mesh.mesh == null or _mesh.mesh.get_surface_count() <= SURFACE:
		push_warning("TashMouthCycle: Body mesh not found; mouth off.")
		set_process(false)
		return
	var base := _mesh.get_active_material(SURFACE) as StandardMaterial3D
	if base == null:
		set_process(false)
		return
	_mat = base.duplicate() as StandardMaterial3D
	_mat.resource_local_to_scene = true
	_set_frame("closed", true)
	set_process(true)


func owns(mesh_inst: MeshInstance3D, surface: int) -> bool:
	return _mat != null and mesh_inst == _mesh and surface == SURFACE


## Stab: switch to the blood frames (stays owner of Body surface 0).
func set_blood(on: bool) -> void:
	_blood = on
	_set_frame(_frame if _frame != "" else "closed", true)


func _on_caption(speaker: String, text: String, duration: float) -> void:
	if speaker.to_upper() == "TASH" and text != "":
		_speaking_until_ms = Time.get_ticks_msec() + int(duration * 1000.0)
		_loud_caption = _is_loud_text(text)
		_next_t = 0.0
	else:
		# Another speaker replaced the caption (single label) or it was cleared.
		_speaking_until_ms = 0


func _is_loud_text(text: String) -> bool:
	if is_instance_valid(_voices) and _voices.has_method("is_loud_tash"):
		return _voices.is_loud_tash(text)
	if text.contains("!"):
		return true
	var fs = _walker.get("FIRST_SIGHT_LINES") if _walker else null
	if fs is Array:
		for chunk in fs:
			if chunk is Array and (chunk as Array).has(text):
				return true
	return false


func _clip_loud() -> bool:
	var ap := _walker.get("_anim") as AnimationPlayer if _walker else null
	if ap == null or not ap.is_playing():
		return false
	var cur := String(ap.current_animation).to_lower()
	for c in LOUD_CLIPS:
		if cur.contains(c):
			return true
	return false


func _dead() -> bool:
	return bool(_walker.get("_tash_dead")) if _walker else false


func _process(delta: float) -> void:
	if _mat == null:
		return
	# Keep ownership if anything else replaced the override on this surface.
	if _mesh.get_surface_override_material(SURFACE) != _mat:
		_mesh.set_surface_override_material(SURFACE, _mat)
	if _dead():
		_set_frame("closed")
		return
	var speaking := Time.get_ticks_msec() < _speaking_until_ms
	# Voice-driven: while TASH blips play, the mouth follows them exactly.
	if is_instance_valid(_voices) and speaking and _voices.current_speaker() == "TASH":
		if Time.get_ticks_msec() >= _blip_until_ms:
			_set_frame("closed")
		return
	if is_instance_valid(_voices) and speaking and not _clip_loud():
		# Caption still up but the voice has finished: keep the mouth shut.
		_set_frame("closed")
		return
	var loud := _clip_loud() or (speaking and _loud_caption)
	if not speaking and not loud:
		_set_frame("closed")
		return
	_next_t -= delta
	if _next_t > 0.0:
		return
	_next_t = randf_range(1.0 / 10.0, 1.0 / 8.0) * randf_range(0.8, 1.35)
	if loud:
		_set_frame("open" if randf() < 0.78 else "half")
	else:
		_set_frame("half" if _frame != "half" else ("closed" if randf() < 0.75 else "half"))


func _set_frame(f: String, force: bool = false) -> void:
	if _mat == null or (f == _frame and not force):
		return
	_frame = f
	var key := ("blood_" + f) if _blood else f
	var t := _tex.get(key) as Texture2D
	if t == null:
		return
	_mat.albedo_texture = t
	if _mesh.get_surface_override_material(SURFACE) != _mat:
		_mesh.set_surface_override_material(SURFACE, _mat)
	if DEBUG_LOG or OS.has_feature("mouth_log"):
		print("[MOUTH] %s" % key)


func current_key() -> String:
	return ("blood_" + _frame) if _blood else _frame


func _exit_tree() -> void:
	if is_instance_valid(_voices) and _voices.has_signal("blip") and _voices.blip.is_connected(_on_blip):
		_voices.blip.disconnect(_on_blip)
