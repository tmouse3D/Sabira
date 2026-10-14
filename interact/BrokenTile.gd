# Godot 4.x - Sabira / HOUSE
class_name BrokenTile
extends Interactable
## Cracked floor tile in the F1 bathroom. Spawned by GameState after the FIRST catch (always,
## clock key or not). Entering the bathroom: Sabira says STORY_LINES.tile_crack_enter (once).
## [E] Look at the tile -> ui/TilePuzzleUI.gd (drag the 6 shards back). Solved: the tile is
## lifted and gives tash_room_key (opens Tash's bedroom AND office, see interact/Door.gd).
## Esc in the puzzle keeps the progress (the UI node stays alive here).

const TilePuzzleUIScript := preload("res://ui/TilePuzzleUI.gd")
const NotePaperUIScript := preload("res://ui/NotePaperUI.gd")
## F1 downstairs bathroom bounds (same box as TashWalker BATH_MIN / BATH_MAX).
const BATH_MIN := Vector3(3.55, -0.5, 2.0)
const BATH_MAX := Vector3(6.95, 1.5, 5.4)

var _busy: bool = false
var _mesh: MeshInstance3D
var _ui: CanvasLayer = null
var _note_ui: CanvasLayer = null
var _enter_said: bool = false
var _enter_t: float = 0.0
var _shake_cam: Camera3D = null
const SHAKE_DUR := 0.35


func _ready() -> void:
	add_to_group("broken_tile")
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	# No tile mesh of its own: the real floor tile shows through. Only a thin crack line on
	# top of it + the collider for the prompt. (_mesh is just the holder for the crack.)
	_mesh = MeshInstance3D.new()
	add_child(_mesh)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.04, 0.035, 0.03, 0.85)
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for c in [[0.20, 32.0, Vector3(-0.03, 0, 0.01)], [0.11, 58.0, Vector3(0.085, 0, -0.06)]]:
		var crack := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(float(c[0]), 0.002, 0.004)
		crack.mesh = cm
		crack.material_override = cmat
		crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		crack.rotation.y = deg_to_rad(float(c[1]))
		crack.position = Vector3(c[2]) + Vector3(0, 0.002, 0)
		_mesh.add_child(crack)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.4, 0.1, 0.4)
	cs.shape = sh
	cs.position.y = 0.05
	add_child(cs)
	_apply_done_state()
	refresh_prompt()


## Re-entry / respawn: restore the right look from GameState (crack, open socket, or closed).
func _apply_done_state() -> void:
	if not GameState.tile_done:
		return
	_mesh.visible = false
	if GameState.amina_note_found and not GameState.amina_note_reacted:
		_show_lifted()
		_show_note_paper()


func refresh_prompt() -> void:
	if GameState.tile_done:
		# Note reward: the lifted tile spot stays readable.
		if GameState.amina_note_found and not GameState.amina_note_reacted:
			prompt_text = String(GameState.STORY_LINES["tile_note_prompt"])
			interact_enabled = true
			return
		prompt_text = ""
		interact_enabled = false
		return
	prompt_text = String(GameState.STORY_LINES["tile_look_prompt"])


func get_prompt() -> String:
	if _busy or not interact_enabled:
		return ""
	return prompt_text


func _physics_process(delta: float) -> void:
	if _enter_said or GameState.tile_done:
		return
	_enter_t -= delta
	if _enter_t > 0.0:
		return
	_enter_t = 0.2
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var g := p.global_position
	if g.x > BATH_MIN.x and g.x < BATH_MAX.x and g.y > BATH_MIN.y and g.y < BATH_MAX.y and g.z > BATH_MIN.z and g.z < BATH_MAX.z:
		_enter_said = true
		get_tree().call_group("subtitle", "show_line", "SABIRA", String(GameState.STORY_LINES["tile_crack_enter"]), 3.0)
		_crack_shake()
		print("[TILE] she entered the F1 bathroom: crack line")


func _on_interact(_player: Node) -> void:
	if _busy:
		return
	if GameState.tile_done:
		if GameState.amina_note_found and not GameState.amina_note_reacted:
			_read_note()
		return
	if _ui != null and is_instance_valid(_ui) and bool(_ui.get("_done")):
		_on_solved()   # puzzle already finished earlier, carry slots were full
		return
	if _ui == null or not is_instance_valid(_ui):
		_ui = TilePuzzleUIScript.new()
		_ui.name = "TilePuzzleUI"
		get_tree().root.add_child(_ui)
		_ui.connect("solved", _on_solved)
	_ui.call("open")


