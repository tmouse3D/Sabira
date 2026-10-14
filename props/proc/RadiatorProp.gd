# Godot 4.x - Sabira / HOUSE
class_name RadiatorProp
extends Node3D
## Cast-iron radiator with a rusty chain to an open ankle shackle on the floor. Local frame:
## origin on the floor at the wall, +Z = into the room, X along the wall. Built by
## world/LowerRoom.gd. Radiator: the user's Blender model (MODEL_PATH, exported from
## Assets for games/radiator.blend by scripts/_export_radiator.py) scaled to MODEL_SIZE_FACTOR x
## the old procedural one; falls back to the procedural PSX radiator if the GLB is missing.
## Solid box collider (layer 1). Chain + shackle: no blocking. [E] Look: STORY_LINES.radiator_look.

const MODEL_PATH := "res://props/radiator/radiator.glb"
## Front-face diagonal (width x height) relative to the procedural radiator (~1.02 m).
## 1.452 = 1.2 x 1.1 x 1.1 (two +10% steps on 2026-10-13).
const MODEL_SIZE_FACTOR := 1.452
## Grunge look on the model (its GLB texture is 1x1 white): rust streaks, grime, gap AO, base dirt.
const GRUNGE_SHADER := "res://props/radiator/radiator_grunge.gdshader"
const GRUNGE_TEX := "res://props/radiator/radiator_grunge.png"
## Chain start on the model: fraction of the width from the left edge / of the height.
const CHAIN_ANCHOR_X := 0.3
const CHAIN_ANCHOR_Y := 0.25
const SECTIONS := 7
const PITCH := 0.105            # section spacing (7 x 0.105 ~ 0.74 m wide)
const SEC_R := 0.045            # section radius (8-sided), stretched in depth
const SEC_DEPTH_SCALE := 1.6
const WALL_GAP := 0.07
const FOOT_H := 0.1
const HEIGHT := 0.6
const CHAIN_FLOOR_LEN := 1.0
const LINK_STEP := 0.042

var _rust_tex: ImageTexture
var _cz: float = WALL_GAP + SEC_R * SEC_DEPTH_SCALE   # section centre depth
## Local point on the radiator the chain (and the cuff wire, see wire_anchor_global) starts at.
var anchor_local: Vector3 = Vector3.ZERO
var used_model: bool = false
var model_scale: float = 1.0


func wire_anchor_global() -> Vector3:
	return to_global(anchor_local)


func build() -> void:
	_rust_tex = _make_rust_tex()
	var iron := _mat(_make_iron_tex(), Color.WHITE, 0.8)
	iron.metallic = 0.3
	var ps: PackedScene = null
	if ResourceLoader.exists(MODEL_PATH):
		ps = load(MODEL_PATH) as PackedScene
	if ps != null:
		_build_model(ps, iron)
	else:
		push_warning("RadiatorProp: %s missing, procedural radiator" % MODEL_PATH)
		_build_procedural(iron)


## The user's model: long side along X, back against the wall (WALL_GAP), feet on the floor.
func _build_model(ps: PackedScene, iron: StandardMaterial3D) -> void:
	used_model = true
	var inst := ps.instantiate() as Node3D
	inst.name = "RadiatorModel"
	add_child(inst)
	var ab := _aabb_in_self(inst)
	var proc_diag := Vector2(PITCH * SECTIONS, HEIGHT + FOOT_H).length()
	var diag := Vector2(ab.size.x, ab.size.y).length()
	model_scale = MODEL_SIZE_FACTOR * proc_diag / maxf(diag, 0.001)
	inst.scale = Vector3.ONE * model_scale
	_apply_grunge(inst)
	ab = _aabb_in_self(inst)
	inst.position = Vector3(-(ab.position.x + ab.size.x * 0.5), -ab.position.y, WALL_GAP - ab.position.z)
	ab = _aabb_in_self(inst)
	var w := ab.size.x
	var h := ab.size.y
	var front := ab.end.z
	_cz = (ab.position.z + ab.end.z) * 0.5
	var body := StaticBody3D.new()
	body.name = "RadiatorBody"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_shape(body, ab.size + Vector3(0.02, 0.0, 0.02), ab.get_center())
	anchor_local = Vector3(-w * 0.5 + w * CHAIN_ANCHOR_X, h * CHAIN_ANCHOR_Y, front - 0.01)
	var end := _build_chain(iron, anchor_local)
	var look := RadiatorLook.new()
	look.name = "RadiatorLook"
	add_child(look)
	_shape(look, Vector3(w + 0.1, h + 0.05, ab.size.z + 0.1), Vector3(0, h * 0.5, _cz + 0.03))
	_shape(look, Vector3(0.14, 0.07, CHAIN_FLOOR_LEN), Vector3(end.x, 0.035, (front + 0.15 + end.z) * 0.5))
	_shape(look, Vector3(0.2, 0.08, 0.2), Vector3(end.x, 0.04, end.z + 0.06))
	print("[LOWER] radiator model %s scale %.3f -> %.2f x %.2f x %.2f m" % [MODEL_PATH, model_scale, w, h, ab.size.z])


