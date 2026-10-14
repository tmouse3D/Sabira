# Godot 4.x - Sabira / HOUSE
extends CanvasLayer
## Catch sequence, spawned by GameState.begin_catch() on Tash's grab_swing (TashWalker "grab").
## Lock player -> hit frame: punch + fast fade to black -> Tash frozen.
##   Catch 1: STORY_LINES.catch1_card on black; consequences (GameState.apply_catch1_consequences);
##     Sabira placed on the peas corner, Tash in her doorway; fade in; catch1_scold lines; Tash
##     leaves (TashWalker.catch_release); player unlocked; catch1_after lines.
##   Catch 2: catch2_card on black, then GameState.trigger_caught_ending() (EndingCard "caught").
## All text: GameState.STORY_LINES.

const HIT_SEC := 0.85
## Extra wait after HIT_SEC before punch + fade, so the black lands on the swing connecting.
@export var punch_delay_sec: float = 0.4  # HIT_SEC 0.85 + 0.4 = instant black at 1.25 s
## Scold voice: TASH_LOUD profile + this boost on Tash's blips.
@export var scold_boost_db: float = 6.0
const FADE_OUT_SEC := 0.18
const FADE_IN_SEC := 1.0
const CARD_IN := 0.6
const CARD_HOLD := 2.8
const CARD_OUT := 0.5
const SCOLD_SEC := 4.0
const AFTER_SEC := 3.6
const PUNCH_SFX := "res://audio/sfx/punch_hit.wav"
## Hall side of Door_Sabira (doorway centre x 2.5, z ~0.875) and the peas corner fallback.
const DOORWAY_HALL := Vector3(2.1, 3.01, 0.875)
const DOORWAY_CENTRE := Vector3(2.5, 3.01, 0.875)
const PEAS_FALLBACK := Vector3(6.55, 3.06, 1.87)

var _black: ColorRect
var _label: Label
var _tash: Node = null
## Grab swing -> blackout: camera locked and turned smoothly onto Tash's head bone.
@export var look_turn_rate: float = 9.0
var _look_on: bool = false
var _skippable: bool = false
var _skip: bool = false


func _input(event: InputEvent) -> void:
	if not _skippable or _skip:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_SPACE:
		_skip = true
		get_viewport().set_input_as_handled()
		print("[CATCH] doorway monologue skipped")


## Timer that returns early once Space skipped.
func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()


func _end_skipped_lines() -> void:
	get_tree().call_group("subtitle", "show_line", "", "", 0.01)
	var v := get_node_or_null("/root/Voices")
	if v != null and is_instance_valid(v) and v.has_method("stop"):
		v.call("stop")


func _process(delta: float) -> void:
	if not _look_on or _tash == null or not is_instance_valid(_tash) or not _tash.has_method("head_world_pos"):
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var pivot := p.get_node_or_null("CameraPivot") as Node3D
	var cam := p.get_node_or_null("CameraPivot/Camera3D") as Node3D
	var from := cam.global_position if cam != null else p.global_position + Vector3(0, 1.5, 0)
	var dir: Vector3 = (_tash.call("head_world_pos") as Vector3) - from
	var flat := Vector2(dir.x, dir.z).length()
	if flat < 0.01:
		return
	var k := 1.0 - exp(-look_turn_rate * delta)
	p.rotation.y = lerp_angle(p.rotation.y, atan2(-dir.x, -dir.z), k)
	if pivot != null:
		pivot.rotation.x = lerp_angle(pivot.rotation.x, clampf(atan2(dir.y, flat), deg_to_rad(-85.0), deg_to_rad(85.0)), k)


func _ready() -> void:
	name = "CatchSequence"
	layer = 89  # under EndingCard (90) so the caught ending card draws on top
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	_black.modulate.a = 0.0
	add_child(_black)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 72
	_label.offset_right = -72
	_label.add_theme_font_size_override("font_size", 32)
	_label.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.modulate.a = 0.0
	add_child(_label)


