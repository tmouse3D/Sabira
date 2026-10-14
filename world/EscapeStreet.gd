# Godot 4.x - Sabira / HOUSE
extends Node3D
## Escape street (GameState.trigger_escape_win -> here -> EndingCard). Night, heavy depth fog,
## a flat PSX street built in code: pavement, grass verges, a metal railing, facades (brick and
## white siding), utility boxes and flickering street lamps (world/FlickerLight.gd, desynced).
## A camera rig at the player's eye height auto-walks forward (no mouse look, small head bob),
## carrying Mum if she came along. If Mum was left behind, one warm window glows in the fog.
## Shortly after the fade-in, GameState.escape_start_card() plays the ending card lines as an
## overlay on top of the walk (EndingCard.play_over_scene); the walk continues until the card has
## faded to black (it pauses the tree), clamped at the end of the street.

const CARD_DELAY_SEC := 1.6
const SPEED_ALONE := 0.7
const SPEED_MUM := 0.4
const FADE_IN_SEC := 1.2
const STEP_SEC_ALONE := 0.85
const STEP_SEC_MUM := 1.15
const STREET_END_Z := -36.0
const FOG_DENSITY := 0.24
const DEAD_LAMP_EVERY := 3
const BOB_AMP := 0.025
const TEX := "res://textures/street/"
const SFX := "res://audio/sfx/street/"
const FLICKER := preload("res://world/FlickerLight.gd")

var _rig: Node3D
var _cam: Camera3D
var _t: float = 0.0
var _walking: bool = false
var _done: bool = false
var _card_started: bool = false
var _with_mum: bool = false
var _speed: float = SPEED_ALONE
var _step_sec: float = STEP_SEC_ALONE
var _step_t: float = 0.3
var _steps: Array[AudioStream] = []
var _step_player: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _dog: AudioStreamPlayer3D
var _dog_t: float = 2.2
var _mats: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_with_mum = GameState != null and GameState.escape_with_mum
	_speed = SPEED_MUM if _with_mum else SPEED_ALONE
	_step_sec = STEP_SEC_MUM if _with_mum else STEP_SEC_ALONE
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_environment()
	_build_street()
	_build_rig()
	_build_audio()
	if not _with_mum:
		_build_window_glow()
	if GameState != null:
		GameState.escape_fade_in(FADE_IN_SEC)
	_walking = true
	print("[STREET] walk at %.2f m/s, steps %.2f s (%s)" % [_speed, _step_sec, "with Mum" if _with_mum else "alone"])


