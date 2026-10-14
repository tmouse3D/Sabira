# Godot 4.x - Sabira / HOUSE
class_name Door
extends Interactable
## Simple door that rotates open/closed around its hinge (self origin).

@export var open_angle_deg: float = 90.0
@export var open_speed: float = 3.0
@export var starts_open: bool = false
@export var locked: bool = false
## Bible key id: "front_key" / "back_key" / "tash_room_key" / "cage_key" (empty = no key unlock).
@export var required_key: String = ""
@export var creak_stream: AudioStream
@export var locked_jiggle_stream: AudioStream
@export var creak_volume_db: float = -14.0
@export var jiggle_volume_db: float = -12.0

var _is_open: bool = false
var _target_yaw: float = 0.0
var _closed_yaw: float = 0.0
var _busy: bool = false
var _creak: AudioStreamPlayer3D
var _jiggle: AudioStreamPlayer3D

const LOCKED_LINE := "Locked."
const WRONG_KEY_LINE := "Wrong key."
const UNLOCKED_LINE := "Unlocked."
const LINE_DURATION := 2.0
## Keys removed on Unlock (tash_room_key stays - opens two doors).
const CONSUME_ON_UNLOCK := ["front_key", "cage_key"]
const ESCAPE_PROMPT := "[E] Get her out."
const LEAVE_PROMPT := "[E] Leave."
const ESCAPE_KEYS := ["front_key", "back_key"]


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	_closed_yaw = rotation.y
	_is_open = starts_open
	_target_yaw = _closed_yaw + deg_to_rad(open_angle_deg) if _is_open else _closed_yaw
	if _is_open:
		rotation.y = _target_yaw
	_ensure_creak_player()
	_ensure_jiggle_player()
	_update_prompt()


func _ensure_jiggle_player() -> void:
	_jiggle = get_node_or_null("JigglePlayer") as AudioStreamPlayer3D
	if _jiggle == null:
		_jiggle = AudioStreamPlayer3D.new()
		_jiggle.name = "JigglePlayer"
		_jiggle.max_distance = 12.0
		add_child(_jiggle)
	if locked_jiggle_stream == null:
		locked_jiggle_stream = load("res://audio/horror_sfx/Door_handle_jiggle_checking if locked.wav") as AudioStream
	_jiggle.stream = locked_jiggle_stream
	_jiggle.volume_db = jiggle_volume_db
	_jiggle.bus = &"Master"


func _ensure_creak_player() -> void:
	_creak = get_node_or_null("CreakPlayer") as AudioStreamPlayer3D
	if _creak == null:
		_creak = AudioStreamPlayer3D.new()
		_creak.name = "CreakPlayer"
		_creak.max_distance = 14.0
		add_child(_creak)
	if creak_stream == null:
		creak_stream = load("res://audio/horror_sfx/Door_squeeky_2.wav") as AudioStream
	if creak_stream == null:
		creak_stream = load("res://audio/sfx/door_creak.wav") as AudioStream
	_creak.stream = creak_stream
	_creak.volume_db = creak_volume_db
	_creak.bus = &"Master"


## Re-apply hinge state after a parent (e.g. Doorway) overrides exports post-_ready.
func configure_from_parent(p_open_angle_deg: float, p_starts_open: bool, p_locked: bool, p_required_key: String = "") -> void:
	open_angle_deg = p_open_angle_deg
	starts_open = p_starts_open
	locked = p_locked
	required_key = p_required_key
	_is_open = starts_open
	_target_yaw = _closed_yaw + deg_to_rad(open_angle_deg) if _is_open else _closed_yaw
	rotation.y = _target_yaw
	_update_prompt()


func _physics_process(delta: float) -> void:
	var current := rotation.y
	if absf(wrapf(current - _target_yaw, -PI, PI)) < 0.01:
		rotation.y = _target_yaw
		_busy = false
		if not _is_open:
			_set_leaf_solid(true)
		elif collision_layer == 0:
			# Opened by Tash (set_passage_open drops collision): once settled, stay
			# interactable for the player (layer 4 = interact ray only, not solid).
			_set_leaf_interact_only()
		return
	_busy = true
	rotation.y = lerp_angle(current, _target_yaw, clampf(open_speed * delta, 0.0, 1.0))


## Scripted passage (Tash). Same hinge target as player interact. Ignores the lock.
## Opening drops leaf collision immediately. Closing restores it once the hinge settles.
func set_passage_open(want_open: bool) -> void:
	_is_open = want_open
	if want_open:
		_target_yaw = _closed_yaw + deg_to_rad(open_angle_deg)
	else:
		_target_yaw = _closed_yaw
	_set_leaf_solid(false)
	_play_creak()
	_update_prompt()


func is_passage_open() -> bool:
	if not _is_open:
		return false
	return absf(wrapf(rotation.y - _target_yaw, -PI, PI)) < 0.08


## Player interact only. Tash set_passage_open ignores this flag.
func set_player_locked(want_locked: bool) -> void:
	locked = want_locked
	_update_prompt()