func _apply_grunge(root: Node3D) -> void:
	var sh := load(GRUNGE_SHADER) as Shader
	var tex := load(GRUNGE_TEX) as Texture2D
	if sh == null or tex == null:
		push_warning("RadiatorProp: grunge shader / texture missing, plain model material")
		return
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var ab := mi.mesh.get_aabb()
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("grunge", tex)
		m.set_shader_parameter("aabb_min", ab.position)
		m.set_shader_parameter("aabb_size", ab.size)
		mi.material_override = m


func _aabb_in_self(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := global_transform.affine_inverse()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var b := (inv * mi.global_transform) * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _build_procedural(iron: StandardMaterial3D) -> void:
	var paint := _mat(_rust_tex, Color.WHITE, 0.9)
	var w := PITCH * SECTIONS
	var x0 := -w * 0.5 + PITCH * 0.5
	var y_mid := FOOT_H + HEIGHT * 0.5
	# Sections: rounded 8-sided columns.
	for i in SECTIONS:
		var cap := CapsuleMesh.new()
		cap.radius = SEC_R
		cap.height = HEIGHT
		cap.radial_segments = 8
		cap.rings = 2
		var mi := _mi(cap, paint, Vector3(x0 + PITCH * i, y_mid, _cz))
		mi.scale = Vector3(1.0, 1.0, SEC_DEPTH_SCALE)
		mi.rotation.y = deg_to_rad(randf_range(-1.5, 1.5))
	# Top / bottom headers joining the sections (accordion look).
	for hy in [FOOT_H + 0.06, FOOT_H + HEIGHT - 0.06]:
		_pipe(Vector3(-w * 0.5, hy, _cz), Vector3(w * 0.5, hy, _cz), 0.026, paint)
	# Feet.
	for fx in [-w * 0.32, w * 0.32]:
		_box(Vector3(0.05, FOOT_H, 0.09), Vector3(fx, FOOT_H * 0.5, _cz), iron)
	# Supply pipe into the top-left + T-handle valve; return pipe along the bottom.
	var ty := FOOT_H + HEIGHT - 0.06
	var lx := -w * 0.5
	_pipe(Vector3(lx - 0.36, ty, _cz), Vector3(lx, ty, _cz), 0.017, iron)
	_pipe(Vector3(lx - 0.36, ty, _cz), Vector3(lx - 0.36, ty, 0.0), 0.017, iron)       # into the wall
	_pipe(Vector3(lx - 0.16, ty, _cz), Vector3(lx - 0.16, ty + 0.07, _cz), 0.008, iron)  # valve stem
	_pipe(Vector3(lx - 0.2, ty + 0.075, _cz), Vector3(lx - 0.12, ty + 0.075, _cz), 0.006, iron)  # T handle
	_box(Vector3(0.05, 0.04, 0.045), Vector3(lx - 0.16, ty, _cz), iron)                  # valve body
	var by := FOOT_H + 0.06
	var rx := w * 0.5
	_pipe(Vector3(rx, by, _cz), Vector3(rx + 0.32, by, _cz), 0.017, iron)
	_pipe(Vector3(rx + 0.32, by, _cz), Vector3(rx + 0.32, by, 0.0), 0.017, iron)
	_pipe(Vector3(-w * 0.5 - 0.05, by - 0.03, _cz + 0.04), Vector3(rx, by - 0.03, _cz + 0.04), 0.014, iron)  # return line
	# Rust-brown puddle stain under it.
	var pud := CylinderMesh.new()
	pud.top_radius = 0.26
	pud.bottom_radius = 0.26
	pud.height = 0.002
	pud.radial_segments = 10
	pud.rings = 1
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.32, 0.15, 0.07, 0.55)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.roughness = 0.4
	var pmi := _mi(pud, pm, Vector3(0.05, 0.003, _cz + 0.1))
	pmi.scale = Vector3(1.4, 1.0, 0.8)
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Solid radiator collider (layer 1).
	var body := StaticBody3D.new()
	body.name = "RadiatorBody"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_shape(body, Vector3(w + 0.04, HEIGHT + FOOT_H, SEC_R * 2.0 * SEC_DEPTH_SCALE + 0.02), Vector3(0, (HEIGHT + FOOT_H) * 0.5, _cz))
	# Chain + shackle, then the look interactable.
	anchor_local = Vector3(x0 + PITCH * 2.0, FOOT_H + 0.12, _cz + SEC_R * SEC_DEPTH_SCALE)
	var end := _build_chain(iron, anchor_local)
	var look := RadiatorLook.new()
	look.name = "RadiatorLook"
	add_child(look)
	_shape(look, Vector3(w + 0.1, HEIGHT + FOOT_H + 0.05, 0.22), Vector3(0, (HEIGHT + FOOT_H) * 0.5, _cz + 0.03))
	_shape(look, Vector3(0.14, 0.07, CHAIN_FLOOR_LEN), Vector3(end.x, 0.035, (_cz + 0.15 + end.z) * 0.5))
	_shape(look, Vector3(0.2, 0.08, 0.2), Vector3(end.x, 0.04, end.z + 0.06))


