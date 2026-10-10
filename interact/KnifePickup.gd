# Godot 4.x - Sabira / HOUSE
class_name KnifePickup
extends Interactable
## Knife take + return-to-spawn only (kitchen table / knife spawn).
## Empty: [E] Take knife -> Took the knife.
## Holding: [E] Put the knife back. -> Left the knife. (frees slot, respawns mesh)

@export var take_line: String = "Took the knife."
@export var return_line: String = "Left the knife."
@export var line_duration: float = 2.0
@export var take_prompt: String = "[E] Take knife"
@export var return_prompt: String = "[E] Put the knife back."
@export var take_stream: AudioStream
@export var take_volume_db: float = -18.0

var _take_sfx: AudioStreamPlayer3D
var _sedated_knife_line_said: bool = false
var _sedated_knife_last: String = ""

var _dead_knife_last: String = ""

## After Tash is dead (couch stab). Random, no immediate repeat.
const _DEAD_KNIFE_LINES: PackedStringArray = [
	"He won't be torturing us anymore.",
	"It's done. No more tears. No more scars.",
]

const _SEDATED_KNIFE_LINES: PackedStringArray = [
	"For everything he did to Mom. He's a monster.",
	"Now or never. I end him.",
	"Or should I?",
]


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	_ensure_take_player()
	if GameState and GameState.has_knife:
		_consume_visual()
	else:
		_restore_visual()
	_sync_world_blood()
	_refresh_prompt()


func can_interact(_player: Node) -> bool:
	return interact_enabled and GameState != null


func get_prompt() -> String:
	if GameState == null:
		return ""
	if GameState.has_knife:
		return return_prompt
	return take_prompt


func _ensure_take_player() -> void:
	_take_sfx = get_node_or_null("TakePlayer") as AudioStreamPlayer3D
	if _take_sfx == null:
		_take_sfx = AudioStreamPlayer3D.new()
		_take_sfx.name = "TakePlayer"
		_take_sfx.max_distance = 10.0
		add_child(_take_sfx)
	if take_stream == null:
		take_stream = load("res://audio/sfx/ui_soft_click.wav") as AudioStream
	_take_sfx.stream = take_stream
	_take_sfx.volume_db = take_volume_db
	_take_sfx.bus = &"Master"


func _play_take_sfx() -> void:
	if _take_sfx == null:
		_ensure_take_player()
	if _take_sfx and _take_sfx.stream:
		_take_sfx.pitch_scale = randf_range(0.96, 1.04)
		_take_sfx.volume_db = take_volume_db + randf_range(-1.0, 0.5)
		_take_sfx.play()


func _on_interact(_player: Node) -> void:
	if GameState == null:
		return
	if GameState.has_knife:
		_return_knife()
	else:
		_take_knife()


func _take_knife() -> void:
	if GameState.has_knife:
		return
	# Capacity first: full => Can't carry more. (GameState); knife stays in world.
	if not GameState.add_inventory_flag("knife"):
		return
	_play_take_sfx()
	_say_take_line()
	_consume_visual()
	_sync_world_blood()
	_refresh_prompt()


func _return_knife() -> void:
	if not GameState.has_knife:
		return
	if not GameState.remove_inventory_flag("knife"):
		return
	_play_take_sfx()
	_restore_visual()
	_sync_world_blood()
	if not return_line.is_empty():
		get_tree().call_group("subtitle", "show_line", "SABIRA", return_line, line_duration)
	_refresh_prompt()


func _consume_visual() -> void:
	visible = true
	for c in get_children():
		if c is CollisionShape3D:
			continue
		if String(c.name) == "TableBlood":
			continue
		if c is Node3D:
			(c as Node3D).visible = false


func _restore_visual() -> void:
	visible = true
	for c in get_children():
		if c is CollisionShape3D:
			continue
		if c is Node3D:
			(c as Node3D).visible = true


func _refresh_prompt() -> void:
	prompt_text = get_prompt()

