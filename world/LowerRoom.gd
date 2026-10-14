# Godot 4.x - Sabira / HOUSE
class_name LowerRoom
extends Node3D
## Empty room directly under the secret room (Structure/HiddenRoom, behind the bookcase),
## reached by a floor hatch to the right of Mom's bed. Same footprint (HiddenRoomVolume 2.6 x 4.2)
## and height as the secret room, same wall / floor / ceiling materials and a copy of its light.
## Built at runtime by KeySpawner._spawn_lower_room. Before building, the room's AABB is tested
## against every existing collider and mesh; on overlap it is lowered further (STEP_DOWN).
## Geometry is on layer 1 (player walks on it); hatches are interact-only (layer 4).
## Tash's chase navmesh (layers 1 | 8) may pick the floor up as a separate, unreachable island,
## which is harmless; his route graph never goes here.

const CENTER_XZ := Vector2(-6.4, -2.8)      # HiddenRoom origin (x, z)
const INNER := Vector3(2.6, 2.75, 4.2)      # width, height, depth (secret room: floor 0 -> ceiling 2.79)
const WALL := 0.2
const FLOOR_TOP_START := -3.5
const STEP_DOWN := 1.5
const MAX_TRIES := 6
## Floor hatch spot in the secret room: right of the bed (bed x -7.83..-6.67, z -3.7..-1.7).
const HATCH_XZ := Vector2(-6.2, -3.95)
const HATCH_SIZE := 0.7

var floor_top: float = FLOOR_TOP_START


func setup() -> void:
	add_to_group("lower_room")
	name = "LowerRoom"
	await get_tree().physics_frame
	await get_tree().physics_frame
	var tries := 0
	while _overlaps(_outer_aabb()) and tries < MAX_TRIES:
		print("[LOWER] overlap at floor y %.2f, lowering" % floor_top)
		floor_top -= STEP_DOWN
		tries += 1
	_build_room()
	_build_hatches()
	_build_floor_box()
	_build_bucket()
	_build_radiator()
	_build_clutter()
	_attach_cuff_to_tash()
	var a := _outer_aabb()
	print("[LOWER] room built: inner x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f (outer %s)" % [
		CENTER_XZ.x - INNER.x * 0.5, CENTER_XZ.x + INNER.x * 0.5, floor_top, floor_top + INNER.y,
		CENTER_XZ.y - INNER.z * 0.5, CENTER_XZ.y + INNER.z * 0.5, a])


func _outer_aabb() -> AABB:
	var size := Vector3(INNER.x + WALL * 2.0, INNER.y + WALL * 2.0, INNER.z + WALL * 2.0)
	var pos := Vector3(CENTER_XZ.x - size.x * 0.5, floor_top - WALL, CENTER_XZ.y - size.z * 0.5)
	return AABB(pos, size)


func _overlaps(box: AABB) -> bool:
	var grown := box.grow(0.05)
	# Colliders (any layer).
	var sh := BoxShape3D.new()
	sh.size = grown.size
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, grown.get_center())
	q.collision_mask = 0xFFFFFFFF
	q.collide_with_areas = false
	var hits := get_world_3d().direct_space_state.intersect_shape(q, 8)
	if not hits.is_empty():
		print("[LOWER] collider overlap: %s" % [hits[0].get("collider")])
		return true
	# Visible meshes.
	var scene := get_tree().current_scene
	if scene != null:
		for n in scene.find_children("*", "GeometryInstance3D", true, false):
			var vi := n as GeometryInstance3D
			if vi == null or not vi.is_visible_in_tree() or is_ancestor_of(vi):
				continue
			var ab := vi.global_transform * vi.get_aabb()
			if ab.size.length() > 0.0 and ab.intersects(grown):
				print("[LOWER] mesh overlap: %s" % vi.get_path())
				return true
	return false


