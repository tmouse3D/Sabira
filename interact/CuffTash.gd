# Godot 4.x - Sabira / HOUSE
class_name CuffTash
extends Interactable
## Lower secret (2026-10-13). Rides on Tash (child of the TashWalker, added by world/LowerRoom.gd).
## Holding 'handcuffs' (GameState.has_handcuffs) and looking at him shows STORY_LINES.cuff_prompt
## ("[E] Cuff him") only when:
##   (a) dosed couch sleep: walker.is_drunk_locked() (drink sit after GameState.bottle_dosed) and
##       no stab (not walker.is_tash_dead(), no walker._stab_layer card running), or
##   (b) chase trip: walker._chase_hold with walker._hold_kind "fall" / "lie" (fall_flat, lying).
## [E]: fade to black + STORY_LINES.cuff_fade_text, then the lower room: Tash lies CUFF_TASH_DIST
## in front of the radiator playing laying_breathless (baked from Laying Breathless.fbx; fallback:
## dying held on its last frame), AI frozen (walker.set_intro_frozen), a thin wire from his wrist
## bone to the radiator, the player facing the radiator. GameState.tash_cuffed blocks the hatch.
## Then STORY_LINES.feel_it_prompt ("[E] Make him feel it"): fade to black, SCREAM_PATH (audio
## only), then Ending 19 (GameState.trigger_like_father_ending).

const LIE_CLIP := "laying_breathless"
const LIE_FALLBACK_CLIP := "dying"
const SCREAM_PATH := "res://audio/sfx/tash_pain_scream.wav"
const SCREAM_DB := -2.0
## Tash's yaw while lying in front of the radiator (deg, world). 90 = body along the wall.
const TASH_LIE_YAW_DEG := 90.0
## Camera pitch on landing (deg, negative = look down at him).
const PLAYER_PITCH_DEG := -18.0
const FADE_IN_SEC := 0.8
const TEXT_IN_SEC := 0.8
const TEXT_HOLD_SEC := 4.0
const TEXT_OUT_SEC := 0.6
const FADE_OUT_SEC := 1.0

var lower_room: LowerRoom = null
var _walker: Node3D = null
var _mode: String = "cuff"     # "cuff" -> "feel" -> "done"
var _busy: bool = false
var _shape: CollisionShape3D
var _skel: Skeleton3D = null
var _wrist: int = -1
## Where he was placed (world). Pinned every physics frame while cuffed: see _place_scene.
var _pin: Transform3D = Transform3D.IDENTITY
var _pinned: bool = false
var _fallback: Node = null
const FALLBACK_CHECK_SEC := 1.0
const PIN_TOLERANCE_M := 0.5


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	interact_enabled = true
	_walker = get_parent() as Node3D
	_shape = CollisionShape3D.new()
	_shape.shape = BoxShape3D.new()
	add_child(_shape)
	_set_box(Vector3(0.9, 1.3, 0.9), Vector3(0, 0.72, 0))


func _set_box(size: Vector3, pos: Vector3) -> void:
	(_shape.shape as BoxShape3D).size = size
	_shape.position = pos


func _wcall(m: String) -> Variant:
	if _walker != null and _walker.has_method(m):
		return _walker.call(m)
	return null


func _state_ok() -> bool:
	if GameState.ending_reached != "" or _walker == null:
		return false
	if _wcall("is_tash_dead") == true:
		return false
	if _mode == "feel":
		return GameState.tash_cuffed
	if _mode != "cuff" or GameState.tash_cuffed or not GameState.has_handcuffs:
		return false
	if _wcall("is_drunk_locked") == true and GameState.bottle_dosed and _walker.get("_stab_layer") == null:
		return true
	var kind := String(_walker.get("_hold_kind"))
	return _walker.get("_chase_hold") == true and (kind == "fall" or kind == "lie")


func _physics_process(_delta: float) -> void:
	if _pinned and _walker != null and _walker.global_transform != _pin:
		_walker.global_transform = _pin
	var ok := _state_ok() and not _busy
	collision_layer = 4 if ok else 0
	if ok and _mode == "cuff":
		var lying: bool = _walker.get("_chase_hold") == true
		if lying:
			_set_box(Vector3(2.0, 0.6, 2.0), Vector3(0, 0.3, 0))
		else:
			_set_box(Vector3(0.9, 1.3, 0.9), Vector3(0, 0.72, 0))