func _say_take_line() -> void:
	# After the stab: aftermath lines instead of the sedated ones (never Took the knife).
	if GameState != null and GameState.is_tash_dead():
		var dead_line := _pick_dead_knife_line()
		if dead_line != "":
			_show_sabira_deferred(dead_line, 3.5)
		return
	# While he is sedated, never say Took the knife. That line was replacing the reaction.
	if GameState != null and GameState.tash_sedated:
		if not _sedated_knife_line_said:
			_sedated_knife_line_said = true
			var line := _pick_sedated_knife_line()
			if line != "":
				_show_sabira_deferred(line, 3.5)
		return
	if take_line != "":
		get_tree().call_group("subtitle", "show_line", "SABIRA", take_line, line_duration)

func _show_sabira_deferred(line: String, duration: float) -> void:
	# Next frame, so a same-frame Took the knife cannot cover it.
	_show_sabira_line.call_deferred(line, duration)

func _show_sabira_line(line: String, duration: float) -> void:
	var tree := get_tree()
	if tree == null or line == "":
		return
	tree.call_group("subtitle", "show_line", "SABIRA", line, duration)

func _pick_sedated_knife_line() -> String:
	var choices: Array[String] = []
	for line in _SEDATED_KNIFE_LINES:
		if line != _sedated_knife_last:
			choices.append(line)
	if choices.is_empty():
		return ""
	var pick: String = choices[randi() % choices.size()]
	_sedated_knife_last = pick
	return pick

func _pick_dead_knife_line() -> String:
	var choices: Array[String] = []
	for line in _DEAD_KNIFE_LINES:
		if line != _dead_knife_last:
			choices.append(line)
	if choices.is_empty():
		return ""
	var pick: String = choices[randi() % choices.size()]
	_dead_knife_last = pick
	return pick

func _sync_world_blood() -> void:
	var bloody := GameState != null and GameState.knife_bloody
	var on_table := GameState == null or not GameState.has_knife
	var mesh := get_node_or_null("Mesh") as Node
	if bloody and on_table:
		if mesh != null:
			_paint_knife(mesh)
		_ensure_table_stain()
		return
	if mesh != null:
		_clear_knife_paint(mesh)


func _ensure_table_stain() -> void:
	if get_node_or_null("TableBlood") != null:
		return
	var stain := MeshInstance3D.new()
	stain.name = "TableBlood"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.055
	disc.bottom_radius = 0.075
	disc.height = 0.004
	disc.radial_segments = 20
	stain.mesh = disc
	stain.position = Vector3(0.0, 0.012, 0.0)
	stain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.42, 0.02, 0.03, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	stain.material_override = mat
	add_child(stain)


func _paint_knife(node: Node) -> void:
	if node is MeshInstance3D and String(node.name) != "KnifeBlood" and String(node.name) != "TableBlood":
		var mi := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		var active := mi.get_active_material(0)
		if active != null:
			var copied := active.duplicate() as Material
			if copied is StandardMaterial3D:
				mat = copied as StandardMaterial3D
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.36, 0.025, 0.03)
		mi.material_override = mat
	if node is Node3D and String(node.name) == "Mesh" and node.get_node_or_null("KnifeBlood") == null:
		var stain := MeshInstance3D.new()
		stain.name = "KnifeBlood"
		var box := BoxMesh.new()
		box.size = Vector3(0.018, 0.008, 0.06)
		stain.mesh = box
		stain.position = Vector3(0.0, 0.006, 0.04)
		stain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var blob := StandardMaterial3D.new()
		blob.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		blob.albedo_color = Color(0.48, 0.02, 0.03)
		blob.cull_mode = BaseMaterial3D.CULL_DISABLED
		stain.material_override = blob
		node.add_child(stain)
	for child in node.get_children():
		if String(child.name) == "KnifeBlood" or String(child.name) == "TableBlood":
			continue
		_paint_knife(child)


func _clear_knife_paint(node: Node) -> void:
	if String(node.name) == "TableBlood":
		return
	if node is MeshInstance3D and String(node.name) != "KnifeBlood":
		(node as MeshInstance3D).material_override = null
	var blob := node.get_node_or_null("KnifeBlood")
	if blob != null and node == get_node_or_null("Mesh"):
		blob.queue_free()
	for child in node.get_children():
		if String(child.name) == "TableBlood":
			continue
		_clear_knife_paint(child)
