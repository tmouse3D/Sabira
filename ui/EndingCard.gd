# Godot 4.x - Sabira / HOUSE
extends CanvasLayer
## Escape ending card. Spawned by GameState.trigger_escape_win(exit_door) when the player opens an
## unlocked exit door (FrontDoor after front_key, BackDoor after back_key). Amina is optional.
## Sequence: lock input -> fade to black -> white card lines (style of the Tash stab card in
## characters/TashWalker.gd, but 32 px: Color(0.93, 0.91, 0.86), each line fades in 0.6 s,
## holds 5.0 s, fades out 0.55 s) -> end state (black screen, tree paused, input locked, mouse freed).
## DISCLAIMER_LINE: small text at the bottom of the screen on every ending; it fades in with the
## first card line and stays through the end state.
##
## ENDING_CARDS: one entry per combination, key = "<mum>/<photos>/<tash>/<door>":
##   mum    = "with_mum" | "alone"            (GameState.carrying_amina)
##   photos = "photos" | "no_photos"          (photos in the carry slots)
##   tash   = "tash_dead" | "tash_alive"      (GameState.is_tash_dead())
##   door   = "front" | "back"
## Each value = the card lines, shown one after another (final text, 2026-10-10). Front and back
## share lines, except with_mum + tash_alive on the back door: line 1 starts "The back step. ".

signal finished

const FADE_TO_BLACK_SEC := 1.2
const LINE_IN := 0.6
const LINE_HOLD := 5.0
const LINE_OUT := 0.55
const GAP_BEFORE_LINES := 0.5
const CARD_FONT_SIZE := 32
const DISCLAIMER_FONT_SIZE := 18
const DISCLAIMER_LINE := "A work of fiction, inspired by bride kidnapping and forced marriage in Central Asia."

const ENDING_CARDS := {
	"with_mum/photos/tash_dead/front": [
		"The photos come out before the questions do.",
		"They'll still look at my hands. But the paper is older than the knife.",
		"We are not forgiven. We are not disappeared into his name.",
	],
	"with_mum/photos/tash_dead/back": [
		"The photos come out before the questions do.",
		"They'll still look at my hands. But the paper is older than the knife.",
		"We are not forgiven. We are not disappeared into his name.",
	],
	"with_mum/photos/tash_alive/front": [
		"I get her out before the sky turns. She weighs almost nothing.",
		"In my pocket, her face at eighteen. A man still upstairs in that house.",
		"It is not safety. But the house is behind us now.",
	],
	"with_mum/photos/tash_alive/back": [
		"The back step. I get her out before the sky turns. She weighs almost nothing.",
		"In my pocket, her face at eighteen. A man still upstairs in that house.",
		"It is not safety. But the house is behind us now.",
	],
	"with_mum/no_photos/tash_dead/front": [
		"They'll find him, and a woman who shouldn't exist.",
		"No photos. Only blood they can name.",
		"They'll call it two crimes. Not eighteen years.",
	],
	"with_mum/no_photos/tash_dead/back": [
		"They'll find him, and a woman who shouldn't exist.",
		"No photos. Only blood they can name.",
		"They'll call it two crimes. Not eighteen years.",
	],
	"with_mum/no_photos/tash_alive/front": [
		"I drag her into the air. The night does not change.",
		"No photos. Only her breathing, and a story they won't believe.",
		"People believe houses. They believe fathers.",
	],
	"with_mum/no_photos/tash_alive/back": [
		"The back step. I drag her into the air. The night does not change.",
		"No photos. Only her breathing, and a story they won't believe.",
		"People believe houses. They believe fathers.",
	],
	"alone/photos/tash_dead/front": [
		"The photos come out before the questions do.",
		"I walk. She does not. The pictures are of her.",
		"The empty room will be photographed by other people now.",
	],
	"alone/photos/tash_dead/back": [
		"The photos come out before the questions do.",
		"I walk. She does not. The pictures are of her.",
		"The empty room will be photographed by other people now.",
	],
	"alone/photos/tash_alive/front": [
		"I have him in my bag. The dates. The girl in the wall.",
		"A case can be opened from a bus station.",
		"She is still counting hours in a room with no clock.",
	],
	"alone/photos/tash_alive/back": [
		"I have him in my bag. The dates. The girl in the wall.",
		"A case can be opened from a bus station.",
		"She is still counting hours in a room with no clock.",
	],
	"alone/no_photos/tash_dead/front": [
		"He's dead, and nobody knows she exists.",
		"Just a daughter, a knife, and a story in the wrong order.",
		"Behind the books, she is still breathing.",
	],
	"alone/no_photos/tash_dead/back": [
		"He's dead, and nobody knows she exists.",
		"Just a daughter, a knife, and a story in the wrong order.",
		"Behind the books, she is still breathing.",
	],
	"alone/no_photos/tash_alive/front": [
		"I tell myself I'll send someone. I tell myself she nodded.",
		"The road is wide and empty, and I am alive in it.",
		"Behind the bookcase, the air does not move.",
	],
	"alone/no_photos/tash_alive/back": [
		"I tell myself I'll send someone. I tell myself she nodded.",
		"The road is wide and empty, and I am alive in it.",
		"Behind the bookcase, the air does not move.",
	],
}

