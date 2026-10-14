# Godot 4.x - Sabira / HOUSE
class_name WallScratch
extends Interactable
## Realistic only (spawned by KeySpawner._spawn_medbox): GameState.med_code scratched into the
## laundry wall under the hanging towels (Structure/Laundry/Laundry_HangerRail). [E] Look.

const RAIL_PATH := "Structure/Laundry/Laundry_HangerRail"
const BELOW_RAIL := 1.2      # metres under the rail (rail ~1.75 above floor -> ~0.55 m)
const FALLBACK_POS := Vector3(-6.22, 0.6, 0.06)
const PEN_FONT := "res://fonts/JosefinSans-Italic-VF.ttf"

var _busy: bool = false


func _ready() -> void:
	add_to_group("wall_scratch")
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	prompt_text = String(GameState.STORY_LINES["scratch_prompt"])


func setup() -> void:
	await get_tree().physics_frame  # physics space has the house colliders by now
	await get_tree().physics_frame
	var scene := get_tree().current_scene
	var rail := scene.get_node_or_null(RAIL_PATH) as Node3D if scene != null else null
	var pos := FALLBACK_POS
	var normal := Vector3(0, 0, 1)
	var hit := {}
	if rail != null:
		var from := rail.global_position + Vector3(0, -BELOW_RAIL, 0.6)
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 0, -1.6))
		q.collision_mask = 1
		hit = get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			pos = hit["position"]
			var n: Vector3 = hit["normal"]
			n.y = 0.0
			if n.length_squared() > 0.01:
				normal = n.normalized()
		else:
			pos = rail.global_position + Vector3(0, -BELOW_RAIL, -0.12)
	global_transform = Transform3D(Basis.looking_at(-normal, Vector3.UP), pos + normal * 0.004)
	_build(GameState.ensure_med_code())
	print("[HOUSE] WallScratch at %s (%s)" % [global_position, "wall hit" if not hit.is_empty() else "fallback"])


func _build(code: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(code)
	var x := -0.105
	for ch in code:
		var l := Label3D.new()
		l.text = ch
		l.font_size = 80
		var pen := _pen_font()   # only these digits; the global theme stays Metal Mania
		if pen != null:
			l.font = pen
		l.pixel_size = 0.0016
		l.outline_size = 0
		l.modulate = Color(0.07, 0.065, 0.07, 0.62)   # black pen, soft against the wall
		l.shaded = true
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		l.position = Vector3(x + rng.randf_range(-0.006, 0.006), rng.randf_range(-0.008, 0.008), 0.0)
		l.rotation.z = deg_to_rad(rng.randf_range(-9.0, 9.0))
		add_child(l)
		x += 0.07
	# A few scratch strokes around the digits.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.07, 0.07, 0.3)   # faint pen strokes
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in range(5):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.04, 0.12), 0.0012, 0.001)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3(rng.randf_range(-0.14, 0.14), rng.randf_range(-0.07, 0.07), 0.0)
		mi.rotation.z = deg_to_rad(rng.randf_range(-35.0, 35.0))
		add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.36, 0.16, 0.06)
	cs.shape = sh
	add_child(cs)


## Josefin Sans Thin Italic (OFL, fonts/JosefinSans-Italic-VF.ttf; default axis wght=100).
## Imported resource if available, else read the raw file (works before the editor import).
static func _pen_font() -> Font:
	if ResourceLoader.exists(PEN_FONT):
		var f := load(PEN_FONT) as Font
		if f != null:
			return f
	var ff := FontFile.new()
	if ff.load_dynamic_font(ProjectSettings.globalize_path(PEN_FONT)) != OK:
		return null
	return ff


func _on_interact(_player: Node) -> void:
	if _busy:
		return
	_busy = true
	var code := GameState.ensure_med_code()
	get_tree().call_group("subtitle", "show_line", "SABIRA", String(GameState.STORY_LINES["scratch_look"]), 3.4)
	await get_tree().create_timer(3.5).timeout
	get_tree().call_group("subtitle", "show_line", "SABIRA", " ".join(PackedStringArray(code.split(""))), 3.5)
	await get_tree().create_timer(1.0).timeout
	_busy = false