func _mat(file: String, uv: Vector3 = Vector3.ONE, tint: Color = Color(1, 1, 1)) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [file, uv, tint]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + file) as Texture2D
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_scale = uv
	m.roughness = 1.0
	_mats[key] = m
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.005, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.11, 0.16)
	env.ambient_light_energy = 0.03
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.012, 0.014, 0.022)
	env.fog_density = FOG_DENSITY
	env.fog_sky_affect = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_street() -> void:
	var z0 := 6.0
	var z1 := -40.0
	var ln := z0 - z1
	var zc := (z0 + z1) * 0.5
	# Pavement path, curbs, grass verges, dark road beyond the left railing.
	_box(Vector3(2.0, 0.06, ln), Vector3(0, -0.03, zc), _mat("pavement.png", Vector3(2, ln * 0.5, 1)))
	_box(Vector3(0.15, 0.12, ln), Vector3(-1.07, 0.0, zc), _mat("curb.png", Vector3(1, ln, 1), Color(0.8, 0.8, 0.8)))
	_box(Vector3(0.15, 0.12, ln), Vector3(1.07, 0.0, zc), _mat("curb.png", Vector3(1, ln, 1), Color(0.8, 0.8, 0.8)))
	_box(Vector3(1.6, 0.04, ln), Vector3(-1.95, -0.02, zc), _mat("grass.png", Vector3(1, ln * 0.6, 1), Color(0.55, 0.62, 0.5)))
	_box(Vector3(2.2, 0.04, ln), Vector3(2.25, -0.02, zc), _mat("grass.png", Vector3(1, ln * 0.6, 1), Color(0.55, 0.62, 0.5)))
	_box(Vector3(9.0, 0.02, ln), Vector3(-7.3, -0.04, zc), _mat("curb.png", Vector3(4, ln * 0.5, 1), Color(0.25, 0.25, 0.28)))
	# Metal railing fence along the left verge.
	var metal := _mat("metal.png", Vector3.ONE, Color(0.55, 0.57, 0.6))
	var z := z0
	while z > z1:
		_box(Vector3(0.05, 1.0, 0.05), Vector3(-2.7, 0.5, z), metal)
		z -= 1.8
	_box(Vector3(0.04, 0.05, ln), Vector3(-2.7, 0.95, zc), metal)
	_box(Vector3(0.04, 0.05, ln), Vector3(-2.7, 0.5, zc), metal)
	# Facades on the right (flat boxes, alternating brick / white siding) with dark windows.
	var win := StandardMaterial3D.new()
	win.albedo_color = Color(0.02, 0.025, 0.04)
	win.roughness = 0.3
	var fz := z0
	var i := 0
	while fz > z1:
		var w := 4.0 + float(i % 3) * 1.2
		var h := 5.0 + float((i * 7) % 3)
		var brick := i % 2 == 0
		var mat := _mat("brick_red.png", Vector3(w / 1.5, h / 1.5, 1)) if brick else _mat("siding_white.png", Vector3(w / 1.2, h / 1.2, 1), Color(0.8, 0.8, 0.78))
		_box(Vector3(0.5, h, w), Vector3(4.6, h * 0.5, fz - w * 0.5), mat)
		for k in 2:
			_box(Vector3(0.04, 0.9, 0.7), Vector3(4.33, 1.6 + 2.0 * k, fz - w * 0.5 + (k - 0.5) * 1.4), win)
		fz -= w + 0.15
		i += 1
	# Distant row across the road (fog does the rest).
	fz = z0
	i = 0
	while fz > z1:
		var w2 := 5.0 + float(i % 2) * 2.0
		var h2 := 6.0 + float(i % 3)
		var mat2 := _mat("siding_white.png", Vector3(w2, h2, 1), Color(0.6, 0.6, 0.6)) if i % 2 == 0 else _mat("brick_red.png", Vector3(w2 / 1.5, h2 / 1.5, 1), Color(0.7, 0.7, 0.7))
		_box(Vector3(0.5, h2, w2), Vector3(-12.5, h2 * 0.5, fz - w2 * 0.5), mat2)
		fz -= w2 + 0.4
		i += 1
	# Utility boxes on the right verge.
	var ub := _mat("utility_box.png", Vector3.ONE, Color(0.7, 0.72, 0.7))
	_box(Vector3(0.45, 1.05, 0.6), Vector3(1.9, 0.52, -3.0), ub)
	_box(Vector3(0.4, 0.8, 0.5), Vector3(2.1, 0.4, -11.5), ub)
	# Street lamps (left verge, just inside the railing), each with a desynced flicker.
	var pole := _mat("metal.png", Vector3.ONE, Color(0.3, 0.31, 0.33))
	var lz := 2.0
	var li := 0
	while lz > z1:
		_lamp(Vector3(-2.35, 0, lz), pole, li % DEAD_LAMP_EVERY == DEAD_LAMP_EVERY - 1)
		lz -= 6.0
		li += 1


func _lamp(base: Vector3, pole: Material, dead: bool) -> void:
	_box(Vector3(0.1, 4.2, 0.1), base + Vector3(0, 2.1, 0), pole)
	_box(Vector3(0.8, 0.06, 0.08), base + Vector3(0.4, 4.15, 0), pole)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	bulb.mesh = sm
	var em := StandardMaterial3D.new()
	if dead:
		# Every 3rd lamp is dead: dark bulb, no light, no flicker.
		em.albedo_color = Color(0.08, 0.08, 0.07)
		em.roughness = 0.4
	else:
		em.albedo_color = Color(1.0, 0.85, 0.6)
		em.emission_enabled = true
		em.emission = Color(1.0, 0.8, 0.5)
		em.emission_energy_multiplier = 2.0
	bulb.material_override = em
	bulb.position = base + Vector3(0.75, 4.05, 0)
	add_child(bulb)
	if dead:
		return
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.78, 0.5)
	l.light_energy = 2.6
	l.omni_range = 7.0
	l.omni_attenuation = 1.3
	l.position = base + Vector3(0.75, 3.95, 0)
	l.set_script(FLICKER)
	add_child(l)


