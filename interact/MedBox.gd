# Godot 4.x - Sabira / HOUSE
class_name MedBox
extends Interactable
## Realistic only (spawned by KeySpawner._spawn_medbox): white wall medicine cabinet above the
## F2 bath sink. The pills jar (PillsJar_BathBody + mesh) is moved inside and stays locked
## (PillsJarPickup.set_box_locked) until the 4-digit GameState.med_code is entered on the
## KeypadUI. Code: laundry wall scratch (interact/WallScratch.gd).

const KeypadUIScript := preload("res://ui/KeypadUI.gd")
const SIZE := Vector3(0.42, 0.5, 0.16)
const WALL := 0.012
const RISE_ABOVE_JAR := 0.6   # box centre above the jar's sink-top spot
const FALLBACK_BACK := Vector3(0, 0, -0.30)  # if no wall ray hit: this far toward -Z

var _jar: Node3D = null
var _jar_mesh: Node3D = null
var _hinge: Node3D = null
var _ui: Node = null
var _solved: bool = false
var _open: bool = false


func _ready() -> void:
	add_to_group("medbox")
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	prompt_text = String(GameState.STORY_LINES["medbox_prompt"])


func setup(jar: Node3D) -> void:
	await get_tree().physics_frame  # physics space has the house colliders by now
	await get_tree().physics_frame
	_jar = jar
	if jar != null and "mesh_path" in jar:
		_jar_mesh = jar.get_node_or_null(jar.get("mesh_path")) as Node3D
	var base := jar.global_position if jar != null else Vector3(-2.96, 3.89, -5.17)
	# Find the wall behind the sink (ray toward -Z, world layer 1).
	var from := base + Vector3(0, RISE_ABOVE_JAR, 0.25)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 0, -1.6))
	q.collision_mask = 1
	if jar is CollisionObject3D:
		q.exclude = [(jar as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var normal := Vector3(0, 0, 1)
	var wall_pt := base + Vector3(0, RISE_ABOVE_JAR, 0) + FALLBACK_BACK
	if not hit.is_empty():
		wall_pt = hit["position"]
		var n: Vector3 = hit["normal"]
		n.y = 0.0
		if n.length_squared() > 0.01:
			normal = n.normalized()
	else:
		push_warning("MedBox: no wall hit behind the sink, using fallback offset")
	var centre := wall_pt + normal * (SIZE.z * 0.5 + 0.005)
	global_transform = Transform3D(Basis.looking_at(-normal, Vector3.UP), centre)
	_build()
	# Jar inside, on the bottom shelf.
	if _jar != null:
		var target := global_transform * Vector3(0.0, -SIZE.y * 0.5 + WALL + 0.045, -0.01)
		var delta := target - _jar.global_position
		_jar.global_position += delta
		if _jar_mesh != null:
			_jar_mesh.global_position += delta
		if _jar.has_method("set_box_locked"):
			_jar.call("set_box_locked", true)
	print("[HOUSE] MedBox at %s (wall %s, normal %s) code %s" % [centre, "hit" if not hit.is_empty() else "fallback", normal, GameState.med_code])


func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.55
	return m


func _panel(size: Vector3, pos: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build() -> void:
	var white := _mat(Color(0.9, 0.9, 0.86))
	var h := SIZE * 0.5
	_panel(Vector3(SIZE.x, SIZE.y, WALL), Vector3(0, 0, -h.z + WALL * 0.5), white, self)  # back
	_panel(Vector3(SIZE.x, WALL, SIZE.z), Vector3(0, h.y - WALL * 0.5, 0), white, self)    # top
	_panel(Vector3(SIZE.x, WALL, SIZE.z), Vector3(0, -h.y + WALL * 0.5, 0), white, self)   # bottom
	_panel(Vector3(WALL, SIZE.y, SIZE.z), Vector3(-h.x + WALL * 0.5, 0, 0), white, self)   # left
	_panel(Vector3(WALL, SIZE.y, SIZE.z), Vector3(h.x - WALL * 0.5, 0, 0), white, self)    # right
	_panel(Vector3(SIZE.x - WALL * 2.0, WALL, SIZE.z - WALL), Vector3(0, 0.02, 0), white, self)  # shelf
	# Door on a left hinge, red cross, small keypad plate.
	_hinge = Node3D.new()
	_hinge.position = Vector3(-h.x, 0, h.z)
	add_child(_hinge)
	_panel(Vector3(SIZE.x, SIZE.y, WALL * 1.5), Vector3(h.x, 0, WALL * 0.75), white, _hinge)
	var red := _mat(Color(0.7, 0.08, 0.06))
	_panel(Vector3(0.12, 0.035, 0.004), Vector3(h.x, 0.08, WALL * 1.5 + 0.002), red, _hinge)
	_panel(Vector3(0.035, 0.12, 0.004), Vector3(h.x, 0.08, WALL * 1.5 + 0.002), red, _hinge)
	var dark := _mat(Color(0.12, 0.12, 0.13))
	_panel(Vector3(0.07, 0.09, 0.006), Vector3(SIZE.x - 0.06, -0.12, WALL * 1.5 + 0.003), dark, _hinge)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = SIZE
	cs.shape = sh
	add_child(cs)


func get_prompt() -> String:
	return "" if _open or not interact_enabled else prompt_text


func _on_interact(_player: Node) -> void:
	if _open:
		return
	if not _solved:
		get_tree().call_group("subtitle", "show_line", "SABIRA", String(GameState.STORY_LINES["medbox_locked"]), 2.5)
		_open_keypad()


func _open_keypad() -> void:
	if _ui == null or not is_instance_valid(_ui):
		_ui = KeypadUIScript.new()
		_ui.name = "MedBoxKeypadUI"
		var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		host.add_child(_ui)
		_ui.connect("solved", _on_keypad_solved)
		_ui.connect("closed", _on_keypad_closed)
	_ui.call("open", GameState.ensure_med_code())


func _on_keypad_solved() -> void:
	_solved = true


func _on_keypad_closed() -> void:
	if not _solved or _open:
		return
	_open = true
	GameState.med_box_open = true
	interact_enabled = false
	collision_layer = 0  # let the interact ray reach the jar inside
	var tw := create_tween()
	tw.tween_property(_hinge, "rotation:y", deg_to_rad(-105.0), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	if _jar != null and is_instance_valid(_jar) and _jar.has_method("set_box_locked"):
		_jar.call("set_box_locked", false)
	print("[HOUSE] MedBox opened")


func _exit_tree() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.queue_free()
