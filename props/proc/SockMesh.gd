@tool
# Godot 4.x - Sabira / HOUSE
extends MeshInstance3D
## Procedural lying sock: a flattened tube along an L-shaped path (leg along -Z, heel bend,
## foot along +X) with a rounded toe and an open cuff. Lies on the floor (y = 0 .. thickness).
## Used by props/laundry/LaundryCorner.tscn (Sock_1..3) in place of the old flat crumple quads.

@export var leg_len: float = 0.26:
	set(v):
		leg_len = v
		_rebuild()
@export var foot_len: float = 0.17:
	set(v):
		foot_len = v
		_rebuild()
@export var width: float = 0.075:
	set(v):
		width = v
		_rebuild()
@export var thickness: float = 0.022:
	set(v):
		thickness = v
		_rebuild()
## Heel bend angle in degrees (90 = L-shape).
@export var heel_deg: float = 95.0:
	set(v):
		heel_deg = v
		_rebuild()
@export var seed_value: int = 1:
	set(v):
		seed_value = v
		_rebuild()
@export var sock_material: Material:
	set(v):
		sock_material = v
		_rebuild()

const RING := 10
const STEPS := 22


func _ready() -> void:
	_rebuild()


func _path() -> Array:
	# Points + tangents: cuff -> straight leg -> heel arc -> foot -> toe.
	var pts: Array = []
	var r := width * 0.9
	var ang := deg_to_rad(heel_deg)
	var leg_n := 8
	for i in leg_n + 1:
		var t := float(i) / leg_n
		pts.append([Vector3(0, 0, -leg_len + t * (leg_len - r)), Vector3(0, 0, 1)])
	var c := Vector3(r, 0, -r)
	var arc_n := 6
	for i in range(1, arc_n + 1):
		var a := ang * float(i) / arc_n
		var p := c + Vector3(-cos(a) * r, 0, sin(a) * r)
		var tan := Vector3(sin(a), 0, cos(a))
		pts.append([p, tan])
	var last: Vector3 = pts[pts.size() - 1][0]
	var dir: Vector3 = pts[pts.size() - 1][1]
	var foot_n := 7
	for i in range(1, foot_n + 1):
		pts.append([last + dir * (foot_len - r) * float(i) / foot_n, dir])
	return pts


func _rebuild() -> void:
	if not is_inside_tree() and not Engine.is_editor_hint():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pts := _path()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var total := 0.0
	var vs: Array = []
	for i in n:
		if i > 0:
			total += (pts[i][0] as Vector3).distance_to(pts[i - 1][0])
		var p: Vector3 = pts[i][0]
		var tan: Vector3 = (pts[i][1] as Vector3).normalized()
		var side := Vector3.UP.cross(tan).normalized()
		var k := float(i) / (n - 1)
		# Toe rounds off over the last 20 %; the cuff is a little wider and loose.
		var taper := 1.0
		if k > 0.8:
			taper = sqrt(maxf(0.0, 1.0 - pow((k - 0.8) / 0.2, 2.0))) * 0.85 + 0.15
		var w := width * 0.5 * taper * (1.08 if k < 0.06 else 1.0) * (1.0 + rng.randf_range(-0.04, 0.04))
		var h := thickness * 0.5 * maxf(taper, 0.35)
		var ring: Array = []
		for j in RING:
			var a := TAU * float(j) / RING
			var off := side * cos(a) * w + Vector3.UP * (sin(a) * h + h)
			ring.append(p + off)
		vs.append([ring, total])
	for i in n - 1:
		var r0: Array = vs[i][0]
		var r1: Array = vs[i + 1][0]
		var v0: float = vs[i][1] / maxf(total, 0.001)
		var v1: float = vs[i + 1][1] / maxf(total, 0.001)
		for j in RING:
			var j2 := (j + 1) % RING
			var u0 := float(j) / RING
			var u1 := float(j + 1) / RING
			_tri(st, r0[j], r1[j], r1[j2], Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1))
			_tri(st, r0[j], r1[j2], r0[j2], Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0))
	# Toe cap.
	var tip: Vector3 = (pts[n - 1][0] as Vector3) + (pts[n - 1][1] as Vector3).normalized() * width * 0.12 + Vector3.UP * thickness * 0.4
	var rl: Array = vs[n - 1][0]
	for j in RING:
		_tri(st, rl[j], tip, rl[(j + 1) % RING], Vector2(0, 1), Vector2(0.5, 1), Vector2(1, 1))
	st.generate_normals()
	var m := st.commit()
	if sock_material != null:
		m.surface_set_material(0, sock_material)
	mesh = m


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)