func can_interact(_player: Node) -> bool:
	return interact_enabled and not _busy and _state_ok()


func get_prompt() -> String:
	if not can_interact(null):
		return ""
	return String(GameState.STORY_LINES["cuff_prompt" if _mode == "cuff" else "feel_it_prompt"])


func _on_interact(player: Node) -> void:
	if not can_interact(player):
		return
	if _mode == "cuff":
		_cuff(player as Node3D)
	elif _mode == "feel":
		_feel_it()


func _process(_delta: float) -> void:
	_update_wire()


# --- Cuff him ------------------------------------------------------------------------------
func _cuff(player: Node3D) -> void:
	_busy = true
	var tree := get_tree()
	tree.call_group("player", "set_input_locked", true)
	tree.call_group("interact_prompt", "suppress_for", 9999.0)
	var fade := _make_fade()
	var black := fade.get_child(0) as ColorRect
	var label := black.get_child(0) as Label
	var t := create_tween()
	t.tween_property(black, "color:a", 1.0, FADE_IN_SEC)
	await t.finished
	# Black: stop him and move everyone downstairs.
	_stop_ai()
	GameState.remove_inventory_flag("handcuffs")
	GameState.tash_cuffed = true
	_place_scene(player)
	label.text = String(GameState.STORY_LINES["cuff_fade_text"])
	var ti := create_tween()
	ti.tween_property(label, "modulate:a", 1.0, TEXT_IN_SEC)
	await ti.finished
	await tree.create_timer(TEXT_HOLD_SEC).timeout
	var to := create_tween()
	to.tween_property(label, "modulate:a", 0.0, TEXT_OUT_SEC)
	await to.finished
	_mode = "feel"
	_set_box(Vector3(2.0, 0.6, 2.0), Vector3(0, 0.3, 0))
	var tb := create_tween()
	tb.tween_property(black, "color:a", 0.0, FADE_OUT_SEC)
	await tb.finished
	fade.queue_free()
	tree.call_group("player", "set_input_locked", false)
	tree.call_group("interact_prompt", "suppress_for", 0.05)
	_busy = false
	print("[CUFF] Tash cuffed to the radiator")
	# After the fade is gone: prompt must be live within FALLBACK_CHECK_SEC, else the fallback.
	_check_fallback_later(player)


func _stop_ai() -> void:
	if _wcall("is_chasing") == true or _walker.get("_chase_hold") == true:
		_walker.set("_chase_hold", false)
		_walker.set("_hold_kind", "")
		_walker.call("_end_chase_to_patrol", "cuffed")
	if _wcall("is_drunk_locked") == true:
		_walker.call("_set_drunk_look_active", false)
	if _walker.has_method("_restore_couch_props"):
		_walker.call("_restore_couch_props")
	if _walker.has_method("set_intro_frozen"):
		_walker.call("set_intro_frozen", true)
	GameState.tash_alert_changed.emit("ambient")


