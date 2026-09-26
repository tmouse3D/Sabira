# Godot 4.x - Sabira / HOUSE
class_name DoseBottle
extends Interactable
## Living wine bottle near F1 couch. With pills: dose bottle, strip pills, set bottle_dosed.
## No pills: no prompt. Already dosed: Already done.

@export var dose_prompt: String = "[E] Put pills in the bottle."
@export var dose_line: String = "Dosed the bottle."
@export var already_line: String = "Already done."
@export var line_duration: float = 2.5
@export var dose_stream: AudioStream
@export var dose_volume_db: float = -18.0

var _dose_sfx: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	_ensure_sfx()
	_refresh_prompt()
	if GameState != null and not GameState.inventory_changed.is_connected(_on_inv):
		GameState.inventory_changed.connect(_on_inv)


func _on_inv() -> void:
	_refresh_prompt()


func _ensure_sfx() -> void:
	_dose_sfx = get_node_or_null("DosePlayer") as AudioStreamPlayer3D
	if _dose_sfx == null:
		_dose_sfx = AudioStreamPlayer3D.new()
		_dose_sfx.name = "DosePlayer"
		_dose_sfx.max_distance = 10.0
		add_child(_dose_sfx)
	if dose_stream == null:
		dose_stream = load("res://audio/sfx/ui_soft_click.wav") as AudioStream
	_dose_sfx.stream = dose_stream
	_dose_sfx.volume_db = dose_volume_db
	_dose_sfx.bus = &"Master"


func _play_sfx() -> void:
	if _dose_sfx == null:
		_ensure_sfx()
	if _dose_sfx and _dose_sfx.stream:
		_dose_sfx.pitch_scale = randf_range(0.96, 1.04)
		_dose_sfx.volume_db = dose_volume_db + randf_range(-1.0, 0.5)
		_dose_sfx.play()


func _refresh_prompt() -> void:
	if GameState == null:
		prompt_text = ""
		interact_enabled = false
		return
	if GameState.bottle_dosed:
		prompt_text = "[E] Look"
		interact_enabled = true
		return
	if GameState.has_pills:
		prompt_text = dose_prompt
		interact_enabled = true
		return
	# No pills: no prompt (Look-only would still clutter - hide).
	prompt_text = ""
	interact_enabled = false


func can_interact(_player: Node) -> bool:
	if GameState == null:
		return false
	if GameState.bottle_dosed:
		return interact_enabled
	return interact_enabled and GameState.has_pills


func get_prompt() -> String:
	if not can_interact(null):
		return ""
	if GameState != null and GameState.bottle_dosed:
		return "[E] Look"
	return dose_prompt


func _on_interact(_player: Node) -> void:
	if GameState == null:
		return
	if GameState.bottle_dosed:
		get_tree().call_group("subtitle", "show_line", "SABIRA", already_line, line_duration)
		return
	if not GameState.has_pills:
		_refresh_prompt()
		return
	if not GameState.remove_inventory_flag("pills"):
		return
	GameState.bottle_dosed = true
	_play_sfx()
	get_tree().call_group("subtitle", "show_line", "SABIRA", dose_line, line_duration)
	_refresh_prompt()