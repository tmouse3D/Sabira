# Godot 4.x ?- Sabira / HOUSE
class_name Painting
extends Interactable
## Wall painting: examine for a short wrong subtitle line.

@export var painting_title: String = "Painting"
@export_multiline var look_text: String = ""
@export var speaker: String = ""
@export var show_every_look: bool = true
@export var canvas_texture: Texture2D

var _seen: bool = false


func _ready() -> void:
	collision_layer = 5  # world (1) + interactable (4)
	collision_mask = 0
	prompt_text = "[E] Look"
	_apply_canvas_texture()


func _apply_canvas_texture() -> void:
	if canvas_texture == null:
		return
	var canvas := get_node_or_null("Canvas") as MeshInstance3D
	if canvas == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = canvas_texture
	mat.roughness = 0.9
	mat.metallic = 0.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	canvas.material_override = mat


func _on_interact(_player: Node) -> void:
	if not show_every_look and _seen:
		return
	_seen = true
	var who := speaker if speaker != "" else painting_title
	get_tree().call_group("subtitle", "show_line", who, look_text)
