# Godot 4.x - Sabira / HOUSE
class_name HeldKnife
extends Node3D
## Instances knife.glb under camera when GameState.has_knife.
## Hold pose prefers Player root exports (Inspector: Player > Held Knife).
## Local hold_* exports are fallback defaults if no CharacterBody3D parent.
## Separate from world KnifePickup; cast_shadow OFF on held mesh only.

@export var knife_scene: PackedScene
@export var hold_offset: Vector3 = Vector3(0.22, -0.22, -0.42)
@export var hold_rotation_deg: Vector3 = Vector3(-10, 85, 110)
@export var hold_scale: float = 1.15

const _CarryShadows = preload("res://player/CarryShadows.gd")

var _mesh: Node3D = null
## Scratch store for CarryShadows (held instance is freed on drop; no world restore).
var _shadow_store: Dictionary = {}


func _ready() -> void:
	add_to_group("held_knife")
	if knife_scene == null:
		knife_scene = load("res://props/clutter/knife.glb") as PackedScene
	if GameState != null and not GameState.inventory_changed.is_connected(_on_inventory_changed):
		GameState.inventory_changed.connect(_on_inventory_changed)
	_refresh()


func _process(_delta: float) -> void:
	_apply_hold_transform()


func _on_inventory_changed() -> void:
	_refresh()


func _refresh() -> void:
	var want := GameState != null and GameState.has_knife
	if want:
		if _mesh == null or not is_instance_valid(_mesh):
			_spawn_mesh()
		else:
			_apply_hold_transform()
	else:
		_clear_mesh()


func _find_player() -> Node:
	var p := get_parent()
	while p and not (p is CharacterBody3D):
		p = p.get_parent()
	return p


func _apply_hold_transform() -> void:
	if _mesh == null or not is_instance_valid(_mesh):
		return
	var p := _find_player()
	if p != null and "knife_hold_offset" in p:
		_mesh.position = p.knife_hold_offset
		_mesh.rotation_degrees = p.knife_hold_rotation_deg
		_mesh.scale = Vector3.ONE * p.knife_hold_scale
	else:
		_mesh.position = hold_offset
		_mesh.rotation_degrees = hold_rotation_deg
		_mesh.scale = Vector3.ONE * hold_scale


func _spawn_mesh() -> void:
	_clear_mesh()
	if knife_scene == null:
		return
	_mesh = knife_scene.instantiate() as Node3D
	if _mesh == null:
		return
	_mesh.name = "HeldKnifeMesh"
	add_child(_mesh)
	_apply_hold_transform()
	# No floating mid-air shadow while knife is on camera.
	_shadow_store.clear()
	_CarryShadows.set_tree(_mesh, false, _shadow_store)
	if GameState != null and GameState.knife_bloody:
		stain_blood()


func _clear_mesh() -> void:
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.queue_free()
	_mesh = null
	_shadow_store.clear()
	# Also free any leftover mesh children (e.g. after hot-reload).
	for c in get_children():
		if c is Node3D:
			c.queue_free()

func stain_blood() -> void:
	if GameState != null:
		GameState.knife_bloody = true
	if _mesh == null or not is_instance_valid(_mesh):
		return
	_redden_knife(_mesh)
	if _mesh.get_node_or_null("KnifeBlood") != null:
		return
	var stain := MeshInstance3D.new()
	stain.name = "KnifeBlood"
	var box := BoxMesh.new()
	box.size = Vector3(0.018, 0.008, 0.06)
	stain.mesh = box
	# Blade runs along local Z. Child only. Hold offset is untouched.
	stain.position = Vector3(0.0, 0.006, 0.04)
	stain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.48, 0.02, 0.03)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	stain.material_override = mat
	_mesh.add_child(stain)

func _redden_knife(node: Node) -> void:
	if node is MeshInstance3D and String(node.name) != "KnifeBlood":
		var mi := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		var active := mi.get_active_material(0)
		if active != null:
			var copied := active.duplicate() as Material
			if copied is StandardMaterial3D:
				mat = copied as StandardMaterial3D
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.36, 0.025, 0.03)
		mi.material_override = mat
	for child in node.get_children():
		_redden_knife(child)

func wash_blood() -> void:
	if GameState != null:
		GameState.knife_bloody = false
	if _mesh == null or not is_instance_valid(_mesh):
		return
	var blob := _mesh.get_node_or_null("KnifeBlood")
	if blob != null:
		blob.queue_free()
	_clear_blood_override(_mesh)


func _clear_blood_override(node: Node) -> void:
	if node is MeshInstance3D and String(node.name) != "KnifeBlood":
		(node as MeshInstance3D).material_override = null
	for child in node.get_children():
		_clear_blood_override(child)