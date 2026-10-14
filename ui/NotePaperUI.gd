# Godot 4.x - Sabira / HOUSE
extends CanvasLayer
## Aged paper sheet (Amina's note) shown full-screen like BookPage: dim + a procedural beige
## paper (noise, stains, darker edges, a fold line) with handwritten-ish dark ink text in the
## project font (Metal Mania). [E] / Esc / click closes; emits finished. Locks the player.

signal finished

const PAPER_W := 300
const PAPER_H := 400
const SHOW_SCALE := 1.45

var _open: bool = false
var _label: Label
var _hint: Label
static var _tex_cache: ImageTexture = null


func _ready() -> void:
	layer = 41
	visible = false
	_build()


func open_note(text: String) -> void:
	if _open:
		return
	_open = true
	_label.text = text
	visible = true
	get_tree().call_group("player", "set_input_locked", true)
	get_tree().call_group("interact_prompt", "suppress_for", 999.0)


func close_note() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().call_group("player", "set_input_locked", false)
	get_tree().call_group("interact_prompt", "suppress_for", 0.3)
	finished.emit()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		get_viewport().set_input_as_handled()
		var kc := key.physical_keycode
		if kc == KEY_E or kc == KEY_ESCAPE or kc == KEY_SPACE:
			close_note()
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		get_viewport().set_input_as_handled()
		close_note()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(PAPER_W, PAPER_H) * SHOW_SCALE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(holder)
	var paper := TextureRect.new()
	paper.texture = _paper_texture()
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.size = Vector2(PAPER_W, PAPER_H) * SHOW_SCALE
	paper.pivot_offset = paper.size * 0.5
	paper.rotation = deg_to_rad(-2.2)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(paper)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 44
	_label.offset_right = -36
	_label.offset_top = 70
	_label.offset_bottom = -60
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color(0.13, 0.09, 0.07, 0.92))
	_label.add_theme_constant_override("line_spacing", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(_label)
	_hint = Label.new()
	_hint.text = "[E] Put it down"
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86, 0.6))
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -48
	_hint.offset_bottom = -20
	_hint.offset_left = -150
	_hint.offset_right = 150
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


static func _paper_texture() -> ImageTexture:
	if _tex_cache != null:
		return _tex_cache
	var img := Image.create(PAPER_W, PAPER_H, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = 7
	n.frequency = 0.035
	var fine := FastNoiseLite.new()
	fine.seed = 21
	fine.frequency = 0.45
	var stains := FastNoiseLite.new()
	stains.seed = 3
	stains.frequency = 0.012
	var base := Color(0.80, 0.72, 0.56)
	var fold_y := PAPER_H * 0.48
	for y in PAPER_H:
		for x in PAPER_W:
			var c := base
			c = c.darkened(0.08 * (n.get_noise_2d(x, y) * 0.5 + 0.5))
			c = c.darkened(0.05 * fine.get_noise_2d(x, y))
			# Tea / water stains.
			var s := stains.get_noise_2d(x, y)
			if s > 0.32:
				c = c.lerp(Color(0.55, 0.40, 0.24), clampf((s - 0.32) * 1.6, 0.0, 0.35))
			# Darker, burnt-looking edges.
			var ex := minf(x, PAPER_W - 1 - x)
			var ey := minf(y, PAPER_H - 1 - y)
			var e := minf(ex, ey) + n.get_noise_2d(x * 3.0, y * 3.0) * 6.0
			if e < 22.0:
				c = c.darkened(clampf((22.0 - e) / 22.0, 0.0, 1.0) * 0.45)
			# Fold crease: thin dark line + soft light band under it.
			var fd := absf(y - fold_y)
			if fd < 1.2:
				c = c.darkened(0.22)
			elif fd < 5.0 and y > fold_y:
				c = c.lightened(0.05 * (5.0 - fd) / 5.0)
			# Ragged corners: cut a little out of the sheet.
			var alpha := 1.0
			if e < 1.5:
				alpha = 0.0
			c.a = alpha
			img.set_pixel(x, y, c)
	_tex_cache = ImageTexture.create_from_image(img)
	return _tex_cache
