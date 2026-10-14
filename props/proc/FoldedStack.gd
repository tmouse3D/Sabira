# Godot 4.x - Sabira / HOUSE
@tool
extends Node3D
## Folded-clothes stack for the laundry baskets (props/laundry/LaundryCorner.tscn). Each layer is
## a low-poly soft slab: subdivided box projected onto a rounded box (soft edges), pillowy top,
## edges drooping, plus a rolled fold along one long side. Uneven sizes / offsets / twists,
## colours from a faded laundry palette with a small PSX-style noise texture (nearest filter).
## Origin = bottom centre of the stack.

@export var count: int = 6
@export var footprint: Vector2 = Vector2(0.26, 0.2)
@export var slab_h: float = 0.045
@export var seed_value: int = 1

const PALETTE := [
	Color(0.46, 0.56, 0.68),   # faded blue
	Color(0.62, 0.34, 0.32),   # dusty red
	Color(0.86, 0.82, 0.70),   # cream
	Color(0.55, 0.55, 0.56),   # grey
	Color(0.76, 0.62, 0.30),   # mustard
	Color(0.48, 0.36, 0.26),   # brown
]
const SUBDIV := 4

static var _noise_cache: Dictionary = {}


func _ready() -> void:
	for c in get_children():
		c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var y := 0.0
	var last := -1
	for i in count:
		var h := slab_h * rng.randf_range(0.8, 1.2)
		var sz := Vector2(footprint.x * rng.randf_range(0.86, 1.0), footprint.y * rng.randf_range(0.86, 1.0))
		var ci := rng.randi() % PALETTE.size()
		if ci == last:
			ci = (ci + 1 + rng.randi() % (PALETTE.size() - 1)) % PALETTE.size()
		last = ci
		var mat := _fabric_mat(ci)
		var slab := MeshInstance3D.new()
		slab.mesh = _soft_slab(Vector3(sz.x, h, sz.y), rng)
		slab.material_override = mat
		slab.position = Vector3(rng.randf_range(-0.012, 0.012), y + h * 0.5, rng.randf_range(-0.012, 0.012))
		slab.rotation = Vector3(deg_to_rad(rng.randf_range(-2.0, 2.0)), deg_to_rad(rng.randf_range(-8.0, 8.0)), deg_to_rad(rng.randf_range(-2.0, 2.0)))
		add_child(slab)
		# Rolled fold along one long edge (front or back, random).
		var roll := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = h * 0.42
		cm.bottom_radius = h * 0.42
		cm.height = sz.x * 0.92
		cm.radial_segments = 6
		cm.rings = 1
		roll.mesh = cm
		roll.material_override = mat
		roll.rotation.z = PI * 0.5
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		roll.position = Vector3(0.0, -h * 0.05, side * (sz.y * 0.5 - h * 0.3))
		slab.add_child(roll)
		y += h * 0.92   # slight compression: layers sit into each other


## Subdivided box -> rounded box (radius r) -> pillow top + drooping edges.
func _soft_slab(size: Vector3, rng: RandomNumberGenerator) -> ArrayMesh:
	var bm := BoxMesh.new()
	bm.size = size
	bm.subdivide_width = SUBDIV
	bm.subdivide_depth = SUBDIV
	bm.subdivide_height = 1
	var arr := bm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var half := size * 0.5
	var r := minf(size.y * 0.45, minf(half.x, half.z) * 0.5)
	var inner := half - Vector3(r, r, r)
	var bulge := size.y * rng.randf_range(0.15, 0.3)
	var droop := size.y * rng.randf_range(0.2, 0.4)
	for i in verts.size():
		var p := verts[i]
		var q := p.clamp(-inner, inner)
		var d := p - q
		if d.length() > 0.00001:
			p = q + d.normalized() * r
		var ux := clampf(p.x / half.x, -1.0, 1.0)
		var uz := clampf(p.z / half.z, -1.0, 1.0)
		if p.y > 0.0:
			p.y += bulge * (1.0 - ux * ux) * (1.0 - uz * uz)
		var e := maxf(absf(ux), absf(uz))
		p.y -= droop * e * e * e
		verts[i] = p
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = null
	arr[Mesh.ARRAY_TANGENT] = null
	var tmp := ArrayMesh.new()
	tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(tmp, 0)
	st.generate_normals()
	return st.commit()


func _fabric_mat(ci: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.albedo_texture = _noise_tex(ci)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	m.uv1_scale = Vector3(2, 2, 2)
	return m


## 16x16 flat colour + faint per-pixel noise (PSX look), cached per palette entry.
static func _noise_tex(ci: int) -> ImageTexture:
	if _noise_cache.has(ci):
		return _noise_cache[ci]
	var base: Color = PALETTE[ci]
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + ci
	for y in 16:
		for x in 16:
			var n := rng.randf_range(-0.045, 0.045)
			img.set_pixel(x, y, Color(base.r + n, base.g + n, base.b + n))
	var t := ImageTexture.create_from_image(img)
	_noise_cache[ci] = t
	return t