var ending_key: String = ""
## Space skips all card text straight to the end state (Main Menu + "Ending N of 19").
var _skippable: bool = false
var _skip: bool = false
var _disclaimer_fade_started: bool = false
## Not-saved-Amina endings: bottom-right "Hold E - Try to save her again" (RETRY_HOLD_SEC).
const RETRY_HOLD_SEC := 1.2
var _retry_fill: ColorRect = null
var _retry_t: float = 0.0
var _retry_done: bool = false


func _input(event: InputEvent) -> void:
	if not _skippable or _skip:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_SPACE:
		_skip = true
		get_viewport().set_input_as_handled()
		print("[HOUSE] ending card text skipped")


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()


## Manual fade (works while the tree is paused; stops early on skip).
func _fade_skip(node: CanvasItem, to: float, sec: float, with_disclaimer: bool = false) -> void:
	var from := node.modulate.a
	var t := 0.0
	while t < sec and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()
		var k := clampf(t / sec, 0.0, 1.0)
		node.modulate.a = lerpf(from, to, k)
		if with_disclaimer and _disclaimer_fade_started:
			_disclaimer.modulate.a = maxf(_disclaimer.modulate.a, k)
	if not _skip:
		node.modulate.a = to
var _black: ColorRect
var _label: Label
var _disclaimer: Label


static func make_key(with_mum: bool, photos: bool, tash_dead: bool, exit_door: String) -> String:
	return "%s/%s/%s/%s" % [
		"with_mum" if with_mum else "alone",
		"photos" if photos else "no_photos",
		"tash_dead" if tash_dead else "tash_alive",
		"back" if exit_door == "back" else "front",
	]


static func lines_for(key: String) -> PackedStringArray:
	var out: PackedStringArray = []
	# Caught ending (second catch): text lives in GameState.STORY_LINES.caught_ending.
	if key == "caught":
		for l in GameState.STORY_LINES["caught_ending"]:
			out.append(String(l))
		return out
	if key == "shut_tight":
		for l in GameState.STORY_LINES["shut_tight_ending"]:
			out.append(String(l))
		return out
	# Ending 19 "Like Father, Like Daughter": STORY_LINES.like_father_ending (may be empty).
	if key == "like_father":
		for l in GameState.STORY_LINES["like_father_ending"]:
			out.append(String(l))
		return out
	if ENDING_CARDS.has(key):
		for l in ENDING_CARDS[key]:
			out.append(String(l))
	return out


func _ready() -> void:
	name = "EndingCard"
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black = ColorRect.new()
	_black.name = "Black"
	_black.color = Color(0, 0, 0, 1)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	_black.modulate.a = 0.0
	add_child(_black)
	_label = Label.new()
	_label.name = "Card"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 72
	_label.offset_right = -72
	_label.offset_top = 40
	_label.offset_bottom = -40
	_label.add_theme_font_size_override("font_size", CARD_FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.modulate.a = 0.0
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	# Siblings of Black (drawn above it) so they can show over the live street while Black is clear.
	add_child(_label)
	_disclaimer = Label.new()
	_disclaimer.name = "Disclaimer"
	_disclaimer.text = DISCLAIMER_LINE
	_disclaimer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_disclaimer.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_disclaimer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_disclaimer.offset_left = 72
	_disclaimer.offset_right = -72
	_disclaimer.offset_bottom = -28
	_disclaimer.add_theme_font_size_override("font_size", DISCLAIMER_FONT_SIZE)
	_disclaimer.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86, 0.7))
	_disclaimer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disclaimer.modulate.a = 0.0
	add_child(_disclaimer)


