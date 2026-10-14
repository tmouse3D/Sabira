extends SceneTree
## Headless cuff test (cuff_fix 2026-10-13): godot --headless --path . -s res://tests/cuff_test.gd [-- fall]

func _initialize() -> void:
	_run.call_deferred()


func _dump(tag: String, w: Node3D) -> void:
	var m := w.get_node_or_null("Model") as Node3D
	var ct := w.get_node_or_null("CuffTash") as CollisionObject3D
	print("[TEST] %s tash pos=%s vis=%s model_vis=%s model_pos=%s parent=%s pm=%d frozen=%s" % [tag, w.global_position, w.is_visible_in_tree(), m.is_visible_in_tree() if m else null, m.global_position if m else null, w.get_parent().name, w.process_mode, w.get("_intro_frozen")])
	if ct != null:
		print("[TEST] %s cuff area pos=%s layer=%d prompt=%s" % [tag, ct.global_position, ct.collision_layer, ct.call("get_prompt")])
	var sk := w.find_child("GeneralSkeleton", true, false) as Node3D
	if sk:
		print("[TEST] %s skeleton pos=%s" % [tag, sk.global_position])


func _run() -> void:
	change_scene_to_file("res://world/House.tscn")
	for i in 120:
		await physics_frame
	var gs := root.get_node("GameState")
	var w := get_first_node_in_group("tash") as Node3D
	var lr := get_first_node_in_group("lower_room") as Node3D
	var p := get_first_node_in_group("player") as Node3D
	print("[TEST] tash=%s lower=%s player=%s" % [w, lr, p])
	gs.set("intro_pending", false)
	gs.call("add_inventory_flag", "handcuffs")
	var fall := OS.get_cmdline_user_args().has("fall")
	if fall:
		w.set("_chasing", true)
		w.call("_begin_chase_hold", "fall")
	else:
		gs.set("bottle_dosed", true)
		w.set("_couch_drink_phase", 2)
	_dump("before", w)
	var ct := w.get_node("CuffTash")
	print("[TEST] state_ok=%s" % ct.call("_state_ok"))
	ct.call("_cuff", p)
	for i in 30:
		await physics_frame
	_dump("mid", w)
	for k in 12:
		for i in 50:
			await physics_frame
		var pf := w.get_parent() as Node3D
		print("[TEST] t%d pf_global=%s w_local=%s w_global=%s" % [k, pf.global_position, w.position, w.global_position])
	_dump("after", w)
	print("[TEST] player pos=%s lower floor_top=%s radiator=%s" % [p.global_position, lr.get("floor_top"), (lr.get("radiator") as Node3D).global_position])
	var cam := p.get_node("CameraPivot/Camera3D") as Node3D
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, w.global_position + Vector3(0, 0.25, 0))
	q.collision_mask = 1 | 4
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	print("[TEST] ray player->tash hits %s" % (hit.get("collider") as Node).name if not hit.is_empty() else "[TEST] ray hit nothing")
	var wire := lr.get_node_or_null("CuffWire") as MeshInstance3D
	print("[TEST] wire=%s mid=%s len=%s" % [wire != null, wire.global_position if wire else null, wire.global_transform.basis.y.length() if wire else null])
	var sk := (w.find_children("*", "Skeleton3D", true, false)[0]) as Skeleton3D
	var coil := sk.get_node_or_null("CuffCoil") as Node3D if sk else null
	if coil != null:
		var bi := sk.find_bone(String(coil.get("bone_name")))
		for k in 4:
			var bw := sk.global_transform * sk.get_bone_global_pose(bi).origin
			print("[TEST] coil f%d coil=%s bone=%s gap=%.4f hand->loop=%.3f" % [k, coil.global_position, bw, coil.global_position.distance_to(bw), coil.global_position.distance_to((lr.get_node("Radiator/CuffRadLoop") as Node3D).global_position)])
			for i in 8:
				await physics_frame
	else:
		print("[TEST] no CuffCoil")
	quit()
