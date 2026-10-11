# Godot 4.x - Sabira / HOUSE
class_name LightSwitch
extends Interactable
## Wall switch: toggles one room's light node(s) only. Scriptwriter prompts (no Sabira line).
## OFF leaves a tiny residual energy so the player can still navigate (horror near-black, not soft-lock).

@export var light_paths: Array[NodePath] = []
## False = toggling is silent (no GameState noise for Tash). Off on Switch_Hidden / Switch_Landing.
@export var makes_noise: bool = true

## Residual energy when "off" ?- enough to see walls, rooms still feel black.
const OFF_ENERGY := 0.03
## Energies at or below this count as off when syncing from scene.
const ON_THRESHOLD := 0.055

var _lights: Array[Light3D] = []
var _saved_energy: Dictionary = {}  # Light3D -> float (ON energy)
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
			# Prefer flicker script nominal energy so a dim frame is not saved as ON.
			if light.has_method("get_base_energy"):
				e = float(light.call("get_base_energy"))
			elif light.get("base_energy") != null:
				e = float(light.get("base_energy"))
			# Store the intended ON brightness (never the residual off value).
			if e > ON_THRESHOLD:
				_saved_energy[light] = e
			else:
				_saved_energy[light] = 0.35


func _sync_state_from_lights() -> void:
	_lights_on = false
	for light in _lights:
		if light and is_instance_valid(light) and light.light_energy > ON_THRESHOLD:
			_lights_on = true
			break


func _update_prompt() -> void:
	if _lights_on:
		prompt_text = "[E] Turn lights off"
	else:
		prompt_text = "[E] Turn lights on"


func _apply_lights() -> void:
	for light in _lights:
		if light == null or not is_instance_valid(light):
			continue
		if _lights_on:
			var restore: float = float(_saved_energy.get(light, 0.35))
			if restore <= ON_THRESHOLD:
				restore = 0.35
			light.light_energy = restore
			light.visible = true
		else:
			# Keep intended ON energy, then drop to residual.
			if light.has_method("get_base_energy"):
				_saved_energy[light] = float(light.call("get_base_energy"))
			elif light.light_energy > ON_THRESHOLD:
				_saved_energy[light] = light.light_energy
			light.light_energy = OFF_ENERGY
			light.visible = true  # residual must stay visible


func _on_interact(_player: Node) -> void:
	if _lights.is_empty():
		_resolve_lights()
		_capture_energies()
		_sync_state_from_lights()
	if _lights.is_empty():
		push_warning("LightSwitch '%s': no lights resolved; check light_paths" % name)
		return
	_lights_on = not _lights_on
	_apply_lights()
	_update_prompt()
	# Clicking a switch is a noise Tash can hear (GameState.noise_reported -> TashWalker).
	if GameState and makes_noise:
		GameState.report_noise(0.8, global_position, "light_switch:" + String(name))


func is_on() -> bool:
	return _lights_on


## Used by Tash (relight). No noise, no prompt sound.
func set_lights_on_silent(on: bool) -> void:
	if _lights.is_empty():
		_resolve_lights()
		_capture_energies()
	_lights_on = on
	_apply_lights()
	_update_prompt()
