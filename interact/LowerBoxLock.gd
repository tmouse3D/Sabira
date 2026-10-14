# Godot 4.x - Sabira / HOUSE
class_name LowerBoxLock
extends Interactable
## The one lower-room floor box (world/LowerRoom.gd _build_floor_box). [E] Open: the flaps fold
## back and a small iron lockbox with 6 letter dials shows inside -> ui/LetterLockUI.gd with
## GameState.LOWER_BOX_CODE. Solved: its lid swings open and gives the 'handcuffs' carry item
## (Handcuffs + metal wire, ui/icons/handcuffs.png). Carry full: the prompt stays [E] Take.
## The box stays open for the run (GameState.lower_box_open).

const LetterLockUIScript := preload("res://ui/LetterLockUI.gd")

var _size: Vector3 = Vector3(0.5, 0.4, 0.4)
var _ui: CanvasLayer = null
var _inner: Node3D = null
var _lid: Node3D = null
## Handcuffs taken from this box (the prompt then becomes [E] Look: "Empty now.").
var _taken: bool = false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	interact_enabled = true


## Interact shape over the box (body-local, origin on the floor at the box centre).
func setup(size: Vector3) -> void:
	_size = size
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size + Vector3(0.04, 0.04, 0.04)
	cs.shape = bs
	cs.position = Vector3(0, size.y * 0.5, 0)
	add_child(cs)
	if GameState.lower_box_open:
		_build_inner()
		_lid.rotation.x = deg_to_rad(110.0)


func get_prompt() -> String:
	if _ui != null and is_instance_valid(_ui) and _ui.call("is_open"):
		return ""
	if not GameState.lower_box_open:
		return String(GameState.STORY_LINES["lower_box_prompt"])
	if not _taken:
		return "[E] Take"
	return "[E] Look"


func _on_interact(_player: Node) -> void:
	if not GameState.lower_box_open:
		if _inner == null:
			_build_inner()
		_open_ui()
		return
	if not _taken:
		_give_cuffs()
		return
	get_tree().call_group("subtitle", "show_line", "SABIRA", String(GameState.STORY_LINES["lower_box_empty"]), 2.0)


func _open_ui() -> void:
	if _ui == null or not is_instance_valid(_ui):
		_ui = LetterLockUIScript.new()
		_ui.name = "LetterLockUI"
		var host: Node = get_tree().current_scene
		if host == null:
			host = get_tree().root
		host.add_child(_ui)
		_ui.connect("solved", _on_solved)
		_ui.connect("closed", _on_closed)
	_ui.call("open", GameState.LOWER_BOX_CODE)


func _on_solved() -> void:
	GameState.lower_box_open = true
	print("[LOWER] letter lock solved (%s)" % GameState.LOWER_BOX_CODE)


func _on_closed() -> void:
	if not GameState.lower_box_open or _taken:
		return
	if _lid != null:
		var tw := create_tween()
		tw.tween_property(_lid, "rotation:x", deg_to_rad(110.0), 0.45).set_trans(Tween.TRANS_SINE)
		await tw.finished
	_give_cuffs()


func _give_cuffs() -> void:
	# Carry full: GameState shows "Can't carry more." and the prompt stays [E] Take.
	if not GameState.add_inventory_flag("handcuffs"):
		return
	_taken = true
	if _inner != null:
		var cuffs := _inner.get_node_or_null("Cuffs") as Node3D
		if cuffs != null:
			cuffs.visible = false
	get_tree().call_group("subtitle", "show_line", "SABIRA", String(GameState.STORY_LINES["lower_box_got"]), 3.0)


## Small dark-iron lockbox sitting in the open cardboard box (top just above the rim), with a
## row of 6 brass dials on the front and the cuffs + wire coil inside.
func _build_inner() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.15, 0.14)
	iron.metallic = 0.6
	iron.roughness = 0.6
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.62, 0.48, 0.22)
	brass.metallic = 0.7
	brass.roughness = 0.45
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.6, 0.6, 0.62)
	steel.metallic = 0.8
	steel.roughness = 0.35
	var w := minf(_size.x * 0.6, 0.3)
	var d := minf(_size.z * 0.55, 0.2)
	var h := 0.11
	_inner = Node3D.new()
	_inner.name = "LockBox"
	add_child(_inner)
	_inner.position = Vector3(0, _size.y - h + 0.03, 0)
	_mesh(_inner, Vector3(w, h, d), Vector3(0, h * 0.5, 0), iron)
	for i in 6:
		var dial := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.011
		cm.bottom_radius = 0.011
		cm.height = 0.012
		cm.radial_segments = 8
		dial.mesh = cm
		dial.material_override = brass
		dial.rotation.x = PI * 0.5
		dial.position = Vector3(-w * 0.35 + w * 0.7 * float(i) / 5.0, h * 0.55, -d * 0.5 - 0.005)
		_inner.add_child(dial)
	var cuffs := Node3D.new()
	cuffs.name = "Cuffs"
	_inner.add_child(cuffs)
	for k in 2:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.026
		tm.outer_radius = 0.034
		tm.rings = 10
		tm.ring_segments = 4
		ring.mesh = tm
		ring.material_override = steel
		ring.position = Vector3(-0.04 + 0.08 * k, h + 0.004, 0.0)
		cuffs.add_child(ring)
	# Lid hinged on the back edge (+Z side, away from the dials).
	_lid = Node3D.new()
	_lid.name = "Lid"
	_lid.position = Vector3(0, h, d * 0.5)
	_inner.add_child(_lid)
	_mesh(_lid, Vector3(w + 0.01, 0.015, d + 0.01), Vector3(0, 0.0075, -d * 0.5), iron)


func _mesh(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
