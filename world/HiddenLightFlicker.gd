# Godot 4.x - Sabira / HOUSE
extends OmniLight3D
## Inconsistent flicker for HiddenRoom light. Respects LightSwitch off residual.

@export var base_energy: float = 2.2
@export var min_energy: float = 0.12
@export var max_energy: float = 2.35

const OFF_THRESHOLD := 0.055

var _timer: float = 0.0
var _hold_timer: float = 0.0
var _flicker_mult: float = 1.0


func _ready() -> void:
	if light_energy > OFF_THRESHOLD:
		base_energy = light_energy
	_timer = randf_range(0.05, 0.25)
	_hold_timer = 0.0
	_flicker_mult = 1.0


func get_base_energy() -> float:
	return base_energy


func _process(delta: float) -> void:
	# Switch off: leave residual alone; do not fight LightSwitch.
	if light_energy <= OFF_THRESHOLD:
		return
	if _hold_timer > 0.0:
		_hold_timer -= delta
		light_energy = base_energy * _flicker_mult
		return
	_timer -= delta
	if _timer > 0.0:
		light_energy = base_energy * _flicker_mult
		return
	# Occasional steady hold for inconsistent feel.
	if randf() < 0.18:
		_flicker_mult = randf_range(0.85, 1.02)
		_hold_timer = randf_range(0.4, 1.2)
		_timer = 0.0
	else:
		var roll := randf()
		if roll < 0.12:
			# Deep dip
			_flicker_mult = randf_range(0.08, 0.22)
		elif roll < 0.22:
			# Brief spike
			_flicker_mult = randf_range(1.0, 1.08)
		else:
			_flicker_mult = randf_range(min_energy / maxf(base_energy, 0.01), max_energy / maxf(base_energy, 0.01))
			_flicker_mult = clampf(_flicker_mult, 0.05, 1.08)
		_timer = randf_range(0.05, 0.35)
	light_energy = base_energy * _flicker_mult
