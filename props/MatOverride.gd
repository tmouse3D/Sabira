# Godot 4.x - Sabira / HOUSE
extends Node3D
## Material overrides applied at _ready (survives editor saves of House.tscn, unlike per-child
## overrides on an instanced GLB). Used by the bath wrapper scenes.
## Walks EVERY MeshInstance3D descendant (mesh_names empty = all; otherwise only those names)
## and sets a surface override on EVERY surface index. Each surface gets a copy of `material`
## that keeps the original surface's cull mode (the bath GLBs are double-sided; culling their
## back faces is what showed as black), vertex-colour albedo flag and transparency.

@export var mesh_names: PackedStringArray = []
@export var material: Material
## Force double-sided on every surface regardless of the original.
@export var force_double_sided: bool = true


func _ready() -> void:
	if material == null:
		return
	var cache := {}
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		if not mesh_names.is_empty() and not mesh_names.has(String(mi.name)):
			continue
		mi.material_override = null
		for i in mi.mesh.get_surface_count():
			var orig := mi.mesh.surface_get_material(i)
			if cache.has(orig):
				mi.set_surface_override_material(i, cache[orig])
				continue
			var m := material.duplicate() as Material
			var sm := m as BaseMaterial3D
			var om := orig as BaseMaterial3D
			if sm != null:
				if om != null:
					sm.cull_mode = om.cull_mode
					sm.vertex_color_use_as_albedo = om.vertex_color_use_as_albedo
					sm.transparency = om.transparency
				if force_double_sided:
					sm.cull_mode = BaseMaterial3D.CULL_DISABLED
			cache[orig] = m
			mi.set_surface_override_material(i, m)