func _mat(path: String) -> Material:
	var scene := get_tree().current_scene
	var n := scene.get_node_or_null(path) if scene != null else null
	if n != null and n.get("material") is Material:
		return n.get("material")
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.48, 0.45)
	return m


func _slab(nm: String, size: Vector3, center: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	body.global_position = center
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)


func _build_room() -> void:
	var wall_m := _mat("Structure/HiddenRoom_WallS")
	var floor_m := _mat("Structure/GroundFloor")
	var ceil_m := _mat("Structure/WestWingCeiling")
	var cx := CENTER_XZ.x
	var cz := CENTER_XZ.y
	var w := INNER.x
	var h := INNER.y
	var d := INNER.z
	var ym := floor_top + h * 0.5
	_slab("Floor", Vector3(w + WALL * 2.0, WALL, d + WALL * 2.0), Vector3(cx, floor_top - WALL * 0.5, cz), floor_m)
	_slab("Ceiling", Vector3(w + WALL * 2.0, WALL, d + WALL * 2.0), Vector3(cx, floor_top + h + WALL * 0.5, cz), ceil_m)
	_slab("Wall_W", Vector3(WALL, h, d + WALL * 2.0), Vector3(cx - w * 0.5 - WALL * 0.5, ym, cz), wall_m)
	_slab("Wall_E", Vector3(WALL, h, d + WALL * 2.0), Vector3(cx + w * 0.5 + WALL * 0.5, ym, cz), wall_m)
	_slab("Wall_N", Vector3(w, h, WALL), Vector3(cx, ym, cz - d * 0.5 - WALL * 0.5), wall_m)
	_slab("Wall_S", Vector3(w, h, WALL), Vector3(cx, ym, cz + d * 0.5 + WALL * 0.5), wall_m)
	# Light: copy of the secret room's OmniLight (always on; the hidden switch stays upstairs).
	var src := get_tree().current_scene.get_node_or_null("Lighting/HiddenRoom/OmniLight3D") as OmniLight3D
	var lamp := OmniLight3D.new()
	lamp.name = "LowerLight"
	if src != null:
		lamp.light_color = src.light_color
		lamp.light_energy = src.light_energy
		lamp.omni_range = src.omni_range
		lamp.omni_attenuation = src.omni_attenuation
		lamp.shadow_enabled = src.shadow_enabled
	else:
		lamp.light_color = Color(0.55, 0.65, 0.75)
		lamp.light_energy = 2.2
		lamp.omni_range = 5.0
		lamp.shadow_enabled = true
	add_child(lamp)
	lamp.global_position = Vector3(cx + 0.4, floor_top + h - 0.3, cz + 0.6)
	var fx := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.3, 0.06, 0.15)
	fx.mesh = fm
	var fsrc := get_tree().current_scene.get_node_or_null("Lighting/HiddenRoom/Fixture")
	if fsrc != null and fsrc.get("material") is Material:
		fx.material_override = fsrc.get("material")
	add_child(fx)
	fx.global_position = Vector3(cx + 0.4, floor_top + h - 0.03, cz + 0.6)


func _wood() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.22, 0.14)
	m.roughness = 0.9
	return m


func _box_mesh(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _upper_floor_y() -> float:
	var from := Vector3(HATCH_XZ.x, 1.0, HATCH_XZ.y)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -1.6, 0))
	q.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else 0.0


