# Godot 4.x - Sabira / HOUSE
class_name BookcasePush
extends Interactable
## Back face of the secret bookcase (hidden-room side). Hold [E] "Push": slides it open from
## behind, 3x slower than the button (BookcaseMover.push_*). Release pauses it (partial stop,
## like the button's Stop). Spawned as a child of Structure/BookcaseMover by KeySpawner, so it
## rides along with the bookcase. Layer 4 only (interact ray), never blocks or touches the navmesh.

const BACK_LOCAL := Vector3(0.016, 1.05, 0.0)    # BookcaseBody back face (x 0.046) - 3 cm
const SIZE := Vector3(0.05, 1.8, 1.3)            # thin slab, 1.3 m along the wall (Z)
const MAX_REACH := 2.0

var _mover: Node3D = null
var _player: Node3D = null


func setup(mover: Node3D) -> void:
	_mover = mover
	name = "BookcasePush"
	position = BACK_LOCAL
	collision_layer = 4
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = SIZE
	cs.shape = bs
	add_child(cs)
	prompt_text = "[Hold E] Push"


func can_interact(player: Node) -> bool:
	return interact_enabled and _mover != null and bool(_mover.call("can_push")) and _behind(player)


## Only from the hidden-room side (mover-local -X).
func _behind(player: Node) -> bool:
	if not (player is Node3D) or _mover == null:
		return false
	return _mover.to_local((player as Node3D).global_position).x < 0.0


func get_prompt() -> String:
	if _mover != null and bool(_mover.call("is_pushing")):
		return "[Hold E] Pushing..."
	return prompt_text


func _on_interact(player: Node) -> void:
	if _mover == null or bool(_mover.call("is_pushing")):
		return
	_player = player as Node3D
	_mover.call("push_begin")


func _process(delta: float) -> void:
	if _mover == null or not bool(_mover.call("is_pushing")):
		return
	var held := Input.is_physical_key_pressed(KEY_E)
	var near := _player != null and is_instance_valid(_player) and _player.global_position.distance_to(global_position) < MAX_REACH
	if held and near and not GameState.is_player_input_locked():
		_mover.call("push_tick", delta)
	else:
		_mover.call("push_end")
