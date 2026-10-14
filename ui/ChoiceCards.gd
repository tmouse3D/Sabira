# Godot 4.x - Sabira / HOUSE
extends Control
## Choice-card prologue (Firewatch-style). Plays after Main Menu > Play (difficulty) and before
## IntroSlides (House). Black screen, "Age N" header, lines fade in (no voice blips;
## cards are silent), 2-3 ScratchButton choices (keyboard/gamepad focus), result lines, next card.
## Cards cannot be skipped. Space once reveals the current card's remaining lines and choice
## buttons instantly (fades finish at once). IntroSlides (next scene) keep their own skip.
## Choices write GameState flags (GameState.set_flag); reset_for_new_game clears them.
##
## SCRIPTWRITER: edit CARDS below. Each card:
##   {"age": "Age 7", "place": "The kitchen. Evening." (optional line under the header),
##    "lines": [ {"speaker": "" (narration) / "SABIRA" / "TASH" / "DANA" / "MUM" / "GIRL" / "FATHER", "text": "..."}, ... ],
##    (GIRL / FATHER are display tags; their voice comes from VOICE_OF: GIRL->DANA, FATHER->TASH)
##    "choices": [ {"text": "button text", "flags": ["flag_name", ...],
##                  "result": [ {"speaker": ..., "text": ...}, ... ]}, ... ] }   # 2-3 choices
## Flags in use: cat_scratch (chase fall 2% -> 10% + leg lines), met_dana (diary Look line),
## market_warned / market_silent (later lines: GameState.PROLOGUE_LINES).
## A card with one choice still waits for the button.

const NEXT_SCENE := "res://world/House.tscn"
const FADE_SEC := 0.8
const LINE_IN_SEC := 0.6
## Display speaker tag -> Voices speaker (unused: cards play no voice blips).
const VOICE_OF := {"GIRL": "DANA", "FATHER": "TASH"}
## Body / choice text sizes (+~18%: was 22 / 24 / ScratchButton 26). Header + place unchanged.
const BODY_NOTE_SIZE := 26
const BODY_SPEECH_SIZE := 28
const CHOICE_SIZE := 30
const TEXT_COLOR := Color(0.93, 0.91, 0.86)
const NOTE_COLOR := Color(0.65, 0.63, 0.58)

