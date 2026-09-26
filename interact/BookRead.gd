# Godot 4.x - Sabira / HOUSE
class_name BookRead
extends Interactable
## F2 Landing book: Read opens BookPage caption; Sabira reacts once after close.
## Five Scriptwriter paragraphs rotate via GameState.book_read_index.
## Knowledge flags survive Catch-1 (mirror discovered_photos).

@export var read_prompt: String = "[E] Read the book."
@export var look_prompt: String = "[E] Look"
@export var look_line: String = "A thick book. Someone underlined the page."
@export var sabira_react_line: String = "I wonder if I'll be married the same way."
@export var reread_soft_line: String = "Still that book."
@export var line_duration: float = 3.0
@export var offer_look_first: bool = true

## Scriptwriter EXACT - cycle each Read (index in GameState.book_read_index).
const BOOK_PARAGRAPHS: PackedStringArray = [
	'In some regions, a lively custom called ala kachuu once meant a groom "stealing" a bride for marriage. The literature insists it is tradition, romance, even a compliment. Neighbors clap. Mothers cry. The bride is told she will grow to love him. The paperwork catches up later, if it catches up at all.',
	'Field notes describe the car ride as "festive." The groom\'s friends block the exits. A scarf is useful if she screams. Elders call it courtship. The police call it a family matter, when they call it anything.',
	"Surveys quietly admit many women did not consent. The same surveys add that divorce is shameful, so the numbers look like success. A happy ending is defined as staying.",
	"One textbook chapter lists gifts for the husband's family: livestock, cash, silence. The bride is both prize and receipt. Love, the author writes, can be taught.",
	"Historians debate whether the custom is ancient or invented yesterday and dressed as forever. Either way, the house has a spare room ready. The door locks from the outside.",
]

var _page_open: bool = false
var _looked: bool = false


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	_refresh_prompt()


func can_interact(_player: Node) -> bool:
	return interact_enabled and not _page_open


func get_prompt() -> String:
	if not can_interact(null):
		return ""
	# Optional Look once before first Read (Scriptwriter Look without Read).
	if offer_look_first and not _looked and GameState != null and not GameState.read_ala_kachuu_book:
		return look_prompt
	return read_prompt


func _refresh_prompt() -> void:
	prompt_text = get_prompt()


func _current_paragraph() -> String:
	if BOOK_PARAGRAPHS.is_empty():
		return ""
	var idx := 0
	if GameState != null:
		idx = int(GameState.book_read_index) % BOOK_PARAGRAPHS.size()
		if idx < 0:
			idx = 0
	return BOOK_PARAGRAPHS[idx]


func _advance_book_index() -> void:
	if GameState == null or BOOK_PARAGRAPHS.is_empty():
		return
	GameState.book_read_index = (int(GameState.book_read_index) + 1) % BOOK_PARAGRAPHS.size()


func _on_interact(_player: Node) -> void:
	if _page_open or GameState == null:
		return
	# First beat: Look only (no page yet).
	if offer_look_first and not _looked and not GameState.read_ala_kachuu_book:
		_looked = true
		get_tree().call_group("subtitle", "show_line", "SABIRA", look_line, line_duration)
		_refresh_prompt()
		return
	_open_page()


func _open_page() -> void:
	var page_text := _current_paragraph()
	var ui := get_tree().get_first_node_in_group("book_page")
	if ui == null or not ui.has_method("open_page"):
		# Fallback: subtitle caption if BookPage missing.
		get_tree().call_group("subtitle", "show_line", "", page_text, 8.0)
		_after_page_closed()
		return
	_page_open = true
	_refresh_prompt()
	if ui.has_signal("finished") and not ui.finished.is_connected(_on_page_finished):
		ui.finished.connect(_on_page_finished, CONNECT_ONE_SHOT)
	ui.call("open_page", page_text)


func _on_page_finished() -> void:
	_page_open = false
	_after_page_closed()
	_refresh_prompt()


func _after_page_closed() -> void:
	if GameState == null:
		return
	var first_read := not GameState.read_ala_kachuu_book
	GameState.read_ala_kachuu_book = true
	_advance_book_index()
	if not GameState.sabira_book_reacted:
		GameState.sabira_book_reacted = true
		get_tree().call_group("subtitle", "show_line", "SABIRA", sabira_react_line, line_duration)
		return
	# Re-Read: next paragraph already queued via index; soft line only (no second wonder).
	if not first_read:
		get_tree().call_group("subtitle", "show_line", "SABIRA", reread_soft_line, line_duration)
