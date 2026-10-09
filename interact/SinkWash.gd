# Godot 4.x - Sabira / HOUSE
class_name SinkWash
extends Interactable
## Bathroom sink. [E] Wash the knife only while the held knife is bloody.

@export var wash_prompt: String = "[E] Wash the knife"


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	prompt_text = wash_prompt


func can_interact(_player: Node) -> bool:
	return GameState != null and GameState.has_knife and GameState.knife_bloody


func get_prompt() -> String:
	if not can_interact(null):
		return ""
	return wash_prompt


func _on_interact(_player: Node) -> void:
	if not can_interact(_player):
		return
	get_tree().call_group("held_knife", "wash_blood")