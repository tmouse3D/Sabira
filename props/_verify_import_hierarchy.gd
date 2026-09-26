extends SceneTree

func _init() -> void:
	var packed: PackedScene = load("res://props/Mom_Amina.glb") as PackedScene
	if packed == null:
		print("FAIL load Mom_Amina.glb")
		quit(1)
		return
	var root: Node = packed.instantiate()
	print("ROOT_NAME=", root.name)
	_dump(root, 0)
	var need := ["Mom_Amina_Root", "Body", "StumpBox_LArm", "StumpBox_RArm", "StumpBox_LLeg", "StumpBox_RLeg", "Mouth_Plea", "Mouth_Scream", "Mouth_Grimace"]
	for nm in need:
		var n: Node = root.find_child(nm, true, false)
		if n == null:
			print("MISSING ", nm)
		else:
			var p: Node = n.get_parent()
			print("OK ", nm, " parent=", p.name if p else "<none>")
	# mosaic material check on stump
	for sn in ["StumpBox_LArm", "StumpBox_RArm", "StumpBox_LLeg", "StumpBox_RLeg"]:
		var box: Node = root.find_child(sn, true, false)
		if box is MeshInstance3D:
			var mi := box as MeshInstance3D
			var mat := mi.get_active_material(0)
			print("MAT ", sn, " ", mat)
	quit(0)

func _dump(n: Node, depth: int) -> void:
	var pad := ""
	for i in depth:
		pad += "  "
	print(pad, n.name, " [", n.get_class(), "]")
	for c in n.get_children():
		_dump(c, depth + 1)