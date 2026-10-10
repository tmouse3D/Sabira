# Godot 4.x - Sabira / HOUSE
class_name InteractHit
extends StaticBody3D
## Interact-ray-only target (layer 4) inside an Interactable. Bigger than the solid shape so
## the prop is easier to aim at, but the player never bumps into it (player mask is 1|8).
## Player._resolve_interactable walks up to the parent Interactable.
## Mirrors the parent: off whenever the parent is off the interact layer (4) (open cupboard,
## minute-hand site blocked) or its interact_enabled is false.

const HIT_LAYER := 4


func _ready() -> void:
	collision_mask = 0
	_sync()


func _physics_process(_delta: float) -> void:
	_sync()


func _sync() -> void:
	var p := get_parent() as CollisionObject3D
	var on := p != null and (p.collision_layer & HIT_LAYER) != 0
	if on and p is Interactable and not (p as Interactable).interact_enabled:
		on = false
	var want := HIT_LAYER if on else 0
	if collision_layer != want:
		collision_layer = want