func _build_hatches() -> void:
	var wood := _wood()
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.1, 0.09)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.35, 0.34, 0.33)
	metal.metallic = 0.7
	metal.roughness = 0.5
	var fy := _upper_floor_y()
	var s := HATCH_SIZE
	# --- Floor hatch (secret room) ---
	var up := RoomHatch.new()
	up.name = "FloorHatch"
	up.prompt_text = "[E] Climb down"
	add_child(up)
	up.global_position = Vector3(HATCH_XZ.x, fy, HATCH_XZ.y)
	_box_mesh(up, Vector3(s + 0.08, 0.012, s + 0.08), Vector3(0, 0.006, 0), dark)   # frame / gap
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0.014, -s * 0.5)   # hinge on the north edge
	up.add_child(pivot)
	_box_mesh(pivot, Vector3(s, 0.025, s), Vector3(0, 0.0125, s * 0.5), wood)
	for i in 3:
		_box_mesh(pivot, Vector3(s * 0.98, 0.006, 0.02), Vector3(0, 0.028, s * (0.2 + 0.3 * i)), dark)
	_box_mesh(pivot, Vector3(0.12, 0.02, 0.02), Vector3(0, 0.035, s * 0.85), metal)  # pull handle
	up.lid = pivot
	up.open_axis = Vector3(-1, 0, 0)   # lid lifts toward the hinge side, up and away
	var ucs := CollisionShape3D.new()
	var ubs := BoxShape3D.new()
	ubs.size = Vector3(s, 0.12, s)
	ucs.shape = ubs
	ucs.position.y = 0.06
	up.add_child(ucs)
	# --- Ceiling hatch + ladder (lower room) ---
	var ceil_y := floor_top + INNER.y
	var down := RoomHatch.new()
	down.name = "CeilingHatch"
	down.kind = "up"
	down.prompt_text = "[E] Climb up"
	add_child(down)
	down.global_position = Vector3(HATCH_XZ.x, floor_top, HATCH_XZ.y)
	_box_mesh(down, Vector3(s + 0.08, 0.012, s + 0.08), Vector3(0, INNER.y - 0.006, 0), dark)
	_box_mesh(down, Vector3(s, 0.025, s), Vector3(0, INNER.y - 0.025, 0), wood)
	# Ladder along the hatch's north edge, floor to ceiling. Solid (layer 1, thin) so it can't be
	# walked through; the interact slab sits just in front of its south face, full height, so the
	# ray hits it whether she looks straight at the rungs or up at the hatch.
	var lz := -s * 0.5 + 0.06
	for x in [-0.2, 0.2]:
		_box_mesh(down, Vector3(0.05, INNER.y, 0.05), Vector3(x, INNER.y * 0.5, lz), wood)
	var r := 0.3
	while r < INNER.y - 0.1:
		_box_mesh(down, Vector3(0.4, 0.035, 0.035), Vector3(0, r, lz), wood)
		r += 0.3
	var solid := StaticBody3D.new()
	solid.name = "LadderSolid"
	solid.collision_layer = 1
	solid.collision_mask = 0
	down.add_child(solid)
	var scs := CollisionShape3D.new()
	var sbs := BoxShape3D.new()
	sbs.size = Vector3(0.46, INNER.y, 0.06)
	scs.shape = sbs
	scs.position = Vector3(0, INNER.y * 0.5, lz)
	solid.add_child(scs)
	var dcs := CollisionShape3D.new()
	var dbs := BoxShape3D.new()
	dbs.size = Vector3(0.56, INNER.y - 0.02, 0.06)
	dcs.shape = dbs
	dcs.position = Vector3(0, INNER.y * 0.5, lz + 0.065)
	down.add_child(dcs)
	# Hatch underside panel for looking straight up (thin, below the ceiling).
	var ucs2 := CollisionShape3D.new()
	var ubs2 := BoxShape3D.new()
	ubs2.size = Vector3(s, 0.04, s)
	ucs2.shape = ubs2
	ucs2.position = Vector3(0, INNER.y - 0.06, 0)
	down.add_child(ucs2)
	# Wiring: arrive next to the other end (south of the hatch, clear of the lid / ladder).
	up.target_pos = Vector3(HATCH_XZ.x, floor_top + 0.05, HATCH_XZ.y + 0.7)
	up.face_yaw = PI   # land facing +Z (south end wall, away from the ladder): the radiator
	down.target_pos = Vector3(HATCH_XZ.x, fy + 0.05, HATCH_XZ.y + 0.75)
	print("[LOWER] floor hatch at %s, ceiling hatch at %s" % [up.global_position, Vector3(HATCH_XZ.x, ceil_y, HATCH_XZ.y)])



