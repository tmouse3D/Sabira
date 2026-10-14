extends SceneTree
## Headless radio + dark test (radio_dark 2026-10-14):
## godot --headless --fixed-fps 60 --path . -s res://tests/radio_lure_test.gd
## Presses [E] through Player._try_interact (same path as the real input).

func _initialize() -> void:
	_run.call_deferred()


func _press(p: Node, target: Node) -> void:
	p.set("_current_target", target)
	p.call("_try_interact")


func _run() -> void:
	change_scene_to_file("res://world/House.tscn")
	for i in 30:
		await physics_frame
	var gs := root.get_node("GameState")
	var w := get_first_node_in_group("tash") as Node3D
	var p := get_first_node_in_group("player") as Node3D
	var lr := get_first_node_in_group("lower_room") as Node3D
	var rt := current_scene.find_child("RadioToggle", true, false)
	# A) As the game starts (no flags forced): first press right away.
	print("[TEST] A intro=%s patrol=%s hold=%s/%s" % [w.get("_intro_frozen"), w.get("_patrol_started"), w.get("_chase_hold"), w.get("_hold_kind")])
	_press(p, rt)
	await physics_frame
	print("[TEST] A radio on=%s playing=%s prompt=%s" % [rt.call("is_on"), (rt.get_node("Static") as AudioStreamPlayer3D).playing, rt.call("get_prompt")])
	_press(p, rt)
	print("[TEST] A after 2nd press on=%s" % rt.call("is_on"))
	# B) Patrol running, she far away (lower room): he comes and switches it off.
	gs.set("intro_pending", false)
	w.set("_intro_frozen", false)
	w.set("_patrol_started", true)
	p.global_position = (lr.call("inner_aabb") as AABB).get_center()
	for i in 60 * 40:
		await physics_frame
		if w.call("_radio_busy_reason") == "":
			break
	_press(p, rt)
	var off_at := -1.0
	for i in 60 * 60:
		await physics_frame
		if off_at < 0.0 and not bool(rt.call("is_on")):
			off_at = i / 60.0
			var sp: Vector3 = rt.call("stand_point")
			print("[TEST] B radio off after %.1f s, tash %.2f m from stand spot" % [off_at, Vector2(w.global_position.x - sp.x, w.global_position.z - sp.z).length()])
			break
	# C) Player turns it on and off again before he arrives: he still comes (pending/coming).
	for i in 60 * 20:
		await physics_frame
		if w.call("_radio_busy_reason") == "" and not bool(w.get("_investigating")):
			break
	_press(p, rt)
	_press(p, rt)
	print("[TEST] C on/off quick: radio on=%s, tash radio=%s" % [rt.call("is_on"), w.get("_radio")])
	for i in 60 * 40:
		await physics_frame
		if w.get("_radio") == null and not bool(w.get("_relight_pending")):
			break
	print("[TEST] C tash at %s" % w.global_position)
	# D) Sedated: radio plays, ignored.
	gs.set("tash_sedated", true)
	_press(p, rt)
	print("[TEST] D sedated: on=%s" % rt.call("is_on"))
	_press(p, rt)
	gs.set("tash_sedated", false)
	# E) Dark room: kitchen light off with him walking his route.
	var sw := current_scene.get_node_or_null("LightSwitches/Switch_Kitchen")
	if sw == null:
		for n in current_scene.find_children("*", "LightSwitch", true, false):
			if String(n.name) != "Switch_Living":
				sw = n
				break
	sw = current_scene.get_node("LightSwitches/Switch_Living") if sw == null else sw
	var sws := current_scene.find_children("*", "LightSwitch", true, false)
	for n in sws:
		if String(n.name) in ["Switch_Living", "Switch_Kitchen", "Switch_Hall", "Switch_Landing"]:
			n.call("set_lights_on_silent", false)
	print("[TEST] E lights off: Living/Kitchen/Hall/Landing")
	var relit := false
	for i in 60 * 120:
		await physics_frame
		for n in sws:
			if String(n.name) in ["Switch_Living", "Switch_Kitchen", "Switch_Hall", "Switch_Landing"] and bool(n.call("is_on")):
				print("[TEST] E %s relit after %.1f s" % [n.name, i / 60.0])
				relit = true
		if relit:
			break
	# F) Dark helper.
	p.global_position = Vector3(0.0, 0.05, -1.0)
	for n in sws:
		n.call("set_lights_on_silent", false)
	await physics_frame
	print("[TEST] F living dark=%s" % w.call("_is_dark_between", p))
	for n in sws:
		n.call("set_lights_on_silent", true)
	await physics_frame
	print("[TEST] F living lit: dark=%s" % w.call("_is_dark_between", p))
	# G) Priorities: Tash on F2, F2 lights out, radio on downstairs -> nearby F2 switch first.
	for n in sws:
		n.call("set_lights_on_silent", true)
	var got_f2 := false
	for i in 60 * 240:
		await physics_frame
		if w.global_position.y > 2.5 and w.call("_radio_busy_reason") == "" and not bool(w.get("_inv_pending")) and w.get("_inv_switch") == null:
			got_f2 = true
			break
	if not got_f2:
		print("[TEST] G Tash never reached F2 free; skipped")
	else:
		for n in sws:
			if (n as Node3D).global_position.y > 2.6 and not (String(n.name) in ["Switch_SabiraRoom", "Switch_Hidden"]):
				n.call("set_lights_on_silent", false)
		print("[TEST] G tash on F2 at %s; F2 lights off, radio on" % w.global_position)
		_press(p, rt)
		var first := ""
		for i in 60 * 150:
			await physics_frame
			if i % 600 == 0:
				print("[TEST] G t=%d busy='%s' act=%s inv_switch=%s radio=%s pend=%s dark=%s inv_pending=%s" % [i / 60, w.call("_radio_busy_reason"), w.get("_act"), w.get("_inv_switch"), w.get("_radio"), w.get("_radio_pending"), (w.get("_dark_pending") as Dictionary).keys(), w.get("_inv_pending")])
			var cur = w.get("_inv_switch")
			if first == "" and cur != null:
				first = String((cur as Node).name)
				print("[TEST] G first task: %s (%s)" % [first, "PASS" if first != "RadioToggle" else "FAIL"])
			if first != "" and not bool(rt.call("is_on")):
				print("[TEST] G radio off after %.1f s (second task)" % (i / 60.0))
				break
	quit()
