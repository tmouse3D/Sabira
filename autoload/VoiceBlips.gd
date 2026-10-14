# Godot 4.x - Sabira / HOUSE
extends Node
## Gibberish voices (autoload "Voices"). Short pitched syllable blips while a caption is shown.
## Blips are synthesised at boot (glottal pulse + two formants per vowel variant), no files.
## Hooks: GameState.caption_changed (ui/Subtitle.gd) and IntroSlides (speak / stop).
## Bus "Voice" (Settings.voice_volume). PROCESS_MODE_PAUSABLE: pausing the tree freezes the
## schedule and pauses the player, so the pause menu silences it.
## Signal blip(speaker, loud, sec) lets TashMouthCycle open the mouth on each blip.

signal blip(speaker: String, loud: bool, sec: float)

const MIX := 22050
const DEBUG_LOG := false

## Voice profiles. f0 Hz, formant scale, blip sec, letters per blip, gap sec, volume dB,
## pitch jitter (semitones), drive (distortion), breath noise.
const PROFILES := {
	"TASH": {"f0": 92.0, "fs": 0.82, "len": 0.085, "every": 3, "gap": 0.075, "db": -6.0, "jit": 1.2, "drive": 1.6, "noise": 0.10},
	"TASH_LOUD": {"f0": 128.0, "fs": 0.9, "len": 0.07, "every": 2, "gap": 0.055, "db": -1.5, "jit": 2.0, "drive": 4.5, "noise": 0.22},
	"TASH_INTRO": {"f0": 98.0, "fs": 0.85, "len": 0.09, "every": 3, "gap": 0.085, "db": -9.0, "jit": 0.8, "drive": 1.2, "noise": 0.06},
	"SABIRA": {"f0": 255.0, "fs": 1.18, "len": 0.06, "every": 2, "gap": 0.07, "db": -12.0, "jit": 1.0, "drive": 1.0, "noise": 0.03},
	"SABIRA_INTRO": {"f0": 240.0, "fs": 1.15, "len": 0.065, "every": 2, "gap": 0.08, "db": -13.0, "jit": 0.7, "drive": 1.0, "noise": 0.02},
	"DANA": {"f0": 300.0, "fs": 1.25, "len": 0.05, "every": 2, "gap": 0.06, "db": -11.0, "jit": 2.2, "drive": 1.0, "noise": 0.02},
	"MUM": {"f0": 205.0, "fs": 1.08, "len": 0.075, "every": 3, "gap": 0.09, "db": -12.0, "jit": 0.6, "drive": 1.0, "noise": 0.08},
	"NEUTRAL": {"f0": 165.0, "fs": 1.0, "len": 0.065, "every": 3, "gap": 0.075, "db": -12.0, "jit": 1.0, "drive": 1.0, "noise": 0.03},
}
## Vowel formants (F1, F2): a, e, i, o, u.
const VOWELS := [Vector2(750, 1150), Vector2(480, 1800), Vector2(300, 2200), Vector2(480, 850), Vector2(330, 900)]
const PAUSE_COMMA := 0.13
const PAUSE_STOP := 0.26

var _banks: Dictionary = {}  # profile -> Array[AudioStreamWAV]
var _players: Array[AudioStreamPlayer] = []
var _pi: int = 0
var _queue: Array = []  # [delay_sec, kind] kind 0 = blip, 1 = pause
var _t: float = 0.0
var _profile: String = ""
var _speaker: String = ""
var _loud: bool = false
## Scold boost (CatchSequence): extra dB on TASH blips and force the TASH_LOUD profile.
var tash_boost_db: float = 0.0
var tash_force_loud: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	_ensure_bus()
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.bus = &"Voice"
		add_child(p)
		_players.append(p)
	for k in PROFILES:
		_banks[k] = _make_bank(PROFILES[k], k.length() * 31)
	if GameState != null and GameState.has_signal("caption_changed"):
		GameState.caption_changed.connect(_on_caption)
	set_process(false)


func _ensure_bus() -> void:
	if AudioServer.get_bus_index("Voice") >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, "Voice")
	AudioServer.set_bus_send(i, "Master")


func _on_caption(speaker: String, text: String, _duration: float) -> void:
	if speaker == "" or text == "":
		stop()
		return
	speak(speaker, text)


## Start blips for a line (replaces any line in progress).
func speak(speaker: String, text: String, profile_override: String = "") -> void:
	stop()
	var sp := speaker.to_upper()
	_speaker = sp
	_loud = sp == "TASH" and (tash_force_loud or is_loud_tash(text))
	if profile_override != "":
		_profile = profile_override
	elif sp == "TASH":
		_profile = "TASH_LOUD" if _loud else "TASH"
	elif sp == "SABIRA":
		_profile = "SABIRA"
	elif sp == "DANA":
		_profile = "DANA"
	elif sp in ["MUM", "MOM", "AMINA", "MOTHER"]:
		_profile = "MUM"
	else:
		_profile = "NEUTRAL"
	if not PROFILES.has(_profile):
		_profile = "NEUTRAL"
	_queue = _schedule(text, PROFILES[_profile])
	_t = 0.0
	if DEBUG_LOG or OS.has_feature("voice_log"):
		print("[VOICE] %s (%s) %d blips: %s" % [sp, _profile, _count_blips(), text.left(40)])
	set_process(not _queue.is_empty())


