@tool
extends Node3D
## Wrapper helper: hides named meshes and/or drops surface indices from a named mesh
## of the instanced glb child, at runtime and in the editor (survives editor saves).

@export var hide_meshes: PackedStringArray = []
@export var strip_mesh: String = ""
@export var strip_surfaces: PackedInt32Array = []


func _ready() -> void:
	for nm in hide_meshes:
		var n := find_child(nm, true, false) as Node3D
		if n:
			n.visible = false
	if strip_mesh == "":
		return
	var mi := find_child(strip_mesh, true, false) as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	var src := mi.mesh
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		if strip_surfaces.has(s):
			continue
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), src.surface_get_arrays(s))
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))
	mi.mesh = out
