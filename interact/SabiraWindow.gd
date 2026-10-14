# Godot 4.x - Sabira / HOUSE
class_name SabiraWindow
extends Interactable
## "Sabira Window": the drawing props/sabira_window/sabira_window.jpg on a thin paper sheet (long side 0.7 m), taped
## crookedly to a free wall spot in Sabira's room. Spawned at runtime by KeySpawner.
## setup() raycasts from inside the room to the wall (RAY_FROM -> RAY_TO) and sticks the sheet
## on the hit point, facing the room. [E] Look: LOOK_LINE.

const LOOK_LINE := "My window. The only one I can open."
## Far wall facing her door: Doors/Door_Sabira at world (2.5, 3.0, 0.403) in the room's west wall
## (x 2.5). Straight in from the doorway the ray meets
## Structure/Wall_East (x 7.0, room face x 6.9). Centre 1.5 m above her floor (3.05) = y 4.55.
const RAY_FROM := Vector3(3.6, 4.55, 0.403)   # past the door leaf swing
const RAY_TO := Vector3(7.6, 4.55, 0.403)
const FALLBACK_POS := Vector3(6.9, 4.55, 0.403)
const FALLBACK_NRM := Vector3(-1, 0, 0)
const SHEET := Vector2(0.30, 0.40)
const TILT_DEG := -5.5
const LONG_SIDE := 0.7
## Tape strips scale with the sheet (base sizes were for the 0.35 m sheet).
const TAPE_SCALE := 2.0
const IMAGE_PATH := "res://props/sabira_window/sabira_window.jpg"

var _sheet: Vector2 = SHEET


func _ready() -> void:
	add_to_group("sabira_window")
	collision_layer = 5
	collision_mask = 0
	prompt_text = "[E] Look"
	interact_enabled = true


func setup() -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(RAY_FROM, RAY_TO)
	q.collision_mask = 1
	var hit := space.intersect_ray(q)
	var pos := FALLBACK_POS
	var nrm := FALLBACK_NRM
	if not hit.is_empty():
		pos = hit["position"]
		nrm = (hit["normal"] as Vector3).normalized()
	else:
		push_warning("SabiraWindow: no wall hit, using fallback spot")
	global_position = pos + nrm * 0.004
	# Face the room: local +Z = wall normal.
	look_at(global_position - nrm, Vector3.UP)
	rotate_object_local(Vector3.FORWARD, deg_to_rad(TILT_DEG))
	_build()
	print("[PROP] Sabira Window at %s (normal %s)" % [global_position, nrm])


func _build() -> void:
	var tex := _load_texture()
	_sheet = SHEET
	if tex != null and tex.get_width() > 0 and tex.get_height() > 0:
		# Fit the sheet to the image aspect, long side = LONG_SIDE.
		var asp := float(tex.get_width()) / float(tex.get_height())
		_sheet = Vector2(LONG_SIDE, LONG_SIDE / asp) if asp >= 1.0 else Vector2(LONG_SIDE * asp, LONG_SIDE)
	var paper := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = _sheet
	paper.mesh = qm
	var mat := StandardMaterial3D.new()
	if tex != null:
		mat.albedo_texture = tex
	else:
		mat.albedo_color = Color(0.93, 0.91, 0.84)
	mat.roughness = 1.0
	paper.material_override = mat
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(paper)
	# Tape strips at the corners: translucent beige quads, slightly crooked.
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.92, 0.86, 0.68, 0.55)
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.roughness = 0.4
	for c in [[-1, 1, 38.0], [1, 1, -35.0], [-1, -1, -40.0], [1, -1, 33.0]]:
		var tape := MeshInstance3D.new()
		var tm := QuadMesh.new()
		tm.size = Vector2(0.075, 0.022) * TAPE_SCALE
		tape.mesh = tm
		tape.material_override = tmat
		tape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tape.position = Vector3(float(c[0]) * (_sheet.x * 0.5 - 0.012 * TAPE_SCALE), float(c[1]) * (_sheet.y * 0.5 - 0.012 * TAPE_SCALE), 0.002)
		tape.rotation.z = deg_to_rad(float(c[2]))
		add_child(tape)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_sheet.x, _sheet.y, 0.03)
	cs.shape = box
	add_child(cs)


func _on_interact(_player: Node) -> void:
	get_tree().call_group("subtitle", "show_line", "SABIRA", LOOK_LINE, 3.0)


## The user's drawing (props/sabira_window/sabira_window.jpg). Imported resource if Godot has
## imported it, otherwise read the raw file (works before the first editor import).
static func _load_texture() -> Texture2D:
	if ResourceLoader.exists(IMAGE_PATH):
		var t := load(IMAGE_PATH) as Texture2D
		if t != null:
			return t
	var img := Image.load_from_file(ProjectSettings.globalize_path(IMAGE_PATH))
	if img == null or img.is_empty():
		push_warning("SabiraWindow: could not load " + IMAGE_PATH)
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