func stop() -> void:
	if not _queue.is_empty() and (DEBUG_LOG or OS.has_feature("voice_log")):
		print("[VOICE] stop %s (%d left)" % [_speaker, _count_blips()])
	_queue.clear()
	set_process(false)


func is_speaking() -> bool:
	return not _queue.is_empty()


func current_speaker() -> String:
	return _speaker if is_speaking() else ""


## Yell / chase / first-sight / "!" captions (shared with TashMouthCycle).
func is_loud_tash(text: String) -> bool:
	if text.contains("!"):
		return true
	var t := get_tree().get_first_node_in_group("tash") if get_tree() else null
	if t == null:
		return false
	if bool(t.get("_chasing")):
		return true
	var ys = t.get("_CHASE_YELL_LINES")
	if ys is Array and (ys as Array).has(text):
		return true
	var fs = t.get("FIRST_SIGHT_LINES")
	if fs is Array:
		for chunk in fs:
			if chunk is Array and (chunk as Array).has(text):
				return true
	return false


func _count_blips() -> int:
	var n := 0
	for e in _queue:
		if e[1] == 0:
			n += 1
	return n


func _schedule(text: String, prof: Dictionary) -> Array:
	var q: Array = []
	var every: int = prof["every"]
	var gap: float = prof["gap"]
	var letters := 0
	for ch in text:
		if ch in ",;:-":
			q.append([PAUSE_COMMA, 1])
			letters = 0
		elif ch in ".!?":
			q.append([PAUSE_STOP, 1])
			letters = 0
		elif ch == " " or ch == "'" or ch == "\"":
			continue
		else:
			if letters % every == 0:
				q.append([gap * _rng.randf_range(0.85, 1.2), 0])
			letters += 1
	# Collapse runs of pauses ("..." / "?!").
	var out: Array = []
	for e in q:
		if e[1] == 1 and not out.is_empty() and out[-1][1] == 1:
			out[-1][0] = maxf(out[-1][0], e[0])
		else:
			out.append(e)
	return out


func _process(delta: float) -> void:
	_t -= delta
	while _t <= 0.0 and not _queue.is_empty():
		var e: Array = _queue.pop_front()
		if e[1] == 0:
			_play_blip()
		_t += float(e[0])
	if _queue.is_empty() and _t <= 0.0:
		set_process(false)


func _play_blip() -> void:
	var prof: Dictionary = PROFILES[_profile]
	var bank: Array = _banks[_profile]
	var p := _players[_pi]
	_pi = (_pi + 1) % _players.size()
	p.stream = bank[_rng.randi() % bank.size()]
	p.pitch_scale = pow(2.0, _rng.randf_range(-prof["jit"], prof["jit"]) / 12.0)
	p.volume_db = float(prof["db"]) + _rng.randf_range(-1.5, 1.0) + (tash_boost_db if _speaker == "TASH" else 0.0)
	p.play()
	blip.emit(_speaker, _loud, float(prof["len"]))


func _make_bank(prof: Dictionary, seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var bank: Array = []
	for v in VOWELS:
		bank.append(_synth(prof, v * float(prof["fs"]), rng))
	return bank


func _synth(prof: Dictionary, formants: Vector2, rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(MIX * float(prof["len"]))
	var f0: float = prof["f0"] * rng.randf_range(0.95, 1.05)
	var drive: float = prof["drive"]
	var noise_amt: float = prof["noise"]
	# Two resonators (2-pole bandpass) for the formants.
	var bp := [_bp_coef(formants.x, 90.0), _bp_coef(formants.y, 140.0)]
	var st := [[0.0, 0.0], [0.0, 0.0]]
	var phase := 0.0
	var data := PackedByteArray()
	data.resize(n * 2)
	var peak := 0.0
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var u := float(i) / n
		# Slight pitch fall over the syllable.
		var f := f0 * (1.06 - 0.12 * u)
		phase = fmod(phase + f / MIX, 1.0)
		var src := (1.0 - 2.0 * phase) + noise_amt * rng.randf_range(-1.0, 1.0)
		var y := 0.0
		for k in 2:
			var c: Array = bp[k]
			var o: float = c[0] * src - c[1] * st[k][0] - c[2] * st[k][1]
			st[k][1] = st[k][0]
			st[k][0] = o
			y += o * (1.0 if k == 0 else 0.6)
		var env := minf(u / 0.08, 1.0) * pow(1.0 - u, 1.6)
		y = tanh(y * drive * 0.5) * env
		buf[i] = y
		peak = maxf(peak, absf(y))
	var g := 0.85 / maxf(peak, 0.0001)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i] * g, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX
	w.stereo = false
	w.data = data
	return w


func _bp_coef(freq: float, bw: float) -> Array:
	var r := exp(-PI * bw / MIX)
	var a1 := -2.0 * r * cos(TAU * freq / MIX)
	var a2 := r * r
	return [1.0 - r, a1, a2]
