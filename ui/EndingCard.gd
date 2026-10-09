# Godot 4.x - Sabira / HOUSE
extends CanvasLayer
## Escape ending card. Spawned by GameState.trigger_escape_win(exit_door) when the player opens an
## unlocked exit door (FrontDoor after front_key, BackDoor after back_key). Amina is optional.
## Sequence: lock input -> fade to black -> white card lines (same look and timing as the Tash
## stab card in characters/TashWalker.gd: 26 px, Color(0.93, 0.91, 0.86), each line fades in 0.6 s,
## holds 3.0 s, fades out 0.55 s) -> end state (black screen, tree paused, input locked, mouse freed).
##
## ENDING_CARDS: one entry per combination, key = "<mum>/<photos>/<tash>/<door>":
##   mum    = "with_mum" | "alone"            (GameState.carrying_amina)
##   photos = "photos" | "no_photos"          (photos in the carry slots)
##   tash   = "tash_dead" | "tash_alive"      (GameState.is_tash_dead())
##   door   = "front" | "back"
## Each value = the card lines, shown one after another. ALL TEXT IS PLACEHOLDER (Scriptwriter).

signal finished

const FADE_TO_BLACK_SEC := 1.2
const LINE_IN := 0.6
const LINE_HOLD := 3.0
const LINE_OUT := 0.55
const GAP_BEFORE_LINES := 0.5

const ENDING_CARDS := {
	"with_mum/photos/tash_dead/front": [
		"The front door. The whole street can see us now.",
		"He isn't coming after us. The photos will tell them why.",
		"Some doors only open once.",
	],
	"with_mum/photos/tash_dead/back": [
		"Out the back, through the wet grass.",
		"He stays on the floor where he fell. I keep the photos close.",
		"Nobody has to know which way we went.",
	],
	"with_mum/photos/tash_alive/front": [
		"We walk out the front door like we're allowed to.",
		"He's still asleep in there. The photos will wake everyone else.",
		"Let him come looking. This time there's proof.",
	],
	"with_mum/photos/tash_alive/back": [
		"The back gate. Cold air. Mum breathing against my neck.",
		"He'll wake up to an empty house.",
		"The photos are all we took. They have to be enough.",
	],
	"with_mum/no_photos/tash_dead/front": [
		"Out the front, into the streetlight.",
		"He's gone, and we're still here. Nobody will understand why.",
		"All we have left is just a moment.",
	],
	"with_mum/no_photos/tash_dead/back": [
		"Through the back, into the dark.",
		"Mum doesn't ask what happened to him. I don't tell her.",
		"Some injuries cannot be healed.",
	],
	"with_mum/no_photos/tash_alive/front": [
		"We're out. The street doesn't even look up.",
		"He's still in there. He'll tell them his version.",
		"We have nothing but each other. It has to be enough.",
	],
	"with_mum/no_photos/tash_alive/back": [
		"The back door, the garden, the fence.",
		"Mum is light. Too light.",
		"He'll wake up. He'll come looking. We keep walking.",
	],
	"alone/photos/tash_dead/front": [
		"I walk out the front door alone.",
		"Mum is still in that room. He can't hurt her now.",
		"The photos will have to speak for both of us.",
	],
	"alone/photos/tash_dead/back": [
		"Out the back. I don't look at the windows.",
		"He's still on the floor. Mum is still inside.",
		"I have the photos. I'll bring someone back. I swear.",
	],
	"alone/photos/tash_alive/front": [
		"The front door. Nobody stops me.",
		"Mum is still in there with him.",
		"The photos are in my hand. I have to make someone look.",
	],
	"alone/photos/tash_alive/back": [
		"Over the back fence, the photos inside my shirt.",
		"I left her. I left her with him.",
		"I'm coming back. With people this time.",
	],
	"alone/no_photos/tash_dead/front": [
		"I'm out. The street is empty.",
		"He's dead, and Mum is still inside.",
		"Who believes a girl with blood on her hands?",
	],
	"alone/no_photos/tash_dead/back": [
		"The back garden. The gate. The road.",
		"I couldn't carry her. I couldn't carry anything.",
		"Some monsters cannot be tamed. Some can only be left behind.",
	],
	"alone/no_photos/tash_alive/front": [
		"I'm out. Just me.",
		"Mum is still in there. So is he.",
		"All I have left is just a moment.",
	],
	"alone/no_photos/tash_alive/back": [
		"Out the back. Running.",
		"I left her behind. I left everything behind.",
		"He'll be awake soon.",
	],
}

var ending_key: String = ""
var _black: ColorRect
var _label: Label


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
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.modulate.a = 0.0
	_black.add_child(_label)


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
	for line in lines:
		_label.text = line
		_label.modulate.a = 0.0
		var fade_in := create_tween()
		fade_in.tween_property(_label, "modulate:a", 1.0, LINE_IN)
		await fade_in.finished
		await tree.create_timer(LINE_HOLD).timeout
		var fade_out := create_tween()
		fade_out.tween_property(_label, "modulate:a", 0.0, LINE_OUT)
		await fade_out.finished
	# End state: stay on black, input locked, mouse free.
	_label.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("[HOUSE] ENDING finished: %s" % key)
	finished.emit()
