@tool
extends MeshInstance3D
## Low-poly dish: flat centre, sloped rim. Planar top-down UVs. Origin = bottom centre.

@export var radius: float = 0.1
@export var depth: float = 0.02
@export var segments: int = 16
@export var plate_material: Material


func _ready() -> void:
	_build()


func _build() -> void:
	var prof := [Vector2(0.0, 0.0), Vector2(0.6, 0.0), Vector2(0.85, 0.55), Vector2(1.0, 1.0)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in prof.size() - 1:
		for s in segments:
			var a0 := TAU * float(s) / segments
			var a1 := TAU * float(s + 1) / segments
			var quad := [[k, a0], [k, a1], [k + 1, a0], [k, a1], [k + 1, a1], [k + 1, a0]]
			for e in quad:
				var pr: Vector2 = prof[e[0]]
				var p := Vector3(cos(e[1]) * pr.x * radius, pr.y * depth, sin(e[1]) * pr.x * radius)
				st.set_uv(Vector2(p.x / (2.0 * radius) + 0.5, p.z / (2.0 * radius) + 0.5))
				st.add_vertex(p)
	st.generate_normals()
	var m := st.commit()
	if plate_material:
		m.surface_set_material(0, plate_material)
	mesh = m
