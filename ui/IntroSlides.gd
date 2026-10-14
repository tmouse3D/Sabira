# Godot 4.x - Sabira / HOUSE
extends CanvasLayer
## New-game intro slideshow (spawned by Player._ready when GameState.intro_pending).
## Full-screen dark overlay, a scratchy-framed image per slide (ScratchButton.frame_style),
## a caption/note line and speaker lines. Fades IN_SEC; each slide holds at least HOLD_SEC or
## until its lines finish. Input locked, Tash frozen, pause menu blocked (input lock) and music
## faded while it runs. Skip: Esc, or hold E / Space for SKIP_HOLD_SEC.
## After: player seated on Kitchen_Chair_4Body (ChairSit, safe zone on; its caption is shown
## SAFE_LINE_DELAY s later), Tash starts in the F1 couch TV sit, ambient music, dinner_started.
## SLIDE DATA: edit SLIDES below (any number of entries). POST_INTRO_LINE is the optional
## caption ~1.5 s after control returns (set speaker/line to "" to disable).

const FADE_SEC := 0.8
const HOLD_SEC := 4.0
const LINE_IN_SEC := 0.35
const LINE_SEC := 2.6
const SKIP_HOLD_SEC := 1.0
const SAFE_LINE_DELAY := 5.5
const CHAIR_PATH := "Structure/KitchenDining/Kitchen_Chair_4Body"

# ==== INTRO DATA (final text; placeholder images: the [bracket] note is for the artist) ===============================================================
# One Dictionary per slide, played in order (N slides supported):
#   "texture":  optional res:// path ("" = blank dark frame)
#   "note":     optional grey note line shown first ("" = none)
#   "captions": list of {"speaker": "TASH"/"SABIRA"/"" , "line": "..."} (speaker "" = grey note)
#   "hold":     optional minimum seconds on screen (0 = HOLD_SEC)
const SLIDES: Array = [
	{"texture": "", "note": "[house exterior at dusk, one lit window]", "captions": [
		{"speaker": "SABIRA", "line": "It's just me and my father in this house."},
	], "hold": 0.0},  # S1
	{"texture": "", "note": "[Sabira's room, peas corner, prayer mat]", "captions": [
		{"speaker": "SABIRA", "line": "When I think for myself, I'm punished. When I try to do things alone, I'm punished."},
	], "hold": 0.0},  # S2
	{"texture": "", "note": "[locked front door, Tash's coat on the hook]", "captions": [
		{"speaker": "SABIRA", "line": "I'm not allowed outside without him. Not ever."},
	], "hold": 0.0},  # S3
	{"texture": "", "note": "[small cake on a bare kitchen table]", "captions": [
		{"speaker": "SABIRA", "line": "Today is my birthday. He hasn't said a word about it."},
	], "hold": 0.0},  # S4
	{"texture": "", "note": "[kitchen dinner, Tash at head of table]", "captions": [
		{"speaker": "TASH", "line": "So. Your birthday. You're a big girl now."},
	], "hold": 0.0},  # S5
	{"texture": "", "note": "[Tash eating, not looking at her]", "captions": [
		{"speaker": "TASH", "line": "Today you may stay and eat a little longer. Don't make me regret it."},
	], "hold": 0.0},  # S6
	{"texture": "", "note": "[Sabira's hands around her cup]", "captions": [
		{"speaker": "SABIRA", "line": "He never talks about the past. But tonight he let me stay."},
	], "hold": 0.0},  # S7
	{"texture": "", "note": "[close on Sabira looking up]", "captions": [
		{"speaker": "SABIRA", "line": "Dad... what was Mum like?"},
	], "hold": 0.0},  # S8
	{"texture": "", "note": "[Tash's eyes flick toward the bookcase]", "captions": [], "hold": 1.5},  # S9
	{"texture": "", "note": "[Tash standing, chair pushed back]", "captions": [
		{"speaker": "TASH", "line": "That's not your concern. Finish your plate."},
	], "hold": 0.0},  # S10
	{"texture": "", "note": "[empty doorway, footsteps fading]", "captions": [
		{"speaker": "SABIRA", "line": "He left. He didn't even look at me."},
	], "hold": 0.0},  # S11
]
## Shown POST_INTRO_DELAY s after control returns. Empty line = off.
const POST_INTRO_LINE := {"speaker": "SABIRA", "line": "I'd better be fast and quiet. I'm not allowed to walk around without a task.", "sec": 4.0}
const POST_INTRO_DELAY := 1.5
# ==============================================================================================