# --- One floor box (lower_secret 2026-10-13) -------------------------------------------------
## The plank shelves, their boxes and the searchable photo box are gone. One of Tash's closet
## boxes (props/closet/box*.glb) sits on the floor against the west wall, mid-room: clear of the
## ladder / hatch (north end, x -6.55..-5.85, z -4.3..-3.6), the landing walkway (x ~-6.2 down
## to the radiator) and the radiator + chain (south wall, x ~-7.0..-5.8, z -0.7..-2.1).
## Layer-1 box collider; interact/LowerBoxLock.gd on top ([E] Open -> letter lock -> handcuffs).
const FLOOR_BOX_SCENE := "res://props/closet/box2.glb"
const FLOOR_BOX_XZ := Vector2(-7.28, -2.45)
const FLOOR_BOX_MAX := 0.55        # largest box side after scaling (m)
const FLOOR_BOX_YAW_DEG := 8.0

var radiator: RadiatorProp = null

## Old metal bucket (props/Bucket.glb, already in the project) on the floor by the east wall,
## south of the ladder / hatch, east of the walkway (x ~-6.2) and of cuffed Tash (z -1.5),
## north-east of the floor box and the radiator chain. Layer-1 cylinder collider.
const BUCKET_SCENE := "res://props/Bucket.glb"
const BUCKET_XZ := Vector2(-5.42, -2.75)
const BUCKET_H := 0.3             # target height (m)
const BUCKET_YAW_DEG := 37.0
const BUCKET_TILT_DEG := 3.0      # sits a little crooked on its dented base
var floor_box_top: float = 0.0


## Mesh AABB of `root` in `ref`'s frame (default: root's own, unscaled).
func _local_aabb(root: Node3D, ref: Node3D = null) -> AABB:
	var out := AABB()
	var first := true
	var inv := (ref if ref != null else root).global_transform.affine_inverse()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var ab := (inv * mi.global_transform) * mi.get_aabb()
		out = ab if first else out.merge(ab)
		first = false
	return out


func _box_collider(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	body.add_child(cs)


func _build_floor_box() -> void:
	var ps := load(FLOOR_BOX_SCENE) as PackedScene
	var body := StaticBody3D.new()
	body.name = "FloorBox"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	body.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(FLOOR_BOX_YAW_DEG)), Vector3(FLOOR_BOX_XZ.x, floor_top, FLOOR_BOX_XZ.y))
	var size := Vector3(0.5, 0.4, 0.4)
	if ps != null:
		var bx := ps.instantiate() as Node3D
		body.add_child(bx)
		var ab := _local_aabb(bx, body)
		var sc := FLOOR_BOX_MAX / maxf(maxf(ab.size.x, ab.size.z), 0.01)
		bx.scale = Vector3.ONE * sc
		ab = _local_aabb(bx, body)
		bx.position = Vector3(-(ab.position.x + ab.size.x * 0.5), -ab.position.y, -(ab.position.z + ab.size.z * 0.5))
		size = ab.size
	else:
		push_warning("LowerRoom: %s missing, plain box" % FLOOR_BOX_SCENE)
		_box_mesh(body, size, Vector3(0, size.y * 0.5, 0), _wood())
	_box_collider(body, size, Vector3(0, size.y * 0.5, 0))
	floor_box_top = floor_top + size.y
	var lock := LowerBoxLock.new()
	lock.name = "LowerBoxLock"
	body.add_child(lock)
	lock.setup(size)
	print("[LOWER] floor box %s at %s, size %s" % [FLOOR_BOX_SCENE, body.global_position, size])


