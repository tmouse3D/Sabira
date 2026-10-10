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
const DISCLAIMER_FONT_SIZE := 15
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
	_black.add_child(_label)
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
	_black.add_child(_disclaimer)


func play(key: String) -> void:
	ending_key = key
	var tree := get_tree()
	tree.call_group("player", "set_input_locked", true)
	tree.call_group("interact_prompt", "suppress_for", 9999.0)
	var t := create_tween()
	t.tween_property(_black, "modulate:a", 1.0, FADE_TO_BLACK_SEC)
	await t.finished
	# Freeze the house (Tash, timers) once the screen is black. This layer keeps running.
	tree.paused = true
	await tree.create_timer(GAP_BEFORE_LINES).timeout
	var lines := lines_for(key)
	if lines.is_empty():
		push_warning("EndingCard: no text for %s" % key)
	var first := true
	for line in lines:
		_label.text = line
		_label.modulate.a = 0.0
		var fade_in := create_tween()
		fade_in.tween_property(_label, "modulate:a", 1.0, LINE_IN)
		if first:
			fade_in.parallel().tween_property(_disclaimer, "modulate:a", 1.0, LINE_IN)
			first = false
		await fade_in.finished
		await tree.create_timer(LINE_HOLD).timeout
		var fade_out := create_tween()
		fade_out.tween_property(_label, "modulate:a", 0.0, LINE_OUT)
		await fade_out.finished
	_disclaimer.modulate.a = 1.0
	# End state: stay on black, input locked, mouse free.
	_label.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("[HOUSE] ENDING finished: %s" % key)
	finished.emit()
