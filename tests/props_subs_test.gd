extends SceneTree
## Headless props_subs test (2026-10-14): godot --headless --path . -s res://tests/props_subs_test.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://world/House.tscn")
	for i in 120:
		await physics_frame
	var w := get_first_node_in_group("tash") as Node3D
	var lr := get_first_node_in_group("lower_room") as Node3D
	var p := get_first_node_in_group("player") as CharacterBody3D
	print("[TEST] tash at ", w.global_position, " player at ", p.global_position)
	var a: AABB = lr.call("inner_aabb")
	p.global_position = a.get_center()
	print("[TEST] lower room: normal=%s loud=%s" % [w.call("_can_player_hear_line", false), w.call("_can_player_hear_line", true)])
	w.call("_say", "lower room test line", 1.0, true)
	p.global_position = w.global_position + Vector3(1.5, 0, 0)
	await physics_frame
	print("[TEST] near: normal=%s loud=%s" % [w.call("_can_player_hear_line", false), w.call("_can_player_hear_line", true)])
	var other := Vector3(w.global_position.x, w.global_position.y + (3.0 if w.global_position.y < 2.0 else -3.0), w.global_position.z)
	p.global_position = other
	await physics_frame
	print("[TEST] other floor: normal=%s loud=%s" % [w.call("_can_player_hear_line", false), w.call("_can_player_hear_line", true)])
	w.call("_say", "other floor normal test", 1.0, false)
	# Face lock (headless: mouse not captured, so arm it directly).
	p.global_position = w.global_position + Vector3(3.0, 0.05, 2.0)
	p.rotation.y = 0.0
	await physics_frame
	p.set("_face_lock_target", w)
	p.set("_face_lock_total", 2.0)
	p.set("_face_lock_t", 0.0)
	p.set("_face_lock_from_yaw", p.rotation.y)
	p.set("_face_lock_from_pitch", (p.get_node("CameraPivot") as Node3D).rotation.x)
	for i in 140:
		await physics_frame
		if i == 10 or i == 25 or i == 60:
			var cam := p.get_node("CameraPivot/Camera3D") as Camera3D
			var fwd := -cam.global_transform.basis.z
			var to: Vector3 = (w.call("face_point") as Vector3 - cam.global_position).normalized()
			print("[TEST] facelock frame %d t=%.2f locked=%s aim_err_deg=%.1f" % [i, p.get("_face_lock_t"), p.call("is_face_locked"), rad_to_deg(fwd.angle_to(to))])
	print("[TEST] facelock after 140 frames locked=%s" % p.call("is_face_locked"))
	quit()