## Same code for both entry paths (couch dose and chase fall).
## Root cause of the "no Tash downstairs" bug: the walker is a child of his PathFollow3D. Setting
## only his global_transform left him ~10 m off the PathFollow's origin, and the PathFollow's yaw
## kept being turned afterwards (visual yaw settle / facing code), swinging him around that
## origin out of the room (headless test: (-4.38, -3.5, 13.28) instead of (-6.4, -3.5, -1.5)).
## Now he is top_level (parent transform ignored) and his transform is pinned every frame.
func _place_scene(player: Node3D) -> void:
	if lower_room == null or not is_instance_valid(lower_room):
		push_warning("CuffTash: no LowerRoom")
		return
	var pos := lower_room.cuff_tash_pos()
	var face := lower_room.cuff_player_pos()
	_walker.top_level = true
	_pin = Transform3D(Basis(Vector3.UP, deg_to_rad(TASH_LIE_YAW_DEG)), pos)
	if lower_room.radiator != null:
		_pin.basis = lower_room.radiator.global_transform.basis * Basis(Vector3.UP, deg_to_rad(TASH_LIE_YAW_DEG + 180.0))
	_walker.global_transform = _pin
	_pinned = true
	_walker.visible = true
	var model := _walker.get_node_or_null("Model") as Node3D
	if model != null:
		model.visible = true
	if _walker is CollisionObject3D:
		(_walker as CollisionObject3D).collision_layer = 0
		(_walker as CollisionObject3D).collision_mask = 0
	lower_room.set_radiator_look_enabled(false)
	_play_lie_clip()
	print("[CUFF] placed Tash at %s (room %s)" % [_walker.global_position, lower_room.inner_aabb()])
	if player != null:
		player.global_position = face
		if lower_room.radiator != null:
			var to := lower_room.radiator.global_position - face
			player.rotation.y = atan2(-to.x, -to.z)   # face the radiator
		else:
			player.rotation.y = PI
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
		var pivot := player.get_node_or_null("CameraPivot") as Node3D
		if pivot != null:
			pivot.rotation.x = deg_to_rad(PLAYER_PITCH_DEG)
	_build_wire()


func _play_lie_clip() -> void:
	var ap := _walker.get("_anim") as AnimationPlayer
	if ap == null:
		ap = _walker.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		push_warning("CuffTash: no AnimationPlayer on Tash")
		return
	ap.speed_scale = 1.0
	var clip := String(_wcall_arg("_resolve_clip_path", LIE_CLIP))
	if clip != "" and ap.has_animation(clip):
		ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		ap.play(clip, 0.0)
		print("[CUFF] lie clip %s" % clip)
		return
	clip = String(_wcall_arg("_resolve_clip_path", LIE_FALLBACK_CLIP))
	if clip != "" and ap.has_animation(clip):
		var a := ap.get_animation(clip)
		a.loop_mode = Animation.LOOP_NONE
		ap.play(clip, 0.0)
		ap.seek(a.length, true)
		ap.pause()
		push_warning("CuffTash: %s missing, holding the last frame of %s" % [LIE_CLIP, clip])


func _wcall_arg(m: String, arg: Variant) -> Variant:
	if _walker != null and _walker.has_method(m):
		return _walker.call(m, arg)
	return ""


# --- Wire: left wrist coil -> link rod -> loop on a lower radiator section ------------------
## Thick black rusty wire (one shared material): WIRE_LOOPS tilted tori round the wrist on a
## BoneAttachment3D (mixamorig:LeftHand), a WIRE_LINK_R rod from the coil to a small loop round
## a lower radiator section, re-aimed every frame so it follows the Laying Breathless pose.
## After the lie clip has posed him, the hand nearest that loop is checked: if the RIGHT hand is
## nearer, his yaw is flipped 180 deg so the left hand faces the radiator.
const WIRE_LOOPS := 4
const WIRE_LOOP_R := 0.055
const WIRE_TUBE := 0.016
const WIRE_LINK_R := 0.024
## Radiator loop: offset from the chain anchor (radiator local), round a lower section.
const RAD_LOOP_OFFSET := Vector3(0.28, -0.04, -0.03)
const RAD_LOOP_R := 0.05

var _coil: BoneAttachment3D = null
var _link: MeshInstance3D = null
var _wire_mat: StandardMaterial3D = null
var hand_used: String = ""


func _find_bone_any(names: PackedStringArray) -> int:
	if _skel == null:
		return -1
	for n in names:
		var i := _skel.find_bone(n)
		if i >= 0:
			return i
	return -1


func _bone_world(i: int) -> Vector3:
	return _skel.global_transform * _skel.get_bone_global_pose(i).origin


func _rad_loop_global() -> Vector3:
	var rad := lower_room.radiator
	return rad.to_global(rad.anchor_local + RAD_LOOP_OFFSET)


func _make_wire_mat() -> StandardMaterial3D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for y in 32:
		for x in 32:
			var t := rng.randf()
			var c := Color(0.05, 0.045, 0.04)
			if t > 0.72:
				c = Color(0.30, 0.15, 0.07).lerp(Color(0.18, 0.09, 0.05), rng.randf())
			img.set_pixel(x, y, c.darkened(rng.randf_range(0.0, 0.25)))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.95
	m.metallic = 0.25
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(18, 18, 18)
	return m


