# Godot 4.x - Sabira / HOUSE
class_name PhotosLookthrough
extends CanvasLayer
## First-Take photo look-through: 4 plates + SABIRA subtitles, advance on E/click/timer.
## Soft UI click between flips. Freezes player via group "player" set_input_locked.
## Emits finished() when closed (caller then shows Found the photos. + inventory).

signal finished

@export var photo_dir: String = "res://ui/photos"
@export var plate_count: int = 4
@export var auto_advance_sec: float = 4.5
@export var dim_alpha: float = 0.78
@export var allow_click_advance: bool = true
@export var click_stream: AudioStream
@export var click_volume_db: float = -16.0

const PLATE_LINES: PackedStringArray = [
	"A woman on a street. Close. Too close.",
	"Same face. Different day.",
	"Through a window. She doesn't know.",
	"Young. Before this house.",
]

var _textures: Array[Texture2D] = []
var _index: int = 0
var _busy: bool = false
var _click: AudioStreamPlayer

@onready var _dim: ColorRect = $Dim
@onready var _photo: TextureRect = $Center/Photo
@onready var _caption: Label = $Caption
@onready var _hint: Label = $Hint
@onready var _timer: Timer = $AutoTimer


func _ready() -> void:
	add_to_group("photos_lookthrough")
	layer = 30
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _dim:
		_dim.color = Color(0, 0, 0, dim_alpha)
	if _timer:
		_timer.wait_time = auto_advance_sec
		_timer.one_shot = false
		if not _timer.timeout.is_connected(_on_auto_advance):
			_timer.timeout.connect(_on_auto_advance)
	_ensure_click()
	_load_textures()
	_refresh()


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


func _load_textures() -> void:
	_textures.clear()
	for i in range(1, plate_count + 1):
		var path := "%s/photo_%02d.png" % [photo_dir, i]
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				_textures.append(tex)
		else:
			push_warning("PhotosLookthrough: missing %s" % path)


## Open the look-through. Caller should await finished then set has_photos + Found line.
func open_look() -> void:
	if _busy:
		return
	if _textures.is_empty():
		_load_textures()
	if _textures.is_empty():
		push_warning("PhotosLookthrough: no photos ?- finishing immediately")
		finished.emit()
		return
	_index = 0
	_busy = true
	visible = true
	get_tree().call_group("player", "set_input_locked", true)
	get_tree().call_group("interact_prompt", "suppress_for", 999.0)
	_refresh()
	if _timer and auto_advance_sec > 0.0:
		_timer.start()


func close_look() -> void:
	if not _busy:
		return
	_busy = false
	if _timer:
		_timer.stop()
	visible = false
	get_tree().call_group("player", "set_input_locked", false)
	# Clear long suppress; Prompt restores pending text next frame.
	get_tree().call_group("interact_prompt", "suppress_for", 0.05)
	finished.emit()


func _refresh() -> void:
	if _photo == null or _textures.is_empty():
		return
	_index = clampi(_index, 0, _textures.size() - 1)
	_photo.texture = _textures[_index]
	if _caption:
		var line := ""
		if _index < PLATE_LINES.size():
			line = PLATE_LINES[_index]
		_caption.text = "SABIRA\n%s" % line if line != "" else ""
	if _hint:
		_hint.text = "[E] next  ?*  %d / %d" % [_index + 1, _textures.size()]


func _advance() -> void:
	if not _busy:
		return
	if _index >= _textures.size() - 1:
		close_look()
		return
	_play_click()
	_index += 1
	_refresh()
	if _timer and auto_advance_sec > 0.0:
		_timer.start()


func _on_auto_advance() -> void:
	_advance()


func _unhandled_input(event: InputEvent) -> void:
	if not _busy:
		return
	var advance := false
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		advance = true
	elif allow_click_advance and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			advance = true
	if advance:
		_advance()
		get_viewport().set_input_as_handled()