func _set_leaf_interact_only() -> void:
	collision_layer = 4
	for child in find_children("*", "CollisionShape3D", true, false):
		var shape := child as CollisionShape3D
		if shape:
			shape.disabled = false


func _set_leaf_solid(solid: bool) -> void:
	collision_layer = 5 if solid else 0
	for child in find_children("*", "CollisionShape3D", true, false):
		var shape := child as CollisionShape3D
		if shape:
			shape.disabled = not solid


func can_interact(_player: Node) -> bool:
	# Locked doors still show "[E] Unlock" and accept E (subtitle / unlock).
	return interact_enabled


func _is_escape_exit() -> bool:
	return required_key in ESCAPE_KEYS


func _carrying_amina() -> bool:
	return GameState != null and GameState.carrying_amina


## Ending only through an exit that is already unlocked (front_key / back_key used first).
## Amina is optional: alone = "[E] Leave.", carrying her = "[E] Get her out.".
func _can_escape_here() -> bool:
	return _is_escape_exit() and not locked


func _exit_name() -> String:
	return "back" if required_key == "back_key" else "front"


func get_prompt() -> String:
	if GameState != null and GameState.ending_reached != "":
		return ""
	if _can_escape_here():
		return ESCAPE_PROMPT if _carrying_amina() else LEAVE_PROMPT
	return prompt_text if interact_enabled else ""



func _has_required_key() -> bool:
	if required_key.is_empty() or GameState == null:
		return false
	return GameState.has_inventory_flag(required_key)


func _player_has_any_other_key() -> bool:
	if GameState == null:
		return false
	for flag in ["front_key", "back_key", "tash_room_key", "cage_key", "key"]:
		if flag == required_key:
			continue
		if GameState.has_inventory_flag(flag):
			return true
	return false


func _consume_key_if_needed() -> void:
	if GameState == null or required_key.is_empty():
		return
	if required_key in CONSUME_ON_UNLOCK:
		GameState.remove_inventory_flag(required_key)

var _prologue_said: bool = false


## Front door, first interaction: market_silent line once, after the door's own caption.
func _prologue_door_line() -> void:
	if _prologue_said or required_key != "front_key" or GameState == null:
		return
	_prologue_said = true
	var alt: Array = GameState.prologue_line("front_door_look")
	if alt.is_empty():
		return
	get_tree().create_timer(LINE_DURATION + 0.2).timeout.connect(func() -> void:
		if GameState.ending_reached != "":
			return
		get_tree().call_group("subtitle", "show_line", String(alt[0]), String(alt[1]), 4.0)
		print("[PROLOGUE] front door line: ", alt[1]))


func _on_interact(_player: Node) -> void:
	_prologue_door_line()
	# Ending: opening an unlocked front/back exit (with or without Mum) -> GameState ending card.
	# Locked exit falls through to the lock check below (needs front_key / back_key).
	if _can_escape_here():
		if GameState == null or GameState.ending_reached != "":
			return
		if not _is_open:
			_is_open = true
			_target_yaw = _closed_yaw + deg_to_rad(open_angle_deg)
			_play_creak()
		GameState.trigger_escape_win(_exit_name())
		return
	if locked:
		if _has_required_key():
			locked = false
			# Exit doors unlock but stay shut: the next [E] (Leave / Get her out) is the ending.
			if not _is_escape_exit():
				_is_open = true
				_target_yaw = _closed_yaw + deg_to_rad(open_angle_deg)
				_play_creak()
			_consume_key_if_needed()
			get_tree().call_group("subtitle", "show_line", "SABIRA", UNLOCKED_LINE, LINE_DURATION)
			_update_prompt()
			return
		_play_jiggle()
		var line := WRONG_KEY_LINE if _player_has_any_other_key() else LOCKED_LINE
		get_tree().call_group("subtitle", "show_line", "SABIRA", line, LINE_DURATION)
		return
	_is_open = not _is_open
	_target_yaw = _closed_yaw + deg_to_rad(open_angle_deg) if _is_open else _closed_yaw
	_play_creak()
	_update_prompt()
	if GameState:
		GameState.note_door_toggle(global_position, String(get_parent().name) if get_parent() else String(name))


func _play_jiggle() -> void:
	if _jiggle == null:
		_ensure_jiggle_player()
	if _jiggle and _jiggle.stream:
		_jiggle.pitch_scale = randf_range(0.95, 1.05)
		_jiggle.volume_db = jiggle_volume_db + randf_range(-1.0, 0.5)
		_jiggle.play()


func _play_creak() -> void:
	if _creak == null:
		_ensure_creak_player()
	if _creak and _creak.stream:
		_creak.pitch_scale = randf_range(0.78, 0.92)
		_creak.volume_db = creak_volume_db + randf_range(-1.5, 0.5)
		_creak.play()


func _update_prompt() -> void:
	# Escape prompt is resolved live in get_prompt(); prompt_text always mirrors lock/open state.
	if locked:
		prompt_text = "[E] Unlock"
	elif _is_open:
		prompt_text = "[E] Close"
	else:
		prompt_text = "[E] Open"
