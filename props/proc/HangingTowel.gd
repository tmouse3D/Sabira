@tool
extends MeshInstance3D
## Towel folded over a rail: back drape, arc over the bar, front drape.
## Origin = bar centre. Rounded bottom corners, slight sag and bulge.
## Texture v runs back hem (0) -> front hem (1); hem stripes sit near both ends.

@export var width: float = 0.3
@export var front_len: float = 0.45
@export var back_len: float = 0.4
@export var bar_radius: float = 0.016
@export var sag: float = 0.02
@export var corner_radius: float = 0.035
@export var tilt_seed: int = 1
@export var towel_material: Material

const COLS := 10
const DRAPE_ROWS := 14
const ARC_ROWS := 8


func _ready() -> void:
	_build()


func _drape_point(x: float, depth: float, length: float, side: float, rng_w: float) -> Vector3:
	var hw := width * 0.5
	# Rounded bottom corners (clamp into a rounded rectangle).
	var cr := corner_radius
	var cx := hw - cr
	var cy := length - cr
	if absf(x) > cx and depth > cy:
		var d := Vector2(absf(x) - cx, depth - cy)
		if d.length() > cr:
			d = d.normalized() * cr
		x = signf(x) * (cx + d.x)
		depth = cy + d.y
	var u := x / hw
	var t := depth / maxf(length, 0.001)
	var y := -depth - sag * (1.0 - u * u) * t
	var z := side * (bar_radius + 0.006 * t + 0.008 * (1.0 - u * u) * sin(PI * t)) + side * rng_w * t
	return Vector3(x, y, z)


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = tilt_seed
	var wob := rng.randf_range(-0.006, 0.006)
	var arc_len := PI * bar_radius
	var total := back_len + arc_len + front_len
	var rows: Array = []  # each: Array of [Vector3, Vector2]
	# Back drape: bottom -> top.
	for r in DRAPE_ROWS + 1:
		var depth := back_len * (1.0 - float(r) / DRAPE_ROWS)
		var row: Array = []
		for c in COLS + 1:
			var x := (float(c) / COLS - 0.5) * width
			var p := _drape_point(x, depth, back_len, -1.0, wob)
			row.append([p, Vector2(float(c) / COLS, (back_len - depth) / total)])
		rows.append(row)
	# Arc over the bar.
	for r in range(1, ARC_ROWS):
		var a := PI * float(r) / ARC_ROWS
		var row: Array = []
		for c in COLS + 1:
			var x := (float(c) / COLS - 0.5) * width
			var p := Vector3(x, sin(a) * bar_radius, -cos(a) * bar_radius)
			row.append([p, Vector2(float(c) / COLS, (back_len + arc_len * float(r) / ARC_ROWS) / total)])
		rows.append(row)
	# Front drape: top -> bottom.
	for r in DRAPE_ROWS + 1:
		var depth := front_len * float(r) / DRAPE_ROWS
		var row: Array = []
		for c in COLS + 1:
			var x := (float(c) / COLS - 0.5) * width
			var p := _drape_point(x, depth, front_len, 1.0, -wob)
			row.append([p, Vector2(float(c) / COLS, (back_len + arc_len + depth) / total)])
		rows.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rows.size() - 1:
		for c in COLS:
			var q := [rows[r][c], rows[r][c + 1], rows[r + 1][c], rows[r][c + 1], rows[r + 1][c + 1], rows[r + 1][c]]
			for e in q:
				st.set_uv(e[1])
				st.add_vertex(e[0])
	st.generate_normals()
	var m := st.commit()
	if towel_material:
		m.surface_set_material(0, towel_material)
	mesh = m