func _build_bucket() -> void:
	var ps := load(BUCKET_SCENE) as PackedScene
	if ps == null:
		push_warning("LowerRoom: %s missing, no bucket" % BUCKET_SCENE)
		return
	var body := StaticBody3D.new()
	body.name = "Bucket"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	body.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(BUCKET_YAW_DEG)), Vector3(BUCKET_XZ.x, floor_top, BUCKET_XZ.y))
	var bk := ps.instantiate() as Node3D
	body.add_child(bk)
	var ab := _local_aabb(bk, body)
	var sc := BUCKET_H / maxf(ab.size.y, 0.01)
	bk.scale = Vector3.ONE * sc
	ab = _local_aabb(bk, body)
	bk.position = Vector3(-(ab.position.x + ab.size.x * 0.5), -ab.position.y, -(ab.position.z + ab.size.z * 0.5))
	bk.rotation.z = deg_to_rad(BUCKET_TILT_DEG)
	# Slight rust on the galvanized texture: multiply tint over every surface.
	var rust := StandardMaterial3D.new()
	rust.albedo_color = Color(0.86, 0.74, 0.62, 0.35)
	rust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rust.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	rust.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for n in bk.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_overlay = rust
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = maxf(ab.size.x, ab.size.z) * 0.5
	cyl.height = ab.size.y
	cs.shape = cyl
	cs.position = Vector3(0, ab.size.y * 0.5, 0)
	body.add_child(cs)
	print("[LOWER] bucket %s at %s, size %s" % [BUCKET_SCENE, body.global_position, ab.size])


# --- Floor clutter (props_subs 2026-10-14) -------------------------------------------------
## Horror-pack wine bottles (one lying) by the floor box (west wall) and pill bottles by the
## bucket (east wall). [name, scene, x, z, yaw_deg, lying]. Each spot is checked against the
## room bounds and the keep-outs below; a blocked spot is skipped with a warning.
const CLUTTER := [
	["Wine_A", HorrorProps.WINE, -7.50, -3.05, 0.0, false],
	["Wine_B", HorrorProps.WINE, -7.12, -3.32, 65.0, true],
	["Wine_C", HorrorProps.WINE, -7.58, -3.62, 0.0, false],
	["Pills_A", HorrorProps.PILL_A, -5.25, -3.02, 0.0, false],
	["Pills_B", HorrorProps.PILL_B, -5.62, -2.50, 120.0, true],
	["Pills_C", HorrorProps.PILL_B, -7.05, -3.00, 0.0, false],
]
const CLUTTER_WALL_MARGIN := 0.12
const CLUTTER_KEEP_CUFF_M := 0.6      # from cuff_tash_pos / cuff_player_pos
const CLUTTER_WALKWAY_X := -6.2
const CLUTTER_WALKWAY_HALF := 0.4
const CLUTTER_LADDER := Rect2(-6.75, -4.5, 1.1, 1.1)   # ladder / hatch x -6.55..-5.85, z -4.3..-3.6 (+0.2)
const CLUTTER_RADIATOR := Rect2(-7.2, -2.3, 1.6, 1.7)  # radiator + chain x -7.0..-5.8, z -2.1..-0.7 (+0.2)


func _clutter_blocked(xz: Vector2) -> String:
	var a := inner_aabb()
	if xz.x < a.position.x + CLUTTER_WALL_MARGIN or xz.x > a.end.x - CLUTTER_WALL_MARGIN or xz.y < a.position.z + CLUTTER_WALL_MARGIN or xz.y > a.end.z - CLUTTER_WALL_MARGIN:
		return "outside room"
	if CLUTTER_LADDER.has_point(xz):
		return "ladder"
	if CLUTTER_RADIATOR.has_point(xz):
		return "radiator chain"
	if absf(xz.x - CLUTTER_WALKWAY_X) < CLUTTER_WALKWAY_HALF:
		return "walkway"
	for p in [cuff_tash_pos(), cuff_player_pos()]:
		if Vector2(p.x, p.z).distance_to(xz) < CLUTTER_KEEP_CUFF_M:
			return "cuff scene spot"
	return ""


