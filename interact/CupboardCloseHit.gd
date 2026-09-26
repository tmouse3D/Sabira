# Godot 4.x - Sabira / HOUSE
class_name CupboardCloseHit
extends Interactable
## Thin door-leaf / frame hitbox active only while host prop is open.
## Forwards interact to host (CupboardOpen / PropHingeDoor) so Close still works when
## the large volume body has collision_layer=0 (ray reaches interior pickups).

var host: Interactable


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	interact_enabled = false
	prompt_text = "[E] Close"


func setup(owner_host: Interactable, prompt: String) -> void:
	host = owner_host
	if not prompt.is_empty():
		prompt_text = prompt


func set_active(on: bool) -> void:
	collision_layer = 5 if on else 0
	interact_enabled = on


func _on_interact(player: Node) -> void:
	if host:
		host._on_interact(player)
