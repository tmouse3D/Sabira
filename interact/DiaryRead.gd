# Godot 4.x - Sabira / HOUSE
class_name DiaryRead
extends Interactable
## Sabira's diary (props/home/SabiraHomeStudy.tscn). First [E]: Look line. Then [E] Read opens
## the shared BookPage UI (group "book_page", instanced in House.tscn) as a page-turner.
## Sabira says close_line once after the first close.
##
## SCRIPTWRITER: edit DIARY_PAGES only. One Dictionary per page, in order:
##   {"text": "default text",
##    "variants": [ {"flag": "met_dana", "text": "..."}, ... ]}   # optional
## Variants are checked top to bottom; the first whose GameState prologue flag is set wins,
## otherwise "text" is used. Flags: met_dana, cat_scratch, market_warned, market_silent.
## Use "" for text to hide a page when no variant matches.

const DIARY_PAGES: Array = [
	{"text": "The bags for the market are so heavy my arms shake. Father walks ahead with nothing. But if I'm good and strong, one day he'll be proud. One day it will all be worth it."},
	{"text": "There was a woman in Father's newspaper. She was a doctor for animals. I think about her hands, how careful they were. I'm not allowed to want that. I want it anyway."},
	{"text": "I left the cat under the bench. I call it Stain, because it was so dirty. I still see its eyes when I close mine.",
		"variants": [{"flag": "cat_scratch", "text": "The cat fought him. It was so small and it still fought him. I call it Stain, because it was so dirty. I hope Stain found somewhere warm."}]},
	{"text": "I drew Stain again today. Sad eyes, crooked ear, a smudge on the nose. My best one is under the mattress. Father would tear it up."},
	{"text": "A girl waved at me from the street. I pretended I couldn't hear. I hear her every day now.",
		"variants": [{"flag": "met_dana", "text": "Her name is Dana. She found a hedgehog behind the bakery and she wanted to show me. I never went. I don't know if she waited. I don't know where she is now."}]},
	{"text": "I never met my mother. Father won't say her name. I wonder if she had my hands. I wonder if she drew things too."},
	{"text": "There's a noise in the walls at night. A scratch, then quiet, then a scratch again. Something is in there."},
	{"text": "I know what it is now. It's Stain. He's digging a tunnel through the wall, all the way to my room. He's getting closer every night. When he breaks through, we'll crawl out together."},
	{"text": "The noise is loudest by the big bookcase downstairs. That must be where Stain's tunnel ends. When Father is asleep I'll look behind it. If Stain is there, we'll run away together and never come back."},
	# Default = market_silent text (also used if neither market flag is set).
	{"text": "The stones are not magic. I knew, and I said nothing. Father said I'm learning. I don't want to learn this.",
		"variants": [{"flag": "market_warned", "text": "I told the man the truth. Father said nothing all the way home. The silence was worse than his hand."}]},
	{"text": "I grew taller. I can reach the top shelf now. The books up there are all dusty. Father doesn't read anymore. He just drinks that spicy-smelling stuff."},
	{"text": "Snow again. The yard is white to the gate and then the world starts. From my window, the gate is the end of everything."},
	{"text": "One day I'll walk down a street all by myself. Nobody behind me. Nobody telling me where to look. I could buy bread. I could just keep walking."},
	{"text": "Another birthday. Just more rules. One day I'll take a bus to the city and nobody will know my name. Just me."},
]

@export var look_prompt: String = "[E] Look"
@export var read_prompt: String = "[E] Read the diary"
@export var look_line: String = "My diary. He doesn't know about it. Or he doesn't care."
@export var nav_hint: String = "[A/D] Turn page   [E] Close"
@export var close_line: String = "I should put it back anyway."
@export var speaker: String = "SABIRA"
@export var line_duration: float = 4.5

var _looked: bool = false
var _closed_once: bool = false
var _page_open: bool = false


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	prompt_text = get_prompt()


func can_interact(_player: Node) -> bool:
	return interact_enabled and not _page_open


func get_prompt() -> String:
	if not can_interact(null):
		return ""
	return read_prompt if _looked else look_prompt


static func build_pages() -> PackedStringArray:
	var out := PackedStringArray()
	for page_any in DIARY_PAGES:
		var page: Dictionary = page_any
		var text := String(page.get("text", ""))
		for v_any in page.get("variants", []):
			var v: Dictionary = v_any
			if GameState != null and GameState.flag(String(v.get("flag", ""))):
				text = String(v.get("text", text))
				break
		if text != "":
			out.append(text)
	return out


func _on_interact(_player: Node) -> void:
	if _page_open:
		return
	if not _looked:
		_looked = true
		get_tree().call_group("subtitle", "show_line", speaker, look_line, line_duration)
		prompt_text = get_prompt()
		return
	var pages := build_pages()
	if pages.is_empty():
		return
	var ui := get_tree().get_first_node_in_group("book_page")
	if ui == null or not ui.has_method("open_pages"):
		get_tree().call_group("subtitle", "show_line", "", pages[0], 8.0)
		return
	_page_open = true
	prompt_text = get_prompt()
	if ui.has_signal("finished") and not ui.finished.is_connected(_on_page_finished):
		ui.finished.connect(_on_page_finished, CONNECT_ONE_SHOT)
	ui.call("open_pages", pages, nav_hint)


func _on_page_finished() -> void:
	_page_open = false
	prompt_text = get_prompt()
	if not _closed_once:
		_closed_once = true
		get_tree().call_group("subtitle", "show_line", speaker, close_line, line_duration)
