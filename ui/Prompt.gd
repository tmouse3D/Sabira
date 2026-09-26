# Godot 4.x ?- Sabira / HOUSE
extends Control
## On-screen interact prompt label.

@onready var _label: Label = $Label

var _pending_text: String = ""
var _suppressed: bool = false
var _suppress_left: float = 0.0


func _ready() -> void:
	add_to_group("interact_prompt")
	set_prompt("")
	set_process(false)


func set_prompt(text: String) -> void:
	_pending_text = text
	if _suppressed:
		return
	_apply(text)


## Hide prompt for duration (e.g. while a subtitle line plays), then restore.
func suppress_for(duration: float) -> void:
	_suppressed = true
	_suppress_left = maxf(duration, 0.0)
	if _label:
		_label.text = ""
	visible = false
	set_process(true)


func _process(delta: float) -> void:
	_suppress_left -= delta
	if _suppress_left <= 0.0:
		_suppressed = false
		set_process(false)
		_apply(_pending_text)


func _apply(text: String) -> void:
	if _label == null:
		return
	_label.text = text
	visible = text != ""
