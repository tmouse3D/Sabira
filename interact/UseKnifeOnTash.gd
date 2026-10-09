# Godot 4.x - Sabira / HOUSE
class_name UseKnifeOnTash
extends Interactable
## Bedroom marker. Not the living-couch stab.
## Couch [E] Stab lives on TashDrunkLook while drunk-locked. catch_count does not gate that.
## This body stays inactive so it is not a second ray hit.

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	interact_enabled = false
	prompt_text = ""


func can_interact(_player: Node) -> bool:
	return false


func get_prompt() -> String:
	return ""


func _on_interact(_player: Node) -> void:
	return