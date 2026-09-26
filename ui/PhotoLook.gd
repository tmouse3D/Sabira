# Godot 4.x - Sabira / HOUSE
class_name PhotoLook
extends CanvasLayer
## TEMP first-pickup zoom/cutscene: browse ui/photos/photo_01..06.
## Art pipeline stub ?- wire from PhotosPickup on first Take (see handoff).
## Replace TEMP PNGs later; keep filenames. Emits finished() when closed.

signal finished

@export var photo_dir: String = "res://ui/photos"
@export var photo_count: int = 6
@export var auto_advance_sec: float = 0.9
@export var dim_alpha: float = 0.72
@export var allow_click_advance: bool = true

var _textures: Array[Texture2D] = []
var _index: int = 0
var _busy: bool = false

@onready var _dim: ColorRect = $Dim
@onready var _photo: TextureRect = $Center/Photo
@onready var _hint: Label = $Hint
@onready var _timer: Timer = $AutoTimer


func _ready() -> void:
	layer = 30
	add_to_group("photo_look")
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _dim:
		_dim.color = Color(0, 0, 0, dim_alpha)
	if _timer:
		_timer.wait_time = auto_advance_sec
		_timer.one_shot = false
		if not _timer.timeout.is_connected(_on_auto_advance):
			_timer.timeout.connect(_on_auto_advance)
	_load_textures()
	_refresh()


func _load_textures() -> void:
	_textures.clear()
	for i in range(1, photo_count + 1):
		var path := "%s/photo_%02d.png" % [photo_dir, i]
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				_textures.append(tex)
		else:
			push_warning("PhotoLook: missing %s" % path)


## Open the look-through. Caller should await finished then add inventory.
func open_look() -> void:
	if _textures.is_empty():
		_load_textures()
	if _textures.is_empty():
		push_warning("PhotoLook: no photos ?- finishing immediately")
		finished.emit()
		return
	_index = 0
	_busy = true
	visible = true
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
	finished.emit()


func _refresh() -> void:
	if _photo == null or _textures.is_empty():
		return
	_index = clampi(_index, 0, _textures.size() - 1)
	_photo.texture = _textures[_index]
	if _hint:
		_hint.text = "[E] / click next  ?*  %d / %d  ?*  Esc skip" % [_index + 1, _textures.size()]


func _advance() -> void:
	if not _busy:
		return
	if _index >= _textures.size() - 1:
		close_look()
		return
	_index += 1
	_refresh()


func _on_auto_advance() -> void:
	_advance()


func _unhandled_input(event: InputEvent) -> void:
	if not _busy:
		return
	if event.is_action_pressed("ui_cancel"):
		close_look()
		get_viewport().set_input_as_handled()
		return
	# Interact / ui_accept / click
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
