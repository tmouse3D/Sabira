# Godot 4.x - Sabira / HOUSE
class_name LookExamine
extends Interactable
## Optional Look prop ?- rotates through Scriptwriter captions.

@export var look_lines: PackedStringArray = []
@export var speaker: String = "SABIRA"
@export var line_duration: float = 2.5
@export var look_prompt: String = "[E] Look"
## Pick a random line each time, never the same one twice in a row.
@export var random_order: bool = false

## Optional extra line(s) unlocked by a GameState prologue flag (e.g. met_dana). Shown first,
## then mixed into the normal lines.
@export var flag_name: String = ""
@export var flag_lines: PackedStringArray = []
## Shown first (once) when flag_name is NOT set.
@export var noflag_lines: PackedStringArray = []

var _next: int = 0
var _flag_said: bool = false
var _last: int = -1


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
	var line := ""
	var pool := look_lines
	if flag_name != "" and not flag_lines.is_empty() and GameState != null and GameState.flag(flag_name):
		if not _flag_said:
			_flag_said = true
			get_tree().call_group("subtitle", "show_line", speaker, flag_lines[0], line_duration)
			return
		pool = look_lines + flag_lines
	elif flag_name != "" and not noflag_lines.is_empty() and GameState != null and not GameState.flag(flag_name):
		if not _flag_said:
			_flag_said = true
			get_tree().call_group("subtitle", "show_line", speaker, noflag_lines[0], line_duration)
			return
		pool = look_lines + noflag_lines
	if random_order:
		var i := randi() % pool.size()
		if pool.size() > 1 and i == _last:
			i = (i + 1 + randi() % (pool.size() - 1)) % pool.size()
		_last = i
		line = pool[i]
	else:
		line = pool[_next % pool.size()]
		_next = (_next + 1) % pool.size()
	get_tree().call_group("subtitle", "show_line", speaker, line, line_duration)
