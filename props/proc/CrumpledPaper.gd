@tool
extends MeshInstance3D
## Crumpled toilet paper square: a 5x5 grid bent along a fold with random crumple.
## Built in _ready (also in the editor), so the scene only stores the parameters.

@export var size: Vector2 = Vector2(0.1, 0.11)
@export var bend: float = 0.25
@export var crumple: float = 0.012
@export var seed_value: int = 1
@export var paper_material: Material


func _ready() -> void:
	_build()


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := 5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fold_dir := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
	var pts: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	for j in n:
		for i in n:
			var u := float(i) / float(n - 1)
			var v := float(j) / float(n - 1)
			var x := (u - 0.5) * size.x
			var z := (v - 0.5) * size.y
			var dist := absf(Vector2(x, z).dot(fold_dir))
			var y := dist * bend + rng.randf_range(-crumple, crumple)
			# Edges curl a little.
			var edge := maxf(absf(u - 0.5), absf(v - 0.5)) * 2.0
			y += edge * edge * crumple * rng.randf_range(0.2, 1.0)
			x += rng.randf_range(-crumple, crumple) * 0.4
			z += rng.randf_range(-crumple, crumple) * 0.4
			pts.append(Vector3(x, y, z))
			uvs.append(Vector2(u, v))
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			var idx := [a, a + 1, a + n, a + 1, a + n + 1, a + n]
			for k in idx:
				st.set_uv(uvs[k])
				st.add_vertex(pts[k])
	st.generate_normals()
	var m := st.commit()
	if paper_material:
		m.surface_set_material(0, paper_material)
	mesh = m
