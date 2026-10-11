# Godot 4.x ?- Sabira / HOUSE
extends CanvasLayer
## Short story subtitle (speaker + line).
## Layout: word-smart autowrap, width = WIDTH_FRAC of the viewport, centred horizontally.
## The box grows UPWARD from a bottom edge that sits GAP_ABOVE_SLOTS px above the top of the
## SlotHud slot row (group "slot_hud", its Root/Margin rect), so 2-3 wrapped rows never cover the
## slots. Re-laid out on viewport resize and on every show_line.

const WIDTH_FRAC: float = 0.48
const GAP_ABOVE_SLOTS: float = 8.0
## Used when no SlotHud is found: SlotHud MARGIN_BOTTOM 48 + SLOT_PX 96.
const FALLBACK_SLOT_TOP_FROM_BOTTOM: float = 144.0

@onready var _label: Label = $Label

var _timer: float = 0.0


func _ready() -> void:
	add_to_group("subtitle")
	layer = 20
	if _label:
		_label.text = ""
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	visible = false
	set_process(false)
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_layout):
		vp.size_changed.connect(_layout)
	_layout.call_deferred()


## Distance (canvas px) from the viewport bottom up to the top edge of the SlotHud slot row.
func _slot_top_from_bottom(vp_h: float) -> float:
	var hud := get_tree().get_first_node_in_group("slot_hud")
	if hud != null:
		var margin := hud.get_node_or_null("Root/Margin") as Control
		if margin != null and margin.is_inside_tree():
			var top := margin.get_global_rect().position.y
			if top > 0.0 and top < vp_h:
				return vp_h - top
	return FALLBACK_SLOT_TOP_FROM_BOTTOM


func _layout() -> void:
	if _label == null or not is_inside_tree():
		return
	var vp_size := get_viewport().get_visible_rect().size
	var bottom := _slot_top_from_bottom(vp_size.y) + GAP_ABOVE_SLOTS
	var side := (1.0 - WIDTH_FRAC) * 0.5
	_label.anchor_left = side
	_label.anchor_right = 1.0 - side
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = 0.0
	_label.offset_right = 0.0
	_label.offset_bottom = -bottom
	# Zero-height box at the bottom edge; GROW_DIRECTION_BEGIN lets the wrapped text grow upward.
	_label.offset_top = -bottom


func show_line(speaker: String, text: String, duration: float = 3.5) -> void:
	if _label == null:
		return
	if speaker != "":
		_label.text = "%s\n%s" % [speaker, text]
	else:
		_label.text = text
	_layout()
	visible = true
	_timer = duration
	set_process(true)
	if GameState != null and GameState.has_signal("caption_changed"):
		GameState.caption_changed.emit(speaker, text, duration)
	# Hide interact prompt while the line is up; Prompt restores after.
	get_tree().call_group("interact_prompt", "suppress_for", duration)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		visible = false
		if _label:
			_label.text = ""
		set_process(false)
		if GameState != null and GameState.has_signal("caption_changed"):
			GameState.caption_changed.emit("", "", 0.0)
