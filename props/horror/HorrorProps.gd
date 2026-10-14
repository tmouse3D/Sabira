# Godot 4.x - Sabira / HOUSE
class_name HorrorProps
extends RefCounted
## Runtime clutter from the Low Poly PSX Horror Pack (Devil's Workshop, commercial licence,
## props/horror/license_devilsworkshop.txt). The pack ships untextured GLBs, so each sub-mesh gets
## a flat PSX tint over a tiny grey noise albedo (horror_grunge.png, nearest filter).
## Every prop is a layer-1 StaticBody3D with a box collider fitted to its mesh AABB.

const GRUNGE_TEX := "res://props/horror/horror_grunge.png"
const ASHTRAY := "res://props/horror/Ashtray.glb"
const RADIO := "res://props/horror/Radio.glb"
const WINE := "res://props/horror/BottleWine01.glb"
const PILL_A := "res://props/horror/PillBottle01.glb"
const PILL_B := "res://props/horror/PillBottle02.glb"

## Sub-mesh name (Godot-imported, "." -> "_") -> tint. "*" = default.
const TINT_ASHTRAY := {"*": Color(0.32, 0.34, 0.36)}
const TINT_RADIO := {"Radio": Color(0.62, 0.62, 0.6), "Radio_001": Color(0.12, 0.11, 0.1), "Radio_002": Color(0.42, 0.26, 0.15), "Radio_003": Color(0.2, 0.19, 0.18), "*": Color(0.4, 0.3, 0.2)}
const TINT_WINE := {"*": Color(0.1, 0.22, 0.12)}
const TINT_PILL := {"*": Color(0.72, 0.42, 0.12)}

## F2 coffee table (Landing, by the red couch): ashtray on the half of the tabletop away from
## the cup, TABLE_EDGE_M from the edges.
const TABLE_EDGE_M := 0.04
## F1 living room radio: on top of LivingCupboard2 (spawn_cupboard), [E] on / off (RadioToggle).
const RADIO_SCALE := 0.9

static var _tex: Texture2D = null


static func _mat(c: Color) -> StandardMaterial3D:
	if _tex == null:
		_tex = load(GRUNGE_TEX) as Texture2D
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = _tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.85
	return m


## AABB of every mesh under `n` (n included), in `ref`'s frame (default world).
static func world_aabb(n: Node, ref: Node3D = null) -> AABB:
	var out := AABB()
	var first := true
	var inv := ref.global_transform.affine_inverse() if ref != null else Transform3D.IDENTITY
	var list: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		list.append(n)
	for m in list:
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var a: AABB = (inv * mi.global_transform) * mi.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


## Spawn `path` as a StaticBody3D under `parent`: bottom centre at `pos`, yaw about +Y, optionally
## lying on its side (model tipped 90 deg about X). Returns the body (null if the GLB is missing).
static func spawn(parent: Node, nm: String, path: String, tint: Dictionary, pos: Vector3, yaw_deg: float = 0.0, lying: bool = false, scl: float = 1.0) -> StaticBody3D:
	var ps := load(path) as PackedScene
	if ps == null:
		push_warning("HorrorProps: %s missing" % path)
		return null
	var body := StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	body.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)
	var mdl := ps.instantiate() as Node3D
	body.add_child(mdl)
	mdl.scale = Vector3.ONE * scl
	if lying:
		mdl.rotation.x = PI * 0.5
	for m in mdl.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var key := String(mi.name).replace(".", "_")
		var c: Color = tint.get(key, tint.get("*", Color(0.5, 0.5, 0.5)))
		for s in mi.get_surface_override_material_count():
			mi.set_surface_override_material(s, _mat(c))
	# Recentre: mesh bottom on the body origin, centred in x / z (body frame).
	var a := world_aabb(mdl, body)
	mdl.position = Vector3(-(a.position.x + a.size.x * 0.5), -a.position.y, -(a.position.z + a.size.z * 0.5))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = a.size
	cs.shape = bs
	cs.position = Vector3(0, a.size.y * 0.5, 0)
	body.add_child(cs)
	print("[HORROR] %s (%s) at %s size %s" % [nm, path.get_file(), body.global_position, a.size])
	return body