var _black: ColorRect
var _root: Control
var _image: TextureRect
var _lines_box: VBoxContainer
var _hint: Label
var _skip: bool = false
var _hold_t: float = 0.0
var _done: bool = false
var _done_at: int = 0


func _ready() -> void:
	name = "IntroSlides"
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_start.call_deferred()


func _build() -> void:
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 1)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_black)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.modulate.a = 0.0
	add_child(_root)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	_root.add_child(col)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ScratchButton.frame_style(0.9))
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(frame)
	_image = TextureRect.new()
	_image.custom_minimum_size = Vector2(640, 360)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_image)
	_lines_box = VBoxContainer.new()
	_lines_box.custom_minimum_size = Vector2(0, 120)
	_lines_box.add_theme_constant_override("separation", 6)
	col.add_child(_lines_box)
	_hint = Label.new()
	_hint.text = "Hold E / Space to skip   (Esc)"
	_hint.add_theme_font_size_override("font_size", 17)
	_hint.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86, 0.45))
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position = Vector2(-300, -40)
	_hint.size = Vector2(280, 24)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_hint)


func _tash() -> Node:
	return get_tree().get_first_node_in_group("tash")


func _start() -> void:
	get_tree().call_group("player", "set_input_locked", true)
	var t := _tash()
	if t != null and t.has_method("set_intro_frozen"):
		t.set_intro_frozen(true)
	if GameState != null and GameState.skip_intro_once:
		# Ending retry: no slides, straight to the seated-at-table start.
		GameState.skip_intro_once = false
		print("[INTRO] retry: skipping slides -> seated start")
		_finish()
		return
	MusicManager.fade_out_all(1.5)
	print("[INTRO] start")
	for entry in SLIDES:
		if _skip:
			break
		var d: Dictionary = entry
		var path := String(d.get("texture", ""))
		var tex: Texture2D = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
		var lines: Array = []
		if String(d.get("note", "")) != "":
			lines.append(["", String(d["note"])])
		for c in d.get("captions", []):
			lines.append([String(c.get("speaker", "")), String(c.get("line", ""))])
		await _play_slide(tex, lines, float(d.get("hold", 0.0)))
	_finish()


func _play_slide(tex: Texture2D, lines: Array, hold: float = 0.0) -> void:
	for c in _lines_box.get_children():
		c.queue_free()
	_image.texture = tex
	await _fade(_root, 1.0, FADE_SEC)
	var held := 0.0
	for entry in lines:
		if _skip:
			return
		var lbl := _make_line(String(entry[0]), String(entry[1]))
		_lines_box.add_child(lbl)
		if String(entry[0]) != "":
			var v := _voices()
			if v != null:
				v.call("speak", String(entry[0]), String(entry[1]), String(entry[0]).to_upper() + "_INTRO")
		await _fade(lbl, 1.0, LINE_IN_SEC)
		# Read time by length: notes short, spoken lines ~1.5 s + 0.045 s/char (2.6-5.5 s).
		var read := 1.2 if String(entry[0]) == "" else clampf(1.5 + String(entry[1]).length() * 0.045, LINE_SEC, 5.5)
		await _wait(read)
		held += LINE_IN_SEC + read
	var min_hold := hold if hold > 0.0 else HOLD_SEC
	if hold > 0.0:
		held = minf(held, hold)
	if held < min_hold:
		await _wait(min_hold - held)
	await _fade(_root, 0.0, FADE_SEC)


