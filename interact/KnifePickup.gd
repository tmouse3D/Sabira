# Godot 4.x - Sabira / HOUSE
class_name KnifePickup
extends Interactable
## Knife take + return-to-spawn only (kitchen table / knife spawn).
## Empty: [E] Take knife -> Took the knife.
## Holding: [E] Put the knife back. -> Left the knife. (frees slot, respawns mesh)

@export var take_line: String = "Took the knife."
@export var return_line: String = "Left the knife."
@export var line_duration: float = 2.0
@export var take_prompt: String = "[E] Take knife"
@export var return_prompt: String = "[E] Put the knife back."
@export var take_stream: AudioStream
@export var take_volume_db: float = -18.0

var _take_sfx: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	_ensure_take_player()
	if GameState and GameState.has_knife:
		_consume_visual()
	else:
		_restore_visual()
	_refresh_prompt()


func can_interact(_player: Node) -> bool:
	return interact_enabled and GameState != null


func get_prompt() -> String:
	if GameState == null:
		return ""
	if GameState.has_knife:
		return return_prompt
	return take_prompt


func _ensure_take_player() -> void:
	_take_sfx = get_node_or_null("TakePlayer") as AudioStreamPlayer3D
	if _take_sfx == null:
		_take_sfx = AudioStreamPlayer3D.new()
		_take_sfx.name = "TakePlayer"
		_take_sfx.max_distance = 10.0
		add_child(_take_sfx)
	if take_stream == null:
		take_stream = load("res://audio/sfx/ui_soft_click.wav") as AudioStream
	_take_sfx.stream = take_stream
	_take_sfx.volume_db = take_volume_db
	_take_sfx.bus = &"Master"


func _play_take_sfx() -> void:
	if _take_sfx == null:
		_ensure_take_player()
	if _take_sfx and _take_sfx.stream:
		_take_sfx.pitch_scale = randf_range(0.96, 1.04)
		_take_sfx.volume_db = take_volume_db + randf_range(-1.0, 0.5)
		_take_sfx.play()


func _on_interact(_player: Node) -> void:
	if GameState == null:
		return
	if GameState.has_knife:
		_return_knife()
	else:
		_take_knife()


func _take_knife() -> void:
	if GameState.has_knife:
		return
	# Capacity first: full => Can't carry more. (GameState); knife stays in world.
	if not GameState.add_inventory_flag("knife"):
		return
	_play_take_sfx()
	get_tree().call_group("subtitle", "show_line", "SABIRA", take_line, line_duration)
	_consume_visual()
	_refresh_prompt()


func _return_knife() -> void:
	if not GameState.has_knife:
		return
	if not GameState.remove_inventory_flag("knife"):
		return
	_play_take_sfx()
	_restore_visual()
	if not return_line.is_empty():
		get_tree().call_group("subtitle", "show_line", "SABIRA", return_line, line_duration)
	_refresh_prompt()


func _consume_visual() -> void:
	visible = false
	for c in get_children():
		if c is CollisionShape3D:
			continue
		if c is Node3D:
			(c as Node3D).visible = false


func _restore_visual() -> void:
	visible = true
	for c in get_children():
		if c is CollisionShape3D:
			continue
		if c is Node3D:
			(c as Node3D).visible = true


func _refresh_prompt() -> void:
	prompt_text = get_prompt()
