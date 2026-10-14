# Godot 4.x - Sabira / HOUSE
class_name RadioToggle
extends Interactable
## Living-room radio (radio_lure 2026-10-14). Child of the Radio prop body (HorrorProps).
## [E] Turn on / off: looping static (audio/sfx/radio_static.wav, AudioStreamPlayer3D).
## Turning it on tells TashWalker.radio_noise(self) (he chases / comes / parks it pending /
## ignores it). The radio itself is never gated: always interactable, static always plays.
## radio_dark fix: the old _ready() also connected `interacted` to _on_interact, and
## Interactable.interact() emits that signal AND calls _on_interact -> every [E] ran twice
## (on, then straight back off).

const STATIC_SFX := "res://audio/sfx/radio_static.wav"
const STATIC_DB := -6.0
const STATIC_UNIT_SIZE := 5.0
const STATIC_MAX_DIST := 14.0
const PROMPT_ON := "[E] Turn on radio"
const PROMPT_OFF := "[E] Turn off radio"
## Tash stand spot: this far in front of the radio (its +Z = into the room), on the floor.
const STAND_DIST := 0.6

var floor_y: float = 0.0
var _on: bool = false
var _audio: AudioStreamPlayer3D = null


func setup(size: Vector3, floor_height: float) -> void:
	floor_y = floor_height
	collision_layer = 4
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size + Vector3(0.04, 0.04, 0.04)
	cs.shape = bs
	cs.position = Vector3(0, size.y * 0.5, 0)
	add_child(cs)
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "Static"
	var st := load(STATIC_SFX) as AudioStreamWAV
	if st != null:
		st = st.duplicate() as AudioStreamWAV
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = int(st.get_length() * st.mix_rate)
	_audio.stream = st
	_audio.volume_db = STATIC_DB
	_audio.unit_size = STATIC_UNIT_SIZE
	_audio.max_distance = STATIC_MAX_DIST
	_audio.position = Vector3(0, size.y * 0.5, 0)
	add_child(_audio)
	_update_prompt()


func _ready() -> void:
	# Interactable.interact() already calls _on_interact(); do not also connect `interacted`.
	_update_prompt()


func _update_prompt() -> void:
	prompt_text = PROMPT_OFF if _on else PROMPT_ON


func is_on() -> bool:
	return _on


func set_on(on: bool) -> void:
	_on = on
	if _audio != null:
		if on and not _audio.playing:
			_audio.play()
		elif not on:
			_audio.stop()
	_update_prompt()
	print("[RADIO] %s (playing=%s)" % ["on" if on else "off", _audio.playing if _audio != null else false])


func _on_interact(_player: Node) -> void:
	set_on(not _on)
	if not _on:
		return
	if _audio == null or _audio.stream == null or not _audio.is_inside_tree():
		push_warning("RadioToggle: static player not ready (stream %s)" % (_audio.stream if _audio else null))
	var tash := get_tree().get_first_node_in_group("tash")
	if tash != null and tash.has_method("radio_noise"):
		print("[RADIO] Tash: %s" % String(tash.call("radio_noise", self)))


## Tash reached the stand spot and reached out (TashWalker._relight_now).
func tash_turn_off() -> void:
	if _on:
		set_on(false)
	print("[RADIO] Tash switched it off")


func stand_point() -> Vector3:
	var f := global_transform.basis.z
	f.y = 0.0
	f = f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD
	var p := global_position + f * STAND_DIST
	return Vector3(p.x, floor_y, p.z)