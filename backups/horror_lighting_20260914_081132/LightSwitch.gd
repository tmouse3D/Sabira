# Godot 4.x - Sabira / HOUSE
extends Interactable
## Wall switch: toggles one room's light node(s) only. Scriptwriter prompts (no Sabira line).

@export var light_paths: Array[NodePath] = []

var _lights: Array[Light3D] = []
var _saved_energy: Dictionary = {}  # Light3D -> float
var _lights_on: bool = true


func _ready() -> void:
	collision_layer = 5  # world (1) + interactable (4)
	collision_mask = 0
	interact_enabled = true
	_resolve_lights()
	_capture_energies()
	_sync_state_from_lights()
	_update_prompt()


func _resolve_lights() -> void:
	_lights.clear()
	for p in light_paths:
		if p == NodePath(""):
			continue
		var n := get_node_or_null(p)
		if n is Light3D:
			_lights.append(n as Light3D)


func _capture_energies() -> void:
	for light in _lights:
		if light == null or not is_instance_valid(light):
			continue
		if not _saved_energy.has(light):
			var e: float = light.light_energy
			_saved_energy[light] = e if e > 0.001 else 0.35


func _sync_state_from_lights() -> void:
	_lights_on = false
	for light in _lights:
		if light and is_instance_valid(light) and light.light_energy > 0.001:
			_lights_on = true
			break


func _update_prompt() -> void:
	if _lights_on:
		prompt_text = "[E] Turn lights off"
	else:
		prompt_text = "[E] Turn lights on"


func _on_interact(_player: Node) -> void:
	if _lights.is_empty():
		_resolve_lights()
		_capture_energies()
		_sync_state_from_lights()
	if _lights.is_empty():
		push_warning("LightSwitch '%s': no lights resolved; check light_paths" % name)
		return
	_lights_on = not _lights_on
	for light in _lights:
		if light == null or not is_instance_valid(light):
			continue
		if _lights_on:
			var restore: float = float(_saved_energy.get(light, 0.35))
			if restore <= 0.001:
				restore = 0.35
			light.light_energy = restore
			light.visible = true
		else:
			if light.light_energy > 0.001:
				_saved_energy[light] = light.light_energy
			light.light_energy = 0.0
	_update_prompt()