func _torus(parent: Node3D, r: float, tube: float) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = r - tube
	tm.outer_radius = r + tube
	tm.rings = 10
	tm.ring_segments = 5
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	mi.material_override = _wire_mat
	parent.add_child(mi)
	return mi


func _build_wire() -> void:
	_skel = _walker.find_child("GeneralSkeleton", true, false) as Skeleton3D
	if _skel == null:
		_skel = _walker.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skel == null or lower_room.radiator == null:
		push_warning("CuffTash: no skeleton / radiator, no wire")
		return
	# Let the lie clip pose him first (we are under the black fade).
	await get_tree().process_frame
	await get_tree().process_frame
	var li := _find_bone_any(PackedStringArray(["mixamorig:LeftHand", "LeftHand", "mixamorig_LeftHand"]))
	var ri := _find_bone_any(PackedStringArray(["mixamorig:RightHand", "RightHand", "mixamorig_RightHand"]))
	if li < 0:
		push_warning("CuffTash: no LeftHand bone, no wire")
		return
	var target := _rad_loop_global()
	var dl := _bone_world(li).distance_to(target)
	var dr := _bone_world(ri).distance_to(target) if ri >= 0 else INF
	if dr < dl:
		_pin.basis = _pin.basis * Basis(Vector3.UP, PI)
		_walker.global_transform = _pin
		await get_tree().process_frame
		print("[CUFF] right hand was nearer (L %.2f / R %.2f m): yaw flipped 180" % [dl, dr])
		dl = _bone_world(li).distance_to(target)
	hand_used = _skel.get_bone_name(li)
	_wire_mat = _make_wire_mat()
	# Wrist coil on the bone (counter the skeleton's world scale so the sizes are in metres).
	_coil = BoneAttachment3D.new()
	_coil.name = "CuffCoil"
	_coil.bone_name = hand_used
	_skel.add_child(_coil)
	var holder := Node3D.new()
	var gs := _skel.global_transform.basis.get_scale()
	holder.scale = Vector3(1.0 / maxf(gs.x, 0.0001), 1.0 / maxf(gs.y, 0.0001), 1.0 / maxf(gs.z, 0.0001))
	_coil.add_child(holder)
	for k in WIRE_LOOPS:
		var t := _torus(holder, lerpf(0.052, 0.062, float(k) / float(WIRE_LOOPS - 1)), WIRE_TUBE)
		t.position = Vector3(0, -0.012 + 0.011 * float(k), 0.004 * float(k % 2))
		t.rotation = Vector3(deg_to_rad(-12.0 + 9.0 * float(k)), deg_to_rad(23.0 * float(k)), deg_to_rad(8.0 - 6.0 * float(k)))
	# Loop round the lower radiator section (vertical axis = round the column).
	var rloop := _torus(lower_room.radiator, RAD_LOOP_R, WIRE_TUBE)
	rloop.name = "CuffRadLoop"
	rloop.global_position = target
	rloop.rotation = Vector3(deg_to_rad(8.0), 0.0, deg_to_rad(-6.0))
	# Link rod, re-aimed every frame (_update_wire).
	var cm := CylinderMesh.new()
	cm.top_radius = WIRE_LINK_R
	cm.bottom_radius = WIRE_LINK_R
	cm.height = 1.0
	cm.radial_segments = 6
	cm.rings = 1
	_link = MeshInstance3D.new()
	_link.name = "CuffWire"
	_link.mesh = cm
	_link.material_override = _wire_mat
	lower_room.add_child(_link)
	_update_wire()
	print("[CUFF] wire on %s, hand->radiator loop %.2f m" % [hand_used, dl])


func _wrist_global() -> Vector3:
	if _coil != null and is_instance_valid(_coil):
		return _coil.global_position
	return _walker.global_position + Vector3(0, 0.15, 0)


