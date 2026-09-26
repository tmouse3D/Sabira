# Godot 4.x - Sabira / HOUSE
class_name BookPage
extends CanvasLayer
## On-screen book page caption panel (text-only). Mirrors PhotosLookthrough input lock.
## Open via open_page(text); emits finished() when closed with [E]/click.

signal finished

@export var dim_alpha: float = 0.72
@export var allow_click_close: bool = true
@export var click_stream: AudioStream
@export var click_volume_db: float = -16.0

var _busy: bool = false
var _click: AudioStreamPlayer

@onready var _dim: ColorRect = $Dim
@onready var _caption: Label = $Caption
@onready var _hint: Label = $Hint


func _ready() -> void:
	add_to_group("book_page")
	layer = 30
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _dim:
		_dim.color = Color(0, 0, 0, dim_alpha)
	if _hint:
		_hint.text = "[E] close"
	_ensure_click()


func _ensure_click() -> void:
	_click = get_node_or_null("ClickPlayer") as AudioStreamPlayer
	if _click == null:
		_click = AudioStreamPlayer.new()
		_click.name = "ClickPlayer"
		add_child(_click)
	if click_stream == null:
		click_stream = load("res://audio/sfx/ui_soft_click.wav") as AudioStream
	_click.stream = click_stream
	_click.volume_db = click_volume_db
	_click.bus = &"Master"


func _play_click() -> void:
	if _click == null:
		_ensure_click()
	if _click and _click.stream:
		_click.pitch_scale = randf_range(0.97, 1.03)
		_click.volume_db = click_volume_db + randf_range(-1.0, 0.5)
		_click.play()


## Show page text. Caller awaits finished then fires Sabira beat.
func open_page(text: String) -> void:
	if _busy:
		return
	_busy = true
	visible = true
	if _caption:
		_caption.text = text
	if _hint:
		_hint.text = "[E] close"
	get_tree().call_group("player", "set_input_locked", true)
	get_tree().call_group("interact_prompt", "suppress_for", 999.0)


func close_page() -> void:
	if not _busy:
		return
	_busy = false
	_play_click()
	visible = false
	if _caption:
		_caption.text = ""
	get_tree().call_group("player", "set_input_locked", false)
	get_tree().call_group("interact_prompt", "suppress_for", 0.05)
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _busy:
		return
	var close_it := false
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		close_it = true
	elif event.is_action_pressed("ui_cancel"):
		close_it = true
	elif allow_click_close and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close_it = true
	if close_it:
		close_page()
		get_viewport().set_input_as_handled()