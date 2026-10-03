extends MeshInstance3D
## Living-room couch TV. Loads slide PNGs from disk so they can be replaced.
## Does not touch the TV set material. Hidden unless Tash is on the couch.
## TvFlicker is a small screen glow. Off whenever the screen hides.

@export var slide_paths: PackedStringArray = PackedStringArray([
	"res://art/tv_placeholders/slide_1.png",
	"res://art/tv_placeholders/slide_2.png",
	"res://art/tv_placeholders/slide_3.png",
	"res://art/tv_placeholders/slide_4.png",
])
@export var seconds_per_slide: float = 3.5
@export var flicker_path: NodePath = NodePath("TvFlicker")

const _GLOW_BASE := 0.55

var _on: bool = false
var _index: int = 0
var _left: float = 0.0
var _mat: StandardMaterial3D
var _glow: OmniLight3D
var _glow_t: float = 0.0
var _glow_kick: float = 0.0


func _ready() -> void:
	visible = false
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material_override = _mat
	_glow = get_node_or_null(flicker_path) as OmniLight3D
	_set_glow(false)
	_apply_slide(0)


func set_playing(want_on: bool) -> void:
	_on = want_on
	visible = want_on
	_set_glow(want_on)
	if not want_on:
		return
	_index = 0
	_left = seconds_per_slide
	_glow_kick = 0.1
	_apply_slide(0)


func _process(delta: float) -> void:
	if not _on or slide_paths.is_empty():
		_set_glow(false)
		return
	_glow_t += delta
	_glow_kick = maxf(_glow_kick - delta * 0.35, 0.0)
	if _glow != null:
		var wobble := 0.05 * sin(_glow_t * 5.2) + 0.03 * sin(_glow_t * 11.0)
		_glow.light_energy = clampf(_GLOW_BASE + wobble + _glow_kick, 0.35, 0.75)
	_left -= delta
	if _left > 0.0:
		return
	_left = seconds_per_slide
	_index = (_index + 1) % slide_paths.size()
	_glow_kick = 0.12
	_apply_slide(_index)


func _set_glow(want_on: bool) -> void:
	if _glow == null:
		return
	_glow.visible = want_on
	if not want_on:
		_glow.light_energy = 0.0
		return
	_glow.light_energy = _GLOW_BASE


func _apply_slide(index: int) -> void:
	if _mat == null or slide_paths.is_empty():
		return
	var path := String(slide_paths[index % slide_paths.size()])
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("TvSlideshow: missing " + path)
		return
	_mat.albedo_texture = tex