const CARDS := [
	{"age": "Age 7", "place": "The kitchen. Evening.", "lines": [
		{"speaker": "", "text": "The kitchen smells of onions and bleach."},
		{"speaker": "", "text": "He reads the newspaper at the table. On the back page, a woman in a white coat is listening to a dog's heart."},
		{"speaker": "", "text": "You ask him if you could do that one day. Help people. Or animals."},
		{"speaker": "FATHER", "text": "Doctors. Ha."},
		{"speaker": "FATHER", "text": "You'll be a good housewife. Learn to clean. Learn to cook. That is enough."},
	], "choices": [
		{"text": "I understand.", "flags": [], "result": [
			{"speaker": "", "text": "He turns the page. You never see the woman in the white coat again."},
		]},
	]},
	{"age": "Age 8", "place": "The road home. Late afternoon.", "lines": [
		{"speaker": "", "text": "Walking home behind him. Grey slush, grey sky."},
		{"speaker": "", "text": "A stray cat under a bench. Thin. Dirty. Sad eyes."},
		{"speaker": "", "text": "You crouch and touch it. It doesn't run. It leans into your hand, like it was waiting for someone."},
		{"speaker": "", "text": "You ask if you can take it home."},
		{"speaker": "FATHER", "text": "No. Leave it. It carries disease."},
	], "choices": [
		{"text": "Pick up the cat.", "flags": ["cat_scratch"], "result": [
			{"speaker": "", "text": "He pulls it from your arms and swings his boot at it."},
			{"speaker": "", "text": "The cat twists and rakes his leg. Blood darkens his trouser."},
			{"speaker": "FATHER", "text": "Stupid animal! Look what you did!"},
			{"speaker": "", "text": "You never see the cat again. He limps for a week. He does not forget."},
		]},
		{"text": "Let it go.", "flags": [], "result": [
			{"speaker": "", "text": "You stand up. The cat watches you leave."},
			{"speaker": "", "text": "You do not look back. That was the lesson."},
		]},
	]},
	{"age": "Age 11", "place": "The yard. Afternoon.", "lines": [
		{"speaker": "", "text": "You are allowed as far as the gate. Not one step more."},
		{"speaker": "", "text": "A girl on the street stops and waves. Bright scarf, scraped knees."},
		{"speaker": "GIRL", "text": "Hey! Want to play?"},
		{"speaker": "FATHER", "text": "(from the doorway) Inside. Now."},
	], "choices": [
		{"text": "Answer her.", "flags": ["met_dana"], "result": [
			{"speaker": "", "text": "You say your name through the bars. She grins."},
			{"speaker": "GIRL", "text": "I'm Dana!"},
			{"speaker": "DANA", "text": "I saw a hedgehog behind the bakery. A real one. It snorts!"},
			{"speaker": "DANA", "text": "Come tomorrow, I'll show you. Promise?"},
			{"speaker": "", "text": "You nod. He drags you in by the wrist."},
			{"speaker": "", "text": "The next day, the door stays locked. And the day after."},
			{"speaker": "", "text": "You never find out if she waited. Or what happened to the hedgehog. Or to her."},
		]},
		{"text": "Pretend you didn't hear.", "flags": [], "result": [
			{"speaker": "", "text": "You turn and go inside. Behind you, she calls once more. Then nothing."},
		]},
	]},
	{"age": "Age 13", "place": "The market. Morning.", "lines": [
		{"speaker": "", "text": "The market. Noise, smoke, cold hands."},
		{"speaker": "", "text": "Father brought you to carry the box. Bracelets and polished stones."},
		{"speaker": "FATHER", "text": "Magic stones. For luck. For health. Very old."},
		{"speaker": "", "text": "They are not magic. You watched him buy them by the kilo."},
		{"speaker": "", "text": "A man picks the best bracelet. When he looks away, Father drops a cheap one into the bag instead."},
		{"speaker": "", "text": "The man counts out his money."},
	], "choices": [
		{"text": "Warn him.", "flags": ["market_warned"], "result": [
			{"speaker": "", "text": "You say it quietly. The bracelet. It's not the one you chose."},
			{"speaker": "", "text": "The man looks in the bag. Father laughs, swaps it, apologises for his daughter."},
			{"speaker": "", "text": "Father does not hit you there. He does not say a word the whole way home."},
		]},
		{"text": "Stay silent and look away.", "flags": ["market_silent"], "result": [
			{"speaker": "", "text": "You look down and count the cracks in the stones."},
			{"speaker": "", "text": "The money changes hands. You let it happen."},
			{"speaker": "", "text": "On the way home Father almost smiles."},
			{"speaker": "FATHER", "text": "Good. You're learning."},
		]},
	]},
]

var _header: Label
var _place: Label
var _lines_box: VBoxContainer
var _choice_box: VBoxContainer
var _hint: Label
## Space pressed: finish the current card's reveal instantly. Reset per card / per result.
var _rush: bool = false
var _done: bool = false
var _picked: int = -1


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	col.custom_minimum_size = Vector2(820, 0)
	center.add_child(col)
	_header = Label.new()
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_theme_font_size_override("font_size", 40)
	_header.add_theme_color_override("font_color", TEXT_COLOR)
	_header.modulate.a = 0.0
	col.add_child(_header)
	_place = Label.new()
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place.add_theme_font_size_override("font_size", 20)
	_place.add_theme_color_override("font_color", NOTE_COLOR)
	_place.modulate.a = 0.0
	col.add_child(_place)
	_lines_box = VBoxContainer.new()
	_lines_box.add_theme_constant_override("separation", 14)
	col.add_child(_lines_box)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 12)
	_choice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_choice_box)
	_hint = Label.new()
	_hint.text = "Space: show all"
	_hint.add_theme_font_size_override("font_size", 17)
	_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.6))
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position = Vector2(-230, -40)
	add_child(_hint)
	print("[CARDS] start")
	_run.call_deferred()


func _run() -> void:
	for card in CARDS:
		_rush = false
		await _play_card(card)
	_finish()


