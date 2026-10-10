# Godot 4.x ?- Sabira / HOUSE
class_name Painting
extends Interactable
## Wall painting: examine for a short wrong subtitle line.

@export var painting_title: String = "Painting"
@export_multiline var look_text: String = ""
@export var speaker: String = ""
@export var show_every_look: bool = true
@export var canvas_texture: Texture2D
## Look subtitle time. Paintings only: global Subtitle default (3.5 s) + 1.0 s.
@export var look_duration: float = 4.5
## Per-instance size override (metres, frame outer W x H). Zero = keep Painting.tscn size.
## Set as an exported var on the instance so editor re-saves keep it (child overrides get dropped).
@export var frame_size: Vector2 = Vector2.ZERO

var _seen: bool = false


func _ready() -> void:
	collision_layer = 5  # world (1) + interactable (4)
	collision_mask = 0
	prompt_text = "[E] Look"
	_apply_frame_size()
	_apply_canvas_texture()


func _apply_frame_size() -> void:
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return
	var w := frame_size.x - 0.07
	var h := frame_size.y - 0.08
	var canvas := get_node_or_null("Canvas") as MeshInstance3D
	if canvas != null:
		var q := QuadMesh.new()
		q.size = Vector2(w, h)
		canvas.mesh = q
	var frame := get_node_or_null("Frame") as MeshInstance3D
	if frame != null:
		var bm := BoxMesh.new()
		bm.size = Vector3(frame_size.x, frame_size.y, 0.04)
		frame.mesh = bm
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		var bs := BoxShape3D.new()
		bs.size = Vector3(frame_size.x, frame_size.y, 0.1)
		col.shape = bs


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
	get_tree().call_group("subtitle", "show_line", who, look_text, look_duration)