func _make_line(speaker: String, text: String) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(760, 0)
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	l.modulate.a = 0.0
	if speaker == "":
		l.text = text
		l.add_theme_font_size_override("font_size", 19)
		l.add_theme_color_override("font_color", Color(0.62, 0.6, 0.56, 0.7))
	else:
		l.text = "%s: %s" % [speaker, text]
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86))
	return l


func _fade(node: CanvasItem, to: float, sec: float) -> void:
	if _skip:
		node.modulate.a = to
		return
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", to, sec)
	while tw.is_valid() and tw.is_running():
		if _skip:
			tw.kill()
			node.modulate.a = to
			return
		await get_tree().process_frame


func _wait(sec: float) -> void:
	var left := sec
	while left > 0.0 and not _skip:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_request_skip()


func _process(delta: float) -> void:
	if _done or _skip:
		return
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		_hold_t += delta
		_hint.text = "Skipping... %d%%" % int(clampf(_hold_t / SKIP_HOLD_SEC, 0.0, 1.0) * 100.0)
		if _hold_t >= SKIP_HOLD_SEC:
			_request_skip()
	elif _hold_t > 0.0:
		_hold_t = 0.0
		_hint.text = "Hold E / Space to skip   (Esc)"


func _request_skip() -> void:
	if _skip:
		return
	_skip = true
	_voices_stop()
	print("[INTRO] skipped")


func _finish() -> void:
	if _done:
		return
	_voices_stop()
	_done = true
	_skip = false
	_root.visible = false
	_hint.visible = false
	var house := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player")
	var chair := house.get_node_or_null(CHAIR_PATH) if house != null else null
	if GameState != null:
		GameState.dinner_started = true
		# Auto-sit: the chair's safe caption is said later (below), not on this sit.
		GameState.mark_safe_line_said("chair")
	if chair != null and player != null and chair.has_method("_on_interact"):
		chair._on_interact(player)
	else:
		push_warning("IntroSlides: Kitchen_Chair_4Body or player missing; starting standing.")
	var t := _tash()
	if t != null and t.has_method("begin_intro_couch"):
		t.begin_intro_couch()
	MusicManager.start_game()
	# Control returns as the black fades: unlock + capture now, and let mouse events pass
	# through the overlay (a STOP ColorRect ate the look motion until queue_free).
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().call_group("player", "set_input_locked", false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_done_at = Time.get_ticks_msec()
	await _fade(_black, 0.0, FADE_SEC)
	_black.visible = false
	var post_line := String(POST_INTRO_LINE.get("line", ""))
	if post_line != "":
		await get_tree().create_timer(POST_INTRO_DELAY).timeout
		get_tree().call_group("subtitle", "show_line", String(POST_INTRO_LINE.get("speaker", "SABIRA")), post_line, float(POST_INTRO_LINE.get("sec", 3.0)))
		await get_tree().create_timer(maxf(SAFE_LINE_DELAY - POST_INTRO_DELAY, 0.1)).timeout
	else:
		await get_tree().create_timer(SAFE_LINE_DELAY).timeout
	print("[INTRO] done: seated=%s safe=%s" % [player.is_sitting() if player != null and player.has_method("is_sitting") else false, GameState.is_player_safe()])
	if is_instance_valid(player) and player.has_method("is_sitting") and player.is_sitting():
		get_tree().call_group("subtitle", "show_line", "SABIRA", "Eat. Sit still. He doesn't touch a girl at the table.", 3.5)
	queue_free()


## Autoload lookup each time (never a cached ref): survives any freed / replaced node.
func _voices() -> Node:
	var v := get_node_or_null("/root/Voices")
	return v if v != null and is_instance_valid(v) else null


func _voices_stop() -> void:
	var v := _voices()
	if v != null and v.has_method("stop"):
		v.call("stop")
