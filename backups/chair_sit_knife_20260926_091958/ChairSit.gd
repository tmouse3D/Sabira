# Godot 4.x - Sabira / HOUSE
class_name ChairSit
extends Interactable
## Sit: teleport player to SitPose Marker3D; interact again to stand.

@export var sit_prompt: String = "[E] Sit"
@export var stand_prompt: String = "[E] Stand up"
@export var click_stream: AudioStream
@export var click_volume_db: float = -18.0

var sit_pose: Marker3D
var _occupant: Node = null
var _click_sfx: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	_ensure_sit_pose()
	_ensure_click_player()


func _ensure_sit_pose() -> void:
	sit_pose = get_node_or_null("SitPose") as Marker3D
	if sit_pose != null:
		return
	sit_pose = Marker3D.new()
	sit_pose.name = "SitPose"
	# Body origin is ~seat-box center (y~0.45); drop to floor for CharacterBody3D feet.
	# Slight +Z local nudge toward seat front (away from backrest when body faces -Z).
	sit_pose.position = Vector3(0.0, -0.42, 0.12)
	# Landing/TashOffice bodies use identity rotation while mesh sibling is yawed.
	var sibling_name := String(name).replace("Body", "")
	var parent_n := get_parent()
	if parent_n != null and sibling_name != String(name):
		var mesh_n := parent_n.get_node_or_null(sibling_name) as Node3D
		if mesh_n != null:
			sit_pose.rotation.y = mesh_n.global_rotation.y - global_rotation.y
	add_child(sit_pose)


func _ensure_click_player() -> void:
	_click_sfx = get_node_or_null("ClickPlayer") as AudioStreamPlayer3D
	if _click_sfx == null:
		_click_sfx = AudioStreamPlayer3D.new()
		_click_sfx.name = "ClickPlayer"
		_click_sfx.max_distance = 10.0
		add_child(_click_sfx)
	if click_stream == null:
		click_stream = load("res://audio/sfx/ui_soft_click.wav") as AudioStream
	_click_sfx.stream = click_stream
	_click_sfx.volume_db = click_volume_db
	_click_sfx.bus = &"Master"


func _play_click() -> void:
	if _click_sfx == null:
		_ensure_click_player()
	if _click_sfx and _click_sfx.stream:
		_click_sfx.pitch_scale = randf_range(0.96, 1.04)
		_click_sfx.volume_db = click_volume_db + randf_range(-1.0, 0.5)
		_click_sfx.play()


func can_interact(_player: Node) -> bool:
	if not interact_enabled:
		return false
	if GameState != null and GameState.carrying_amina:
		return false
	return true


func get_prompt() -> String:
	if _occupant != null and is_instance_valid(_occupant):
		return stand_prompt
	return sit_prompt


func is_occupied_by(player: Node) -> bool:
	return _occupant != null and _occupant == player


func clear_occupant() -> void:
	_occupant = null


func _on_interact(player: Node) -> void:
	if player == null:
		return
	if _occupant == player:
		if player.has_method("end_sit"):
			player.end_sit()
		return
	if sit_pose == null:
		_ensure_sit_pose()
	if sit_pose == null:
		push_warning("ChairSit '%s': missing SitPose" % name)
		return
	if player.has_method("begin_sit"):
		_play_click()
		player.begin_sit(self, sit_pose.global_transform)
		if player.has_method("is_sitting") and player.is_sitting():
			_occupant = player
