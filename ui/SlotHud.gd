# Godot 4.x - Sabira / HOUSE
extends CanvasLayer
## 4-slot bottom-left carry HUD. Fills in pickup order from GameState.carried_flags.
## Glass excluded. Empty slots silent. Sits above Subtitle captions.

const SLOT_COUNT: int = 4
const SLOT_PX: int = 96
const ICON_PX: int = 88
const GAP_PX: int = 10
## Subtitle band is roughly bottom 40..120px; keep slots above it.
const MARGIN_BOTTOM: float = 48.0
const MARGIN_LEFT: float = 16.0

const ICON_DIR: String = "res://ui/icons/"

var _icon_rects: Array[TextureRect] = []


func _ready() -> void:
	layer = 12
	add_to_group("slot_hud")
	_build_slots()
	if GameState != null:
		if not GameState.inventory_changed.is_connected(_on_inventory_changed):
			GameState.inventory_changed.connect(_on_inventory_changed)
	_refresh()


func _on_inventory_changed() -> void:
	_refresh()


func _build_slots() -> void:
	var empty_tex: Texture2D = load("res://ui/slot_empty.png") as Texture2D
	var frame_tex: Texture2D = load("res://ui/slot_frame.png") as Texture2D

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var row_w: float = float(SLOT_COUNT * SLOT_PX + (SLOT_COUNT - 1) * GAP_PX)
	var margin := Control.new()
	margin.name = "Margin"
	margin.anchor_left = 0.0
	margin.anchor_top = 1.0
	margin.anchor_right = 0.0
	margin.anchor_bottom = 1.0
	margin.offset_left = MARGIN_LEFT
	margin.offset_top = -(MARGIN_BOTTOM + float(SLOT_PX))
	margin.offset_right = MARGIN_LEFT + row_w
	margin.offset_bottom = -MARGIN_BOTTOM
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", GAP_PX)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	for i in SLOT_COUNT:
		var slot := Control.new()
		slot.name = "Slot%d" % i
		slot.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(slot)

		var empty := TextureRect.new()
		empty.name = "Empty"
		empty.texture = empty_tex
		empty.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		empty.stretch_mode = TextureRect.STRETCH_SCALE
		empty.set_anchors_preset(Control.PRESET_FULL_RECT)
		empty.modulate = Color(1.0, 1.0, 1.0, 1.0)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(empty)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.anchor_left = 0.5
		icon.anchor_top = 0.5
		icon.anchor_right = 0.5
		icon.anchor_bottom = 0.5
		icon.offset_left = -float(ICON_PX) * 0.5
		icon.offset_top = -float(ICON_PX) * 0.5
		icon.offset_right = float(ICON_PX) * 0.5
		icon.offset_bottom = float(ICON_PX) * 0.5
		icon.visible = false
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		_icon_rects.append(icon)

		var frame := TextureRect.new()
		frame.name = "Frame"
		frame.texture = frame_tex
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.modulate = Color(1.0, 1.0, 1.0, 1.0)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(frame)


func _refresh() -> void:
	for icon in _icon_rects:
		icon.texture = null
		icon.visible = false

	if GameState == null:
		return

	# Fill slots in carry / pickup order (max SLOT_COUNT).
	var carry: Array = GameState.get_carry_list()
	var slot_i: int = 0
	for flag_any in carry:
		if slot_i >= SLOT_COUNT:
			break
		var flag_id: String = String(flag_any)
		if flag_id == "" or flag_id == "glass":
			continue
		var icon_path: String = ICON_DIR + flag_id + ".png"
		var tex: Texture2D = load(icon_path) as Texture2D
		if tex == null:
			continue
		_icon_rects[slot_i].texture = tex
		_icon_rects[slot_i].visible = true
		slot_i += 1