func _play_card(card: Dictionary) -> void:
	for c in _lines_box.get_children():
		c.queue_free()
	_header.text = String(card.get("age", ""))
	_place.text = String(card.get("place", ""))
	_fade(_place, 1.0, FADE_SEC)
	await _fade(_header, 1.0, FADE_SEC)
	for l in card.get("lines", []):
		await _show_line(String(l.get("speaker", "")), String(l.get("text", "")))
	var choices: Array = card.get("choices", [])
	if choices.is_empty():
		return
	_picked = -1
	var buttons: Array = []
	for i in choices.size():
		var b := ScratchButton.new()
		b.text = String(choices[i].get("text", "..."))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.custom_minimum_size = Vector2(600, 64)
		b.modulate.a = 0.0
		b.pressed.connect(func() -> void: _picked = i)
		_choice_box.add_child(b)
		b.add_theme_font_size_override("font_size", CHOICE_SIZE)  # after _ready (ScratchButton sets 26)
		buttons.append(b)
	_link_focus(buttons)
	for b in buttons:
		_fade(b, 1.0, 0.4)
	(buttons[0] as Control).grab_focus()
	while _picked < 0:
		await get_tree().process_frame
	for b in buttons:
		b.queue_free()
	_rush = false
	var ch: Dictionary = choices[_picked]
	print("[CARDS] %s -> '%s'" % [card.get("age", ""), ch.get("text", "")])
	for f in ch.get("flags", []):
		GameState.set_flag(String(f), true)
	for l in ch.get("result", []):
		await _show_line(String(l.get("speaker", "")), String(l.get("text", "")))
	await _wait(1.2)
	_fade(_place, 0.0, FADE_SEC * 0.6)
	await _fade(_header, 0.0, FADE_SEC * 0.6)
	for c in _lines_box.get_children():
		_fade(c, 0.0, FADE_SEC * 0.6)
	await _wait(FADE_SEC * 0.7)


func _show_line(speaker: String, text: String) -> void:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(820, 0)
	l.modulate.a = 0.0
	if speaker == "":
		l.text = text
		l.add_theme_font_size_override("font_size", BODY_NOTE_SIZE)
		l.add_theme_color_override("font_color", NOTE_COLOR)
	else:
		l.text = "%s: %s" % [speaker, text]
		l.add_theme_font_size_override("font_size", BODY_SPEECH_SIZE)
		l.add_theme_color_override("font_color", TEXT_COLOR)
	_lines_box.add_child(l)
	# No voice blips during the prologue cards (any speaker).
	await _fade(l, 1.0, LINE_IN_SEC)
	await _wait(clampf(1.2 + text.length() * 0.04, 2.0, 5.5))


static func _link_focus(list: Array) -> void:
	for i in list.size():
		var c: Control = list[i]
		var prev: Control = list[(i - 1 + list.size()) % list.size()]
		var nxt: Control = list[(i + 1) % list.size()]
		c.focus_neighbor_top = c.get_path_to(prev)
		c.focus_neighbor_bottom = c.get_path_to(nxt)
		c.focus_previous = c.get_path_to(prev)
		c.focus_next = c.get_path_to(nxt)


func _fade(node: CanvasItem, to: float, sec: float) -> void:
	if _rush or not is_instance_valid(node):
		if is_instance_valid(node):
			node.modulate.a = to
		return
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", to, sec)
	while tw.is_valid() and tw.is_running():
		if _rush:
			tw.kill()
			if is_instance_valid(node):
				node.modulate.a = to
			return
		await get_tree().process_frame


func _wait(sec: float) -> void:
	var left := sec
	while left > 0.0 and not _rush:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _input(event: InputEvent) -> void:
	if _done or _rush:
		return
	# Space once: reveal the rest of this card now. Only while no choice buttons are up
	# (Space / ui_accept still presses a focused button). The card phase cannot be skipped.
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_SPACE:
		if _choice_box.get_child_count() == 0:
			get_viewport().set_input_as_handled()
			_rush = true
			print("[CARDS] space: reveal card")


func _finish() -> void:
	if _done:
		return
	_done = true
	var voices := get_node_or_null("/root/Voices")
	if voices != null:
		voices.stop()
	print("[CARDS] done, flags=", GameState.prologue_flags)
	get_tree().change_scene_to_file(NEXT_SCENE)