## House props (called by KeySpawner): ashtray on the F2 coffee table, radio in the F1 living room.
static func spawn_house(holder: Node3D, house: Node) -> void:
	var table := house.get_node_or_null("Structure/Landing_CoffeeTable")
	var cup := house.get_node_or_null("Structure/Landing_CoffeeTableCup")
	if table != null:
		var t := world_aabb(table)
		var x := t.position.x + t.size.x * 0.5
		var z := t.position.z + TABLE_EDGE_M + 0.09
		if cup != null:
			var c := world_aabb(cup)
			# Cup on the +Z half -> ashtray on the -Z half, else the other way round.
			if c.get_center().z < t.get_center().z:
				z = t.end.z - TABLE_EDGE_M - 0.09
			x = clampf(c.get_center().x - 0.06, t.position.x + 0.1, t.end.x - 0.1)
		spawn(holder, "Ashtray", ASHTRAY, TINT_ASHTRAY, Vector3(x, t.end.y, z), 20.0)
	else:
		push_warning("HorrorProps: Landing_CoffeeTable not found, no ashtray")
	var cup2 := spawn_cupboard(holder, house)
	if cup2 == null:
		push_warning("HorrorProps: no living cupboard, no radio")
		return
	var top: AABB = cup2.get_meta("aabb")
	# Long side along the east wall (z): radio turned to face into the room (-X).
	var rp := Vector3(top.get_center().x, top.end.y, top.get_center().z)
	var radio := spawn(holder, "Radio", RADIO, TINT_RADIO, rp, RADIO_YAW_DEG, false, RADIO_SCALE)
	if radio != null:
		var rt := RadioToggle.new()
		rt.name = "RadioToggle"
		radio.add_child(rt)
		var ra := world_aabb(radio, radio)
		rt.setup(ra.size, top.position.y)
		print("[HORROR] radio stand point %s" % rt.stand_point())


## F1 living room: a second small cupboard next to the dark corner cabinet
## (Kitchen_Shelf_Pantry_Orphan, east wall, under the paintings): same scene / material, CUPBOARD_LEN
## of its length, flush to the same wall, CUPBOARD_GAP_M south of it. Layer-1 box collider.
## Clear of Tash's route (kdoor 2.6,-0.4 / p37 1.88,0.96) and the kitchen doorway (z -1.8..0).
const CUPBOARD_SRC := "Kitchen_Shelf_Pantry_Orphan"
const CUPBOARD_LEN := 0.6
const CUPBOARD_GAP_M := 0.04
const RADIO_YAW_DEG := -90.0


static func spawn_cupboard(holder: Node3D, house: Node) -> StaticBody3D:
	var src := house.get_node_or_null(CUPBOARD_SRC) as Node3D
	if src == null:
		return null
	var a := world_aabb(src)
	var body := StaticBody3D.new()
	body.name = "LivingCupboard2"
	body.collision_layer = 1
	body.collision_mask = 0
	holder.add_child(body)
	var dup := src.duplicate() as Node3D
	body.add_child(dup)
	dup.global_transform = Transform3D(Basis.from_scale(Vector3(1, 1, CUPBOARD_LEN)) * src.global_transform.basis, src.global_position)
	var b := world_aabb(dup)
	# Flush to the same wall (+X face) and floor, on its south side (fallback: north side).
	var shift := Vector3(a.end.x - b.end.x, a.position.y - b.position.y, (a.end.z + CUPBOARD_GAP_M) - b.position.z)
	if a.end.z + CUPBOARD_GAP_M + b.size.z > -1.9:
		shift.z = (a.position.z - CUPBOARD_GAP_M) - b.end.z
	dup.global_position += shift
	b = world_aabb(dup)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = b.size
	cs.shape = bs
	body.add_child(cs)
	cs.global_position = b.get_center()
	body.set_meta("aabb", b)
	print("[HORROR] LivingCupboard2 at %s .. %s (beside %s %s .. %s)" % [b.position, b.end, CUPBOARD_SRC, a.position, a.end])
	return body
