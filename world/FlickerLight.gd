# Godot 4.x - Sabira / The White Scarf
extends OmniLight3D
## Bare-bulb flicker: slight noise wobble, random dips, and brief buzz-offs (0.05-0.4 s) every
## random 2-10 s. Obeys its LightSwitch: the switch reads get_base_energy() and writes
## light_energy (OFF = 0.03); any outside write is taken as the new on/off state. An optional
## quiet 3D hum child ("Hum") plays only while on.

@export var wobble: float = 0.08
@export var dip_chance_per_s: float = 0.35
@export var buzz_min_gap: float = 2.0
@export var buzz_max_gap: float = 10.0
@export var on_threshold: float = 0.055

var _base: float = 1.0
var _on: bool = true
var _last_set: float = -1.0
var _t: float = 0.0
var _next_buzz: float = 4.0
var _buzz_left: float = 0.0
var _dip_left: float = 0.0
var _dip_depth: float = 1.0
var _hum: AudioStreamPlayer3D = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_base = light_energy
	_on = light_energy > on_threshold
	_last_set = light_energy
	# Desync per instance: own seed, random wobble phase and first buzz timer.
	_rng.randomize()
	_t = _rng.randf_range(0.0, 100.0)
	_next_buzz = _rng.randf_range(buzz_min_gap * 0.5, buzz_max_gap)
	_hum = get_node_or_null("Hum") as AudioStreamPlayer3D
	if _hum != null and _hum.stream is AudioStreamWAV:
		var w := (_hum.stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2
		_hum.stream = w
	_sync_hum()


func get_base_energy() -> float:
	return _base


func _process(delta: float) -> void:
	if absf(light_energy - _last_set) > 0.0005:
		# The switch (or anything else) wrote a new energy.
		_on = light_energy > on_threshold
		if _on:
			_base = light_energy
		_sync_hum()
	if not _on:
		_last_set = light_energy
		return
	_t += delta
	var f := 1.0 + (sin(_t * 23.0) * 0.5 + sin(_t * 61.0 + 1.3) * 0.3 + _rng.randf_range(-0.5, 0.5)) * wobble
	if _buzz_left > 0.0:
		_buzz_left -= delta
		f = 0.04 if _rng.randf() < 0.85 else 0.5
	else:
		_next_buzz -= delta
		if _next_buzz <= 0.0:
			_buzz_left = _rng.randf_range(0.05, 0.4)
			_next_buzz = _rng.randf_range(buzz_min_gap, buzz_max_gap)
	if _dip_left > 0.0:
		_dip_left -= delta
		f *= _dip_depth
	elif _rng.randf() < dip_chance_per_s * delta:
		_dip_left = _rng.randf_range(0.04, 0.18)
		_dip_depth = _rng.randf_range(0.35, 0.75)
	light_energy = maxf(_base * f, on_threshold + 0.01)
	if _buzz_left > 0.0:
		light_energy = _base * f
	_last_set = light_energy
	if _hum != null:
		_hum.volume_db = -30.0 if _buzz_left <= 0.0 else -42.0


func _sync_hum() -> void:
	if _hum == null:
		return
	if _on and not _hum.playing:
		_hum.play()
	elif not _on and _hum.playing:
		_hum.stop()