func _update_wire() -> void:
	if _link == null or not is_instance_valid(_link) or lower_room == null or lower_room.radiator == null:
		return
	var a := _wrist_global()
	var b := _rad_loop_global()
	var dist := a.distance_to(b)
	if dist < 0.01:
		_link.visible = false
		return
	_link.visible = true
	var y := (b - a) / dist
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	_link.global_transform = Transform3D(Basis(x, y * dist, z), (a + b) * 0.5)


# --- Fallback: always finishable -------------------------------------------------------------
func _check_fallback_later(player: Node3D) -> void:
	await get_tree().create_timer(FALLBACK_CHECK_SEC).timeout
	if _mode != "feel":
		return
	var want := lower_room.cuff_tash_pos() if lower_room != null else Vector3.INF
	var placed := _walker != null and is_instance_valid(_walker) and _walker.is_inside_tree() \
			and _walker.global_position.distance_to(want) < PIN_TOLERANCE_M
	var area_ok := is_inside_tree() and is_visible_in_tree() and collision_layer == 4 and _state_ok()
	print("[CUFF] check after %.1f s: placed=%s area_ok=%s tash=%s" % [FALLBACK_CHECK_SEC, placed, area_ok, _walker.global_position if _walker else null])
	if placed and area_ok:
		return
	_spawn_fallback(player)


## Standalone [E] Make him feel it box 1 m in front of the player (layer 4).
func _spawn_fallback(player: Node3D) -> void:
	if _fallback != null and is_instance_valid(_fallback):
		return
	var fb := FeelItFallback.new()
	fb.name = "FeelItFallback"
	fb.owner_cuff = self
	var host: Node = lower_room if lower_room != null else get_tree().current_scene
	host.add_child(fb)
	var fwd := Vector3(0, 0, -1)
	if player != null:
		fwd = -player.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		fb.global_position = player.global_position + fwd * 1.0
	_fallback = fb
	push_warning("CuffTash: placement / prompt check failed, spawned FeelItFallback at %s" % fb.global_position)


func run_feel_it() -> void:
	if _mode == "feel" and not _busy:
		_feel_it()


class FeelItFallback:
	extends Interactable
	var owner_cuff: Node = null

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		interact_enabled = true
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.2, 1.0, 1.2)
		cs.shape = bs
		cs.position = Vector3(0, 0.5, 0)
		add_child(cs)

	func get_prompt() -> String:
		return String(GameState.STORY_LINES["feel_it_prompt"]) if interact_enabled else ""

	func _on_interact(_player: Node) -> void:
		interact_enabled = false
		collision_layer = 0
		if owner_cuff != null and is_instance_valid(owner_cuff):
			owner_cuff.call("run_feel_it")


# --- Make him feel it -----------------------------------------------------------------------
func _feel_it() -> void:
	_busy = true
	_mode = "done"
	var tree := get_tree()
	tree.call_group("player", "set_input_locked", true)
	tree.call_group("interact_prompt", "suppress_for", 9999.0)
	var fade := _make_fade()
	var black := fade.get_child(0) as ColorRect
	var t := create_tween()
	t.tween_property(black, "color:a", 1.0, FADE_IN_SEC)
	await t.finished
	var sp := AudioStreamPlayer.new()
	sp.name = "TashPainScream"
	sp.stream = load(SCREAM_PATH) as AudioStream
	sp.volume_db = SCREAM_DB
	sp.bus = &"Master"
	sp.process_mode = Node.PROCESS_MODE_ALWAYS
	fade.add_child(sp)
	var wait := 2.4
	if sp.stream != null:
		wait = sp.stream.get_length()
		sp.play()
	else:
		push_warning("CuffTash: %s missing" % SCREAM_PATH)
	await tree.create_timer(wait + 0.8).timeout
	# The ending card (layer 90) fades its own black in over this one (layer 89).
	GameState.trigger_like_father_ending()


func _make_fade() -> CanvasLayer:
	var cl := CanvasLayer.new()
	cl.name = "CuffFade"
	cl.layer = 89
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	var cr := ColorRect.new()
	cr.color = Color(0, 0, 0, 0)
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(cr)
	var label := Label.new()
	label.name = "Card"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 160
	label.offset_right = -160
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86))
	label.modulate.a = 0.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.add_child(label)
	get_tree().root.add_child(cl)
	return cl