func _on_solved() -> void:
	if GameState.tile_done:
		return
	if not GameState.catch_took_clock_items:
		# The clock quest is still hers (key kept / clock still solvable): Amina's old note.
		GameState.tile_done = true
		GameState.amina_note_found = true
		_show_lifted()
		_show_note_paper()
		print("[TILE] solved: Amina's note (clock quest still open)")
		refresh_prompt()
		if _ui != null and is_instance_valid(_ui):
			_ui.queue_free()
			_ui = null
		_read_note()
		return
	if not GameState.add_inventory_flag("tash_room_key"):
		# Carry slots full: puzzle stays solved; [E] again after freeing a slot gives the key.
		get_tree().call_group("subtitle", "show_line", "SABIRA", "My hands are full.", 2.0)
		return
	GameState.tile_done = true
	_mesh.visible = false   # key taken at once: tile back in place, plain floor (no socket)
	get_tree().call_group("subtitle", "show_line", "SABIRA", String(GameState.STORY_LINES["tile_lift"]), 3.5)
	print("[TILE] solved: tash_room_key given")
	refresh_prompt()
	if _ui != null and is_instance_valid(_ui):
		_ui.queue_free()
		_ui = null


func _exit_tree() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.queue_free()
	if _note_ui != null and is_instance_valid(_note_ui):
		_note_ui.queue_free()


## Lifted tile: crack hidden, a shallow grout-brown socket where the tile was (never pure black:
## the old 0.05 albedo box read as a solid black square on top of the floor).
func _show_lifted() -> void:
	_mesh.visible = false
	if get_node_or_null("TileSocket") != null:
		return
	var hole := MeshInstance3D.new()
	hole.name = "TileSocket"
	var hm := BoxMesh.new()
	hm.size = Vector3(0.3, 0.002, 0.3)
	hole.mesh = hm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.26, 0.21)
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = Color(0.06, 0.05, 0.04)
	hole.material_override = mat
	hole.position.y = 0.002
	add_child(hole)


## Amina's note as an aged paper sheet (ui/NotePaperUI.gd). First close: Sabira reacts once.
func _read_note() -> void:
	var text := String(GameState.STORY_LINES["amina_note"])
	if _note_ui == null or not is_instance_valid(_note_ui):
		_note_ui = NotePaperUIScript.new()
		_note_ui.name = "NotePaperUI"
		get_tree().root.add_child(_note_ui)
	_busy = true
	_note_ui.call("open_note", text)
	await Signal(_note_ui, "finished")
	_busy = false
	_note_react()


func _note_react() -> void:
	if GameState.amina_note_reacted:
		return
	GameState.amina_note_reacted = true
	_close_floor()
	get_tree().call_group("subtitle", "show_line", "SABIRA", String(GameState.STORY_LINES["amina_note_react"]), 7.0)


## The note lying in the socket: flat aged-paper quad (same generated texture as the 2D
## NotePaperUI), unshaded so it reads in the dark bathroom, 4 mm above the socket.
func _show_note_paper() -> void:
	if get_node_or_null("AminaNotePaper") != null:
		return
	var paper := MeshInstance3D.new()
	paper.name = "AminaNotePaper"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.15, 0.2)
	qm.orientation = PlaneMesh.FACE_Y
	paper.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = NotePaperUIScript._paper_texture()
	mat.albedo_color = Color(0.85, 0.82, 0.76)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paper.material_override = mat
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	paper.position = Vector3(0.0, 0.006, 0.0)
	paper.rotation.y = deg_to_rad(17.0)
	add_child(paper)


## Note / key taken: socket and paper gone, the real floor tile shows through (same material
## as the surrounding floor, since this node never draws a tile of its own). Crack stays hidden.
func _close_floor() -> void:
	_mesh.visible = false
	for n in ["TileSocket", "AminaNotePaper"]:
		var c := get_node_or_null(n)
		if c != null:
			c.queue_free()
	refresh_prompt()
	print("[TILE] note taken: floor tile closed")


## Light camera shake synced with the crack line: only Camera3D h/v_offset (crouch, head-bob,
## pivot look untouched), ~0.35 s decaying, then the original offsets are restored (0).
func _crack_shake() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if absf(cam.h_offset) > 0.0001 or absf(cam.v_offset) > 0.0001:
		return   # another effect (concussion) owns the offsets right now
	_shake_cam = cam
	var tw := create_tween()
	tw.tween_method(_shake_step, 0.0, SHAKE_DUR, SHAKE_DUR)
	tw.tween_callback(_shake_end)


func _shake_step(t: float) -> void:
	if _shake_cam == null or not is_instance_valid(_shake_cam):
		return
	var e := 1.0 - t / SHAKE_DUR
	e *= e
	_shake_cam.h_offset = sin(t * 70.0) * 0.012 * e
	_shake_cam.v_offset = sin(t * 53.0 + 1.1) * 0.009 * e


func _shake_end() -> void:
	if _shake_cam != null and is_instance_valid(_shake_cam):
		_shake_cam.h_offset = 0.0
		_shake_cam.v_offset = 0.0
	_shake_cam = null
