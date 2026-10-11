# Godot 4.x - Sabira / HOUSE
class_name PocketWatch
extends Interactable
## Dad's pocket watch (clock puzzle). Spawned by GameState.find_pocket_watch() where it was
## found (an armed tash_room_key search site). NOT an inventory item: it stays here as a small
## world prop, [E] Look re-opens the close-up (ui/WatchZoomUI.gd) with the watch time.

const WatchZoomUIScript := preload("res://ui/WatchZoomUI.gd")
const FACE_TEXTURE_PATH := "res://props/pocketwatch/pocketwatch_gray.png"

@export var look_prompt: String = "[E] Look"
@export var first_line: String = "Dad's pocket watch. Stopped at the same time, every night... Why this time?"
@export var line_duration: float = 4.0

var _ui: Node = null
var _say_line_on_close: bool = false


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	prompt_text = look_prompt
	add_to_group("pocket_watch")
	_build()


func _build() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.46, 0.46, 0.48, 1.0)
	metal.metallic = 0.6
	metal.roughness = 0.55
	metal.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var case_mesh := CylinderMesh.new()
	case_mesh.top_radius = 0.032
	case_mesh.bottom_radius = 0.032
	case_mesh.height = 0.012
	case_mesh.radial_segments = 12
	case_mesh.rings = 1
	case_mesh.material = metal
	var case_mi := MeshInstance3D.new()
	case_mi.name = "Case"
	case_mi.mesh = case_mesh
	case_mi.position = Vector3(0.0, 0.006, 0.0)
	add_child(case_mi)

	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_texture = load(FACE_TEXTURE_PATH) as Texture2D
	face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	face_mat.alpha_scissor_threshold = 0.5
	face_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	face_mat.roughness = 0.6
	var face_mesh := QuadMesh.new()
	face_mesh.size = Vector2(0.066, 0.066)
	face_mesh.material = face_mat
	var face_mi := MeshInstance3D.new()
	face_mi.name = "Face"
	face_mi.mesh = face_mesh
	face_mi.position = Vector3(0.0, 0.0125, 0.0)
	face_mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(face_mi)

	var bow_mesh := TorusMesh.new()
	bow_mesh.inner_radius = 0.007
	bow_mesh.outer_radius = 0.011
	bow_mesh.rings = 8
	bow_mesh.ring_segments = 4
	bow_mesh.material = metal
	var bow := MeshInstance3D.new()
	bow.name = "Bow"
	bow.mesh = bow_mesh
	bow.position = Vector3(0.0, 0.004, -0.042)
	add_child(bow)

	# Short chain trailing off the bow.
	var chain_mesh := BoxMesh.new()
	chain_mesh.size = Vector3(0.004, 0.003, 0.09)
	chain_mesh.material = metal
	var chain := MeshInstance3D.new()
	chain.name = "Chain"
	chain.mesh = chain_mesh
	chain.position = Vector3(0.018, 0.002, -0.09)
	chain.rotation_degrees = Vector3(0.0, 25.0, 0.0)
	add_child(chain)

	# Generous hit box so the tiny watch is easy to target.
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.14, 0.05, 0.16)
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = shape
	cs.position = Vector3(0.0, 0.025, -0.02)
	add_child(cs)


func _ui_open() -> bool:
	return _ui != null and is_instance_valid(_ui) and bool(_ui.call("is_open"))


func can_interact(_player: Node) -> bool:
	return interact_enabled and not _ui_open() and front_ok(_player)


func _on_interact(_player: Node) -> void:
	open_zoom(false)


func open_zoom(first_find: bool) -> void:
	if _ui_open() or GameState == null:
		return
	GameState.ensure_clock_times()
	if _ui == null or not is_instance_valid(_ui):
		_ui = WatchZoomUIScript.new()
		_ui.name = "WatchZoomUI"
		var host: Node = get_tree().current_scene
		if host == null:
			host = get_tree().root
		host.add_child(_ui)
		_ui.connect("closed", _on_zoom_closed)
	_say_line_on_close = first_find
	_ui.call("open", GameState.watch_hour, GameState.watch_minute)


func _on_zoom_closed() -> void:
	if _say_line_on_close:
		_say_line_on_close = false
		get_tree().call_group("subtitle", "show_line", "SABIRA", first_line, line_duration)
	# Minute hand hidden at the same site shows up now as a pickup next to the watch.
	if GameState != null:
		GameState.flush_pending_minute_hand()
