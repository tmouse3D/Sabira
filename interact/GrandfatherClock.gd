# Godot 4.x - Sabira / HOUSE
class_name GrandfatherClock
extends Interactable
## F2 closet grandfather clock (clock puzzle -> tash_room_key).
## Shows GameState.clock_hour:clock_minute with its own hand meshes (the baked hands were
## painted out of props/grandfather_clock/gfc_albedo_grimy.png). [E] Set the clock opens
## ui/ClockSetUI.gd; matching the pocket watch time (GameState.watch_hour / watch_minute,
## 12-hour) closes it, chimes, and puts tash_room_key in the carry slots.
## Carry full, or catch-1 stripped the key: GameState.clock_key_waiting -> [E] Take key here.
## Solved only once. Quiet looping tick (TickPlayer) at the clock.
## Minute-hand gate: the long hand starts missing (MinutePivot hidden). [E] Put back the hand
## with minute_hand carried reattaches it (GameState.place_minute_hand); only then Set the clock.
## First aim at the clock (get_prompt) or entering IntroArea says intro_line once per run.

const ClockSetUIScript := preload("res://ui/ClockSetUI.gd")

@export var set_prompt: String = "[E] Set the clock"
@export var take_prompt: String = "[E] Take key"
@export var look_prompt: String = "[E] Look"
@export var key_line: String = "Something clicked inside the clock. A key."
@export var take_line: String = "The key from the clock."
@export var look_line: String = "It shows his time now. It still feels wrong."
@export var put_back_prompt: String = "[E] Put back the hand"
@export var missing_prompt: String = "[E] Look"
@export var missing_line: String = "The long hand is missing. It's somewhere in the house... maybe the couches, or the drawers."
@export var put_back_line: String = "There. It fits."
@export var intro_line: String = "That clock... it's not ticking right. Something's stuck in it."
@export var intro_area_path: NodePath = NodePath("IntroArea")
@export var line_duration: float = 3.0
@export var albedo: Texture2D
@export var model_path: NodePath = NodePath("Model")
@export var hour_pivot_path: NodePath = NodePath("Hands/HourPivot")
@export var minute_pivot_path: NodePath = NodePath("Hands/MinutePivot")
@export var key_mesh_path: NodePath = NodePath("KeyMesh")
@export var tick_path: NodePath = NodePath("TickPlayer")
@export var chime_path: NodePath = NodePath("ChimePlayer")

var _ui: Node = null
var _just_solved: bool = false
var _hour_pivot: Node3D
var _minute_pivot: Node3D
var _key_mesh: Node3D


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	prompt_text = set_prompt
	add_to_group("grandfather_clock")
	_hour_pivot = get_node_or_null(hour_pivot_path) as Node3D
	_minute_pivot = get_node_or_null(minute_pivot_path) as Node3D
	_key_mesh = get_node_or_null(key_mesh_path) as Node3D
	_apply_grime_material()
	if GameState != null:
		GameState.ensure_clock_times()
		if not GameState.inventory_changed.is_connected(refresh_key_state):
			GameState.inventory_changed.connect(refresh_key_state)
	_update_hands()
	refresh_key_state()
	var area := get_node_or_null(intro_area_path) as Area3D
	if area != null and not area.body_entered.is_connected(_on_intro_body_entered):
		area.body_entered.connect(_on_intro_body_entered)
	var tick := get_node_or_null(tick_path) as AudioStreamPlayer3D
	if tick != null and tick.stream != null and not tick.playing:
		tick.play()


func _apply_grime_material() -> void:
	var model := get_node_or_null(model_path)
	if model == null or albedo == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = albedo
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat


func _hand_placed() -> bool:
	return GameState != null and GameState.minute_hand_state == "placed"


func _on_intro_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("player"):
		_say_intro()


func _say_intro() -> void:
	if GameState == null or GameState.clock_intro_said:
		return
	GameState.clock_intro_said = true
	get_tree().call_group("subtitle", "show_line", "SABIRA", intro_line, line_duration + 1.0)


