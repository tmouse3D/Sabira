# Godot 4.x - Sabira / HOUSE
class_name TashDrunkLook
extends Interactable
## E Look on Tash only while he is drunk-locked on the F1 living couch.
## Pool A: Amina lock still on. Pool B: GameState.mom_unlocked (padlock removed).
## Look never wakes him, never clears bottle_dosed, never resumes the route.
## With the knife, the same body prompts [E] Stab instead of Look.

@export var look_prompt: String = "[E] Look"
@export var stab_prompt: String = "[E] Stab"
@export var speaker: String = "SABIRA"
@export var line_duration: float = 3.5

## Default while Mom lock is still on.
const POOL_A: PackedStringArray = [
	"He's sleeping. I can get Mom out and tell everyone.",
	"I can move, but the doors squeak. Don't wake him.",
	"He's out cold. If I stay quiet, he won't hear a thing.",
]

## After cage_key unlock: GameState.mom_unlocked.
const POOL_B: PackedStringArray = [
	"He's down. This is my chance to end it.",
	"The knife. I could finish him while he sleeps.",
	"One cut and he's gone. I don't know if I can.",
	"The knife is in the kitchen. I don't know if I have the strength to do it.",
]

## After dying freezes. Look only. Stab stays off.
const POOL_CORPSE: PackedStringArray = [
	"It's done. I don't want to look at him.",
	"It's horrifying. I don't want to stay and look.",
	"I did this.",
]

var _corpse_look: bool = false

var _last_line: String = ""
var _walker: Node = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	interact_enabled = false
	prompt_text = ""
	_walker = get_parent()
	_ensure_shape()
	set_look_active(false)


func _ensure_shape() -> void:
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs != null:
		return
	cs = CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	# Slightly larger than Tash capsule so the ray hits this before layer-1 body.
	box.size = Vector3(0.72, 1.15, 0.72)
	cs.shape = box
	cs.position = Vector3(0.0, 0.72, 0.0)
	add_child(cs)


func set_look_active(active: bool) -> void:
	interact_enabled = active
	if active:
		collision_layer = 5
		prompt_text = look_prompt
	else:
		collision_layer = 0
		prompt_text = ""


func _is_drunk_locked() -> bool:
	if _walker != null and _walker.has_method("is_drunk_locked"):
		return bool(_walker.call("is_drunk_locked"))
	return false


func _is_dead() -> bool:
	if _walker != null and _walker.has_method("is_tash_dead"):
		return bool(_walker.call("is_tash_dead"))
	return false


func _has_knife() -> bool:
	return GameState != null and GameState.has_knife





func set_corpse_look(active: bool) -> void:
	_corpse_look = active
	set_look_active(active)
	if active:
		_reshape_for_corpse()


func _reshape_for_corpse() -> void:
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs == null:
		return
	var box := BoxShape3D.new()
	# Body lies along Z on the floor, in front of the couch.
	box.size = Vector3(0.8, 0.45, 1.8)
	cs.shape = box
	cs.position = Vector3(0.0, 0.16, 0.0)

func _eligible() -> bool:
	if _corpse_look:
		return interact_enabled and _is_dead()
	return interact_enabled and _is_drunk_locked() and not _is_dead()


func can_interact(_player: Node) -> bool:
	return _eligible()


func get_prompt() -> String:
	if not _eligible():
		return ""
	if _corpse_look:
		return look_prompt
	if _has_knife():
		return stab_prompt
	return look_prompt


func _pool() -> PackedStringArray:
	if _corpse_look:
		return POOL_CORPSE
	if GameState != null and GameState.mom_unlocked:
		return POOL_B
	return POOL_A


func _pick_line(pool: PackedStringArray) -> String:
	if pool.is_empty():
		return ""
	if pool.size() == 1:
		return pool[0]
	var choices: Array[String] = []
	for line in pool:
		if line != _last_line:
			choices.append(line)
	if choices.is_empty():
		choices.append(pool[0])
	var pick: String = choices[randi() % choices.size()]
	_last_line = pick
	return pick


func _on_interact(_player: Node) -> void:
	if not _eligible():
		return
	if _corpse_look:
		var corpse_line := _pick_line(POOL_CORPSE)
		if corpse_line == "":
			return
		get_tree().call_group("subtitle", "show_line", speaker, corpse_line, line_duration)
		return
	if _has_knife():
		if _walker != null and _walker.has_method("begin_couch_stab"):
			_walker.call("begin_couch_stab")
		return
	var line := _pick_line(_pool())
	if line == "":
		return
	get_tree().call_group("subtitle", "show_line", speaker, line, line_duration)