## Chain from the section (attach) down to the floor, then CHAIN_FLOOR_LEN into the room,
## links alternating 90 deg. Returns the floor end (local) where the shackle lies.
func _build_chain(mat: Material, attach: Vector3) -> Vector3:
	var floor_y := 0.016
	var drop := Vector3(attach.x, floor_y, attach.z + 0.12)
	var end := Vector3(attach.x + 0.15, floor_y, drop.z + CHAIN_FLOOR_LEN)
	var path := [attach, drop, end]
	var k := 0
	for s in 2:
		var a: Vector3 = path[s]
		var b: Vector3 = path[s + 1]
		var seg := b - a
		var n := maxi(1, int(seg.length() / LINK_STEP))
		var dir := seg.normalized()
		var p1 := dir.cross(Vector3.RIGHT if absf(dir.x) < 0.9 else Vector3.UP).normalized()
		var p2 := dir.cross(p1).normalized()
		for i in n:
			var c := a + seg * ((float(i) + 0.5) / float(n))
			var nrm := p1 if k % 2 == 0 else p2
			if s == 1:
				# Floor run: alternate flat / upright, upright links raised by their radius.
				nrm = Vector3.UP if k % 2 == 0 else dir.cross(Vector3.UP).normalized()
				if k % 2 == 1:
					c.y += 0.014
				c.x += sin(float(i) * 0.7) * 0.012   # lazy slack on the floor
			var tm := TorusMesh.new()
			tm.inner_radius = 0.01
			tm.outer_radius = 0.019
			tm.rings = 8
			tm.ring_segments = 4
			var mi := MeshInstance3D.new()
			mi.mesh = tm
			mi.material_override = mat
			add_child(mi)
			mi.transform = Transform3D(Basis(dir * 1.7, nrm, dir.cross(nrm).normalized()), c)
			k += 1
	_build_shackle(mat, end + Vector3(0, 0, 0.07))
	return end


## Open ankle shackle on the floor: one half-ring flat, the other swung open on its hinge.
func _build_shackle(mat: Material, at: Vector3) -> void:
	var r := 0.055
	var segs := 7
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var hinge := Vector3(-r, 0.0, 0.0)
	var open := Node3D.new()
	open.position = hinge
	open.rotation.z = deg_to_rad(-70.0)
	root.add_child(open)
	for half in 2:
		for i in segs:
			var a0 := PI * float(i) / segs + (0.0 if half == 0 else PI)
			var a1 := PI * float(i + 1) / segs + (0.0 if half == 0 else PI)
			var p0 := Vector3(cos(a0) * r, 0.012, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, 0.012, sin(a1) * r)
			if half == 1:
				p0 -= hinge
				p1 -= hinge
			_pipe(p0, p1, 0.009, mat, root if half == 0 else open)
	_box(Vector3(0.03, 0.03, 0.03), at + hinge + Vector3(0, 0.012, 0), mat)    # hinge knuckle
	_box(Vector3(0.025, 0.02, 0.04), at + Vector3(r, 0.012, 0), mat)          # lock lug


# --- helpers ---------------------------------------------------------------------------------
func _mat(tex: Texture2D, col: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = col
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(6, 6, 6)
	return m


func _mi(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	_mi(bm, mat, pos)


## Cylinder (6 sides) from a to b.
func _pipe(a: Vector3, b: Vector3, r: float, mat: Material, parent: Node3D = null) -> void:
	var plen := a.distance_to(b)
	if plen < 0.001:
		return
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = plen
	cm.radial_segments = 6
	cm.rings = 1
	var mi := _mi(cm, mat, (a + b) * 0.5, parent)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.basis = Basis(x, y, x.cross(y).normalized())


func _shape(body: CollisionObject3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	body.add_child(cs)


## 32x32: peeling off-white paint over heavy orange-brown rust (nearest filtered).
static func _make_rust_tex() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1953
	var noise := FastNoiseLite.new()
	noise.seed = 1953
	noise.frequency = 0.12
	for y in 32:
		for x in 32:
			var v := noise.get_noise_2d(x, y) + rng.randf_range(-0.18, 0.18)
			var c: Color
			if v > 0.12:
				c = Color(0.80, 0.78, 0.71).darkened(rng.randf_range(0.0, 0.12))   # paint
			elif v > 0.02:
				c = Color(0.62, 0.55, 0.45)                                        # flaking edge
			else:
				c = Color(0.52, 0.27, 0.11).lerp(Color(0.34, 0.17, 0.08), rng.randf())  # rust
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _make_iron_tex() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for y in 32:
		for x in 32:
			var t := rng.randf()
			img.set_pixel(x, y, Color(0.2, 0.15, 0.12).lerp(Color(0.42, 0.22, 0.1), t * t))
	return ImageTexture.create_from_image(img)


## [E] Look on radiator / chain / shackle (interact-only layer 4, no blocking).
class RadiatorLook:
	extends Interactable

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		prompt_text = "[E] Look"
		interact_enabled = true

	func _on_interact(_player: Node) -> void:
		get_tree().call_group("subtitle", "show_line", "SABIRA", String(GameState.STORY_LINES["radiator_look"]), 3.5)