func _build_clutter() -> void:
	var holder := Node3D.new()
	holder.name = "Clutter"
	add_child(holder)
	for c in CLUTTER:
		var xz := Vector2(float(c[2]), float(c[3]))
		var why := _clutter_blocked(xz)
		if why != "":
			push_warning("LowerRoom: clutter %s skipped (%s)" % [c[0], why])
			continue
		var tint: Dictionary = HorrorProps.TINT_WINE if String(c[1]) == HorrorProps.WINE else HorrorProps.TINT_PILL
		HorrorProps.spawn(holder, String(c[0]), String(c[1]), tint, Vector3(xz.x, floor_top, xz.y), float(c[4]), bool(c[5]))


## CuffTash ([E] Cuff him / Make him feel it) rides on Tash; needs this room's radiator.
func _attach_cuff_to_tash() -> void:
	var tash := get_tree().get_first_node_in_group("tash")
	if tash == null or not (tash is Node3D):
		push_warning("LowerRoom: no Tash in group 'tash', Cuff him disabled")
		return
	if tash.get_node_or_null("CuffTash") != null:
		return
	var ct := CuffTash.new()
	ct.name = "CuffTash"
	ct.lower_room = self
	tash.add_child(ct)


## Cuffed scene layout (world): Tash lies CUFF_TASH_DIST in front of the radiator, the player
## stands CUFF_PLAYER_DIST in front of it facing the radiator (+Z, yaw PI).
const CUFF_TASH_DIST := 0.8
const CUFF_PLAYER_DIST := 2.0


## Built interior (from the room actually built: floor_top after the overlap lowering).
func inner_aabb() -> AABB:
	var a := _outer_aabb().grow(-WALL)
	return a


## Point `dist` in front of the radiator (its local +Z, into the room), on the floor, clamped
## inside the built interior with `margin`. Falls back to the south wall centre.
func _front_of_radiator(dist: float, margin: float) -> Vector3:
	var p: Vector3
	if radiator != null and is_instance_valid(radiator):
		p = radiator.to_global(Vector3(0, 0, dist))
	else:
		p = Vector3(CENTER_XZ.x, floor_top, CENTER_XZ.y + INNER.z * 0.5 - dist)
	var a := inner_aabb()
	p.x = clampf(p.x, a.position.x + margin, a.end.x - margin)
	p.z = clampf(p.z, a.position.z + margin, a.end.z - margin)
	p.y = floor_top
	return p


func cuff_tash_pos() -> Vector3:
	return _front_of_radiator(CUFF_TASH_DIST, 0.3)


func cuff_player_pos() -> Vector3:
	return _front_of_radiator(CUFF_PLAYER_DIST, 0.4) + Vector3(0, 0.05, 0)


## Radiator / chain / shackle [E] Look areas off while Tash lies there (they sat in front of
## the Make-him-feel-it box and won the interact ray).
func set_radiator_look_enabled(on: bool) -> void:
	if radiator == null or not is_instance_valid(radiator):
		return
	var look := radiator.get_node_or_null("RadiatorLook") as CollisionObject3D
	if look != null:
		look.collision_layer = 4 if on else 0
		look.set("interact_enabled", on)


## Cast-iron radiator + chain + open shackle (props/proc/RadiatorProp.gd) on the wall she faces
## after climbing down: landing (-6.2, z -3.25) facing +Z -> the short south end wall (z -0.7),
## centred at x -6.4, clear of the ladder and the hatch (north end) and of the floor box (west
## wall). Chain runs ~1 m back into the room along the floor.
func _build_radiator() -> void:
	var rad := RadiatorProp.new()
	rad.name = "Radiator"
	add_child(rad)
	var wall_z := CENTER_XZ.y + INNER.z * 0.5
	rad.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(CENTER_XZ.x, floor_top, wall_z))
	rad.build()
	radiator = rad
	print("[LOWER] radiator at %s (south wall, facing -Z)" % rad.global_position)
