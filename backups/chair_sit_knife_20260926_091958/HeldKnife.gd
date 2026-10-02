# Godot 4.x - Sabira / HOUSE
extends Node3D
## Instances knife.glb under camera when GameState.has_knife.

@export var knife_scene: PackedScene
@export var hold_offset: Vector3 = Vector3(0.22, -0.18, -0.35)
@export var hold_rotation_deg: Vector3 = Vector3(5, 95, -25)
@export var hold_scale: float = 1.0

var _mesh: Node3D = null


func _ready() -> void:
	if knife_scene == null:
		knife_scene = load("res://props/clutter/knife.glb") as PackedScene
	if GameState != null and not GameState.inventory_changed.is_connected(_on_inventory_changed):
		GameState.inventory_changed.connect(_on_inventory_changed)
	_refresh()


func _on_inventory_changed() -> void:
	_refresh()


func _refresh() -> void:
	var want := GameState != null and GameState.has_knife
	if want:
		if _mesh == null or not is_instance_valid(_mesh):
			_spawn_mesh()
	else:
		_clear_mesh()


func _spawn_mesh() -> void:
	_clear_mesh()
	if knife_scene == null:
		return
	_mesh = knife_scene.instantiate() as Node3D
	if _mesh == null:
		return
	_mesh.name = "HeldKnifeMesh"
	add_child(_mesh)
	_mesh.position = hold_offset
	_mesh.rotation_degrees = hold_rotation_deg
	_mesh.scale = Vector3.ONE * hold_scale


func _clear_mesh() -> void:
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.queue_free()
	_mesh = null
	# Also free any leftover mesh children (e.g. after hot-reload).
	for c in get_children():
		if c is Node3D:
			c.queue_free()
