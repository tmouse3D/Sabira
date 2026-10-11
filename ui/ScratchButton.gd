# Godot 4.x - Sabira / HOUSE
class_name ScratchButton
extends Button
## Menu button in the SlotHud hand-drawn frame style (ui/slot_frame.png as a StyleBoxTexture).
## Idle: faint frame. Hover / keyboard focus: full white frame plus a subtle flicker.
## Works while the tree is paused (process_mode ALWAYS).

const FRAME_TEX := "res://ui/slot_frame.png"
const TEXT_COLOR := Color(0.93, 0.91, 0.86)
const FONT_SIZE := 26

var _flicker_t: float = 0.0


static func frame_style(alpha: float) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(FRAME_TEX) as Texture2D
	sb.texture_margin_left = 20
	sb.texture_margin_right = 20
	sb.texture_margin_top = 20
	sb.texture_margin_bottom = 20
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	sb.modulate_color = Color(1, 1, 1, alpha)
	return sb


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(260, 56)
	add_theme_stylebox_override("normal", frame_style(0.18))
	add_theme_stylebox_override("hover", frame_style(1.0))
	add_theme_stylebox_override("focus", frame_style(1.0))
	add_theme_stylebox_override("pressed", frame_style(0.7))
	add_theme_stylebox_override("hover_pressed", frame_style(0.7))
	add_theme_stylebox_override("disabled", frame_style(0.08))
	add_theme_color_override("font_color", Color(TEXT_COLOR, 0.72))
	add_theme_color_override("font_hover_color", TEXT_COLOR)
	add_theme_color_override("font_focus_color", TEXT_COLOR)
	add_theme_color_override("font_pressed_color", TEXT_COLOR)
	add_theme_color_override("font_hover_pressed_color", TEXT_COLOR)
	add_theme_font_size_override("font_size", FONT_SIZE)
	mouse_entered.connect(func() -> void: grab_focus())


func _process(delta: float) -> void:
	if has_focus() or is_hovered():
		_flicker_t -= delta
		if _flicker_t <= 0.0:
			_flicker_t = randf_range(0.04, 0.16)
			var a := 1.0 if randf() > 0.18 else randf_range(0.55, 0.85)
			self_modulate = Color(1, 1, 1, a)
	elif self_modulate.a != 1.0:
		self_modulate = Color(1, 1, 1, 1)
