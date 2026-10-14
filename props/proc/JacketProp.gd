# Godot 4.x - Sabira / HOUSE
@tool
extends Node3D
## Low-poly procedural jacket slumped over a laundry basket rim (no jacket model in the asset
## folders). Origin = top of the clothes pile; local +Z = the rim side the front flap hangs over.
## Parts: back panel lying on the pile, front flap folded down over the rim, one sleeve hanging
## over the side, one folded across the back, a rolled collar. Used by props/laundry/LaundryCorner.tscn.

@export var fabric_color: Color = Color(0.27, 0.31, 0.24)
@export var lining_color: Color = Color(0.48, 0.16, 0.14)


func _ready() -> void:
	for c in get_children():
		c.queue_free()
	var fab := StandardMaterial3D.new()
	fab.albedo_color = fabric_color
	fab.roughness = 1.0
	var lin := StandardMaterial3D.new()
	lin.albedo_color = lining_color
	lin.roughness = 1.0
	# Back panel on top of the pile, slightly sagging.
	_box(Vector3(0.30, 0.028, 0.34), Vector3(0.0, 0.0, 0.03), Vector3(-4.0, 0.0, 3.0), fab)
	# Front flap hinged at the rim (z ~0.21), hanging down outside the basket.
	_box(Vector3(0.29, 0.026, 0.22), Vector3(0.0, -0.106, 0.238), Vector3(75.0, 0.0, -2.0), fab)
	# Open front: lining strip visible along the hinge.
	_box(Vector3(0.05, 0.03, 0.20), Vector3(0.0, -0.10, 0.232), Vector3(75.0, 0.0, -2.0), lin, 0.004)
	# Left sleeve drooping over the side rim.
	_sleeve(Vector3(-0.24, -0.04, -0.06), Vector3(0.0, 15.0, -55.0), fab)
	# Right sleeve folded across the back.
	_sleeve(Vector3(0.03, 0.05, -0.01), Vector3(0.0, 32.0, 90.0), fab)
	# Rolled collar at the back edge.
	var col := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.045
	tm.outer_radius = 0.075
	tm.rings = 12
	tm.ring_segments = 6
	col.mesh = tm
	col.material_override = fab
	col.position = Vector3(0.0, 0.025, -0.13)
	col.scale = Vector3(1.0, 0.55, 0.8)
	add_child(col)


func _box(size: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material, lift: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.rotation_degrees = rot_deg
	mi.position = pos + mi.basis.y * lift
	add_child(mi)


func _sleeve(pos: Vector3, rot_deg: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.034
	cm.height = 0.30
	cm.radial_segments = 8
	cm.rings = 2
	mi.mesh = cm
	mi.material_override = mat
	mi.rotation_degrees = rot_deg
	mi.position = pos
	mi.scale = Vector3(1.0, 1.0, 0.75)   # slightly flattened, empty fabric
	add_child(mi)