func play(key: String) -> void:
	ending_key = key
	var tree := get_tree()
	tree.call_group("player", "set_input_locked", true)
	tree.call_group("interact_prompt", "suppress_for", 9999.0)
	MusicManager.fade_out_all(2.0)
	var t := create_tween()
	t.tween_property(_black, "modulate:a", 1.0, FADE_TO_BLACK_SEC)
	await t.finished
	# Freeze the house (Tash, timers) once the screen is black. This layer keeps running.
	tree.paused = true
	await tree.create_timer(GAP_BEFORE_LINES).timeout
	_maybe_show_image(key)
	var lines := lines_for(key)
	if lines.is_empty() and key != "like_father":
		push_warning("EndingCard: no text for %s" % key)
	_skippable = true
	var first := true
	for line in lines:
		if _skip:
			break
		_label.text = line
		_label.modulate.a = 0.0
		if first:
			_disclaimer_fade_started = true
			first = false
		await _fade_skip(_label, 1.0, LINE_IN, true)
		await _wait(LINE_HOLD)
		await _fade_skip(_label, 0.0, LINE_OUT)
	_skippable = false
	_label.modulate.a = 0.0
	_disclaimer.modulate.a = 1.0
	if _skip:
		await get_tree().create_timer(0.25, true).timeout  # the skip press must not hit the button
	# End state: stay on black, input locked, mouse free.
	_label.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("[HOUSE] ENDING finished: %s" % key)
	_show_menu_button()
	finished.emit()


## Escape street variant (world/EscapeStreet.gd): the same lines fade in / hold / fade out as a
## white overlay ON TOP of the walking street (Black stays clear). Black fades in gradually across
## the last two lines; then, on black, the disclaimer and the Main Menu button. The tree is paused
## only at the end, so the street keeps walking under the text.
func play_over_scene(key: String) -> void:
	ending_key = key
	var tree := get_tree()
	tree.call_group("player", "set_input_locked", true)
	tree.call_group("interact_prompt", "suppress_for", 9999.0)
	MusicManager.fade_out_all(2.0)
	_black.modulate.a = 0.0
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines := lines_for(key)
	if lines.is_empty():
		push_warning("EndingCard: no text for %s" % key)
	var n := lines.size()
	var per_line := LINE_IN + LINE_HOLD + LINE_OUT
	_skippable = true
	var dark: Tween = null
	for i in n:
		if _skip:
			break
		if i == maxi(n - 2, 0):
			dark = create_tween()
			dark.tween_property(_black, "modulate:a", 1.0, per_line * float(n - i))
		_label.text = lines[i]
		_label.modulate.a = 0.0
		await _fade_skip(_label, 1.0, LINE_IN)
		await _wait(LINE_HOLD)
		await _fade_skip(_label, 0.0, LINE_OUT)
	_skippable = false
	if dark != null and dark.is_valid():
		dark.kill()
	_black.modulate.a = 1.0
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	tree.paused = true
	_label.text = ""
	_label.modulate.a = 0.0
	if _skip:
		_disclaimer.modulate.a = 1.0
		await get_tree().create_timer(0.25, true).timeout  # the skip press must not hit the button
	else:
		await _fade_skip(_disclaimer, 1.0, LINE_IN)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("[HOUSE] ENDING finished (street): %s" % key)
	_show_menu_button()
	finished.emit()


## End state: scratchy "Main Menu" button (focused). GameState.go_to_main_menu unpauses, resets
## and frees this card.
## Optional ending image under the card text (caught ending: GameState.CAUGHT_ENDING_IMAGE;
## empty path shows nothing).
func _maybe_show_image(key: String) -> void:
	var path := String(GameState.CAUGHT_ENDING_IMAGE) if key == "caught" else ""
	if path == "" or not ResourceLoader.exists(path):
		return
	var tr := TextureRect.new()
	tr.texture = load(path) as Texture2D
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.modulate.a = 0.35
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.add_child(tr)


func _show_menu_button() -> void:
	var b := ScratchButton.new()
	b.name = "MainMenuButton"
	b.text = "Main Menu"
	b.anchor_left = 0.5
	b.anchor_right = 0.5
	b.anchor_top = 0.5
	b.anchor_bottom = 0.5
	b.offset_left = -130
	b.offset_right = 130
	b.offset_top = -28
	b.offset_bottom = 28
	b.modulate.a = 0.0
	b.pressed.connect(func() -> void: GameState.go_to_main_menu())
	_black.add_child(b)
	b.grab_focus()
	create_tween().tween_property(b, "modulate:a", 1.0, LINE_IN)
	# "Ending N of 19 - Name" under the button + unlock save (GameState.ENDINGS).
	var txt := String(GameState.ending_label(ending_key))
	GameState.record_ending(ending_key)
	if txt != "":
		var lab := Label.new()
		lab.name = "EndingNumber"
		lab.text = txt
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.anchor_left = 0.5
		lab.anchor_right = 0.5
		lab.anchor_top = 0.5
		lab.anchor_bottom = 0.5
		lab.offset_left = -400
		lab.offset_right = 400
		lab.offset_top = 40
		lab.offset_bottom = 76
		lab.add_theme_font_size_override("font_size", 20)
		lab.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86, 0.85))
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.modulate.a = 0.0
		_black.add_child(lab)
		create_tween().tween_property(lab, "modulate:a", 1.0, LINE_IN)
		print("[HOUSE] ", txt)
	# Retry rule: only when Amina is not saved (Ending 19: she is not carried out).
	if ending_key == "caught" or ending_key == "shut_tight" or ending_key.begins_with("alone/") \
			or (ending_key == "like_father" and not GameState.carrying_amina):
		_add_retry_button()


