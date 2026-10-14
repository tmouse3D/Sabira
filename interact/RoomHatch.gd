# Godot 4.x - Sabira / HOUSE
class_name RoomHatch
extends Interactable
## Floor hatch (secret room, kind "down") or ceiling hatch + ladder (lower room, kind "up").
## [E]: lid swings open (if it has one), short black fade, the player is moved to `target_pos`
## (yaw kept), lid closes again. Built and wired by world/LowerRoom.gd.
## Ending 18 "Shut Tight" (Realistic): going down while Tash chases -> he shuts the hatch
## (GameState.hatch_shut, chase ends to patrol). Climb up then plays the line + the ending.
## Secret gating (lower_secret 2026-10-13): the floor hatch opens only with 5+ endings unlocked
## (GameState.secret_hatch_unlocked); otherwise [E] plays STORY_LINES.hatch_locked_line and
## returns before any chase check, so the Ending 18 shut can never arm. While Tash is cuffed
## downstairs (GameState.tash_cuffed) the ceiling hatch only says STORY_LINES.hatch_not_yet.

var kind: String = "down"
var target_pos: Vector3 = Vector3.ZERO
## Landing facing (body yaw, rad). NAN = keep the player's yaw.
var face_yaw: float = NAN
var lid: Node3D = null          # pivot rotated on open (hinge along local -Z edge)
var open_axis: Vector3 = Vector3.RIGHT
var _busy: bool = false


func _ready() -> void:
	collision_layer = 4   # interact-only: in the interact ray mask (1 | 4), not the player's (1) or nav (1 | 8)
	collision_mask = 0
	interact_enabled = true


func get_prompt() -> String:
	if _busy:
		return ""
	if kind == "down" and not GameState.secret_hatch_unlocked():
		return String(GameState.STORY_LINES["hatch_locked_prompt"])
	return prompt_text


func _on_interact(player: Node) -> void:
	if _busy or not (player is Node3D):
		return
	if kind == "down" and not GameState.secret_hatch_unlocked():
		get_tree().call_group("subtitle", "show_line", "SABIRA", String(GameState.STORY_LINES["hatch_locked_line"]), 3.0)
		return
	if kind == "up" and GameState.tash_cuffed:
		get_tree().call_group("subtitle", "show_line", "SABIRA", String(GameState.STORY_LINES["hatch_not_yet"]), 2.0)
		return
	_busy = true
	if kind == "up" and GameState.hatch_shut:
		await _shut_tight()
		return
	var chased := false
	if kind == "down" and not GameState.is_easy():
		var tash := get_tree().get_first_node_in_group("tash")
		chased = tash != null and tash.has_method("is_chasing") and bool(tash.call("is_chasing"))
	# Root cause of the old climb-up bug: the ceiling hatch has no lid, so the lid tween had no
	# tweeners; an empty Tween is invalid and never emits `finished` -> _busy stuck forever.
	if lid != null:
		var tw := create_tween()
		tw.tween_property(lid, "rotation", open_axis * deg_to_rad(105.0), 0.35).set_trans(Tween.TRANS_SINE)
		await tw.finished
	var fade := _make_fade()
	var ft := create_tween()
	ft.tween_property(fade.get_child(0), "color:a", 1.0, 0.25)
	await ft.finished
	var p := player as Node3D
	p.global_position = target_pos
	if not is_nan(face_yaw):
		p.rotation.y = face_yaw
	if p is CharacterBody3D:
		(p as CharacterBody3D).velocity = Vector3.ZERO
	print("[HATCH] %s -> %s" % [name, target_pos])
	if lid != null:
		lid.rotation = Vector3.ZERO
	if chased:
		_tash_shuts_it()
	var bt := create_tween()
	bt.tween_property(fade.get_child(0), "color:a", 0.0, 0.35)
	await bt.finished
	fade.queue_free()
	_busy = false


## Tash saw her go down: he shuts the hatch, his chase ends cleanly back to patrol.
func _tash_shuts_it() -> void:
	GameState.hatch_shut = true
	var tash := get_tree().get_first_node_in_group("tash")
	if tash != null and tash.has_method("_end_chase_to_patrol"):
		tash.call("_end_chase_to_patrol", "hatch shut")
	print("[HATCH] Tash shut the hatch (ending 18 armed)")


func _shut_tight() -> void:
	get_tree().call_group("subtitle", "show_line", "SABIRA", String(GameState.STORY_LINES["hatch_shut_line"]), 3.0)
	await get_tree().create_timer(3.2).timeout
	GameState.trigger_shut_tight_ending()


func _make_fade() -> CanvasLayer:
	var cl := CanvasLayer.new()
	cl.layer = 90
	var cr := ColorRect.new()
	cr.color = Color(0, 0, 0, 0)
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(cr)
	get_tree().root.add_child(cl)
	return cl
