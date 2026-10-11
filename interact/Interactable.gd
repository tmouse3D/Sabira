# Godot 4.x ?- Sabira / HOUSE
class_name Interactable
extends StaticBody3D
## Base interactable. Override interact() in subclasses (e.g. Door).

@export var prompt_text: String = "[E] Interact"
@export var interact_enabled: bool = true
## > 0: only targetable when the interact ray hit point is within this many metres of the
## camera (Player checks it). 0 = the player's normal interact_distance.
@export var max_interact_distance: float = 0.0
## Front-side gate: when on, only usable while dot(front_forward, flat(player - front_origin))
## > 0. front_forward / front_origin are world-space (set by the owner, e.g. CouchSearch).
@export var front_only: bool = false
@export var front_forward: Vector3 = Vector3.ZERO
@export var front_origin: Vector3 = Vector3.ZERO

signal interacted(player: Node)


func get_prompt() -> String:
	return prompt_text if interact_enabled else ""


func can_interact(player: Node) -> bool:
	return interact_enabled and front_ok(player)


## True unless front_only is on and the player stands behind (or level with) the front plane.
func front_ok(player: Node) -> bool:
	if not front_only or front_forward.length_squared() < 0.0001:
		return true
	if player == null or not (player is Node3D):
		return true
	var to := (player as Node3D).global_position - front_origin
	to.y = 0.0
	var f := front_forward
	f.y = 0.0
	if to.length_squared() < 0.0001 or f.length_squared() < 0.0001:
		return true
	return f.normalized().dot(to.normalized()) > 0.0


## Copy another interactable's front gate + reach cap (props revealed on a couch site).
func copy_front_gate(src: Interactable) -> void:
	if src == null or not src.front_only:
		return
	front_only = true
	front_forward = src.front_forward
	front_origin = src.front_origin
	max_interact_distance = src.max_interact_distance


func interact(player: Node) -> void:
	if not can_interact(player):
		return
	interacted.emit(player)
	_on_interact(player)


func _on_interact(_player: Node) -> void:
	pass
