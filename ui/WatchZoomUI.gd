# Godot 4.x - Sabira / HOUSE
extends CanvasLayer
## Pocket watch close-up (spawned by interact/PocketWatch.gd). Shows this run's watch time
## (GameState.watch_hour / watch_minute) on a code-drawn face over the gray watch case art.
## Esc or E closes. Locks the player and hides the prompt like ui/KeypadUI.gd.

signal closed

const ClockFaceScript := preload("res://ui/ClockFace.gd")
const CASE_TEXTURE_PATH := "res://props/pocketwatch/pocketwatch_gray.png"
## Ignore the E press that opened the zoom (and key repeats right after).
const OPEN_GUARD_MS := 200
const UNLOCK_DELAY := 0.15

var _open: bool = false
var _opened_ms: int = 0
var _face: Control


func _ready() -> void:
	layer = 40
	visible = false
	_build()


func is_open() -> bool:
	return _open


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	center.add_child(vb)

	_face = ClockFaceScript.new()
	_face.name = "WatchFace"
	_face.style = "watch"
	_face.case_texture = load(CASE_TEXTURE_PATH) as Texture2D
	_face.custom_minimum_size = Vector2(440.0, 500.0)
	vb.add_child(_face)

	var hint := Label.new()
	hint.text = "[E] / [Esc] close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.65, 0.62, 0.56, 1.0))
	vb.add_child(hint)


func open(h: int, m: int) -> void:
	if _open:
		return
	_face.call("set_time", h, m)
	_open = true
	_opened_ms = Time.get_ticks_msec()
	visible = true
	get_tree().call_group("player", "set_input_locked", true)
	get_tree().call_group("interact_prompt", "suppress_for", 999.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().call_group("interact_prompt", "suppress_for", UNLOCK_DELAY + 0.05)
	# Short delay so the closing E press can't re-trigger an interact.
	await get_tree().create_timer(UNLOCK_DELAY).timeout
	get_tree().call_group("player", "set_input_locked", false)
	closed.emit()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var key := event as InputEventKey
	if key == null:
		return
	get_viewport().set_input_as_handled()
	if not key.pressed or key.echo:
		return
	if Time.get_ticks_msec() - _opened_ms < OPEN_GUARD_MS:
		return
	var esc := key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE
	var e_key := key.keycode == KEY_E or key.physical_keycode == KEY_E or event.is_action("interact")
	if esc or e_key:
		close()
