# Godot 4.x - Sabira / HOUSE
class_name LookExamine
extends Interactable
## Optional Look prop ?- rotates through Scriptwriter captions.

@export var look_lines: PackedStringArray = []
@export var speaker: String = "SABIRA"
@export var line_duration: float = 2.5
@export var look_prompt: String = "[E] Look"

var _next: int = 0


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = look_lines.size() > 0
	prompt_text = look_prompt


func get_prompt() -> String:
	return look_prompt if interact_enabled and look_lines.size() > 0 else ""


func _on_interact(_player: Node) -> void:
	if look_lines.is_empty():
		return
	var line := look_lines[_next % look_lines.size()]
	_next = (_next + 1) % look_lines.size()
	get_tree().call_group("subtitle", "show_line", speaker, line, line_duration)