func start(count: int, tash: Node) -> void:
	_tash = tash
	var tree := get_tree()
	tree.call_group("player", "set_input_locked", true)
	tree.call_group("interact_prompt", "suppress_for", 9999.0)
	_look_on = true
	await tree.create_timer(HIT_SEC + punch_delay_sec).timeout
	_play_punch()
	_black.modulate.a = 1.0   # instant cut to black on the punch (no fade)
	_look_on = false
	if _tash != null and is_instance_valid(_tash) and _tash.has_method("catch_freeze"):
		_tash.call("catch_freeze")
	tree.call_group("subtitle", "show_line", "", "", 0.0)
	if count >= 2:
		await _card(GameState.STORY_LINES["catch2_card"])
		GameState.trigger_caught_ending()
		await tree.create_timer(2.0).timeout
		queue_free()
		return
	GameState.apply_catch1_consequences()
	_stage_scene()
	await _card(GameState.STORY_LINES["catch1_card"])
	await _fade(_black, 0.0, FADE_IN_SEC)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var voices := get_node_or_null("/root/Voices")
	if voices != null and "tash_boost_db" in voices:
		voices.set("tash_boost_db", scold_boost_db)
		voices.set("tash_force_loud", true)
	# Space skips the whole doorway monologue (+ after line) straight to the end state.
	_skippable = true
	for l in GameState.STORY_LINES["catch1_scold"]:
		if _skip:
			break
		tree.call_group("subtitle", "show_line", "TASH", String(l), SCOLD_SEC - 0.2)
		await _wait(SCOLD_SEC)
	if voices != null and is_instance_valid(voices) and "tash_boost_db" in voices:
		voices.set("tash_boost_db", 0.0)
		voices.set("tash_force_loud", false)
	if _skip:
		_end_skipped_lines()
	if _tash != null and is_instance_valid(_tash) and _tash.has_method("catch_release"):
		_tash.call("catch_release")
	await _wait(1.6)
	if _skip:
		await tree.create_timer(0.2).timeout  # the skip press must not become a jump
	tree.call_group("player", "set_input_locked", false)
	tree.call_group("interact_prompt", "suppress_for", 0.05)
	for l in GameState.STORY_LINES["catch1_after"]:
		if _skip:
			break
		tree.call_group("subtitle", "show_line", "SABIRA", String(l), AFTER_SEC - 0.2)
		await _wait(AFTER_SEC)
	_skippable = false
	if _skip:
		_end_skipped_lines()
	GameState.catch_sequence_done()
	print("[CATCH] sequence 1 done")
	queue_free()


func _stage_scene() -> void:
	var scene := get_tree().current_scene
	var peas := PEAS_FALLBACK
	var zone := scene.get_node_or_null("Structure/SabiraRoom/Sabira_PeasSafeZone") as Node3D if scene != null else null
	var room := scene.get_node_or_null("Structure/SabiraRoom") as Node3D if scene != null else null
	if zone != null:
		peas = Vector3(zone.global_position.x, (room.global_position.y if room != null else 3.05) + 0.01, zone.global_position.z)
	var door := scene.get_node_or_null("Doors/Door_Sabira") as Node3D if scene != null else null
	var doorway := DOORWAY_CENTRE
	if door != null:
		doorway = door.global_position + door.global_transform.basis.z * 0.475
		if door.has_method("set_passage_open"):
			door.call("set_passage_open", true)
	var hall := Vector3(doorway.x - 0.4, DOORWAY_HALL.y, doorway.z)
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p != null and p.has_method("is_sitting") and p.call("is_sitting") and p.has_method("end_sit"):
		p.call("end_sit")  # caught on the kitchen chair (knife): stand first, then move
	if p != null:
		p.global_position = peas
		if p is CharacterBody3D:
			(p as CharacterBody3D).velocity = Vector3.ZERO
		var dir := doorway - peas
		p.rotation = Vector3(0.0, atan2(-dir.x, -dir.z), 0.0)
		var pivot := p.get_node_or_null("CameraPivot") as Node3D
		if pivot != null:
			pivot.rotation.x = 0.0
	if _tash != null and is_instance_valid(_tash) and _tash.has_method("catch_place_at"):
		_tash.call("catch_place_at", hall, peas)
	print("[CATCH] staged: Sabira on the peas, Tash in her doorway")


func _card(lines: Array) -> void:
	var tree := get_tree()
	for l in lines:
		_label.text = String(l)
		await _fade(_label, 1.0, CARD_IN)
		await tree.create_timer(CARD_HOLD).timeout
		await _fade(_label, 0.0, CARD_OUT)
	_label.text = ""


func _fade(node: CanvasItem, to: float, sec: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", to, sec)
	await tw.finished


func _play_punch() -> void:
	var a := AudioStreamPlayer.new()
	a.stream = load(PUNCH_SFX) as AudioStream
	a.volume_db = -2.0
	add_child(a)
	if a.stream != null:
		a.play()