## Bottom-right boxed button "Try to save her again" with the main-menu title glitch
## (res://ui/menu/title_glitch.gdshader, same burst/dropout/flash driving as MainMenu.gd),
## tiny half-transparent "HOLD E" above it; the 1.2 s hold fill runs inside the box.
const RETRY_GLITCH_SHADER := "res://ui/menu/title_glitch.gdshader"
var _rg_mat: ShaderMaterial = null
var _rg_next: float = 2.0
var _rg_left: float = 0.0
var _rg_drop: float = 0.0


func _add_retry_button() -> void:
	var root := Control.new()
	root.name = "RetryHold"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.anchor_left = 1.0
	root.anchor_right = 1.0
	root.anchor_top = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = -360
	root.offset_right = -48
	root.offset_top = -172
	root.offset_bottom = -100   # clear of the bottom disclaimer lines
	_black.add_child(root)
	var hold := Label.new()
	hold.text = "HOLD E"
	hold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hold.position = Vector2(0, 0)
	hold.size = Vector2(312, 18)
	hold.add_theme_font_size_override("font_size", 15)
	hold.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86, 0.5))
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hold)
	var panel := Panel.new()
	panel.position = Vector2(0, 22)
	panel.size = Vector2(312, 50)
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.045, 0.04, 0.9)
	sb.border_color = Color(0.93, 0.91, 0.86, 0.75)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	_retry_fill = ColorRect.new()
	_retry_fill.color = Color(0.55, 0.12, 0.1, 0.85)
	_retry_fill.position = Vector2(2, 2)
	_retry_fill.size = Vector2(0, 46)
	_retry_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_retry_fill)
	var l := Label.new()
	l.text = "Try to save her again"
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(l)
	var sh := load(RETRY_GLITCH_SHADER) as Shader
	if sh != null:
		var over := ColorRect.new()
		over.name = "RetryGlitch"
		over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		over.set_anchors_preset(Control.PRESET_FULL_RECT)
		over.offset_left = 3
		over.offset_top = 3
		over.offset_right = -3
		over.offset_bottom = -3
		_rg_mat = ShaderMaterial.new()
		_rg_mat.shader = sh
		over.material = _rg_mat
		l.add_child(over)
		_rg_next = randf_range(1.0, 3.0)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, LINE_IN)
	set_process(true)


func _tick_retry_glitch(delta: float) -> void:
	if _rg_mat == null:
		return
	if _rg_left > 0.0:
		_rg_left -= delta
		if _rg_drop > 0.0:
			_rg_drop -= delta
		elif randf() < delta * 3.0:
			_rg_drop = randf_range(0.05, 0.1)
		_rg_mat.set_shader_parameter("burst", 1.0 if _rg_left > 0.0 else 0.0)
		_rg_mat.set_shader_parameter("dropout", 1.0 if _rg_drop > 0.0 else 0.0)
		_rg_mat.set_shader_parameter("flash", randf_range(0.0, 0.8) if randf() < 0.3 else 0.0)
		if _rg_left <= 0.0:
			_rg_drop = 0.0
			_rg_mat.set_shader_parameter("dropout", 0.0)
			_rg_mat.set_shader_parameter("flash", 0.0)
			_rg_next = randf_range(1.5, 5.0)
		return
	_rg_next -= delta
	if _rg_next <= 0.0:
		_rg_left = randf_range(0.1, 0.4)


func _process(delta: float) -> void:
	if _retry_fill == null or _retry_done:
		return
	_tick_retry_glitch(delta)
	if Input.is_physical_key_pressed(KEY_E):
		_retry_t += delta
	else:
		_retry_t = maxf(0.0, _retry_t - delta * 2.0)
	var w := (_retry_fill.get_parent() as Control).size.x - 4.0
	_retry_fill.size.x = w * clampf(_retry_t / RETRY_HOLD_SEC, 0.0, 1.0)
	if _retry_t >= RETRY_HOLD_SEC:
		_retry_done = true
		print("[HOUSE] retry: new run, same difficulty (%s)" % GameState.difficulty)
		GameState.retry_same_difficulty()