func _build_window_glow() -> void:
	# Mum left behind: one lit window in the fog, off to the left.
	var wall := _mat("siding_white.png", Vector3(4, 5, 1), Color(0.5, 0.5, 0.5))
	_box(Vector3(0.5, 6.0, 5.0), Vector3(-6.2, 3.0, -7.0), wall)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.75, 0.4)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.7, 0.35)
	glow.emission_energy_multiplier = 8.0
	_box(Vector3(0.05, 1.0, 0.8), Vector3(-5.93, 3.4, -7.0), glow)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.4)
	l.light_energy = 1.2
	l.omni_range = 3.5
	l.position = Vector3(-5.5, 3.4, -7.0)
	add_child(l)


func _build_rig() -> void:
	_rig = Node3D.new()
	_rig.name = "WalkRig"
	_rig.position = Vector3(0.1, 0, 3.0)
	add_child(_rig)
	_cam = Camera3D.new()
	_cam.name = "Camera3D"
	_cam.fov = GameState.escape_cam_fov if GameState != null else 75.0
	_cam.near = GameState.escape_cam_near if GameState != null else 0.05
	_cam.position = Vector3(0, GameState.escape_eye_height if GameState != null else 1.45, 0)
	_cam.rotation_degrees = Vector3(-2.0, 0, 0)
	_rig.add_child(_cam)
	_cam.make_current()
	if _with_mum and GameState != null:
		var mom := GameState.escape_take_mom()
		if mom != null:
			mom.reparent(_cam, false)
			mom.transform = GameState.escape_mom_transform()


func _build_audio() -> void:
	for i in range(1, 5):
		var s := load(SFX + "step_concrete_%d.ogg" % i) as AudioStream
		if s != null:
			_steps.append(s)
	_step_player = AudioStreamPlayer.new()
	_step_player.volume_db = -10.0
	add_child(_step_player)
	_wind = AudioStreamPlayer.new()
	_wind.stream = load(SFX + "wind_loop.wav") as AudioStream
	_wind.volume_db = -14.0
	_wind.finished.connect(func() -> void: _wind.play())
	add_child(_wind)
	_wind.play()
	_dog = AudioStreamPlayer3D.new()
	# Removed (polish_batch): dog_bark_far.wav read as a crying / whimpering dog at the ending.
	# The player stays with no stream, so the timed play below never fires.
	_dog.stream = null
	_dog.position = Vector3(-14.0, 1.0, -18.0)
	_dog.unit_size = 14.0
	_dog.volume_db = -6.0
	add_child(_dog)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _walking:
		_rig.position.z -= _speed * delta
		var bob := sin(_t * TAU / (_step_sec * 2.0))
		_cam.position.y = (GameState.escape_eye_height if GameState != null else 1.45) + BOB_AMP * absf(bob)
		_cam.position.x = BOB_AMP * 0.5 * bob
		_step_t -= delta
		if _step_t <= 0.0 and not _steps.is_empty():
			_step_t = _step_sec
			_step_player.stream = _steps[randi() % _steps.size()]
			_step_player.pitch_scale = randf_range(0.93, 1.05)
			_step_player.play()
	_dog_t -= delta
	if _dog_t <= 0.0 and _dog.stream != null:
		_dog.play()
		_dog_t = 999.0
	if not _card_started and _t >= CARD_DELAY_SEC:
		_card_started = true
		print("[STREET] ending card overlay starts")
		if GameState != null:
			GameState.escape_start_card()
	if _walking and _rig.position.z <= STREET_END_Z:
		_walking = false