func _update_hands() -> void:
	if GameState == null:
		return
	if _minute_pivot != null:
		_minute_pivot.visible = _hand_placed()
	var h: int = GameState.clock_hour
	var m: int = GameState.clock_minute
	# Pivots spin around their local +Z (the face normal); hands point local +Y at 12.
	if _minute_pivot != null:
		_minute_pivot.rotation = Vector3(0.0, 0.0, -float(m) / 60.0 * TAU)
	if _hour_pivot != null:
		_hour_pivot.rotation = Vector3(0.0, 0.0, -(float(h % 12) + float(m) / 60.0) / 12.0 * TAU)


func refresh_key_state() -> void:
	if _key_mesh != null and GameState != null:
		_key_mesh.visible = GameState.clock_key_waiting and not GameState.has_inventory_flag("tash_room_key")


func _ui_open() -> bool:
	return _ui != null and is_instance_valid(_ui) and bool(_ui.call("is_open"))


func can_interact(_player: Node) -> bool:
	return interact_enabled and not _ui_open()


func _key_waiting() -> bool:
	return GameState != null and GameState.clock_key_waiting and not GameState.has_inventory_flag("tash_room_key")


func get_prompt() -> String:
	if not can_interact(null) or GameState == null:
		return ""
	if not GameState.clock_intro_said:
		call_deferred("_say_intro")
	if not GameState.clock_solved and not _hand_placed():
		return put_back_prompt if GameState.has_minute_hand else missing_prompt
	if not GameState.clock_solved:
		return set_prompt
	if _key_waiting():
		return take_prompt
	return look_prompt


func _on_interact(_player: Node) -> void:
	if GameState == null:
		return
	if not GameState.clock_solved and not _hand_placed():
		if GameState.place_minute_hand():
			_update_hands()
			_play_chime(2.2, -16.0)
			get_tree().call_group("subtitle", "show_line", "SABIRA", put_back_line, line_duration)
		else:
			get_tree().call_group("subtitle", "show_line", "SABIRA", missing_line, line_duration)
		return
	if not GameState.clock_solved:
		_open_ui()
		return
	if _key_waiting():
		if GameState.add_inventory_flag("tash_room_key"):
			GameState.clock_key_waiting = false
			refresh_key_state()
			_play_chime(1.6, -10.0)
			get_tree().call_group("subtitle", "show_line", "SABIRA", take_line, line_duration)
		return
	get_tree().call_group("subtitle", "show_line", "SABIRA", look_line, line_duration)


func _open_ui() -> void:
	GameState.ensure_clock_times()
	if _ui == null or not is_instance_valid(_ui):
		_ui = ClockSetUIScript.new()
		_ui.name = "ClockSetUI"
		var host: Node = get_tree().current_scene
		if host == null:
			host = get_tree().root
		host.add_child(_ui)
		_ui.connect("time_changed", _on_time_changed)
		_ui.connect("solved", _on_solved)
		_ui.connect("closed", _on_ui_closed)
	_ui.call("open", GameState.clock_hour, GameState.clock_minute, GameState.watch_hour, GameState.watch_minute)


func _on_time_changed(h: int, m: int) -> void:
	GameState.clock_hour = h
	GameState.clock_minute = m
	_update_hands()


func _on_solved() -> void:
	if GameState.clock_solved:
		return
	GameState.clock_solved = true
	_just_solved = true
	print("[HOUSE] ClockPuzzle: clock set to %d:%02d - solved" % [GameState.clock_hour, GameState.clock_minute])


func _on_ui_closed() -> void:
	if not _just_solved:
		return
	_just_solved = false
	_play_chime(1.0, -4.0)
	if GameState.add_inventory_flag("tash_room_key"):
		GameState.clock_key_waiting = false
		get_tree().call_group("subtitle", "show_line", "SABIRA", key_line, line_duration)
	else:
		# Carry full: GameState already said "Can't carry more."; key waits here.
		GameState.clock_key_waiting = true
	refresh_key_state()


func _play_chime(pitch: float, vol_db: float) -> void:
	var p := get_node_or_null(chime_path) as AudioStreamPlayer3D
	if p == null or p.stream == null:
		return
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()
